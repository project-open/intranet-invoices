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

    @author frank.bergmann@project-open.com
} {
    { include_task:multiple "" }
    { invoice_id:integer ""}
    { customer_id:integer 0}
    { project_id:integer ""}
    { invoice_currency ""}
    { return_url "/intranet-invoice/"}
}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

if {[info exists include_task]} {
    ns_log Notice "new: include_task=$include_task"
} else {
    ns_log Notice "new: include_task does not exist"
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

# Get some categories for a new invoice
set invoice_status_created_id [db_string invoice_status "select invoice_status_id from im_invoice_status where upper(invoice_status)='CREATED'"]
set invoice_type_normal_id [db_string invoice_type "select invoice_type_id from im_invoice_type where upper(invoice_type)='NORMAL'"]



# Tricky case: Sombebody has called this page from a project
# So we need to find out the customer of the project and create
# an invoice from scratch, invoicing all project elements.
#
# However, invoices are created in very different ways in 
# each business sector:
# - Translation: Sum up the im_trans_tasks and determine the
#   price from im_translation_prices.
# - IT: Create invoices from scratch, from hours or from 
#   (monthly|quarterly|...) service fees
#
if {"" != $project_id} {
    set customer_id [db_string customer_id "select customer_id from im_projects where project_id=:project_id"]
}


# ---------------------------------------------------------------
# 3. Gather invoice data
#	a: if the invoice already exists
# ---------------------------------------------------------------

# Check if we are editing an already existing invoice
#
if { [exists_and_not_null invoice_id] } {
    # We are editing an already existing invoice
    #
    set invoice_mode "exists"
    set button_text "Edit Invoice"
    set page_title "Edit Invoice"
    set context_bar [ad_context_bar [list /intranet/invoices/ "Invoices"] $page_title]

    db_1row invoices_info_query "
select 
	i.*,
	im_name_from_user_id(i.customer_contact_id) as customer_contact_name,
	im_email_from_user_id(i.customer_contact_id) as customer_contact_email,
	c.customer_name,
	c.customer_path as customer_short_name
from
	im_invoices i, 
	im_customers c
where 
        i.invoice_id=:invoice_id
	and i.customer_id=c.customer_id(+)
    "

    # Check if there is a single currency being used in the invoice
    # and get it.
    # This should always be the case, but doesn't need to...

    if {"" == $invoice_currency} {
	catch {
	    db_1row invoices_currency_query "
select distinct
	currency as invoice_currency
from
	im_invoice_items i
where
	i.invoice_id=:invoice_id"
	} err_msg
    }

} else {

# ---------------------------------------------------------------
# Setup the fields for a new invoice
# ---------------------------------------------------------------

    # Build the list of selected tasks ready for invoices
    set invoice_mode "new"
    set in_clause_list [list]
    set button_text "Create Invoice"
    set page_title "New Invoice"
    set context_bar [ad_context_bar [list /intranet/invoices/ "Invoices"] $page_title]

    set invoice_id [db_nextval "im_invoices_seq"]
    set invoice_nr [im_next_invoice_nr]
    set invoice_status_id $invoice_status_created_id
    set invoice_type_id $invoice_type_normal_id
    set invoice_date $todays_date
    set payment_days [ad_parameter -package_id [im_package_invoices_id] "DefaultPaymentDays" "" 30] 
    set due_date [db_string get_due_date "select sysdate+:payment_days from dual"]
    set vat 0
    set tax 0
    set note ""
    set payment_method_id ""
    set invoice_template_id ""
}

# ---------------------------------------------------------------
# 4. Gather customer data from customer_id (both edit or new modes)
# ---------------------------------------------------------------

db_0or1row invoices_info_query "
select 
	c.*,
        o.*,
	im_email_from_user_id(c.accounting_contact_id) as customer_contact_email,
	im_name_from_user_id(c.accounting_contact_id) as customer_contact_name,
	c.customer_name,
	c.customer_path as customer_short_name,
        cc.country_name
from
	im_customers c, 
        im_offices o,
        country_codes cc
where 
        c.customer_id = :customer_id
        and c.main_office_id=o.office_id(+)
        and o.address_country_code=cc.iso(+)
"
ns_log Notice "after looking up customer #$customer_id"


# ---------------------------------------------------------------
# 5. Render the "Invoice Data" and "Customer" blocks
# ---------------------------------------------------------------
set invoice_data_html "
        <tr><td align=middle class=rowtitle colspan=2>Invoice Data</td></tr>
        <tr>
          <td  class=rowodd>Invoice nr.:</td>
          <td  class=rowodd> 
            <input type=text name=invoice_nr size=15 value='$invoice_nr'>
          </td>
        </tr>
        <tr> 
          <td  class=roweven>Invoice date:</td>
          <td  class=roweven> 
            <input type=text name=invoice_date size=15 value='$invoice_date'>
          </td>
        </tr>
<!--        <tr> 
          <td  class=rowodd>Invoice due date:</td>
          <td  class=rowodd> 
            <input type=text name=due_date size=15 value='$due_date'>
          </td>
        </tr>
-->
        <tr> 
          <td class=roweven>Payment terms</td>
          <td class=roweven> 
            <input type=text name=payment_days size=5 value='$payment_days'>
            days date of invoice</td>
        </tr>
        <tr> 
          <td class=rowodd>Payment Method</td>
          <td class=rowodd>[im_invoice_payment_method_select payment_method_id $payment_method_id]</td>
        </tr>
        <tr> 
          <td class=roweven> Invoice template:</td>
          <td class=roweven>[im_invoice_template_select invoice_template_id $invoice_template_id]</td>
        </tr>
        <tr> 
          <td class=rowodd> Invoice status</td>
          <td class=rowodd>[im_invoice_status_select invoice_status_id $invoice_status_id]</td>
        </tr>
        <tr> 
          <td class=roweven> Invoice type</td>
          <td class=roweven>[im_invoice_type_select invoice_type_id $invoice_type_id]</td>
        </tr>
"

    set customer_html "
<tr>
  <td align=center valign=top class=rowtitle colspan=2>Customer</td>
</tr>
<tr>
  <td class=roweven>Customer:</tr>
  <td class=roweven>[im_customer_select customer_id $customer_id]</td>
</tr>
<input type=hidden name=provider_id value=0>
"

# ---------------------------------------------------------------
# 7. Select and format the sum of the invoicable items
# for a new invoice
# ---------------------------------------------------------------

if {[string equal $invoice_mode "new"]} {

    # start formatting the list of sums with the header...
    set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>Order</td>
          <td class=rowtitle>Description</td>
          <td class=rowtitle>Type</td>
          <td class=rowtitle>Units</td>
          <td class=rowtitle>UOM</td>
          <td class=rowtitle>Rate </td>
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
	i.invoice_id=:invoice_id
	and i.project_id=p.project_id(+)
order by
	i.project_id
"

    # start formatting the list of sums with the header...
    set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>Order</td>
          <td class=rowtitle>Description</td>
          <td class=rowtitle>Type</td>
          <td class=rowtitle>Units</td>
          <td class=rowtitle>UOM</td>
          <td class=rowtitle>Rate </td>
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
	          $customer_project_nr
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
	    <input type=text name=item_rate.$ctr size=3 value='0'>[im_currency_select item_currency.$ctr $invoice_currency]
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value=''>
"

    incr ctr
}

# ---------------------------------------------------------------
# 9. Render VAT and TAX
# ---------------------------------------------------------------

set grand_total_html "
        <tr>
          <td> 
          </td>
          <td colspan=99 align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>VAT&nbsp;</td>
                <td><input type=text name=vat value='$vat' size=4> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr> 
          <td> 
          </td>
          <td colspan=99 align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>TAX&nbsp;</td>
                <td><input type=text name=tax value='$tax' size=4> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr> 
          <td>&nbsp; </td>
          <td colspan=6 align=right> 
              <input type=submit name=submit value='$button_text'>
          </td>
        </tr>
"

# ---------------------------------------------------------------
# 10. Join all parts together
# ---------------------------------------------------------------

ns_log Notice "new: before joining the parts together"

set page_body "
[im_invoices_navbar "none" "/intranet/invoices/index" "" "" [list]]

<form action=new-2 method=POST>
[export_form_vars invoice_id return_url]

  <!-- Invoice Data and Customer Tables -->

<!-- outer table -->
<table border=0 width=100%>
<tr><td>

  <table cellpadding=0 cellspacing=0 bordercolor=#6699CC border=0 width=100%>
    <tr valign=top> 
      <td>

        <table border=0 cellPadding=0 cellspacing=2 width=100%>
	  $invoice_data_html
<!--	  <tr><td colspan=2 align=right><input type=submit value='Update'></td></tr> -->
        </table>

      </td>
      <td></td>
      <td align=right>
        <table border=0 cellspacing=2 cellpadding=0 width=100%>
          $customer_html</td>
        </table>
    </tr>
  </table>

</td></tr>
<!-- outer table -->
<tr><td>

  <!-- the list of task sums, distinguised by type and UOM -->
  <table width=100%>
    <tr>
      <td align=right>
 	<table border=0 cellspacing=2 cellpadding=1 width=100%>
          $task_sum_html
          $grand_total_html
        </table>
      </td>
    </tr>
  </table>


<!-- outer table -->
</td></tr>
</table>

</form>
"

ns_log Notice "new: before doc_return"
db_release_unused_handles
doc_return  200 text/html [im_return_template]
