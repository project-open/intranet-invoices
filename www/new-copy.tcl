# /packages/intranet-invoices/www/new-copy.tcl
#
# Copyright (C) 2003-2004 Project/Open
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
    source_invoice_id:integer,optional
    cost_type_id:integer
    { blurb "Copy Financial Document" }
    { return_url "/intranet-invoice/"}
}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}


# The user hasn't yet specified the source invoice from which
# we want to copy. So let's redirect and this page is going
# to refer us back to this one.
if {![info exists source_invoice_id]} {
    ad_returnredirect new-copy-custselect?[export_url_vars cost_type_id blurb return_url]
}


set return_url [im_url_with_query]
set todays_date [db_string get_today "select sysdate from dual"]
set page_focus "im_header_form.keywords"
set view_name "invoice_tasks"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"


# ---------------------------------------------------------------
# Get everything about the original document
# ---------------------------------------------------------------

db_1row invoices_info_query "
select
	im_category_from_id(:cost_type_id) as cost_type,
	i.invoice_nr as org_invoice_nr,
	ci.company_id,
	ci.provider_id,
	ci.effective_date,
	ci.payment_days,
	ci.vat,
	ci.tax,
	ci.amount,
	ci.currency,
	i.payment_method_id,
	ci.template_id,
	ci.cost_status_id,
	im_name_from_user_id(i.company_contact_id) as company_contact_name,
	im_email_from_user_id(i.company_contact_id) as company_contact_email,
	c.company_name as company_name,
	c.company_path as company_short_name,
	p.company_name as provider_name,
	p.company_path as provider_short_name
from
	im_invoices i, 
	im_costs ci,
	im_companies c,
	im_companies p
where 
        i.invoice_id = :source_invoice_id
	and ci.company_id=c.company_id(+)
	and ci.provider_id=p.company_id(+)
	and i.invoice_id = ci.cost_id
"

set invoice_mode "clone"
set button_text "Clone $cost_type"
set page_title "Clone $cost_type"
set context_bar [ad_context_bar [list /intranet/invoices/ "Finance"] $page_title]


# ---------------------------------------------------------------
# Modify some variable between the source and the target invoice
# ---------------------------------------------------------------

set invoice_nr [im_invoice_nr_variant $org_invoice_nr]
set new_invoice_id [im_new_object_id]


# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Company" fields.
set invoice_or_quote_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_quote]]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]]

if {$invoice_or_quote_p} {
    set company_id $company_id
} else {
    set company_id $provider_id
}


# ---------------------------------------------------------------
# Calculate the selects for the ADP page
# ---------------------------------------------------------------

set payment_method_select [im_invoice_payment_method_select payment_method_id $payment_method_id]
set template_select [im_cost_template_select template_id $template_id]
set status_select [im_cost_status_select cost_status_id $cost_status_id]
set type_select [im_cost_type_select cost_type_id $cost_type_id]
set company_select [im_company_select company_id $company_id "" "Company"]
set provider_select [im_company_select provider_id $provider_id "" "Provider"]

# ---------------------------------------------------------------
# Select and format the sum of the invoicable items
# ---------------------------------------------------------------

set invoice_item_sql "
select
	i.*,
	p.*,
	p.project_nr as project_short_name,
	im_category_from_id(i.item_uom_id) as item_uom,
	im_category_from_id(i.item_type_id) as item_type
from
	im_invoice_items i,
	im_projects p
where
	i.invoice_id = :source_invoice_id
	and i.project_id=p.project_id(+)
order by
	i.project_id
"

# start formatting the list of sums with the header...
set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>Line</td>
          <td class=rowtitle>Description</td>
          <td class=rowtitle>Type</td>
          <td class=rowtitle>Units</td>
          <td class=rowtitle>UOM</td>
          <td class=rowtitle>Rate</td>
        </tr>
"

set ctr 1
set old_project_id 0
set colspan 6
set target_language_id ""
db_foreach invoice_item $invoice_item_sql {
    
    # insert intermediate headers for every project
    if {$old_project_id != $project_id} {
	append task_sum_html "
		<tr><td class=rowtitle colspan=$colspan>
	          <A href=/intranet/projects/view?group_id=$project_id>$project_short_name</A>:
	          $project_name
	        </td></tr>\n"
	
	set old_project_id $project_id
    }

    append task_sum_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>
	    <input type=text name=item_sort_order.$ctr size=2 value='$sort_order'>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value='$item_name'>
	  </td>
          <td>
	    <input type=hidden name=item_type_id.$ctr value='$item_type_id'>
            $item_type
          </td>
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='$item_units'>
	  </td>
          <td align=right>
	    <input type=hidden name=item_uom_id.$ctr value='$item_uom_id'>
	    $item_uom
	  </td>
          <td align=right>
	    <input type=text name=item_rate.$ctr size=3 value='$price_per_unit'>
	    <input type=hidden name=item_currency.$ctr value='$currency'>
	    $currency
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value='$project_id'>
"
    incr ctr
}

# ---------------------------------------------------------------
# Add some empty new lines for editing purposes
# ---------------------------------------------------------------

# Add a fixed number of lines to enter data
#
for {set i 0} {$i < 3} {incr i} {
    
    append task_sum_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>
	    <input type=text name=item_sort_order.$ctr size=2 value=''>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value=''>
	  </td>
          <td>
            [im_category_select "Intranet Project Type" item_type_id.$ctr ""]
          </td>
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='0'>
	  </td>
          <td align=right>
            [im_category_select "Intranet UoM" item_uom_id.$ctr 320]
	  </td>
          <td align=right>
            <!-- rate and currency need to be together so that the line doesn't break -->
	    <input type=text name=item_rate.$ctr size=3 value='0'>[im_currency_select item_currency.$ctr $currency]
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value=''>
"

    incr ctr
}

# ---------------------------------------------------------------
# Pass along the number of projects related to this document
# ---------------------------------------------------------------

set related_project_sql "
        select  object_id_one as project_id
        from    acs_rels r
        where   r.object_id_two = :invoice_id
"

set select_project_html ""
db_foreach related_project $related_project_sql {
        append select_project_html "<input type=hidden name=select_project value=$project_id>\n"
}


db_release_unused_handles
