# /packages/intranet-invoices/www/new.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Receives the list of tasks to invoice, creates a draft invoice
    (status: "In Process") and displays it.
    Provides a button to advance to new-2.tcl, which takes the final
    steps of invoice generation by setting the state of the invoice
    to "Created" and the state of the associates im_tasks to "Invoiced".

    @param create_invoice_from_template
           Indicates that "Create Invoice" button was
           used to start creating an invoice from a Quote or a
           Provider Bill from a Purchase Order

    @author frank.bergmann@project-open.com
} {
    { include_task:multiple "" }
    { invoice_id:integer 0}
    { cost_type_id:integer "[im_cost_type_invoice]" }
    { customer_id:integer 0}
    { provider_id:integer 0}
    { project_id:integer 0}
    { invoice_currency ""}
    { create_invoice_from_template ""}
    { return_url "/intranet-invoice/"}
}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

# Check if we have to forward to "new-copy":
if {"" != $create_invoice_from_template} {
    ad_returnredirect [export_vars -base "new-copy" {invoice_id cost_type_id}]
    ad_script_abort
}


# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id view_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

set return_url [im_url_with_query]
set todays_date [db_string get_today "select sysdate from dual"]
set page_focus "im_header_form.keywords"
set view_name "invoice_tasks"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"


# Tricky case: Sombebody has called this page from a project
# So we need to find out the customer of the project and create
# an invoice from scratch, invoicing all project elements.
if {0 != $project_id} {
    set customer_id [db_string customer_id "select customer_id from im_projects where project_id=:project_id"]
}

# ---------------------------------------------------------------
# 3. Gather invoice data
#	a: if the invoice already exists
# ---------------------------------------------------------------

# Check if we are editing an already existing invoice
#
if {$invoice_id} {
    # We are editing an already existing invoice

    db_1row invoices_info_query "
select
	i.invoice_nr,
	ci.customer_id,
	ci.provider_id,
	ci.effective_date,
	ci.payment_days,
	ci.vat,
	ci.tax,
	ci.note as cost_note,
	i.payment_method_id,
	ci.template_id,
	ci.cost_status_id,
	ci.cost_type_id,
	im_category_from_id(ci.cost_type_id) as cost_type,
	im_name_from_user_id(i.customer_contact_id) as customer_contact_name,
	im_email_from_user_id(i.customer_contact_id) as customer_contact_email,
	c.customer_name as customer_name,
	c.customer_path as customer_short_name,
	p.customer_name as provider_name,
	p.customer_path as provider_short_name
from
	im_invoices i, 
	im_costs ci,
	im_customers c,
	im_customers p
where 
        i.invoice_id=:invoice_id
	and ci.customer_id = c.customer_id(+)
	and ci.provider_id = p.customer_id(+)
	and i.invoice_id = ci.cost_id
"

    set invoice_mode "exists"
    set button_text "Edit $cost_type"
    set page_title "Edit $cost_type"
    set context_bar [ad_context_bar [list /intranet/invoices/ "Finance"] $page_title]

    # Check if there is a single currency being used in the invoice
    # and get it.
    # This should always be the case, but doesn't need to...
    if {"" == $invoice_currency} {
	catch {
	    db_1row invoices_currency_query "
		select distinct
			currency as invoice_currency
		from	im_invoice_items i
		where	i.invoice_id=:invoice_id"
	} err_msg
    }

} else {

# ---------------------------------------------------------------
# Setup the fields for a new invoice
# ---------------------------------------------------------------

    # Build the list of selected tasks ready for invoices
    set invoice_mode "new"
    set in_clause_list [list]
    set cost_type [db_string cost_type "select im_category_from_id(:cost_type_id) from dual"]
    set button_text "New $cost_type"
    set page_title "New $cost_type"
    set context_bar [ad_context_bar [list /intranet/invoices/ "Finance"] $page_title]

    set invoice_id [im_new_object_id]
    set invoice_nr [im_next_invoice_nr]
    set cost_status_id [im_cost_status_created]
    set effective_date $todays_date
    set payment_days [ad_parameter -package_id [im_package_cost_id] "DefaultCustomerInvoicePaymentDays" "" 30] 
    set due_date [db_string get_due_date "select sysdate+:payment_days from dual"]
    set vat 0
    set tax 0
    set note ""
    set cost_note ""
    set payment_method_id ""
    set template_id ""
}

if {"" == $invoice_currency} {
    set invoice_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
}


# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Customer" fields.
set invoice_or_quote_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_quote]]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]]

if {$invoice_or_quote_p} {
    set company_id $customer_id
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
set customer_select [im_customer_select customer_id $customer_id "" "Customer"]
set provider_select [im_customer_select provider_id $provider_id "" "Provider"]


# ---------------------------------------------------------------
# 7. Select and format the sum of the invoicable items
# for a new invoice
# ---------------------------------------------------------------

if {[string equal $invoice_mode "new"]} {

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

    # Start formatting the "reference price list" as well, even though it's going
    # to be shown at the very bottom of the page.
    #
    set price_colspan 11
    set ctr 1
    set old_project_id 0
    set colspan 6
    set target_language_id ""

} else {

# ---------------------------------------------------------------
# 8. Get the old invoice items for an already existing invoice
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
	i.invoice_id = :invoice_id
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
}


# ---------------------------------------------------------------
# Add some empty new lines for editing purposes
# ---------------------------------------------------------------

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
	    <input type=text name=item_rate.$ctr size=3 value='0'>[im_currency_select item_currency.$ctr $invoice_currency]
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
	select	object_id_one as project_id
	from	acs_rels r
	where	r.object_id_two = :invoice_id
"

set select_project_html ""
db_foreach related_project $related_project_sql {
	append select_project_html "<input type=hidden name=select_project value=$project_id>\n"
}

db_release_unused_handles

