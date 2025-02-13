# /packages/intranet-invoices/www/list.tcl

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    List all invoices together with their payments

    @param order_by invoice display order 
    @param include_subinvoices_p whether to include sub invoices
    @param cost_status_id criteria for invoice status
    @param cost_type_id criteria for cost_type_id
    @param start_idx the starting index for query
    @param how_many how many rows to return

    @author mbryzek@arsdigita.com
    @cvs-id index.tcl,v 3.24.2.9 2000/09/22 01:38:44 kevin Exp
} {
    { order_by "Effective Date" }
    { filter_project_id:integer 0 }
    { cost_status_id:integer "[im_cost_status_created]" } 
    { cost_type_id:integer 0 } 
    { company_id:integer 0 } 
    { provider_id:integer 0 } 
    { start_date "" }
    { end_date "" }
    { start_idx:integer 0 }
    { how_many "" }
    { view_name "invoice_list" }
    { letter:trim "" }
    { format "html" }
    { number_locale "" }
}



# ---------------------------------------------------------------
# Invoice List Page
#
# This is List-Page with some special functions. It consists of the sections:
#    1. Page Contract: 
#	Receive the filter values defined as parameters to this page.
#    2. Defaults & Security:
#	Initialize variables, set default values for filters 
#	(categories) and limit filter values for unprivileged users
#    3. Define Table Columns:
#	Define the table columns that the user can see.
#	Again, restrictions may apply for unprivileged users,
#	for example hiding company names to freelancers.
#    4. Define Filter Categories:
#	Extract from the database the filter categories that
#	are available for a specific user.
#	For example "potential", "invoiced" and "partially paid" 
#	invoices are not available for unprivileged users.
#    5. Generate SQL Query
#	Compose the SQL query based on filter criteria.
#	All possible columns are selected from the DB, leaving
#	the selection of the visible columns to the table columns,
#	defined in section 3.
#    6. Format Filter
#    7. Format the List Table Header
#    8. Format Result Data
#    9. Format Table Continuation
#   10. Join Everything Together

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [auth::require_login]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set current_user_id $user_id
set today [lindex [split [ns_localsqltimestamp] " "] 0]
set page_title "[_ intranet-invoices.Financial_Documents]"
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set return_url [im_url_with_query]
# Needed for im_view_columns, defined in intranet-views.tcl
set amp "&"
set cur_format [im_l10n_sql_currency_format]
set date_format [im_l10n_sql_date_format]
set default_currency [im_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set local_url "/intranet-invoices/list"
set cost_status_created [im_cost_status_created]
set cost_type [db_string get_cost_type "select category from im_categories where category_id = :cost_type_id" -default [_ intranet-invoices.Costs]]
set letter [string toupper $letter]
set locale [lang::user::locale]
if {"" == $number_locale} { set number_locale $locale  }

if {![im_permission $user_id view_invoices]} {
    ad_return_complaint 1 "<li>You have insufficiente privileges to view this page"
    return
}

if { $how_many eq "" || $how_many < 1 } {
    set how_many [im_parameter -package_id [im_package_core_id] NumberResultsPerPage  "" 50]
}
set end_idx [expr {$start_idx + $how_many}]


if {"" == $start_date} { set start_date [parameter::get_from_package_key -package_key "intranet-cost" -parameter DefaultStartDate -default "2016-01-01"] }
if {"" == $end_date} { set end_date [parameter::get_from_package_key -package_key "intranet-cost" -parameter DefaultEndDate -default "2100-01-01"] }



# ---------------------------------------------------------------
# 3. Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#
set view_id [db_string get_view_id "
	select view_id 
	from im_views 
	where view_name = :view_name
" -default 0
]

if {0 == $view_id} {
    ad_return_complaint 1 "<b>View not found</b>:<br>
    We have got a 0 value for view=$view_id,
    indicating that this view has not been set up yet.<br>
    Please make sure to update to a recent version and to 
    apply the database update patches."
    return
}



set extra_selects [list]
set extra_froms [list]
set extra_wheres [list]

set column_sql "
	select	column_name,
		column_render_tcl,
		visible_for,
		extra_select,
		extra_from,
		extra_where,
		order_by_clause
	from	im_view_columns
	where	view_id = :view_id
		and group_id is null
	order by
		sort_order
"

# Get the main view
set column_headers [list]
set column_vars [list]
set view_order_by_clause ""
db_foreach column_list_sql $column_sql {
    set admin_html ""
    if {$user_is_admin_p} { 
	set url [export_vars -base "/intranet/admin/views/new-column" {column_id return_url}]
	set admin_html "<a href='$url'>[im_gif wrench ""]</a>" 
    }

    if {"" == $visible_for || [eval $visible_for]} {
	lappend column_headers "$column_name"
	lappend column_vars "$column_render_tcl"
	lappend column_headers_admin $admin_html
	if {"" != $extra_select} { lappend extra_selects [eval "set a \"$extra_select\""] }
	if {"" != $extra_from} { lappend extra_froms $extra_from }
	if {"" != $extra_where} { lappend extra_wheres $extra_where }
	if {"" != $order_by_clause && $order_by == $column_name} {
	    set view_order_by_clause $order_by_clause
	}
    }
}

# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

set criteria [list]

if { $filter_project_id ne "" && $filter_project_id > 0 } {
    lappend criteria "ci.project_id in (
	select	sub_p.project_id
	from	im_projects main_p,
		im_projects sub_p
	where	main_p.project_id = :filter_project_id and
		sub_p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey)
    )"
}

if { $cost_status_id ne "" && $cost_status_id > 0 } {
    lappend criteria "ci.cost_status_id in ([join [im_sub_categories $cost_status_id] ","])"
}

if { $cost_type_id ne "" && $cost_type_id != 0 } {
    lappend criteria "ci.cost_type_id in ([join [im_sub_categories $cost_type_id] ","])"
}
if { $company_id ne "" && $company_id != 0 } {
    lappend criteria "(ci.customer_id = :company_id OR ci.provider_id = :company_id)"
}
if { $provider_id ne "" && $provider_id != 0 } {
    lappend criteria "ci.provider_id = :provider_id"
}
if {"" != $start_date} {
    lappend criteria "ci.effective_date >= :start_date::timestamptz"
}
if {"" != $end_date} {
    lappend criteria "ci.effective_date < :end_date::timestamptz"
}



set extra_select [join $extra_selects ",\n\t"]
if { $extra_select ne "" } {
    set extra_select ",\n\t$extra_select"
}

set extra_from [join $extra_froms ",\n\t"]
if { $extra_from ne "" } {
    set extra_from ",\n\t$extra_from"
}

set extra_where [join $extra_wheres "and\n\t"]
if { $extra_where ne "" } {
    set extra_where ",\n\t$extra_where"
}



# Get the list of user's companies for which he can see invoices
set company_ids [db_list users_companies "
select
	company_id
from
	acs_rels r,
	im_companies c
where
	r.object_id_two = :user_id
	and r.object_id_one = c.company_id
"]

lappend company_ids 0

# Determine which invoices the user can see.
# Normally only those of his/her company...
# Special users ("view_invoices") don't need permissions.
set company_where ""
if {![im_permission $user_id view_invoices]} { 
    set company_where "and (i.customer_id in ([join $company_ids ","]) or i.provider_id in ([join $company_ids ","]))"
}
ns_log Notice "/intranet-invoices/index: company_where=$company_where"

set counter_reset_expression ""
set order_by_clause $view_order_by_clause

# If filter is set to Customer or Provider Doc's and no order_by is providedwe order by creation date.
# Before order_by was set to default (Document No). This way documents showed up grouped by document types. 
# Users want to see sub-types of Provider/Customer documents ordered by creation date by default.    

switch $order_by {
    "Document No" { 
	set order_by_clause "order by invoice_nr DESC" 
	set counter_reset_expression {$effective_month}
    }
    "Preview" { 
	set order_by_clause "order by invoice_nr" 
    }
    "Provider" { 
	set order_by_clause "order by provider_name" 
	set counter_reset_expression {$provider_id}
    }
    "Customer" { 
	set order_by_clause "order by customer_name" 
	set counter_reset_expression {$customer_id}
    }
    "Due Date" { 
	set order_by_clause "order by (due_date_calculated) ASC" 
	set counter_reset_expression {$effective_month}
    }
    "Amount" { 
	set order_by_clause "order by ci.amount DESC" 
    }
    "Paid" { 
	set order_by_clause "order by ci.paid_amount" 
    }
    "Status" { 
	set order_by_clause "order by cost_status_id" 
	set counter_reset_expression {$cost_status_id}
    }
    "Type" { 
	set order_by_clause "order by cost_type" 
	set counter_reset_expression {$cost_type_id}
    }
    "Effective Date" {
        set order_by_clause "order by cost_effective_date DESC"
    }
}

set where_clause [join $criteria " and\n            "]
if { $where_clause ne "" } {
    set where_clause " and $where_clause"
}

# -----------------------------------------------------------------
# Define extra SQL for payments
# -----------------------------------------------------------------

set payment_amount ""
set payment_currency ""

# -----------------------------------------------------------------
# Main SQL
# -----------------------------------------------------------------

set sql "
select	i.*,
	ci.*,
	(to_date(to_char(ci.effective_date, :date_format), :date_format) + ci.payment_days) as due_date_calculated,
        to_char(ci.effective_date, 'YYYY-MM-DD') as cost_effective_date,
	ci.currency as invoice_currency,
	ci.paid_amount as payment_amount,
	ci.paid_currency as payment_currency,
	pr.project_id,
	pr.project_nr,
	pr.project_name,
	to_char(ci.effective_date,  'YYYY-MM') as effective_month,
	ci.amount * (1 + coalesce(ci.vat, 0)/100 + coalesce(ci.tax, 0)/100) as invoice_amount,
    	im_email_from_user_id(i.company_contact_id) as company_contact_email,
      	im_name_from_user_id(i.company_contact_id) as company_contact_name,
	im_cost_center_code_from_id(ci.cost_center_id) as cost_center_code,
	c.company_id as invoice_company_id,
        c.company_name as customer_name,
        c.company_path as company_short_name,
	p.company_name as provider_name,
	p.company_path as provider_short_name,
	ci.cost_status_id as invoice_status_id,
        im_category_from_id(ci.cost_status_id) as invoice_status,
        im_category_from_id(ci.cost_status_id) as cost_status,
        im_category_from_id(ci.cost_type_id) as cost_type,
	now()::date - (ci.effective_date::date + ci.payment_days) as overdue
	$extra_select
from
        im_invoices i,
        im_costs ci
	LEFT OUTER JOIN im_projects pr on (ci.project_id = pr.project_id),
        im_companies c,
        im_companies p
	$extra_from
where
	i.invoice_id = ci.cost_id
 	and ci.customer_id = c.company_id
        and ci.provider_id = p.company_id
	and (ci.cost_center_id is NULL or ci.cost_center_id in (
		select distinct cc.cost_center_id
		from	im_cost_centers cc,
			im_cost_types ct,
			acs_permissions p,
			party_approved_member_map m,
			acs_object_context_index c,
			acs_privilege_descendant_map h
		where	p.object_id = c.ancestor_id
			and h.descendant = ct.read_privilege
			and c.object_id = cc.cost_center_id
			and m.member_id = :user_id
			and p.privilege = h.privilege
			and p.grantee_id = m.party_id
			and ct.cost_type_id = ci.cost_type_id
	))
	$company_where
        $where_clause
	$extra_where
$order_by_clause
"

# ---------------------------------------------------------------
# 5a. Limit the SQL query to MAX rows and provide << and >>
# ---------------------------------------------------------------

# Limit the search results to N data sets only
# to be able to manage large sites
#

if {$letter eq "ALL"} {
    # Set these limits to negative values to deactivate them
    set total_in_limited -1
    set how_many -1
    set selection $sql
} else {
    # We can't get around counting in advance if we want to be able to
    # sort inside the table on the page for only those users in the
    # query results
    set total_in_limited [db_string total_in_limited "
        select count(*)
        from ($sql) s
    "]
    set selection [im_select_row_range $sql $start_idx $end_idx]
}



# ---------------------------------------------------------------
# 6a. Format the Filter: Get the admin menu
# ---------------------------------------------------------------

set new_document_menu ""
set parent_menu_label ""

if {[im_category_is_a $cost_type_id [im_cost_type_company_doc]]} {
    set parent_menu_label "invoices_customers"
    set parent_menu_sql "'invoices_customers'"
} elseif {[im_category_is_a $cost_type_id [im_cost_type_provider_doc]]} {
    set parent_menu_label "invoices_providers"
    set parent_menu_sql "'invoices_providers'"
} else {
    set parent_menu_sql "'invoices_customers', 'invoices_providers'"
}

set menu_select_sql "
        select  m.*
        from    im_menus m
        where   parent_menu_id in (select menu_id from im_menus where label in ($parent_menu_sql))
                and im_object_permission_p(m.menu_id, :user_id, 'read') = 't'
        order by sort_order"

# Start formatting the menu bar
set new_document_menu "<ul>"
set ctr 0
db_foreach menu_select $menu_select_sql {
    ns_log Notice "im_sub_navbar: menu_name='$name'"
    regsub -all " " $name "_" name_key
    set name_loc [lang::message::lookup "" $package_name.$name_key $name]
    append new_document_menu "<li><a href=\"$url\">$name_loc</a></li>\n"
    incr ctr
}
append new_document_menu "</ul>"
if {0 == $ctr} { set new_document_menu "" }


# ---------------------------------------------------------------
# 6. Format the Filter
# ---------------------------------------------------------------

# Note that we use a nested table because im_slider might
# return a table with a form in it (if there are too many
# options
set filter_html "
	<form method=get action=\"/intranet-invoices/list\">
	[export_vars -form {order_by how_many view_name include_subinvoices_p}]
	<table border=0 cellpadding=1 cellspacing=1>
	  <tr>
	    <td>[_ intranet-invoices.Document_Status]</td>
	    <td>
              [im_category_select -include_empty_p 1 "Intranet Cost Status" cost_status_id $cost_status_id]
            </td>
	  </tr>
	  <tr>
	    <td>[_ intranet-invoices.Document_Type]</td>
	    <td>
              [im_category_select -include_empty_p 1 "Intranet Cost Type" cost_type_id $cost_type_id]
            </td>
	  </tr>
	  <tr>
	    <td>[lang::message::lookup "" intranet-invoices.Company "Company"]</td>
	    <td>
              [im_company_select -include_empty_p 1 -include_empty_name "All" company_id $company_id]
            </td>
	  </tr>
	  <tr>
	    <td>[_ intranet-core.Project]</td>
	    <td>
              [im_project_select -exclude_subprojects_p 1 -include_empty_p 1 filter_project_id $filter_project_id]
            </td>
	  </tr>
	  <tr>
	    <td class=form-label>[_ intranet-core.Start_Date]</td>
	    <td class=form-widget>
	      <input type='textfield' name='start_date' id='start_date' value='$start_date' size='10'><input id=start_date_calendar style=\"height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');\" type=\"button\">
	    </td>
	  </tr>
	  <tr>
	    <td class=form-label>[lang::message::lookup "" intranet-core.End_Date "End Date"]</td>
	    <td class=form-widget>
	      <input type='textfield' name='end_date' id='end_date' value='$end_date' size='10'><input id=end_date_calendar style=\"height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');\" type=\"button\">
	    </td>
	  </tr>

	  <tr>
	    <td class=form-label>[lang::message::lookup "" intranet-reporting.Format "Format"]</td>
	    <td class=form-widget>[im_report_output_format_select format "" $format]</td>
	  </tr>

          <tr>
              <td class=form-label>[lang::message::lookup "" intranet-reporting.NumberLocale "Number Locale"]</td>
              <td class=form-widget>
                  [im_report_number_locale_select number_locale $number_locale]
              </td>
          </tr>

	  <tr>
	    <td></td>
	    <td><input type=submit value='[_ intranet-invoices.Go]' name=submit></td>
	  </tr>
	</table>
	</form>"

# ---------------------------------------------------------------
# 7. Format the List Table Header
# ---------------------------------------------------------------

# Set up colspan to be the number of headers + 1 for the # column
set colspan [expr {[llength $column_headers] + 1}]

set table_header_html ""
set table_header_csv ""

# Format the header names with links that modify the
# sort order of the SQL query.
#
set url "$local_url?"
set query_string [export_ns_set_vars url [list order_by]]
if { $query_string ne "" } {
    append url "$query_string&"
}

append table_header_html "<tr>\n"
foreach col $column_headers {
    regsub -all " " $col "_" col_key
    regsub -all "#" $col_key "hash_simbol" col_key
    set col_loc [lang::message::lookup ""  intranet-invoices.$col_key $col]

    if {$order_by eq $col || [regexp {input} $col match]} {
	append table_header_html "  <td class=rowtitle>$col_loc</td>\n"
    } else {
	append table_header_html "  <td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col_loc</a></td>\n"
    }

    # Output for CSV format
    set csv_cell_cleaned [im_cvs_output_findoc_clean_cell -value $col_loc]
    append table_header_csv "$csv_cell_cleaned\t"
}

# Add input field 

append table_header_html "</tr>\n"


# ---------------------------------------------------------------
# Format the Result Data
# ---------------------------------------------------------------

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0
set idx $start_idx

db_foreach invoices_info_query $selection {

    set amount_formatted [im_report_format_number [expr round(100.0 * ($amount+0)) / 100.0] $format $number_locale]
    set invoice_amount_formatted [im_report_format_number [expr round(100.0 * ($invoice_amount+0)) / 100.0] $format $number_locale]
    set payment_amount_pretty [im_report_format_number [expr round(100.0 * ($payment_amount+0)) / 100.0] $format $number_locale]
    if {"" eq $payment_amount} { set payment_currency "" }
    
    set url [im_maybe_prepend_http $url]
    if { $url eq "" } {
	set url_string "&nbsp;"
    } else {
	set url_string "<a href=\"$url\">$url</a>"
    }

    # Don't show paid invices over due in red:
    if {$invoice_status_id == [im_cost_status_paid] || \
	$invoice_status_id == [im_cost_status_filed]} {
	set overdue 0
    }

    # paid_amount="" => paid_amount=0
    if {"" == $paid_amount} { set paid_amount 0}
    if {"" == $amount} { set amount 0}

    # ---- Deal with non-writable Invoices ----

    # Calculate the status-select drop-down for this invoice
    set status_select [im_cost_status_select "cost_status.$invoice_id" $invoice_status_id]

    set write_p [im_cost_center_write_p $cost_center_id $cost_type_id $user_id]
    if {!$write_p} {
	set status_select ""
	# Bad Trick: " " let the Del-checkbox disappear...
        if {"" == $payment_amount} { set payment_amount " " }
    }

    # ---- Set vars for "bulk payments"  ----
    set new_payment_amount "<nobr><input size='8' class='invoice_list_new_payment' name='new_payment_amount.$invoice_id' id='new_payment_amount.$invoice_id' amount='[string trim $invoice_amount_formatted]' style='text-align:right;'/>" 
    append new_payment_amount "[im_currency_select "new_payment_currency.$invoice_id" $default_currency]</nobr>"

    set new_payment_type_id "[im_payment_type_select new_payment_type_id.$invoice_id ""]<input type='hidden' name='new_payment_company_id.$invoice_id' value='$invoice_company_id' />"

    set new_payment_date "<input name=\"new_payment_date.$invoice_id\" id=\"new_payment_date.$invoice_id\" value=\"[clock format [clock seconds] -format {%Y-%m-%d}]\" size=\"10\" "
    append new_payment_date "type=\"textfield\"><input style=\"height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');\" " 
    append new_payment_date "onclick=\"return showCalendar('new_payment_date.$invoice_id', 'y-m-d');\" type=\"button\">"

    # ---- Display the main line ----
    # Append together a line of data based on the "column_vars" parameter list
    append table_body_html "<tr$bgcolor([expr {$ctr % 2}])>\n"
    foreach column_var $column_vars {
	append table_body_html "\t<td valign=top>"
	set cmd "append table_body_html $column_var"
	eval $cmd
	append table_body_html "</td>\n"

	# For CSV export
	set cmd "set csv_cell $column_var"
	eval $cmd
	set csv_cell_cleaned [im_cvs_output_findoc_clean_cell -value $csv_cell]
	ns_log Notice "list.tcl: cleaned=$csv_cell_cleaned, org=$csv_cell"
	append table_body_csv "$csv_cell_cleaned\t"
	
    }
    append table_body_html "</tr>\n"
    append table_body_csv "\n"

    # ----

    incr ctr
    if { $how_many > 0 && $ctr > $how_many } {
	break
    }
    incr idx
}

# Show a reasonable message when there are no result rows:
if { $table_body_html eq "" } {
    set table_body_html "
        <tr><td colspan=$colspan><ul><li><b> 
        [_ intranet-invoices.lt_There_are_currently_n]
        </b></ul></td></tr>"
}

if { $end_idx < $total_in_limited } {
    # This means that there are rows that we decided not to return
    # Include a link to go to the next page
    set next_start_idx [expr {$end_idx + 0}]
    set next_page_url "$local_url?start_idx=$next_start_idx&[export_ns_set_vars url [list start_idx]]"
    set next_page "<a href=$next_page_url>[_ intranet-invoices.Next_Page]</a>"
} else {
    set next_page_url ""
    set next_page ""
}

if { $start_idx > 0 } {
    # This means we didn't start with the first row - there is
    # at least 1 previous row. add a previous page link
    set previous_start_idx [expr {$start_idx - $how_many}]
    if { $previous_start_idx < 0 } { set previous_start_idx 0 }
    set previous_page_url "$local_url?start_idx=$previous_start_idx&[export_ns_set_vars url [list start_idx]]"
    set previous_page "<a href=$previous_page_url>[_ intranet-invoices.Previous_Page]</a>"
} else {
    set previous_page_url ""
    set previous_page ""
}

# ---------------------------------------------------------------
# 9. Format Table Continuation
# ---------------------------------------------------------------

set table_continuation_html "
<tr>
  <td align=center colspan=$colspan>
    [im_maybe_insert_link $previous_page $next_page]
  </td>
</tr>"

set invoice_options [list "<option value=save>[lang::message::lookup "" intranet-invoices.Save_Changes "Save Changes"]</option>\n"]
lappend invoice_options "<option value=del>[lang::message::lookup "" intranet-invoices.Delete "Delete"]</option>\n"
set options_sql "select * from im_cost_status"
db_foreach options $options_sql {
    regsub -all " " $cost_status "_" cost_status_mangled
    lappend invoice_options "<option value=status_$cost_status_id>[lang::message::lookup "" intranet-invoices.Set_to_status_$cost_status_mangled "Set to $cost_status"]</option>"
}

set button_html "
<tr>
  <td colspan=$colspan>
  <select name=invoice_action>
  $invoice_options
  </select>
  <input type=submit name=submit_save value='[lang::message::lookup "" intranet-invoices.Update_Financial_Documents "Update Financial Documents"]'>
  </td>
</tr>"


# ---------------------------------------------------------------
# Navbars
# ---------------------------------------------------------------

set sub_navbar [im_costs_navbar "no_alpha" "/intranet-invoices/list" $next_page_url $previous_page_url [list invoice_status_id cost_type_id company_id start_idx order_by how_many view_name start_date end_date] $parent_menu_label ]

set left_navbar_html "
            <div class='filter-block'>
                <div class='filter-title'>
                [_ intranet-invoices.Filter_Documents]
                </div>
                $filter_html
            </div>
" 

if { "" != $new_document_menu } {
    append left_navbar_html "
            <hr/>
            <div class='filter-block'>
                <div class='filter-title'>
                [_ intranet-invoices.lt_New_Company_Documents]
                </div>
                $new_document_menu
            </div>
            <hr/>
    "
}



# ---------------------------------------------------------------
# Handle CSV export
# ---------------------------------------------------------------

switch $format {
    "csv" {
	# Determine filename to write out
	set report_name "${cost_type}_list"
	set report_key [string tolower $report_name]
	regsub -all {[^a-zA-z0-9_]} $report_key "_" report_key
	regsub -all {_+} $report_key "_" report_key


	# Return the report contents
	set outputheaders [ns_conn outputheaders]
	ns_set cput $outputheaders "Content-Disposition" "attachment; filename=${report_key}.csv"
	doc_return 200 "application/csv" "$table_header_csv\n$table_body_csv"
	ad_script_abort
    }
    default {
	# just continue with the page to format output using template
    }
}
