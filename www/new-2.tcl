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
    { customer_id:integer "" }
    { provider_id:integer "" }
    { select_project:integer,multiple {} }
    invoice_nr
    invoice_date
    cost_status_id:integer 
    cost_type_id:integer
    payment_days:integer
    { payment_method_id:integer "" }
    template_id:integer
    vat:float
    tax:float
    note
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
set invoice_or_quote_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_quote]]
ns_log Notice "intranet-invoices/new-2: invoice_or_quote_p=$invoice_or_quote_p"

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]]
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
if {$invoice_or_bill_p && ("" == $payment_method_id || 0 == $payment_method_id)} {
    ad_return_complaint 1 "<li>No payment method specified"
    return
}

if {"" == $provider_id} { set provider_id [im_customer_internal] }
if {"" == $customer_id} { set customer_id [im_customer_internal] }


set project_id ""
if {1 == [llength $select_project]} {
    set project_id [lindex $select_project 0]
}


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
	        invoice_date            => :invoice_date,
	        invoice_template_id     => :template_id,
	        invoice_status_id	=> :cost_status_id,
	        invoice_type_id		=> :cost_type_id,
	        payment_method_id       => :payment_method_id,
	        payment_days            => :payment_days,
		amount			=> 0,
	        vat                     => :vat,
	        tax                     => :tax,
	        note			=> :note
	    );
	END;"
}

# Update the invoice itself
db_dml update_invoice "
update im_invoices 
set 
	invoice_nr	= :invoice_nr,
	payment_method_id = :payment_method_id
where
	invoice_id = :invoice_id
"

db_dml update_costs "
update im_costs
set
	project_id	= :project_id,
	cost_name	= :invoice_nr,
	cost_nr		= :invoice_id,
	customer_id	= :customer_id,
	provider_id	= :provider_id,
	cost_status_id	= :cost_status_id,
	cost_type_id	= :cost_type_id,
	template_id	= :template_id,
	effective_date	= :invoice_date,
	start_block	= ( select max(start_block) 
			    from im_start_months 
			    where start_block < :invoice_date),
	payment_days	= :payment_days,
	vat		= :vat,
	tax		= :tax,
	note		= :note,
	variable_cost_p = 't'
where
	cost_id = :invoice_id
"

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
		item_id, item_name, 
		project_id, invoice_id, 
		item_units, item_uom_id, 
		price_per_unit, currency, 
		sort_order, item_type_id, 
		item_status_id, description
	) VALUES (
		:item_id, :name, 
		:project_id, :invoice_id, 
		:units, :uom_id, 
		:rate, :currency, 
		:sort_order, :type_id, 
		null, ''
	)"

        db_dml insert_invoice_items $insert_invoice_items_sql
    }
}

# ---------------------------------------------------------------
# Associate the invoice with the project via acs_rels
# ---------------------------------------------------------------

foreach project_id $select_project {
    db_dml insert_acs_rels "
        DECLARE
                v_rel_id        integer;
		v_rel_exists	integer;
        BEGIN
		select	count(*)
		into	v_rel_exists
		from	acs_rels
		where	object_id_one = :project_id
			and object_id_two = :invoice_id;

		if 0 = v_rel_exists then
	                v_rel_id := acs_rel.new(
	                        object_id_one => :project_id,
	                        object_id_two => :invoice_id
	                );
		end if;
        END;"
}

# ---------------------------------------------------------------
# Update the invoice amount based on the invoice items
# ---------------------------------------------------------------

set update_invoice_amount_sql "
update im_costs
set amount = (
	select sum(price_per_unit * item_units)
	from im_invoice_items
	where invoice_id = :invoice_id
	group by invoice_id
)
where cost_id = :invoice_id
"

db_dml update_invoice_amount $update_invoice_amount_sql

db_release_unused_handles
ad_returnredirect "/intranet-invoices/view?invoice_id=$invoice_id"
