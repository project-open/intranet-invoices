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
    { render_template_id:optional,integer "" }
    { return_url "" }
}

set user_id [ad_maybe_redirect_for_registration]

if {0 == $invoice_id} {set invoice_id $object_id}
if {0 == $invoice_id} {
    ad_return_complaint 1 "<li>You need to specify a invoice_id"
    return
}

if {![im_permission $user_id view_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You have insufficient privileges to view this page.<BR>
    Please contact your system administrator if you feel that this is an error."
    return
}
if {"" == $return_url} { set return_url [im_url_with_query] }

set bgcolor(0) " class=invoiceroweven"
set bgcolor(1) " class=invoicerowodd"

set cur_format "99,999.009"
set required_field "<font color=red size=+1><B>*</B></font>"
set customer_project_nr_exists [db_column_exists im_projects customer_project_nr]


# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

set cost_type_id [db_string cost_type_id "select cost_type_id from im_costs where cost_id=:invoice_id" -default ""]

# Invoices and Quotes have a "Customer" fields.
set invoice_or_quote_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_quote]]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]]

# CostType for "Generate Invoice from Quote" or "Generate Bill from PO"
set target_cost_type_id ""
set generation_blurb ""
if {$cost_type_id == [im_cost_type_quote]} {
    set target_cost_type_id [im_cost_type_invoice]
    set generation_blurb "Generate Invoice from Quote"
}
if {$cost_type_id == [im_cost_type_po]} {
    set target_cost_type_id [im_cost_type_bill]
    set generation_blurb "Generate Provider Bill from PO"
}


if {$invoice_or_quote_p} {
    # A Customer document
    set customer_or_provider_join "and i.customer_id = c.customer_id(+)"
    set provider_customer "Customer"
} else {
    # A provider document
    set customer_or_provider_join "and i.provider_id = c.customer_id(+)"
    set provider_customer "Provider"
}

# ---------------------------------------------------------------
# 1. Get everything about the invoice
# ---------------------------------------------------------------


append query   "
select
	i.*,
	ci.*,
	ci.note as cost_note,
        c.*,
	c.customer_id as company_id,
        o.*,
	i.invoice_date + i.payment_days as calculated_due_date,
	pm_cat.category as invoice_payment_method,
	pm_cat.category_description as invoice_payment_method_desc,
	im_name_from_user_id(c.accounting_contact_id) as customer_contact_name,
	im_email_from_user_id(c.accounting_contact_id) as customer_contact_email,
        c.customer_name,
        cc.country_name,
	im_category_from_id(ci.cost_status_id) as cost_status,
	im_category_from_id(ci.cost_type_id) as cost_type, 
	im_category_from_id(ci.template_id) as template
from
	im_invoices_active i,
	im_costs ci,
        im_customers c,
        im_offices o,
        country_codes cc,
	im_categories pm_cat
where 
	i.invoice_id=:invoice_id
	and ci.cost_id = i.invoice_id
	and i.payment_method_id=pm_cat.category_id(+)
	$customer_or_provider_join
        and c.main_office_id=o.office_id(+)
        and o.address_country_code=cc.iso(+)
"

if { ![db_0or1row projects_info_query $query] } {
    ad_return_complaint 1 "Can't find the document# $invoice_id"
    return
}

set page_title "One $cost_type"
set context_bar [ad_context_bar [list /intranet-invoices/ "Finance"] $page_title]


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
	    Related Payments
	  </td>
        </tr>"

    set payment_list_sql "
select
	p.*,
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
	      $received_date
 	    </A>
	  </td>
          <td>
	      $amount $currency
          </td>
	  <td>
	    <input type=checkbox name=payment_id value=$payment_id>
	  </td>
        </tr>\n"
	incr payment_ctr
    }

    if {!$payment_ctr} {
	append payment_list_html "<tr class=roweven><td colspan=2 align=center><i>No payments found</i></td></tr>\n"
    }
    append payment_list_html "
        <tr $bgcolor([expr $payment_ctr % 2])>
          <td align=right colspan=3>
	    <input type=submit name=add value=\"Add a Payment\">
	    <input type=submit name=del value=\"Del\">
          </td>
        </tr>
	</table>
        </form>\n"
}

# ---------------------------------------------------------------
# 3. Select and format Invoice Items
# ---------------------------------------------------------------

# start formatting the list of sums with the header...
set item_html "
        <tr align=center>
          <td class=rowtitle>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Description&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
          <td class=rowtitle>Qty.</td>
          <td class=rowtitle>Unit</td>
          <td class=rowtitle>Rate</td>\n"

if {$customer_project_nr_exists} {
    # Only if intranet-translation has added the field
    append item_html "
          <td class=rowtitle>Yr. Job / P.O. No.</td>\n"
    }
append item_html "
          <td class=rowtitle>Our Ref.</td>
          <td class=rowtitle>Amount</td>
        </tr>
"

set invoice_items_sql "
select
        i.*,
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
	and i.project_id=p.project_id(+)
order by
	i.sort_order,
	i.item_type_id
"

set ctr 1
set colspan 7
if {!$customer_project_nr_exists} { set colspan [expr $colspan-1]}


db_foreach invoice_items $invoice_items_sql {

    append item_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>$item_name</td>
          <td align=right>$item_units</td>
          <td align=left>$item_uom</td>
          <td align=right>[im_date_format_locale $price_per_unit 2 3]&nbsp;$currency</td>\n"
    if {$customer_project_nr_exists} {
	# Only if intranet-translation has added the field
	append item_html "
          <td align=left>$customer_project_nr</td>\n"
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
	sum(i.item_units * i.price_per_unit) * :vat / 100 as vat_amount,
	sum(i.item_units * i.price_per_unit) * :tax / 100 as tax_amount,
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
          <td class=rowplain colspan=$colspan_sub align=right><B>Subtotal</B></td>
          <td class=roweven align=right><B> [im_date_format_locale $subtotal 2 2] $currency</B></td>
        </tr>
"

#if {0 != $vat} {
    append item_html "
        <tr>
          <td colspan=$colspan_sub align=right>VAT: $vat %&nbsp;</td>
          <td class=roweven align=right>$vat_amount $currency</td>
        </tr>
"
#}

if {0 != $tax} {
    append item_html "
        <tr> 
          <td colspan=$colspan_sub align=right>TAX: $tax %&nbsp;</td>
          <td class=roweven align=right>$tax_amount $currency</td>
        </tr>
    "
}

append item_html "
        <tr> 
          <td colspan=$colspan_sub align=right><b>Total Due</b></td>
          <td class=roweven align=right><b>[im_date_format_locale $grand_total 2 2] $currency</b></td>
        </tr>
"

append item_html "
        <tr><td colspan=$colspan>&nbsp;</td></tr>
        <tr>
	  <td valign=top>Payment Terms:</td>
          <td valign=top colspan=[expr $colspan-1]> 
            This invoice is past due if unpaid after $calculated_due_date.
          </td>
        </tr>
        <tr>
	  <td valign=top>Payment Method:</td>
          <td valign=top colspan=[expr $colspan-1]> $invoice_payment_method_desc</td>
        </tr>
        <tr>
	  <td valign=top>Note:</td>
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
if {[exists_and_not_null render_template_id]} {

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
