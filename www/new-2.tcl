# /packages/intranet-invoices/www/new-2.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_page_contract {
    Saves invoice changes and set the invoice status to "Created".<br>
    Please note that there are different forms to create invoices for
    example in the intranet-trans-invoicing module of the 
    intranet-server-hosting module.
    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    { customer_id:integer 0 }
    { provider_id:integer 0 }
    { project_id:integer 0 }
    invoice_nr
    invoice_date
    { invoice_status_id "[im_invoice_status_created]" }
    { invoice_type_id "[im_invoice_type_invoice]" }
    payment_days:integer
    { payment_method_id:integer "" }
    invoice_template_id:integer
    vat
    tax
    item_sort_order:array
    item_name:array
    item_units:float,array
    item_uom_id:integer,array
    item_type_id:integer,array
    item_project_id:integer,array
    item_rate:float,array
    item_currency:array
    { return_url "/intranet-invoices/" }
}

# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Customer" fields.
set invoice_or_quote_p [expr $invoice_type_id == [im_invoice_type_invoice] || $invoice_type_id == [im_invoice_type_quote]]
ns_log Notice "intranet-invoices/new-2: invoice_or_quote_p=$invoice_or_quote_p"

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $invoice_type_id == [im_invoice_type_invoice] || $invoice_type_id == [im_invoice_type_bill]]
ns_log Notice "intranet-invoices/new-2: invoice_or_bill_p=$invoice_or_bill_p"

if {$invoice_or_quote_p} {
    set company_id $customer_id
} else {
    set company_id $provider_id
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint 1 "<li>You don't have sufficient privileges to see this page."
    return
}

# Invoices and Bills need a payment method, quotes and POs don't.
if {$invoice_or_bill_p && ("" == $payment_method_id || 0 ==$payment_method_id)} {
    ad_return_complaint 1 "<li>No payment method specified"
    return
}


set customer_internal [db_string customer_internal "select customer_id from im_customers where lower(customer_path) = 'internal'" -default 0]
if {!$customer_internal} {
    ad_return_complaint 1 "<li>Unable to find 'Internal' customer with path 'internal'. <br>Maybe somebody has change the path of the customer?"    
    return
}

if {!$provider_id} { set provider_id $customer_internal }
if {!$customer_id} { set customer_id $customer_internal }

# ---------------------------------------------------------------
# Update invoice base data
# ---------------------------------------------------------------

set invoice_exists_p [db_string invoice_count "select count(*) from im_invoices where invoice_id=:invoice_id"]

# Just update the invoice if it already exists:
if {!$invoice_exists_p} {

    # Let's create the new invoice
    db_dml create_invoice "
DECLARE
    v_invoice_id        integer;
BEGIN
    v_invoice_id := im_invoice.new (
        invoice_id              => :invoice_id,
        creation_user           => :user_id,
        creation_ip             => '[ad_conn peeraddr]',
        invoice_nr              => :invoice_nr,
        customer_id             => :customer_id,
        provider_id             => :provider_id,
        invoice_date            => sysdate,
        invoice_template_id     => :invoice_template_id,
        invoice_status_id       => :invoice_status_id,
        invoice_type_id         => :invoice_type_id,
        payment_method_id       => :payment_method_id,
        payment_days            => :payment_days,
        vat                     => :vat,
        tax                     => :tax
    );
END;"

}

# ---------------------------------------------------------------
# Create the im_invoice_items for the invoice
# ---------------------------------------------------------------

    # Delete the old items if they exist
    db_dml delete_invoice_items "
	DELETE from im_invoice_items
	WHERE invoice_id=:invoice_id
    "

set item_list [array names item_name]
foreach nr $item_list {
    set name $item_name($nr)
    set units $item_units($nr)
    set uom_id $item_uom_id($nr)
    set type_id $item_type_id($nr)
    set project_id $item_project_id($nr)
    set rate $item_rate($nr)
    set currency $item_currency($nr)
    set sort_order $item_sort_order($nr)
    ns_log Notice "item($nr, $name, $units, $uom_id, $project_id, $rate, $currency)"

    # Insert only if it's not an empty line from the edit screen
    if {!("" == [string trim $name] && (0 == $units || "" == $units))} {
	set item_id [db_nextval "im_invoice_items_seq"]
	set insert_invoice_items_sql "
INSERT INTO im_invoice_items (
	item_id, item_name, project_id, invoice_id, item_units, item_uom_id, 
	price_per_unit, currency, sort_order, item_type_id, item_status_id, description
) VALUES (
	:item_id, :name, :project_id, :invoice_id, :units, :uom_id, 
	:rate, :currency, :sort_order, :type_id, null, ''
)"

        db_dml insert_invoice_items $insert_invoice_items_sql
    }
}

db_release_unused_handles
ad_returnredirect "/intranet-invoices/view?invoice_id=$invoice_id"
