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

if {![im_permission $user_id view_customers]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You have insufficient privileges to view this page.<BR>
    Please contact your system administrator if you feel that this is an error.
    return
}
if {"" == $return_url} { set return_url [im_url_with_query] }


set bgcolor(0) " class=invoiceroweven"
set bgcolor(1) " class=invoicerowodd"

# set bgcolor(0) " bgcolor=#FFFF99"
# set bgcolor(1) " bgcolor=#FFFF77"

set cur_format "99,999.009"

set required_field "<font color=red size=+1><B>*</B></font>"

set customer_project_nr_exists [db_column_exists im_projects customer_project_nr]

# ---------------------------------------------------------------
# Auxilary functions
# ---------------------------------------------------------------

ad_proc im_format_cur { cur {min_decimals ""} {max_decimals ""} } {
	Takes a number in "Amercian" format (decimals separated by ".") and
	returns a string formatted according to the current locale.
} {
    ns_log Notice "im_format_cur($cur, $min_decimals, $max_decimals)"

    # Remove thousands separating comas eventually
    regsub "\," $cur "" cur

    # Check if the number has no decimals (for ocurrence of ".")
    if {![regexp {\.} $cur]} {
	# No decimals - set digits to ""
	set digits $cur
	set decimals ""
    } else {
	# Split the digits from the decimals
        regexp {([^\.]*)\.(.*)} $cur match digits decimals
    }

    if {![string equal "" $min_decimals]} {

	# Pad decimals with trailing "0" until they reach $num_decimals
	while {[string length $decimals] < $min_decimals} {
	    append decimals "0"
	}
    }

    if {![string equal "" $max_decimals]} {
	# Adjust decimals by cutting off digits if too long:
	if {[string length $decimals] > $max_decimals} {
	    set decimals [string range $decimals 0 [expr $max_decimals-1]]
	}
    }

    # Format the digits
    if {[string equal "" $digits]} {
	set digits "0"
    }

    return "$digits.$decimals"
}


# ---------------------------------------------------------------
# 1. Get everything about the invoice
# ---------------------------------------------------------------
 
append query   "
select
	i.*,
        c.*,
        o.*,
	i.invoice_date + i.payment_days as calculated_due_date,
	pm_cat.category as invoice_payment_method,
	pm_cat.category_description as invoice_payment_method_desc,
	im_name_from_user_id(c.accounting_contact_id) as customer_contact_name,
	im_email_from_user_id(c.accounting_contact_id) as customer_contact_email,
        c.customer_name,
        cc.country_name,
	im_category_from_id(i.invoice_status_id) as invoice_status,
	im_category_from_id(i.invoice_type_id) as invoice_type, 
	im_category_from_id(i.invoice_template_id) as invoice_template
from
	im_invoices i,
        im_customers c,
        im_offices o,
        country_codes cc,
	im_categories pm_cat
where 
	i.invoice_id=:invoice_id
	and i.payment_method_id=pm_cat.category_id(+)
        and i.customer_id=c.customer_id(+)
        and c.main_office_id=o.office_id(+)
        and o.address_country_code=cc.iso(+)
"

if { ![db_0or1row projects_info_query $query] } {
    ad_return_complaint 1 "Can't find the document# $invoice_id"
    return
}

set page_title "One $invoice_type"
set context_bar [ad_context_bar [list /intranet-invoices/ "Finance"] $page_title]


# ---------------------------------------------------------------
# 2. Render the "Invoice Data" block
# ---------------------------------------------------------------

set invoice_data_html "
        <tr><td align=middle class=rowtitle colspan=2>$invoice_type Data</td></tr>
        <tr>
          <td  class=rowodd>$invoice_type nr.:</td>
          <td  class=rowodd>$invoice_nr</td>
        </tr>
        <tr> 
          <td  class=roweven>$invoice_type date:</td>
          <td  class=roweven>$invoice_date</td>
        </tr>
<!--        <tr> 
          <td  class=rowodd>$invoice_type due date:</td>
          <td  class=rowodd>$due_date</td>
        </tr>
-->
        <tr> 
          <td class=roweven>Payment terms</td>
          <td class=roweven>$payment_days days date of invoice</td>
        </tr>
        <tr> 
          <td class=rowodd>Payment Method</td>
          <td class=rowodd>$invoice_payment_method</td>
        </tr>
        <tr> 
          <td class=roweven> $invoice_type template:</td>
          <td class=roweven>$invoice_template</td>
        </tr>
        <tr> 
          <td class=roweven> $invoice_type type:</td>
          <td class=roweven>$invoice_type</td>
        </tr>
"

set receipient_html "
        <tr><td align=center valign=top class=rowtitle colspan=2> Recipient</td></tr>
        <tr> 
          <td  class=rowodd>Company name</td>
          <td  class=rowodd>
            <A href=/intranet/customers/view?customer_id=$customer_id>$customer_name</A>
          </td>
        </tr>
        <tr> 
          <td  class=roweven>VAT</td>
          <td  class=roweven>$vat_number</td>
        </tr>
        <tr> 
          <td  class=rowodd> Contact</td>
          <td  class=rowodd>
            <A href=/intranet/users/view?user_id=$accounting_contact_id>$customer_contact_name</A>
          </td>
        </tr>
        <tr> 
          <td  class=roweven>Adress</td>
          <td  class=roweven>$address_line1 <br> $address_line2</td>
        </tr>
        <tr> 
          <td  class=rowodd>Zip</td>
          <td  class=rowodd>$address_postal_code</td>
        </tr>
        <tr> 
          <td  class=roweven>Country</td>
          <td  class=roweven>$country_name</td>

        </tr>
        <tr> 
          <td  class=rowodd>Phone</td>
          <td  class=rowodd>$phone</td>
        </tr>
        <tr> 
          <td  class=roweven>Fax</td>
          <td  class=roweven>$fax</td>
        </tr>
        <tr> 
          <td  class=rowodd>Email</td>
          <td  class=rowodd>$customer_contact_email</td>
        </tr>
"


# ---------------------------------------------------------------
# Project List
# ---------------------------------------------------------------

set project_list_html "
        <tr>
          <td align=middle class=rowtitle colspan=2>Related Projects</td>
        </tr>"

set project_list_sql "
select
	p.*
from
	im_projects p,
	acs_rels r
where
	r.object_id_one = p.project_id
	and r.object_id_two = :invoice_id
"

db_foreach project_list $project_list_sql {
    append project_list_html "
        <tr>
          <td class=rowodd>
	    <A href=/intranet/projects/view?project_id=$project_id>$project_nr</A>
	  </td>
          <td class=rowodd>$project_name</td>
        </tr>
"
}


append project_list_html "
        <tr>
          <td align=left colspan=2>
	    <A href=/intranet-invoices/add-project-to-invoice?invoice_id=$invoice_id>
	      Associate with a Project
	    </A>
          </td>
        </tr>"


# ---------------------------------------------------------------
# Payments list
# ---------------------------------------------------------------

set payment_list_html ""
if {[db_table_exists im_payments]} {

    set payment_list_html "
        <tr>
          <td align=middle class=rowtitle colspan=2>Related Payments</td>
        </tr>"

    set payment_list_sql "
select
	p.*,
	im_category_from_id(p.payment_type_id) as payment_type
from
	im_payments p
where
	p.invoice_id = :invoice_id
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
	      $amount $currency $payment_type
          </td>
        </tr>\n"
	incr payment_ctr
    }


    append payment_list_html "
        <tr $bgcolor([expr $payment_ctr % 2])>
          <td align=left colspan=2>
	    <A href=/intranet-payments/new?invoice_id=$invoice_id>
	      Add a payment
	    </A>
          </td>
        </tr>
    "
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
          <td align=right>[im_format_cur $price_per_unit 2 3]&nbsp;$currency</td>\n"
    if {$customer_project_nr_exists} {
	# Only if intranet-translation has added the field
	append item_html "
          <td align=left>$customer_project_nr</td>\n"
    }
    append item_html "
          <td align=left>$project_short_name</td>
          <td align=right>[im_format_cur $amount 2 2]&nbsp;$currency</td>
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
          <td class=roweven align=right><B> [im_format_cur $subtotal 2 2] $currency</B></td>
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
          <td class=roweven align=right><b>[im_format_cur $grand_total 2 2] $currency</b></td>
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
"


# ---------------------------------------------------------------
# 10. Format using an invoice_template
# ---------------------------------------------------------------

if {[exists_and_not_null render_template_id]} {

    # format using an invoice template
    set invoice_template_path [ad_parameter -package_id [im_package_invoices_id] InvoiceTemplatePathUnix "" "/tmp/templates/"]
    append invoice_template_path "/"
    append invoice_template_path [db_string sel_invoice "select category from im_categories where category_id=:render_template_id"]

   if {![file isfile $invoice_template_path] || ![file readable $invoice_template_path]} {
	ad_return_complaint "Unknown $invoice_type Template" "
	<li>$invoice_type template '$invoice_template_path' doesn't exist or is not readable
	for the web server. Please notify your system administrator."
	return
    }

    set out_contents [ns_adp_parse -file $invoice_template_path]
    db_release_unused_handles
    ns_return 200 text/html $out_contents
    return

} else {

    # for the "Preview" button only
    set render_template_id $invoice_template_id

    # No render template defined - render using default html style
    set page_body "
[im_invoices_navbar "none" "/intranet-invoices/index" "" "" [list]]


<!-- Invoice Data and Receipient Tables -->
<table cellpadding=0 cellspacing=0 bordercolor=#6699CC border=0 width=100%>
  <tr valign=top> 
    <td>

          <table border=0 cellPadding=0 cellspacing=2 width=100%>
	    $invoice_data_html

	    <tr>
              <td colspan=2 align=right>

                <table>
                  <tr>
                    <td>  

		<form action=new method=POST>
		  <A HREF=/intranet-invoices/view?[export_url_vars return_url invoice_id render_template_id]>Preview</A>

		  [export_form_vars return_id invoice_id invoice_type_id]
		  <input type=submit name=create_invoice_from_template value='Create Invoice from Quote'>
		  <input type=submit name=edit_invoice value='Edit'>
		</form>

                    </td>
                  </tr>
                </table>


	      </td>
            </tr>
          </table>

          [im_invoices_object_list_component $user_id $invoice_id $return_url]
          <br>

          <table border=0 cellPadding=0 cellspacing=2>
	    $payment_list_html
	    <tr><td colspan=2>&nbsp;</td></tr>
          </table>


    </td>
    <td></td>
    <td align=right>
      <table border=0 cellspacing=2 cellpadding=0 width=100%>
        $receipient_html</td>
      </table>
  </tr>
</table>

<table cellpadding=0 cellspacing=2 border=0 width=100%>
<tr><td align=right>
  <table cellpadding=1 cellspacing=2 border=0 width=100%>
    $item_html
  </table>
</td></tr>
</table>
"

    db_release_unused_handles
    doc_return  200 text/html [im_return_template]
    return

}





