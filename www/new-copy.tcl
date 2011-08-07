# /packages/intranet-invoices/www/new-copy.tcl
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
    { source_invoice_id:integer,multiple "" }
    source_cost_type_id:integer,optional
    target_cost_type_id:integer
    {customer_id:integer ""}
    {provider_id:integer ""}
    {project_id:integer ""}
    { blurb "Copy Financial Document" }
    { return_url "/intranet-invoice/"}
}

# ---------------------------------------------------------------
# Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."
    ad_script_abort
}

foreach source_id $source_invoice_id {
    im_cost_permissions $user_id $source_id view_p read_p write_p admin_p
    if {!$read_p} {
	ad_return_complaint "Insufficient Privileges" "
        <li>You don't have sufficient privileges to see the source document."
        ad_script_abort
    }
    set allowed_cost_type [im_cost_type_write_permissions $user_id]
    if {[lsearch -exact $allowed_cost_type $target_cost_type_id] == -1} {
	ad_return_complaint "Insufficient Privileges" "
        <li>You can't create documents of type #$target_cost_type_id."
        ad_script_abort
    }
}

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------

# The user hasn't yet specified the source invoice from which
# we want to copy. So let's redirect and this page is going
# to refer us back to this one.
if {0 == [llength $source_invoice_id]} {
    ad_returnredirect new-copy-custselect?[export_url_vars source_cost_type_id target_cost_type_id customer_id provider_id project_id blurb return_url]
    ad_script_abort
}

lappend source_invoice_id 0

set tax_format [im_l10n_sql_currency_format -style simple]
set vat_format [im_l10n_sql_currency_format -style simple]
set price_per_unit_format [im_l10n_sql_currency_format -style simple]
set date_format [im_l10n_sql_date_format -style simple]

set return_url [im_url_with_query]
set todays_date [db_string get_today "select now()::date"]
set page_focus "im_header_form.keywords"
set view_name "invoice_tasks"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"


set discount_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceDiscountFieldP" "" 0]
set surcharge_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceSurchargeFieldP" "" 0]


# Should we show a "Material" field for invoice lines?
set material_enabled_p [ad_parameter -package_id [im_package_invoices_id] "ShowInvoiceItemMaterialFieldP" "" 0]
set project_type_enabled_p [ad_parameter -package_id [im_package_invoices_id] "ShowInvoiceItemProjectTypeFieldP" "" 1]


# ---------------------------------------------------------------
# Get everything about the original document
# ---------------------------------------------------------------

db_1row invoices_info_query "
select
	i.*,
	ci.*,
	im_category_from_id(:target_cost_type_id) as target_cost_type,
	i.invoice_nr as org_invoice_nr,
	ci.note as cost_note,
	to_char(ci.effective_date,:date_format) as effective_date,
	trim(to_char(ci.vat, :vat_format)) as vat,
	trim(to_char(ci.tax, :tax_format)) as tax,
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
        i.invoice_id in ([join $source_invoice_id ", "])
	and ci.customer_id = c.company_id
	and ci.provider_id = p.company_id
	and i.invoice_id = ci.cost_id
LIMIT 1
"

# Use today's date as effective date, because the
# quote was old...
set effective_date $todays_date


# ---------------------------------------------------------------

set customer_select [im_company_select customer_id $customer_id "" "CustOrIntl"]
set provider_select [im_company_select provider_id $provider_id "" "Provider"]

# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Company" fields.
set invoice_or_quote_p [im_cost_type_is_invoice_or_quote_p $target_cost_type_id]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [im_cost_type_is_invoice_or_bill_p $target_cost_type_id]

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
# Check for default templates of the customer and use here if set
db_1row default_vals "
	select
		default_vat,
		default_payment_method_id,
		default_payment_days
	from
		im_companies
	where
		company_id = :customer_id
"

set default_tax ""
if {[im_column_exists im_companies default_tax]} {
    set default_tax [db_string default_tax "select default_tax from im_companies where company_id = :company_id" -default "0"]
}


if {$target_cost_type_id == [im_cost_type_invoice]} {
    if {"" != $default_vat} { set vat $default_vat }
    if {"" != $default_tax} { set tax $default_tax }
    if {"" != $default_payment_days} { set payment_days $default_payment_days }
    if {"" != $default_payment_method_id} { set payment_method_id $default_payment_method_id }
}

# Default for template: Get it from the company
set template_id [im_invoices_default_company_template $target_cost_type_id $company_id]


set invoice_mode "[_ intranet-invoices.clone]"
set page_title "[_ intranet-invoices.Clone] $target_cost_type"
set button_text [_ intranet-invoices.Submit]
set context_bar [im_context_bar [list /intranet/invoices/ "Finance"] $page_title]

set invoice_address_label [lang::message::lookup "" intranet-invoices.Invoice_Address "Address"]
set invoice_address_select [im_company_office_select invoice_office_id $invoice_office_id $company_id]

set contact_select [im_company_contact_select company_contact_id $company_contact_id $company_id]

set cost_center_label [lang::message::lookup "" intranet-invoices.Cost_Center "Cost Center"]
set cost_center_select [im_cost_center_select -include_empty 1 -department_only_p 0 cost_center_id $cost_center_id $cost_type_id]


# ---------------------------------------------------------------
# Modify some variable between the source and the target invoice
# ---------------------------------------------------------------

# Old one: add an "a" behind the invoice_nt to indicate
# a variant.
# set invoice_nr [im_invoice_nr_variant $org_invoice_nr]

# New One: Just create a new invoice nr
# for the target FinDoc type.
set invoice_nr [im_next_invoice_nr -cost_type_id $target_cost_type_id]

set new_invoice_id [im_new_object_id]

# ToDo: Create a link between the invoice and the quote
# in order to indicate that the two belong together.
# Is this really a good idea? Invoice-from-Quote may
# workout fine, but other combinations?


# ---------------------------------------------------------------
# Calculate the selects for the ADP page
# ---------------------------------------------------------------

set payment_method_select [im_invoice_payment_method_select payment_method_id $payment_method_id]
set template_select [im_cost_template_select template_id $template_id]
set status_select [im_cost_status_select cost_status_id $cost_status_id]

# Type_select doesnt allow for options anymore...
# set type_select [im_cost_type_select cost_type_id $target_cost_type_id 0 "financial_doc"]
#
set type_select "
        <input type=hidden name=cost_type_id value=$target_cost_type_id>
        $target_cost_type
"


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

    set item_name [ns_quotehtml $item_name]

    append task_sum_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>
	    <input type=text name=item_sort_order.$ctr size=2 value='$item_sort_order'>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value='[ns_quotehtml $item_name]'>
	  </td>
    "
    append task_sum_html "<input type=hidden name=item_task_id.$ctr value='$task_id'>"

    if {$material_enabled_p} {
	append task_sum_html "<td>[im_material_select item_material_id.$ctr $item_material_id]</td>"
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
          <td align=right><nobr>
	    <input type=text name=item_rate.$ctr size=3 value='$price_per_unit'>
	    <input type=hidden name=item_currency.$ctr value='$currency'>
	    $currency
	  </nobr></td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value='$project_id'>
	<input type=hidden name=source_invoice_id.$ctr value='$invoice_id'>
"
    incr ctr
}

# ---------------------------------------------------------------
# Pass along the number of projects related to this document
# ---------------------------------------------------------------

set related_project_sql "
        select distinct
		object_id_one as project_id
        from
		acs_rels r
        where
		r.object_id_two in ([join $source_invoice_id ", "])
"
set select_project_html ""
db_foreach related_project $related_project_sql {
        append select_project_html "<input type=hidden name=select_project value=$project_id>\n"
}


# ---------------------------------------------------------------
# NavBars
# ---------------------------------------------------------------

set sub_navbar_html [im_costs_navbar "none" "/intranet/invoices/index" "" "" [list]]

