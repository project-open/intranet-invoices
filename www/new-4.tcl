# /www/intranet/invoices/new-4.tcl

ad_page_contract {
    Purpose: Save invoice changes and set the invoice status to "Created"
    or higher.
    @author fraber@fraber.de
    @creation-date Aug 2003
} {
    invoice_id:integer
    { customer_id:integer 0 }
    { provider_id:integer 0 }
    invoice_nr
    invoice_date
    { invoice_type_id 700 }
    payment_days:integer
    payment_method_id:integer
    invoice_template_id:integer
    vat
    tax
    item_sort_order:array
    item_name:array
    item_units:array
    item_uom_id:integer,array
    item_type_id:integer,array
    item_project_id:integer,array
    item_rate:array
    item_currency:array
    { return_url "/intranet-invoices/" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id view_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

set invoice_status_created [db_string invoice_status "select invoice_status_id from im_invoice_status where upper(invoice_status)='CREATED'"]

set invoice_status_in_process [db_string invoice_status "select category_id from im_categories where category_type='Intranet Invoice Status' and upper(category)='IN PROCESS'"]

set project_status_invoiced [db_string project_status "select category_id from im_categories where category_type='Intranet Project Status' and upper(category)='INVOICED'"]

set customer_internal [db_string customer_internal "select customer_id from im_customers where lower(customer_path) = 'internal'" -default 0]
if {!$customer_internal} {
    ad_return_complaint 1 "<li>Unable to find 'Internal' customer with path 'internal'. <br>Maybe somebody has change the path of the customer?"    
    return
}

if {!$provider_id} { set provider_id $customer_internal }
if {!$customer_id} { set customer_id $customer_internal }

# ---------------------------------------------------------------
# 0. Update invoice base data
# ---------------------------------------------------------------

set invoice_exists_p [db_string invoice_count "select count(*) from im_invoices where invoice_id=:invoice_id"]
if {!$invoice_exists_p} {

    db_dml create_invoice "
INSERT INTO im_invoices (
	invoice_id, 
	invoice_nr,
	customer_id, 
	provider_id, 
	invoice_date,
	payment_days,
	payment_method_id,
	invoice_template_id,
	vat,
	tax,
	invoice_status_id, 
	invoice_type_id, 
	last_modified, 
	last_modifying_user, 
	modified_ip_address
) VALUES (
	:invoice_id, 
	:invoice_nr,
	:customer_id, 
	:provider_id, 
	:invoice_date,
	:payment_days,
	:payment_method_id,
	:invoice_template_id,
	:vat,
	:tax,
	:invoice_status_created, 
	:invoice_type_id, 
	sysdate,
	:user_id,
	'[ad_conn peeraddr]'
)"
    
} else {

    db_dml update_im_invoices "
UPDATE im_invoices 
SET 
	invoice_nr=:invoice_nr,
	invoice_date=:invoice_date,
	payment_days=:payment_days,
	payment_method_id=:payment_method_id,
	invoice_template_id=:invoice_template_id,
	vat=:vat,
	tax=:tax
WHERE
	invoice_id=:invoice_id
"
}

# ---------------------------------------------------------------
# 1. Create the new "im_invoice_items"
# ---------------------------------------------------------------

    # Delete the old items
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
    if {"" != [string trim $name] || 0 != $units} {
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

# ---------------------------------------------------------------
# Update the invoice status from "In Process" to "Created"
# ---------------------------------------------------------------

# only if 
db_dml update_invoice_status "
	UPDATE im_invoices set invoice_status_id=:invoice_status_created
	WHERE
		invoice_id=:invoice_id
		and invoice_status_id=:invoice_status_in_process
"

db_release_unused_handles
ad_returnredirect "/intranet-invoices/view?invoice_id=$invoice_id"
