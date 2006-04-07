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
    source_cost_type_id:integer,optional
    target_cost_type_id:integer
    {customer_id:integer ""}
    {provider_id:integer ""}
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
    ad_returnredirect new-copy-custselect?[export_url_vars source_cost_type_id target_cost_type_id customer_id provider_id blurb return_url]
}

set date_format "YYYY-MM-DD"
set tax_format "990.00"
set vat_format "990.00"
set price_per_unit_format "990.00"

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
	im_category_from_id(:target_cost_type_id) as target_cost_type,
	i.invoice_nr as org_invoice_nr,
	ci.customer_id,
	ci.provider_id,
	to_char(ci.effective_date,:date_format) as effective_date,
	ci.payment_days,
	to_char(ci.vat, :vat_format) as vat,
	to_char(ci.tax, :tax_format) as tax,
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
	and ci.customer_id = c.company_id
	and ci.provider_id = p.company_id
	and i.invoice_id = ci.cost_id
"

set invoice_mode "[_ intranet-invoices.clone]"
set page_title "[_ intranet-invoices.Clone] $target_cost_type"
set button_text [_ intranet-invoices.Submit]
set context_bar [im_context_bar [list /intranet/invoices/ "Finance"] $page_title]

set customer_select [im_company_select customer_id $customer_id "" "Customer"]
set provider_select [im_company_select provider_id $provider_id "" "Provider"]

# ---------------------------------------------------------------
# Modify some variable between the source and the target invoice
# ---------------------------------------------------------------

# Old one: add an "a" behind the invoice_nt to indicate
# a variant.
# set invoice_nr [im_invoice_nr_variant $org_invoice_nr]

# New One: Just create a new invoice nr
# for the target FinDoc type.
set invoice_nr [im_next_invoice_nr -invoice_type_id $target_cost_type_id]

set new_invoice_id [im_new_object_id]

# ToDo: Create a link between the invoice and the quote
# in order to indicate that the two belong together.
# Is this really a good idea? Invoice-from-Quote may
# workout fine, but other combinations?


# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Company" fields.
set invoice_or_quote_p [expr $target_cost_type_id == [im_cost_type_invoice] || $target_cost_type_id == [im_cost_type_quote]]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $target_cost_type_id == [im_cost_type_invoice] || $target_cost_type_id == [im_cost_type_bill]]

if {$invoice_or_quote_p} {
    set company_id $customer_id
    set company_type [_ intranet-core.Customer]
    set company_select $customer_select
} else {
    set company_id $provider_id
    set company_type [_ intranet-core.Provider]
    set company_select $provider_select
}


# ---------------------------------------------------------------
# Calculate the selects for the ADP page
# ---------------------------------------------------------------

set payment_method_select [im_invoice_payment_method_select payment_method_id $payment_method_id]
set template_select [im_cost_template_select template_id $template_id]
set status_select [im_cost_status_select cost_status_id $cost_status_id]
set type_select [im_cost_type_select cost_type_id $target_cost_type_id]

# ---------------------------------------------------------------
# Select and format the sum of the invoicable items
# ---------------------------------------------------------------

set ctr 1
set old_project_id 0
set colspan 6
set target_language_id ""
set task_sum_html ""
db_foreach invoice_items "" {

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
            [im_category_select "Intranet Project Type" item_type_id.$ctr $item_type_id]
          </td>
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='$item_units'>
	  </td>
          <td align=right>
            [im_category_select "Intranet UoM" item_uom_id.$ctr $item_uom_id]
	  </td>
          <td align=right><nobr>
	    <input type=text name=item_rate.$ctr size=3 value='$price_per_unit_formatted'>
	    <input type=hidden name=item_currency.$ctr value='$currency'>
	    $currency
	  </nobr></td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value='$project_id'>
"
    incr ctr
}

# ---------------------------------------------------------------
# Pass along the number of projects related to this document
# ---------------------------------------------------------------

set related_project_sql "
        select  object_id_one as project_id
        from    acs_rels r
        where   r.object_id_two = :source_invoice_id
"

set select_project_html ""
db_foreach related_project $related_project_sql {
        append select_project_html "<input type=hidden name=select_project value=$project_id>\n"
}


db_release_unused_handles
