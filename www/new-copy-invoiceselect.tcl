# /packages/intranet-invoices/www/new-copy-invoiceselect.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Copy existing financial document to a new one.
    @author frank.bergmann@project-open.com
} {
    source_cost_type_id:integer
    target_cost_type_id:integer
    {blurb "" }
    return_url
    { company_id:integer "" }
    { project_id:integer "" }
    { start_idx:integer 0 }
    { how_many "" }
    { view_name "invoice_select" }
}


# ---------------------------------------------------------------
# Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

# Make sure we can create invoices of target_cost_type_id...
set allowed_cost_type [im_cost_type_write_permissions $user_id]
if {[lsearch -exact $allowed_cost_type $target_cost_type_id] == -1} {
    ad_return_complaint "Insufficient Privileges" "
        <li>You can't create documents of type #$target_cost_type_id."
    ad_script_abort
}


# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------

set page_title "[_ intranet-invoices.Select_Customer]"
set context_bar [im_context_bar [list /intranet/invoices/ "[_ intranet-invoices.Finance]"] $page_title]
set submit_button_text [lang::message::lookup "" intranet-invoices.Select_documents "Select Documents"]


# Needed for im_view_columns, defined in intranet-views.tcl
set amp "&"
set cur_format [im_l10n_sql_currency_format]
set date_format [im_l10n_sql_date_format]

set cost_type [db_string get_cost_type "select category from im_categories where category_id=:target_cost_type_id" -default [_ intranet-invoices.Costs]]

if { [empty_string_p $how_many] || $how_many < 1 } {
    set how_many [ad_parameter -package_id [im_package_core_id] NumberResultsPerPage "" 50]
}
set end_idx [expr $start_idx + $how_many - 1]

if {![im_permission $user_id view_invoices]} {
    ad_return_complaint 1 "<li>You have insufficiente privileges to view this page"
    return
}

if {"" == $company_id && "" != $project_id} {
    set company_id [db_string company_id "select company_id from im_projects where project_id = :project_id" -default ""]
}

if {"" == $company_id} {
    ad_return_complaint 1 "<li>You must supply a value for company_id"
    ad_script_abort
}


# ---------------------------------------------------------------
# 3. Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#
set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name"]
set column_headers [list]
set column_vars [list]

set column_sql "
select
	column_name,
	column_render_tcl,
	visible_for
from
	im_view_columns
where
	view_id=:view_id
	and group_id is null
order by
	sort_order"

db_foreach column_list_sql $column_sql {
    if {"" == $visible_for || [eval $visible_for]} {
	lappend column_headers "$column_name"
	lappend column_vars "$column_render_tcl"
    }
}

# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------


set criteria [list]

if {"" != $project_id} {
    set project_cost_ids_sql "
		                select distinct cost_id
		                from im_costs
		                where project_id in (
					select	children.project_id
					from	im_projects parent,
						im_projects children
					where	children.tree_sortkey 
							between parent.tree_sortkey 
							and tree_right(parent.tree_sortkey)
						and parent.project_id = :project_id
				)
			    UNION
				select distinct object_id_two as cost_id
				from acs_rels
				where object_id_one in (
					select	children.project_id
					from	im_projects parent,
						im_projects children
					where	children.tree_sortkey 
							between parent.tree_sortkey 
							and tree_right(parent.tree_sortkey)
						and parent.project_id = :project_id
				)
    "

    lappend criteria "
	i.invoice_id in (
		$project_cost_ids_sql
	)
    "
}


# Don't add the customer/provider clause if we are
# selecting financial documents from a project.
# In a project, we may have POs for multiple providers...
if {"" != $company_id && "" == $project_id} {

    if {$source_cost_type_id == [im_cost_type_invoice] || $source_cost_type_id == [im_cost_type_quote] || $source_cost_type_id == [im_cost_type_delivery_note] || $source_cost_type_id == [im_cost_type_interco_invoice] || $source_cost_type_id == [im_cost_type_interco_quote]} {
        lappend criteria "i.customer_id = :company_id"
    } else {
        lappend criteria "i.provider_id = :company_id"
    }
}

set project_where_clause [join $criteria " and\n            "]
if { ![empty_string_p $project_where_clause] } {
    set project_where_clause " and $project_where_clause"
}

set order_by_clause "order by invoice_id DESC"

set sql "
select
        i.*,
	(to_date(to_char(i.invoice_date,:date_format),:date_format) + i.payment_days) as due_date_calculated,
	o.object_type,
	ci.amount as invoice_amount,
	ci.currency as invoice_currency,
	ci.paid_amount as payment_amount,
	ci.paid_currency as payment_currency,
	to_char(ci.amount,:cur_format) as invoice_amount_formatted,
    	im_email_from_user_id(i.company_contact_id) as company_contact_email,
      	im_name_from_user_id(i.company_contact_id) as company_contact_name,
        c.company_name as customer_name,
        c.company_path as company_short_name,
	p.company_name as provider_name,
	p.company_path as provider_short_name,
        im_category_from_id(i.invoice_status_id) as invoice_status,
        im_category_from_id(i.cost_type_id) as cost_type
from
        im_invoices_active i,
        im_costs ci,
	acs_objects o,
        im_companies c,
	im_companies p,
	(       select distinct
			cc.cost_center_id,
			ct.cost_type_id
		from    im_cost_centers cc,
			im_cost_types ct,
			acs_permissions p,
			party_approved_member_map m,
			acs_object_context_index c,
			acs_privilege_descendant_map h
		where
			p.object_id = c.ancestor_id
			and h.descendant = ct.read_privilege
			and c.object_id = cc.cost_center_id
			and m.member_id = :user_id
			and p.privilege = h.privilege
			and p.grantee_id = m.party_id
			and ct.cost_type_id = :source_cost_type_id
	) readable_ccs
where
	i.invoice_id = o.object_id
	and i.invoice_id = ci.cost_id
 	and i.customer_id = c.company_id
	and i.provider_id = p.company_id
	and ci.cost_type_id = :source_cost_type_id
	and ci.cost_center_id = readable_ccs.cost_center_id
	$project_where_clause
$order_by_clause
"

# ---------------------------------------------------------------
# 5a. Limit the SQL query to MAX rows and provide << and >>
# ---------------------------------------------------------------

# Limit the search results to N data sets only
# to be able to manage large sites
#
set limited_query [im_select_row_range $sql $start_idx $end_idx]
# We can't get around counting in advance if we want to be able to 
# sort inside the table on the page for only those users in the 
# query results
set total_in_limited [db_string invoices_total_in_limited "
	select count(*) 
        from ($sql) s
"]

# ad_return_complaint 1 $total_in_limited

set selection "select z.* from ($limited_query) z $order_by_clause"

# ---------------------------------------------------------------
# 7. Format the List Table Header
# ---------------------------------------------------------------

# Set up colspan to be the number of headers + 1 for the # column
set colspan [expr [llength $column_headers] + 1]

set table_header_html ""
append table_header_html "<tr>\n"
foreach col $column_headers {
    regsub -all " " $col "_" col_key
    regsub -all "\#" $col_key "hash_simbol" col_key
    append table_header_html "  <td class=rowtitle>[_ intranet-invoices.$col_key]</td>\n"
}

append table_header_html "<td class=rowtitle>[lang::message::lookup "" intranet-invoices.Sel "Sel"]</td>\n"
append table_header_html "</tr>\n"


# ---------------------------------------------------------------
# 8. Format the Result Data
# ---------------------------------------------------------------

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0
set idx $start_idx

db_foreach invoices_info_query $selection {

    # Append together a line of data based on the "column_vars" parameter list
    append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n"
    foreach column_var $column_vars {
	append table_body_html "\t<td valign=top>"
	set cmd "append table_body_html $column_var"
	eval $cmd
	append table_body_html "</td>\n"
    }
    set source_invoice_id $invoice_id

    append table_body_html "<td><input type=checkbox name=source_invoice_id value=$invoice_id></td>\n"
    append table_body_html "</tr>\n"

    incr ctr
    if { $how_many > 0 && $ctr >= $how_many } {
	break
    }
    incr idx
}


# Show a reasonable message when there are no result rows:
if { [empty_string_p $table_body_html] } {
    set table_body_html "
        <tr><td colspan=$colspan><ul><li><b> 
        [_ intranet-invoices.lt_There_are_currently_n]
        </b></ul></td></tr>"
}

if { $ctr == $how_many && $end_idx < $total_in_limited } {
    # This means that there are rows that we decided not to return
    # Include a link to go to the next page
    set next_start_idx [expr $end_idx + 1]
    set next_page_url "$local_url?start_idx=$next_start_idx&[export_ns_set_vars url [list start_idx]]"
} else {
    set next_page_url ""
}

if { $start_idx > 0 } {
    # This means we didn't start with the first row - there is
    # at least 1 previous row. add a previous page link
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 0 } { set previous_start_idx 0 }
    set previous_page_url "$local_url?start_idx=$previous_start_idx&[export_ns_set_vars url [list start_idx]]"
} else {
    set previous_page_url ""
}

# ---------------------------------------------------------------
# 9. Format Table Continuation
# ---------------------------------------------------------------

# Check if there are rows that we decided not to return
# => include a link to go to the next page 
#
if {$ctr==$how_many && $total_in_limited > 0 && $end_idx < $total_in_limited} {
    set next_start_idx [expr $end_idx + 1]
    set next_page "<a href=$local_url?start_idx=$next_start_idx&[export_ns_set_vars url [list start_idx]]>[_ intranet-invoices.Next_Page]</a>"
} else {
    set next_page ""
}

# Check if this is the continuation of a table (we didn't start with the 
# first row - there is at least 1 previous row.
# => add a previous page link
#
if { $start_idx > 0 } {
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 0 } { set previous_start_idx 0 }
    set previous_page "<a href=$local_url?start_idx=$previous_start_idx&[export_ns_set_vars url [list start_idx]]>[_ intranet-invoices.Previous_Page]</a>"
} else {
    set previous_page ""
}

set table_continuation_html "
<tr>
  <td align=center colspan=$colspan>
    [im_maybe_insert_link $previous_page $next_page]
  </td>
</tr>"



