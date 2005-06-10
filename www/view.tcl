# /packages/intranet-invoices/www/view.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    View all the info about a specific project

    @param render_template_id specifies whether the invoice should be show
	   in plain HTML format or formatted using an .adp template
    @param show_all_comments whether to show all comments

    @author frank.bergmann@project-open.com
} {
    { invoice_id:integer 0}
    { object_id:integer 0}
    { show_all_comments 0 }
    { render_template_id:integer 0 }
    { return_url "" }
}

set user_id [ad_maybe_redirect_for_registration]

# Security is defered after getting the invoice information
# from the database, because the customer's users should
# be able to see this invoice even if they don't have any
# financial view permissions otherwise.

if {0 == $invoice_id} {set invoice_id $object_id}
if {0 == $invoice_id} {
    ad_return_complaint 1 "<li>[_ intranet-invoices.lt_You_need_to_specify_a]"
    return
}

if {"" == $return_url} { set return_url [im_url_with_query] }

set bgcolor(0) " class=invoiceroweven"
set bgcolor(1) " class=invoicerowodd"

set cur_format "99,999.009"
set vat_format "990.00"
set tax_format "990.00"

set required_field "<font color=red size=+1><B>*</B></font>"
set company_project_nr_exists [db_column_exists im_projects company_project_nr]


# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

set cost_type_id [db_string cost_type_id "select cost_type_id from im_costs where cost_id=:invoice_id" -default 0]

# Invoices and Quotes have a "Customer" fields.
set invoice_or_quote_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_quote]]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]]

# CostType for "Generate Invoice from Quote" or "Generate Bill from PO"
set target_cost_type_id ""
set generation_blurb ""
if {$cost_type_id == [im_cost_type_quote]} {
    set target_cost_type_id [im_cost_type_invoice]
    set generation_blurb "[_ intranet-invoices.lt_Generate_Invoice_from]"
}
if {$cost_type_id == [im_cost_type_po]} {
    set target_cost_type_id [im_cost_type_bill]
    set generation_blurb "[_ intranet-invoices.lt_Generate_Provider_Bil]"
}


if {$invoice_or_quote_p} {
    # A Customer document
    set customer_or_provider_join "and i.customer_id = c.company_id"
    set provider_company "Customer"
} else {
    # A provider document
    set customer_or_provider_join "and i.provider_id = c.company_id"
    set provider_company "Provider"
}

# ---------------------------------------------------------------
# Get everything about the invoice
# ---------------------------------------------------------------


append query   "
select
	i.*,
	ci.*,
	ci.note as cost_note,
        c.*,
	c.company_id as company_id,
        o.*,
        to_char(i.invoice_date,'YYYY-MM-DD') as invoice_date_pretty,
	to_date(to_char(i.invoice_date,'YYYY-MM-DD'),'YYYY-MM-DD') + i.payment_days as calculated_due_date,
	im_name_from_user_id(c.accounting_contact_id) as company_contact_name,
	im_email_from_user_id(c.accounting_contact_id) as company_contact_email,
        c.company_name,
	im_category_from_id(ci.cost_status_id) as cost_status,
	im_category_from_id(ci.cost_type_id) as cost_type, 
	im_category_from_id(ci.template_id) as template
from
	im_invoices_active i,
	im_costs ci,
        im_companies c,
        im_offices o
where 
	i.invoice_id=:invoice_id
	and ci.cost_id = i.invoice_id
	$customer_or_provider_join
        and c.main_office_id=o.office_id
"

if { ![db_0or1row projects_info_query $query] } {
    ad_return_complaint 1 "[_ intranet-invoices.lt_Cant_find_the_documen]"
    return
}


# ---------------------------------------------------------------
# Check permissions
# ---------------------------------------------------------------

im_company_permissions $user_id $company_id view read write admin

if {!$read && ![im_permission $user_id view_invoices]} {
    ad_return_complaint "[_ intranet-invoices.lt_Insufficient_Privileg]" "
    <li>[_ intranet-invoices.lt_You_have_insufficient_1]<BR>
    [_ intranet-invoices.lt_Please_contact_your_s]"
    return
}




set comp_id "$company_id"
set query "
select
        pm_cat.category as invoice_payment_method,
	pm_cat.category_description as invoice_payment_method_desc
from 
        im_categories pm_cat
where
        pm_cat.category_id = :payment_method_id
"
if { ![db_0or1row category_info_query $query] } {
    set invoice_payment_method ""
    set invoice_payment_method_desc ""
}

set query "
select 
        cc.country_name
from
        country_codes cc
where
        cc.iso = :address_country_code
"
if { ![db_0or1row country_info_query $query] } {
    set country_name ""
}

set page_title "[_ intranet-invoices.One_cost_type]"
set context_bar [im_context_bar [list /intranet-invoices/ "[_ intranet-invoices.Finance]"] $page_title]


# ---------------------------------------------------------------
# Update the amount paid for this cost_item
# ---------------------------------------------------------------

db_dml update_cost_items "
update im_costs
set paid_amount = (
        select  sum(amount)
        from    im_payments
        where   cost_id = :invoice_id
)
where cost_id = :invoice_id
"


# ---------------------------------------------------------------
# Payments list
# ---------------------------------------------------------------

set payment_list_html ""
if {[db_table_exists im_payments]} {

    set cost_id $invoice_id
    set payment_list_html "
	<form action=payment-action method=post>
	[export_form_vars cost_id return_url]
	<table border=0 cellPadding=1 cellspacing=1>
        <tr>
          <td align=middle class=rowtitle colspan=3>
	    [_ intranet-invoices.Related_Payments]
	  </td>
        </tr>"

    set payment_list_sql "
select
	p.*,
        to_char(p.received_date,'YYYY-MM-DD') as received_date_pretty,
	im_category_from_id(p.payment_type_id) as payment_type
from
	im_payments p
where
	p.cost_id = :invoice_id
"

    set payment_ctr 0
    db_foreach payment_list $payment_list_sql {
	append payment_list_html "
        <tr $bgcolor([expr $payment_ctr % 2])>
          <td>
	    <A href=/intranet-payments/view?payment_id=$payment_id>
	      $received_date_pretty
 	    </A>
	  </td>
          <td>
	      $amount $currency
          </td>\n"
	if {$write} {
	    append payment_list_html "
            <td>
	      <input type=checkbox name=payment_id value=$payment_id>
            </td>\n"
	}
	append payment_list_html "
        </tr>\n"
	incr payment_ctr
    }

    if {!$payment_ctr} {
	append payment_list_html "<tr class=roweven><td colspan=2 align=center><i>[_ intranet-invoices.No_payments_found]</i></td></tr>\n"
    }


    if {$write} {
	append payment_list_html "
        <tr $bgcolor([expr $payment_ctr % 2])>
          <td align=right colspan=3>
	    <input type=submit name=add value=\"[_ intranet-invoices.Add_a_Payment]\">
	    <input type=submit name=del value=\"[_ intranet-invoices.Del]\">
          </td>
        </tr>\n"
    }
    append payment_list_html "
	</table>
        </form>\n"
}

# ---------------------------------------------------------------
# 3. Select and format Invoice Items
# ---------------------------------------------------------------

# start formatting the list of sums with the header...
set item_html "
        <tr align=center>
          <td class=rowtitle>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[_ intranet-invoices.Description]&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
          <td class=rowtitle>[_ intranet-invoices.Qty]</td>
          <td class=rowtitle>[_ intranet-invoices.Unit]</td>
          <td class=rowtitle>[_ intranet-invoices.Rate]</td>\n"

if {$company_project_nr_exists} {
    # Only if intranet-translation has added the field
    append item_html "
          <td class=rowtitle>[_ intranet-invoices.Yr_Job__PO_No]</td>\n"
    }
append item_html "
          <td class=rowtitle>[_ intranet-invoices.Our_Ref]</td>
          <td class=rowtitle>[_ intranet-invoices.Amount]</td>
        </tr>
"

set invoice_items_sql "
select
        i.*,
	to_char(i.price_per_unit,:price_per_unit_format) as price_per_unit_formatted,
	p.*,
	im_category_from_id(i.item_type_id) as item_type,
	im_category_from_id(i.item_uom_id) as item_uom,
	p.project_nr as project_short_name,
	i.price_per_unit * i.item_units as amount
from
	im_invoice_items i,
	im_projects p
where
	i.invoice_id=:invoice_id
	and i.project_id=p.project_id
order by
	i.sort_order,
	i.item_type_id
"

set ctr 1
set colspan 7
if {!$company_project_nr_exists} { set colspan [expr $colspan-1]}

db_foreach invoice_items {} {
    append item_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>$item_name</td>
          <td align=right>$item_units</td>
          <td align=left>[_ intranet-core.$item_uom]</td>
          <td align=right>[im_date_format_locale $price_per_unit 2 3]&nbsp;$currency</td>\n"
    if {$company_project_nr_exists} {
	# Only if intranet-translation has added the field
	append item_html "
          <td align=left>$company_project_nr</td>\n"
    }
    append item_html "
          <td align=left>$project_short_name</td>
          <td align=right>[im_date_format_locale $amount 2 2]&nbsp;$currency</td>
	</tr>"
    incr ctr
}

# ---------------------------------------------------------------
# Add subtotal + VAT + TAX = Grand Total
# ---------------------------------------------------------------

# Calculate grand total based on the same inner SQL
db_1row calc_grand_total "
select
	max(i.currency) as currency,
	sum(i.item_units * i.price_per_unit) as subtotal,
	to_char(sum(i.item_units * i.price_per_unit) * :vat / 100, :vat_format) as vat_amount,
	to_char(sum(i.item_units * i.price_per_unit) * :tax / 100, :tax_format) as tax_amount,
	sum(i.item_units * i.price_per_unit) + (sum(i.item_units * i.price_per_unit) * :vat / 100) + (sum(i.item_units * i.price_per_unit) * :tax / 100) as grand_total
from
	im_invoice_items i
where
	i.invoice_id=:invoice_id
"

set colspan_sub [expr $colspan - 1]

# Add a subtotal
append item_html "
        <tr> 
          <td class=rowplain colspan=$colspan_sub align=right><B>[_ intranet-invoices.Subtotal]</B></td>
          <td class=roweven align=right><B> [im_date_format_locale $subtotal 2 2] $currency</B></td>
        </tr>
"

if {"" != $vat && 0 != $vat} {
    append item_html "
        <tr>
          <td colspan=$colspan_sub align=right>[_ intranet-invoices.VAT]: [format "%0.1f" $vat]%&nbsp;</td>
          <td class=roweven align=right>$vat_amount $currency</td>
        </tr>
"
} else {
    append item_html "
        <tr>
          <td colspan=$colspan_sub align=right>[_ intranet-invoices.VAT]: 0%&nbsp;</td>
          <td class=roweven align=right>0 $currency</td>
        </tr>
"
}

if {"" != $tax && 0 != $tax} {
    append item_html "
        <tr> 
          <td colspan=$colspan_sub align=right>[_ intranet-invoices.TAX]: [format "%0.1f" $tax] %&nbsp;</td>
          <td class=roweven align=right>$tax_amount $currency</td>
        </tr>
    "
}

append item_html "
        <tr> 
          <td colspan=$colspan_sub align=right><b>[_ intranet-invoices.Total_Due]</b></td>
          <td class=roweven align=right><b>[im_date_format_locale $grand_total 2 2] $currency</b></td>
        </tr>
"

if {$cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]} {
append item_html "
        <tr>
	  <td valign=top>[_ intranet-invoices.Payment_Terms]</td>
          <td valign=top colspan=[expr $colspan-1]> 
            [_ intranet-invoices.lt_This_invoice_is_past_]
          </td>
        </tr>
        <tr>
	  <td valign=top>[_ intranet-invoices.Payment_Method_1]</td>
          <td valign=top colspan=[expr $colspan-1]> $invoice_payment_method_desc</td>
        </tr>\n"
}

append item_html "
        <tr>
	  <td valign=top>[_ intranet-invoices.Note]</td>
          <td valign=top colspan=[expr $colspan-1]>
	    <pre><span style=\"font-family: verdana, arial, helvetica, sans-serif\">$cost_note</font></pre>
	  </td>
        </tr>
"

# ---------------------------------------------------------------
# 10. Format using a template
# ---------------------------------------------------------------

# Use a specific template ("render_template_id") to render the "preview"
# of this invoice
if {0 != $render_template_id} {

    # format using a template
    set invoice_template_path [ad_parameter -package_id [im_package_invoices_id] InvoiceTemplatePathUnix "" "/tmp/templates/"]
    append invoice_template_path "/"
    append invoice_template_path [db_string sel_invoice "select category from im_categories where category_id=:render_template_id"]

   if {![file isfile $invoice_template_path] || ![file readable $invoice_template_path]} {
	ad_return_complaint "Unknown $cost_type Template" "
	<li>$cost_type template '$invoice_template_path' doesn't exist or is not readable
	for the web server. Please notify your system administrator."
	return
    }

    set out_contents [ns_adp_parse -file $invoice_template_path]
    db_release_unused_handles
    ns_return 200 text/html $out_contents
    return

} 
