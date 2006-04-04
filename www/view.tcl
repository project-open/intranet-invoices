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
    @param send_to_user_as "html" or "pdf".
           Indicates that the content of the
           invoice should be rendered using the default template
           and sent to the default contact.
           The difficulty is that it's not sufficient just to redirect
           to a mail sending page, because it is only this page that 
           "knows" how to render an invoice. So in order to send the
           PDF we first need to redirect to this page, render the invoice
           and then redirect to the mail sending page.

    @author frank.bergmann@project-open.com
} {
    { invoice_id:integer 0}
    { object_id:integer 0}
    { show_all_comments 0 }
    { render_template_id:integer 0 }
    { return_url "" }
    { send_to_user_as ""}
}

set user_id [ad_maybe_redirect_for_registration]

# Get the default locale for this current user
set user_locale [lang::user::locale]
set locale $user_locale

# Security is defered after getting the invoice information
# from the database, because the customer's users should
# be able to see this invoice even if they don't have any
# financial view permissions otherwise.

if {0 == $invoice_id} {set invoice_id $object_id}
if {0 == $invoice_id} {
    ad_return_complaint 1 "<li>[lang::message::lookup $locale intranet-invoices.lt_You_need_to_specify_a]"
    return
}

if {"" == $return_url} { set return_url [im_url_with_query] }

set bgcolor(0) " class=invoiceroweven"
set bgcolor(1) " class=invoicerowodd"

set cur_format "99999999999.00"
set vat_format $cur_format
set tax_format $cur_format

# rounding precision can be between 2 (USD,EUR, ...) 
# and -5 (Old Turkish Lira, ...).
set rounding_precision 2


set required_field "<font color=red size=+1><B>*</B></font>"
set company_project_nr_exists [db_column_exists im_projects company_project_nr]
set rounding_factor [expr exp(log(10) * $rounding_precision)]
set rf $rounding_factor

# ---------------------------------------------------------------
# Pad number with trailing "0" to meet rounding_precision
# ---------------------------------------------------------------

ad_proc -public im_numeric_add_trailing_zeros {
    num
    rounding_precision
} {
    Add trailing "0" until the number has reached the "rounding_precision".
    "num" comes in TCL numeric format (after adding an "expr num+0").
    Example: 1524163.8 => 1524163.80
} {
#    set num "1524163"
#    set rounding_precision -3

    # Check if there is a "." in the format, checking from the rear
    set pos [string first "." $num]

    # Deal with the case of no fraction - this may be OK if the case
    # of negative fraction "rounding_precision".
    if {-1 == $pos} {
	if {$rounding_precision >= 0} { set num "${num}." }
	set pos [string first "." $num]
    }

    # Determine the other stuff of the number
    set len [string length $num]
    set frac [expr $len-$pos-1]
    set missing_frac [expr $rounding_precision-$frac]

    # Deal with the case of no fraction - this may be OK if the case
    # of negative fraction "rounding_precision".
    if {-1 == $pos} {
	if {$rounding_precision >= 0} { set num "${num}." }
    }
    
    set result $num

    while {$missing_frac > 0} {
	set result "${result}0"
	set missing_frac [expr $missing_frac-1]
    }

#    ad_return_complaint 1 "num=$num, prec=$rounding_precision, len=$len, pos=$pos, frac=$frac, mis_frac=$missing_frac, res=$result"

    return $result
}


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
    set generation_blurb "[lang::message::lookup $locale intranet-invoices.lt_Generate_Invoice_from]"
}
if {$cost_type_id == [im_cost_type_po]} {
    set target_cost_type_id [im_cost_type_bill]
    set generation_blurb "[lang::message::lookup $locale intranet-invoices.lt_Generate_Provider_Bil]"
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

if {!$invoice_or_quote_p} { set company_project_nr_exists 0}

# ---------------------------------------------------------------
# Find out if the invoice is associated to a _single_ project.
# We will need this project to access the "customer_project_nr"
# for the invoice
# ---------------------------------------------------------------

set related_projects_sql "
        select distinct
	   	r.object_id_one as project_id,
		p.project_nr
	from
	        acs_rels r,
		im_projects p
	where
		r.object_id_one = p.project_id
	        and r.object_id_two = :invoice_id
"

set related_projects {}
db_foreach related_projects $related_projects_sql {
   lappend related_projects $project_id
   lappend related_project_nrs $project_nr
}

set rel_project_id 0
if {1 == [llength $related_projects]} {
    set rel_project_id [lindex $related_projects 0]
}

# ---------------------------------------------------------------
# Get everything about the invoice
# ---------------------------------------------------------------


set query "
select
	i.*,
	i.invoice_office_id,
	ci.*,
	ci.note as cost_note,
	ci.project_id as cost_project_id,
	c.*,
	to_date(to_char(i.invoice_date,'YYYY-MM-DD'),'YYYY-MM-DD') + i.payment_days as calculated_due_date,
	im_category_from_id(ci.cost_status_id) as cost_status,
	im_category_from_id(ci.cost_type_id) as cost_type, 
	im_category_from_id(ci.template_id) as template
from
	im_invoices_active i,
	im_costs ci,
        im_companies c
where 
	i.invoice_id=:invoice_id
	and ci.cost_id = i.invoice_id
	$customer_or_provider_join
"
if { ![db_0or1row invoice_info_query $query] } {
    ad_return_complaint 1 "[lang::message::lookup $locale intranet-invoices.lt_Cant_find_the_documen]"
    return
}


# Fallback for empty office_id: Main Office
if {"" == $invoice_office_id} {
    set invoice_office_id $main_office_id
}

db_1row office_info_query "
	select *
	from im_offices
	where office_id = :invoice_office_id
"




# Use the "company_contact_id" of the invoices as the main contact.
# Fallback to the accounting_contact_id and primary_contact_id
# if not present.
if {"" == $company_contact_id} { 
    set company_contact_id $accounting_contact_id
}
if {"" == $company_contact_id} { 
    set company_contact_id $primary_contact_id 
}

db_1row accounting_contact_info "
    select
	im_name_from_user_id(:company_contact_id) as company_contact_name,
	im_email_from_user_id(:company_contact_id) as company_contact_email
    "

# ---------------------------------------------------------------
# Determine the language of the template from the template name
# ---------------------------------------------------------------

if {0 != $render_template_id} {

	# OLD convention, "invoice-english.adp"
	if {[regexp {english} $template]} { set locale en }
	if {[regexp {spanish} $template]} { set locale es }
	if {[regexp {german} $template]} { set locale de }
	if {[regexp {french} $template]} { set locale fr }

	# New convention, "invoice.en_US.adp"
	if {[regexp {(.*)\.([_a-zA-Z]*)\.adp} $template match body loc]} {
	    set locale $loc
	}
}


# Check if the given locale throws an error
# Reset the locale to the default locale then
if {[catch {
    lang::message::lookup $locale "dummy_text"
} errmsg]} {
    set locale $user_locale
}

# ---------------------------------------------------------------
# Format Invoice date information according to locale
# ---------------------------------------------------------------

set invoice_date_pretty [lc_time_fmt $invoice_date "%x" $locale]
set calculated_due_date_pretty [lc_time_fmt $calculated_due_date "%x" $locale]

# ---------------------------------------------------------------
# Get more about the invoice's project
# ---------------------------------------------------------------

# We give priority to the project specified in the cost item,
# instead of associated projects.
if {"" != $cost_project_id && 0 != $cost_project_id} {
    set rel_project_id $cost_project_id
}

set project_short_name_default [db_string short_name_default "select project_nr from im_projects where project_id=:rel_project_id" -default ""]
set customer_project_nr_default ""

if {$company_project_nr_exists && $rel_project_id} {

    db_0or1row project_info_query "
    	select
    		p.company_project_nr as customer_project_nr_default
    	from
    		im_projects p
    	where
    		p.project_id = :rel_project_id
    "
}

# ---------------------------------------------------------------
# Check permissions
# ---------------------------------------------------------------

im_cost_permissions $user_id $invoice_id view read write admin
if {!$read} {
    ad_return_complaint "[lang::message::lookup $locale intranet-invoices.lt_Insufficient_Privileg]" "
    <li>[lang::message::lookup $locale intranet-invoices.lt_You_have_insufficient_1]<BR>
    [lang::message::lookup $locale intranet-invoices.lt_Please_contact_your_s]"
    return
}

# ---------------------------------------------------------------
# Page Title and Context Bar
# ---------------------------------------------------------------

set page_title [lang::message::lookup $locale intranet-invoices.One_cost_type]
set context_bar [im_context_bar [list /intranet-invoices/ "[lang::message::lookup $locale intranet-invoices.Finance]"] $page_title]


# ---------------------------------------------------------------
#
# ---------------------------------------------------------------

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


# ---------------------------------------------------------------
# Determine the country name and localize
# ---------------------------------------------------------------

set country_name ""
if {"" != $address_country_code} {
    set query "
	select	cc.country_name
	from	country_codes cc
	where	cc.iso = :address_country_code"
    if { ![db_0or1row country_info_query $query] } {
	    set country_name $address_country_code
    }
    set country_name [lang::message::lookup $locale intranet-core.$country_name $country_name]
}

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
	    [lang::message::lookup $locale intranet-invoices.Related_Payments]
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
	append payment_list_html "<tr class=roweven><td colspan=2 align=center><i>[lang::message::lookup $locale intranet-invoices.No_payments_found]</i></td></tr>\n"
    }


    if {$write} {
	append payment_list_html "
        <tr $bgcolor([expr $payment_ctr % 2])>
          <td align=right colspan=3>
	    <input type=submit name=add value=\"[lang::message::lookup $locale intranet-invoices.Add_a_Payment]\">
	    <input type=submit name=del value=\"[lang::message::lookup $locale intranet-invoices.Del]\">
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
set item_list_html "
        <tr align=center>
          <td class=rowtitle>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[lang::message::lookup $locale intranet-invoices.Description]&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
          <td class=rowtitle>[lang::message::lookup $locale intranet-invoices.Qty]</td>
          <td class=rowtitle>[lang::message::lookup $locale intranet-invoices.Unit]</td>
          <td class=rowtitle>[lang::message::lookup $locale intranet-invoices.Rate]</td>\n"

if {$company_project_nr_exists} {
    # Only if intranet-translation has added the field
    append item_list_html "
          <td class=rowtitle>[lang::message::lookup $locale intranet-invoices.Yr_Job__PO_No]</td>\n"
    }
append item_list_html "
          <td class=rowtitle>[lang::message::lookup $locale intranet-invoices.Our_Ref]</td>
          <td class=rowtitle>[lang::message::lookup $locale intranet-invoices.Amount]</td>
        </tr>
"

set ctr 1
set colspan 7
if {!$company_project_nr_exists} { set colspan [expr $colspan-1]}


db_foreach invoice_items {} {

    # $company_project_nr is normally related to each invoice item,
    # because invoice items can be created based on different projects.
    # However, frequently we only have one project per invoice, so that
    # we can use this project's company_project_nr as a default
    if {$company_project_nr_exists && "" == $company_project_nr} { 
	set company_project_nr $customer_project_nr_default
    }
    if {"" == $project_short_name} { 
	set project_short_name $project_short_name_default
    }

    set amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $amount+0] $rounding_precision] "" $locale]
    set item_units_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $item_units+0] $rounding_precision] "" $locale]
    set price_per_unit_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $price_per_unit+0] $rounding_precision] "" $locale]

    append item_list_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td $bgcolor([expr $ctr % 2])>$item_name</td>
          <td $bgcolor([expr $ctr % 2]) align=right>$item_units_pretty</td>
          <td $bgcolor([expr $ctr % 2]) align=left>[lang::message::lookup $locale intranet-core.$item_uom]</td>
          <td $bgcolor([expr $ctr % 2]) align=right>$price_per_unit_pretty&nbsp;$currency</td>\n"
    if {$company_project_nr_exists} {
	# Only if intranet-translation has added the field
	append item_list_html "
          <td $bgcolor([expr $ctr % 2]) align=left>$company_project_nr</td>\n"
    }
    append item_list_html "
          <td $bgcolor([expr $ctr % 2]) align=left>$project_short_name</td>
          <td $bgcolor([expr $ctr % 2]) align=right>$amount_pretty&nbsp;$currency</td>
	</tr>"
    incr ctr
}

# ---------------------------------------------------------------
# Add subtotal + VAT + TAX = Grand Total
# ---------------------------------------------------------------

# Set these values to 0 in order to allow to calculate the
# formatted grand total
if {"" == $vat} { set vat 0}
if {"" == $tax} { set tax 0}

# Calculate grand total based on the same inner SQL
db_1row calc_grand_total ""

set subtotal_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $subtotal+0] $rounding_precision] "" $locale]
set vat_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $vat_amount+0] $rounding_precision] "" $locale]
set tax_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $tax_amount+0] $rounding_precision] "" $locale]
set grand_total_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $grand_total+0] $rounding_precision] "" $locale]

set colspan_sub [expr $colspan - 1]

# Add a subtotal
append item_list_html "
        <tr> 
          <td class=roweven colspan=$colspan_sub align=right><B>[lang::message::lookup $locale intranet-invoices.Subtotal]</B></td>
          <td class=roweven align=right><B><nobr>$subtotal_pretty $currency</nobr></B></td>
        </tr>
"

if {"" != $vat && 0 != $vat} {
    append item_list_html "
        <tr>
          <td class=roweven colspan=$colspan_sub align=right>[lang::message::lookup $locale intranet-invoices.VAT]: [format "%0.1f" $vat]%&nbsp;</td>
          <td class=roweven align=right>$vat_amount_pretty $currency</td>
        </tr>
"
} else {
    append item_list_html "
        <tr>
          <td class=roweven colspan=$colspan_sub align=right>[lang::message::lookup $locale intranet-invoices.VAT]: 0%&nbsp;</td>
          <td class=roweven align=right>0 $currency</td>
        </tr>
"
}

if {"" != $tax && 0 != $tax} {
    append item_list_html "
        <tr> 
          <td class=roweven colspan=$colspan_sub align=right>[lang::message::lookup $locale intranet-invoices.TAX]: [format "%0.1f" $tax] %&nbsp;</td>
          <td class=roweven align=right>$tax_amount_pretty $currency</td>
        </tr>
    "
}

append item_list_html "
        <tr> 
          <td class=roweven colspan=$colspan_sub align=right><b>[lang::message::lookup $locale intranet-invoices.Total_Due]</b></td>
          <td class=roweven align=right><b><nobr>$grand_total_pretty $currency</nobr></b></td>
        </tr>
"

set payment_terms_html "
        <tr>
	  <td valign=top>[lang::message::lookup $locale intranet-invoices.Payment_Terms]</td>
          <td valign=top colspan=[expr $colspan-1]> 
            [lang::message::lookup $locale intranet-invoices.lt_This_invoice_is_past_]
          </td>
        </tr>
"

set payment_method_html "
        <tr>
	  <td valign=top>[lang::message::lookup $locale intranet-invoices.Payment_Method_1]</td>
          <td valign=top colspan=[expr $colspan-1]> $invoice_payment_method_desc</td>
        </tr>
"

set note_html "
        <tr>
	  <td valign=top>[lang::message::lookup $locale intranet-invoices.Note]</td>
          <td valign=top colspan=[expr $colspan-1]>
	    <pre><span style=\"font-family: verdana, arial, helvetica, sans-serif\">$cost_note</font></pre>
	  </td>
        </tr>
"

set terms_html ""
if {$cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]} {
    set terms_html [concat $payment_terms_html $payment_method_html]
}
append terms_html $note_html

set item_html [concat $item_list_html $terms_html]



# ---------------------------------------------------------------
# Special Output: Format using a template and/or send out as PDF
# ---------------------------------------------------------------

# Use a specific template ("render_template_id") to render the "preview"
# of this invoice
if {0 != $render_template_id || "" != $send_to_user_as} {

    # format using a template
    set invoice_template_path [ad_parameter -package_id [im_package_invoices_id] InvoiceTemplatePathUnix "" "/tmp/templates/"]
    append invoice_template_path "/"
    set invoice_template_body [db_string sel_invoice "select category from im_categories where category_id=:render_template_id" -default ""]
    append invoice_template_path $invoice_template_body

    if {"" == $invoice_template_body} {
	ad_return_complaint "$cost_type Template not specified" "
	<li>You haven't specified a template for your $cost_type."
	return
    }

    if {![file isfile $invoice_template_path] || ![file readable $invoice_template_path]} {
	ad_return_complaint "Unknown $cost_type Template" "
	<li>$cost_type template '$invoice_template_path' doesn't exist or is not readable
	for the web server. Please notify your system administrator."
	return
    }

    # Render the page using the template
    set invoices_as_html [ns_adp_parse -file $invoice_template_path]


    # Redirect to a mail sending page.
    if {"" != $send_to_user_as} {
	# Redirect to mail sending page:
	# Add the rendered invoice to the form variables
	rp_form_put invoice_html $invoices_as_html
	rp_internal_redirect notify
	ad_script_abort

    } else {

	# Show invoice using template
	db_release_unused_handles
	ns_return 200 text/html $invoices_as_html
	ad_script_abort
    }
} 
