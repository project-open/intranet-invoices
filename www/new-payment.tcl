# /www/intranet/invoices/new-payment.tcl

ad_page_contract {
    Purpose: form to enter payments for a project

    @param group_id Must have this if we're adding a payment
    @param payment_id Must have this if we're editing a payment

    @author fraber@fraber.de
    @creation-date August 2003
} {
    { return_url "" }
    { payment_id "" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set page_title "Payments"
set context_bar [ad_context_bar_ws $page_title]
set page_focus "im_header_form.keywords"

# Needed for im_view_columns, defined in intranet-views.tcl
set amp "&"

if {![im_permission $user_id view_finance]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

# ---------------------------------------------------------------
# Extract Payment Values (New vs. Edit)
# ---------------------------------------------------------------

if {[empty_string_p $payment_id]} {

    # We are creating a new Payment

    set add_delete_text 0
    set payment_id [db_nextval "im_payment_id_seq"]
    set page_title "New payment" 
    set context_bar [ad_context_bar_ws [list [im_url_stub]/invoices/ "Invoices"] $page_title]
    set button_name "Add payment"
    set customer_id 0
    set invoice_id 0
    set currency "EUR"
    set payment_type_id 0
    set received_date [db_string today "select to_char(sysdate, 'YYYY-MM-DD') from dual"]
    set note ""

    # Let's default start_block to something close to today
    if { ![db_0or1row nearest_start_block_select {
	select to_char(min(sb.start_block),'Month DD, YYYY') as start_block
	  from im_start_blocks sb
	where sb.start_block >= trunc(sysdate)}] } {
	    ad_return_error "Start block error" "The intranet start blocks are either undefined or we do not have a start block for this week or later into the future."
	    return
    }
	   
} else {

    # We are editing an already existing payment

    db_0or1row get_payment_info "
select
        p.*,
	i.invoice_nr,
	cg.group_name as customer_name,
	to_char(p.start_block,'Month DD, YYYY') as start_block
from
	user_groups cg,
	im_payments p,
	im_invoices i
where
	p.invoice_id=i.invoice_id(+)
	and i.customer_id = cg.group_id(+)
	and p.payment_id = :payment_id
"

    set add_delete_text 1
    set page_title "Edit payment"
    set context_bar [ad_context_bar_ws [list [im_url_stub]/invoices/ "Invoices"] $page_title]
    set button_name "Update"
}

# ---------------------------------------------------------------
# Format the page
# ---------------------------------------------------------------

set table_html "
	  <tr> 
	    <td colspan=2 class=rowtitle>Payment Details</td>
	  </tr>
	  <tr> 
	    <td>Invoice Nr</td>
	    <td> "

if {$invoice_id == 0} {
    append table_html [im_invoice_select invoice_id $invoice_id "" [list "Deleted" "In Process"]]
} else {
    append table_html "<A HREF=/intranet/invoices/view?invoice_id=$invoice_id>$invoice_nr</A>"
}

append table_html "
	    </td>
	  </tr>
	  <tr> 
	    <td>Amount</td>
	    <td> 
              <input type=text name=amount [export_form_value amount] size=8>
              [im_currency_select currency $currency]
	    </td>
	  </tr>

	  <tr> 
	    <td>Received</td>
	    <td>
              <input name=received_date value='$received_date' size=10>
	    </td>
	  </tr>

          <tr>
            <td>Payment Type</td>
            <td>
[im_payment_type_select payment_type_id" $payment_type_id]
            </td>
          </tr>


          <tr>
            <td>Note</td>
            <td>
              <TEXTAREA NAME=note COLS=45 ROWS=5 wrap=soft>$note</textarea>
            </td>
          </tr>

	  <tr> 
	    <td valign=top> </td>
	    <td><input type=submit value='$button_name' name=submit2></td>
	  </tr>
"

# ---------------------------------------------------------------
# Join the parts together
# ---------------------------------------------------------------

set page_body "

<form action=new-payment-2 method=POST>
[export_form_vars payment_id return_url]

<table border=0>
$table_html
</table>

</form>
"

doc_return  200 text/html [im_return_template]
