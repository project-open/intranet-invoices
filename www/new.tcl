# /packages/intranet-invoices/www/new.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
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
    { cost_type_id:integer "" }
    { customer_id:integer 0}
    { provider_id:integer 0}
    { project_id:integer 0}
    { cost_center_id:integer 0}
    { invoice_currency ""}
    { create_invoice_from_template ""}
    { return_url "/intranet-invoices/list"}
    del_invoice:optional
}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set show_cost_center_p [ad_parameter -package_id [im_package_invoices_id] "ShowCostCenterP" "" 0]
set current_url [im_url_with_query]

# Check if we have to forward to "new-copy":
if {"" != $create_invoice_from_template} {
    ad_returnredirect [export_vars -base "new-copy" {invoice_id cost_type_id}]
    ad_script_abort
}

# Check if we need to delete the invoice.
# We get there because the "Delete" button in view.tcl can
# only send to one target, which is this file...
if {[info exists del_invoice]} {
    # Calculate the new return_url, because the invoice itself
    # will dissappear...
    set return_url "/intranet-invoices/list"
    set project_id [db_string pid "select project_id from im_costs where cost_id = :invoice_id" -default 0]
    if {"" != $project_id && 0 != $project_id} {
	set view_name "finance"
	set return_url [export_vars -base "/intranet/projects/view" {project_id view_name}] 
    }
    ad_returnredirect [export_vars -base delete {invoice_id return_url}]
}




# Do we need the cost_center_id for creating a new invoice?
# This is necessary if the invoice_nr depends on the cost_center_id (profit center).
set cost_center_required_p [parameter::get_from_package_key -package_key "intranet-invoices" -parameter "NewInvoiceRequiresCostCenterP" -default 0]
if {$cost_center_required_p && 0 == $invoice_id && ($cost_center_id == "" || $cost_center_id == 0)} {
    ad_returnredirect [export_vars -base "new-cost-center-select" {
	{pass_through_variables { cost_type_id customer_id provider_id include_task project_id invoice_currency create_invoice_from_template invoice_id select_project} }
	include_task
	invoice_id
	cost_type_id 
	customer_id 
	provider_id 
	select_project
	project_id 
	invoice_currency 
	cost_center_id
	create_invoice_from_template 
	{ return_url $current_url}
    }]
}

# Permissions
if {0 == $invoice_id} {
    
    if {"" == $cost_type_id} {
	ad_return_complaint 1 "<li>You need to specify a Cost Type"
	return
    }

    # CostCenter Permissions:
    # We are about to create a new invoice - Check specific creation perms
    set create_cost_types [im_cost_type_write_permissions $user_id]
    if {[lsearch -exact $create_cost_types $cost_type_id] == -1} {
	ad_return_complaint "Insufficient Privileges" "
        <li>You don't have sufficient privileges to create a 
            [db_string t "select im_category_from_id(:cost_type_id)"]."
	return
    }

} else {

    # CostCenter Permissions:
    # The invoice already exists - Check invoice permissions
    im_cost_permissions $user_id $invoice_id view read write admin
    if {!$write} {
	ad_return_complaint "Insufficient Privileges" "
        <li>You don't have sufficient privileges to see this page."    
    }
}


set return_url [im_url_with_query]
set todays_date [db_string get_today "select to_char(sysdate,'YYYY-MM-DD') from dual"]
set page_focus "im_header_form.keywords"
set view_name "invoice_tasks"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"
set cost_note ""
set canned_note ""
set canned_note_id ""

set tax_format "90.9"
set vat_format "90.9"

set discount_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceDiscountFieldP" "" 0]
set surcharge_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceSurchargeFieldP" "" 0]

# Canned Notes is a field with multiple messages per invoice
set canned_note_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceCannedNoteP" "" 0]

# Should we show the "Tax" field?
set tax_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceTaxFieldP" "" 1]

# Should we show a "Material" field for invoice lines?
set material_enabled_p [ad_parameter -package_id [im_package_invoices_id] "ShowInvoiceItemMaterialFieldP" "" 0]
set project_type_enabled_p [ad_parameter -package_id [im_package_invoices_id] "ShowInvoiceItemProjectTypeFieldP" "" 1]

# Tricky case: Sombebody has called this page from a project
# So we need to find out the company of the project and create
# an invoice from scratch, invoicing all project elements.
if {0 != $project_id} {
    db_1row customer_info "
	select
		c.*
	from
		im_projects p,
		im_companies c
	where
		project_id = :project_id
		and p.company_id = c.company_id
    "
}


# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Company" fields.
set invoice_or_quote_p [im_cost_type_is_invoice_or_quote_p $cost_type_id]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [im_cost_type_is_invoice_or_bill_p $cost_type_id]

if {$invoice_or_quote_p} {
    if { 0 == $customer_id } {
	set company_id [db_string cost_type "select customer_id from im_costs where cost_id = :invoice_id" -default ""]    
    } else {
	set company_id $customer_id
    }
    set ajax_company_widget "customer_id"
    set custprov "customer"
} else {
    set company_id $provider_id
    set ajax_company_widget "provider_id"
    set custprov "provider"
}

# ad_return_complaint 1 $company_id


# ---------------------------------------------------------------
# 3. Gather invoice data
#	a: if the invoice already exists
# ---------------------------------------------------------------

# Check if we are editing an already existing invoice
#
if {$invoice_id} {
    # We are editing an already existing invoice

    db_1row invoices_info_query ""
    
    # Canned Notes is a field with multiple messages per invoice
    if {$canned_note_enabled_p} {
	    set canned_note_id [db_list canned_notes "
		select	value
		from	im_dynfield_attr_multi_value
		where	object_id = :invoice_id
	    "]
    }

    set cost_type [im_category_from_id $cost_type_id]
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
    set cost_type [im_category_from_id $cost_type_id]
    set button_text "[_ intranet-invoices.New_cost_type]"
    set page_title "[_ intranet-invoices.New_cost_type]"
    set context_bar [im_context_bar [list /intranet/invoices/ "[_ intranet-invoices.Finance]"] $page_title]

    set invoice_id [im_new_object_id]
    set invoice_nr [im_next_invoice_nr -cost_type_id $cost_type_id -cost_center_id $cost_center_id]
    set cost_status_id [im_cost_status_created]
    set effective_date $todays_date
    set payment_days [ad_parameter -package_id [im_package_cost_id] "DefaultCompanyInvoicePaymentDays" "" 30] 
    set due_date [db_string get_due_date "select sysdate+:payment_days from dual"]
    set vat 0
    set tax 0
    set discount_text ""
    set discount_perc 0
    set surcharge_text ""
    set surcharge_perc 0
    set note ""
    set cost_note ""
    set canned_note ""
    set canned_note_id ""
    set payment_method_id ""
    set template_id ""
    set company_contact_id [im_invoices_default_company_contact $company_id $project_id]
    set read_only_p "f"

    # Default for cost-centers - take the user's
    # dept from HR.
    if {0 == $cost_center_id} {
	set cost_center_id [im_costs_default_cost_center_for_user $user_id]
    }
}

if {"" == $invoice_currency} {
    set invoice_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
}

if {"t" == $read_only_p} {
    ad_return_complaint 1 "
        <b>[lang::message::lookup "" intranet-cost.Invoice_Read_Only "Read Only"]</b>:
        [lang::message::lookup "" intranet-cost.Invoice_Read_Only_Message "
                <p>This financial document is read only.</p>
                <p>This situation may happen if the document has already been exported
                to an external system or in similar cases.</p>
    "]
    "
    ad_script_abort
}


# ---------------------------------------------------------------
# Get default values for VAT and invoice_id from company
# ---------------------------------------------------------------

if {[im_column_exists im_companies default_invoice_template_id]} {
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
}

if {[im_column_exists im_companies default_tax]} {
    if {0 == $tax} {
        set tax [db_string default_tax "select default_tax from im_companies where company_id = :company_id" -default "0"]
    }
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

set type_select [im_cost_type_select cost_type_id $cost_type_id 0 "financial_doc"]
if {"" != $cost_type_id} {
    set type_select "
	<input type=hidden name=cost_type_id value=$cost_type_id>
	$cost_type
    "
}

set customer_select [im_company_select -tag_attributes {onchange "ajaxFunction();" onkeyup "ajaxFunction();"} customer_id $customer_id "" "CustOrIntl"]
set provider_select [im_company_select -tag_attributes {onchange "ajaxFunction();" onkeyup "ajaxFunction();"} provider_id $provider_id "" "Provider"]
set contact_select [im_company_contact_select company_contact_id $company_contact_id $company_id]

# ad_return_complaint 1 "im_company_contact_select company_contact_id $company_contact_id $company_id - $contact_select"

set invoice_address_label [lang::message::lookup "" intranet-invoices.Invoice_Address "Address"]
set invoice_address_select [im_company_office_select invoice_office_id $invoice_office_id $company_id]

set cost_center_label [lang::message::lookup "" intranet-invoices.Cost_Center "Cost Center"]

if {$show_cost_center_p} {
    set cost_center_select [im_cost_center_select -include_empty 1 -department_only_p 0 cost_center_id $cost_center_id $cost_type_id]
} else {
    set cost_center_hidden "<input type=hidden name=cost_center_id value=$cost_center_id>"
}

# ---------------------------------------------------------------
# 7. Select and format the sum of the invoicable items
# for a new invoice
# ---------------------------------------------------------------


# start formatting the list of sums with the header...
set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>[_ intranet-invoices.Line]</td>
          <td class=rowtitle>[_ intranet-invoices.Description]</td>
"
if {$material_enabled_p} {
    append task_sum_html "<td class=rowtitle>[lang::message::lookup "" intranet-invoices.Material "Material"]</td>"
}
if {$project_type_enabled_p} {
    append task_sum_html "<td class=rowtitle>[lang::message::lookup "" intranet-invoices.Type "Type"]</td>"
}
append task_sum_html "
          <td class=rowtitle>[_ intranet-invoices.Units]</td>
          <td class=rowtitle>[_ intranet-invoices.UOM]</td>
          <td class=rowtitle>[_ intranet-invoices.Rate]</td>
        </tr>
"



if {[string equal $invoice_mode "new"]} {

    # Start formatting the "reference price list" as well, even though it's going
    # to be shown at the very bottom of the page.
    #
    set price_colspan 11
    set ctr 1
    set old_project_id 0
    set colspan 6
    set vat_colspan 6
    set target_language_id ""

} else {

# ---------------------------------------------------------------
# 8. Get the old invoice items for an already existing invoice
# ---------------------------------------------------------------

    set ctr 1
    set old_project_id 0
    set colspan 6
    set vat_colspan 6
    set target_language_id ""
    db_foreach invoice_item "" {

	append task_sum_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>
	    <input type=text name=item_sort_order.$ctr size=2 value='$sort_order'>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value='[ns_quotehtml $item_name]'>
	  </td>
	"
	append task_sum_html "<input type=hidden name=item_task_id.$ctr value='$task_id'>"

	if {$material_enabled_p} {
	    append task_sum_html "<td>[im_material_select -max_option_len 100 item_material_id.$ctr $item_material_id]</td>"
	} else {
	    append task_sum_html "<input type=hidden name=item_material_id.$ctr value='$item_material_id'>"
	}

	if {$project_type_enabled_p} {
	    append task_sum_html "<td>[im_category_select "Intranet Project Type" item_type_id.$ctr $item_type_id]</td>"
	} else {
	    append task_sum_html "<input type=hidden name=item_type_id.$ctr value='$item_type_id'>"
	}

	append task_sum_html "
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='$item_units'>
	  </td>
          <td align=right>
            [im_category_select "Intranet UoM" item_uom_id.$ctr $item_uom_id]
	  </td>
          <td align=right>
	    <nobr><input type=text name=item_rate.$ctr size=7 value='$price_per_unit'>[im_currency_select item_currency.$ctr $currency]</nobr>
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value='$project_id'>
	"
	if { [info exists item_source_invoice_id] } {
	    append task_sum_html " <input type=hidden name=source_invoice_id.$ctr value='$item_source_invoice_id'>"
	}
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
	    <input type=text name=item_sort_order.$ctr size=2 value='$ctr'>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value=''>
	  </td>
    "
    append task_sum_html "<input type=hidden name=item_task_id.$ctr value='-1'>"

    if {$material_enabled_p} {
	append task_sum_html "<td>[im_material_select -max_option_len 100 item_material_id.$ctr ""]</td>"
    } else {
	append task_sum_html "<input type=hidden name=item_material_id.$ctr value=''>"
    }
    
    if {$project_type_enabled_p} {
	append task_sum_html "<td>[im_category_select "Intranet Project Type" item_type_id.$ctr ""]</td>"
    } else {
	append task_sum_html "<input type=hidden name=item_type_id.$ctr value=''>"
    }

    append task_sum_html "
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='0'>
	  </td>
          <td align=right>
            [im_category_select "Intranet UoM" item_uom_id.$ctr 320]
	  </td>
          <td align=right>
            <!-- rate and currency need to be together so that the line doesn't break -->
	    <nobr><input type=text name=item_rate.$ctr size=7 value='0'>[im_currency_select item_currency.$ctr $invoice_currency]</nobr>
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value=''>
    "

    incr ctr
}

# ---------------------------------------------------------------
# Pass along the number of projects related to this document
# ---------------------------------------------------------------

# fraber 080515: @CTP: the project_id comes from im_invoice_ITEMS,
# and causes trouble (adding an additional project to the list of
# related projects). Did this code (own_project_related) make ever
# sense?

set own_project_related ""
if {0 != $project_id} { set own_project_related "UNION select :project_id as project_id" }

set related_project_sql "
	select	object_id_one as project_id
	from	acs_rels r
	where	r.object_id_two = :invoice_id
	$own_project_related
"

set select_project_html ""
db_foreach related_project $related_project_sql {
	append select_project_html "<input type=hidden name=select_project value=$project_id>\n"
}

set sub_navbar [im_costs_navbar "none" "/intranet/invoices/index" "" "" [list]] 

db_release_unused_handles

