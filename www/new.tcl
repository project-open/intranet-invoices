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
    { return_url "/intranet-invoices/list"}
    del_invoice:optional
}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]

# Check if we have to forward to "new-copy":
if {"" != $create_invoice_from_template} {
    ad_returnredirect [export_vars -base "new-copy" {invoice_id cost_type_id}]
    ad_script_abort
}

# Check if we need to delete the invoice.
# We get there because the "Delete" button in view.tcl can
# only send to one target, which is this file...
if {[info exists del_invoice]} {
    ad_returnredirect [export_vars -base delete {invoice_id return_url}]
}

im_cost_permissions $user_id $invoice_id view read write admin
if {!$write} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

set return_url [im_url_with_query]
set todays_date [db_string get_today "select to_char(sysdate,'YYYY-MM-DD') from dual"]
set page_focus "im_header_form.keywords"
set view_name "invoice_tasks"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"
set cost_note ""

set tax_format "90.9"
set vat_format "90.9"

# Tricky case: Sombebody has called this page from a project
# So we need to find out the company of the project and create
# an invoice from scratch, invoicing all project elements.
if {0 != $project_id} {
    set customer_id [db_string customer_id "select company_id from im_projects where project_id=:project_id"]
}

# ---------------------------------------------------------------
# 3. Gather invoice data
#	a: if the invoice already exists
# ---------------------------------------------------------------

# Check if we are editing an already existing invoice
#
if {$invoice_id} {
    # We are editing an already existing invoice

    db_1row invoices_info_query ""

    set invoice_mode "exists"
    set page_title "[_ intranet-invoices.Edit_cost_type]"
    set button_text $page_title
    set context_bar [im_context_bar [list /intranet/invoices/ "[_ intranet-invoices.Finance]"] $page_title]

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
    set button_text "[_ intranet-invoices.New_cost_type]"
    set page_title "[_ intranet-invoices.New_cost_type]"
    set context_bar [im_context_bar [list /intranet/invoices/ "[_ intranet-invoices.Finance]"] $page_title]

    set invoice_id [im_new_object_id]
    set invoice_nr [im_next_invoice_nr -invoice_type_id $cost_type_id]
    set cost_status_id [im_cost_status_created]
    set effective_date $todays_date
    set payment_days [ad_parameter -package_id [im_package_cost_id] "DefaultCompanyInvoicePaymentDays" "" 30] 
    set due_date [db_string get_due_date "select sysdate+:payment_days from dual"]
    set vat 0
    set tax 0
    set note ""
    set cost_note ""
    set payment_method_id ""
    set template_id ""
    set company_contact_id ""
}

if {"" == $invoice_currency} {
    set invoice_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
}


# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Company" fields.
set invoice_or_quote_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_quote]]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]]

if {$invoice_or_quote_p} {
    set company_id $customer_id
    set custprov "customer"
} else {
    set company_id $provider_id
    set custprov "provider"
}


# ---------------------------------------------------------------
# Get default values for VAT and invoice_id from company
# ---------------------------------------------------------------

if {0 == $vat} {
    set vat [db_string default_vat "select default_vat from im_companies where company_id = :company_id" -default "0"]
}

if {"" == $template_id} {
    set template_id [db_string default_template "select default_invoice_template_id from im_companies where company_id = :company_id" -default ""]
}

if {"" == $payment_method_id} {
    set payment_method_id [db_string default_payment_method "select default_payment_method_id from im_companies where company_id = :company_id" -default ""]
}

set company_payment_days [db_string default_payment_days "select default_payment_days from im_companies where company_id = :company_id" -default ""]
if {"" != $company_payment_days} {
    set payment_days $company_payment_days
}

# Get a reasonable default value for the invoice_office_id,
# either from the invoice or then from the company_main_office.
set invoice_office_id [db_string invoice_office_info "select invoice_office_id from im_invoices where invoice_id = :invoice_id" -default ""]
if {"" == $invoice_office_id} {
    set invoice_office_id [db_string company_main_office_info "select main_office_id from im_companies where company_id = :company_id" -default ""]
}

# ---------------------------------------------------------------
# Calculate the selects for the ADP page
# ---------------------------------------------------------------

set payment_method_select [im_invoice_payment_method_select payment_method_id $payment_method_id]
set template_select [im_cost_template_select template_id $template_id]
set status_select [im_cost_status_select cost_status_id $cost_status_id]
set type_select [im_cost_type_select cost_type_id $cost_type_id]
set customer_select [im_company_select customer_id $customer_id "" "Customer"]
set provider_select [im_company_select provider_id $provider_id "" "Provider"]
set contact_select [im_company_contact_select company_contact_id $company_contact_id $company_id]

set invoice_address_label [lang::message::lookup "" intranet-invoices.Invoice_Address "Address"]
set invoice_address_select [im_company_office_select invoice_office_id $invoice_office_id $company_id]


# ---------------------------------------------------------------
# 7. Select and format the sum of the invoicable items
# for a new invoice
# ---------------------------------------------------------------

if {[string equal $invoice_mode "new"]} {

    # start formatting the list of sums with the header...
    set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>[_ intranet-invoices.Line]</td>
          <td class=rowtitle>[_ intranet-invoices.Description]</td>
          <td class=rowtitle>[_ intranet-invoices.Type]</td>
          <td class=rowtitle>[_ intranet-invoices.Units]</td>
          <td class=rowtitle>[_ intranet-invoices.UOM]</td>
          <td class=rowtitle>[_ intranet-invoices.Rate]</td>
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

    # start formatting the list of sums with the header...
    set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>[_ intranet-invoices.Line]</td>
          <td class=rowtitle>[_ intranet-invoices.Description]</td>
          <td class=rowtitle>[_ intranet-invoices.Type]</td>
          <td class=rowtitle>[_ intranet-invoices.Units]</td>
          <td class=rowtitle>[_ intranet-invoices.UOM]</td>
          <td class=rowtitle>[_ intranet-invoices.Rate]</td>
        </tr>
    "

    set ctr 1
    set old_project_id 0
    set colspan 6
    set target_language_id ""
    db_foreach invoice_item "" {

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
            [im_category_select "Intranet UoM" item_uom_id.$ctr $item_uom_id]
	  </td>
          <td align=left>
	    <input type=text name=item_rate.$ctr size=7 value='$price_per_unit'>
            [im_currency_select item_currency.$ctr $currency]
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

