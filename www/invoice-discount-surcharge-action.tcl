# /packages/intranet-invoices/www/invoice-discount-surcharge-action.tcl
#
# Copyright (C) 2003 - 2010 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Adds lines for discount/surcharge to the Invoice

    @param return_url the url to return to
    @param invoice_id
    @author frank.bergmann@project-open.com
} {
    return_url
    invoice_id:integer
    pm_fee_percentage
    pm_fee_description
    discount_percentage
    discount_description
    surcharge_percentage
    surcharge_description
}

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint 1 "<li>You have insufficient privileges to see this page"
    return
}

set percentages [list $pm_fee_percentage $surcharge_percentage $discount_percentage]
set descriptions [list $pm_fee_description $surcharge_description $discount_description]

db_1row invoice_info "
	select	*
	from	im_costs c,
		im_invoices i
	where	c.cost_id = :invoice_id and
		c.cost_id = i.invoice_id
"

for {set i 0} {$i < 3} {incr i} {

    set name [lindex $descriptions $i]
    set percentage [lindex $percentages $i]
    set units 1
    set uom_id [im_uom_unit]
    set rate [expr $amount * $percentage / 100.0]
    set type_id ""
    set material_id ""
    set sort_order [db_string sort_order "select 10 + max(sort_order) from im_invoice_items where invoice_id = :invoice_id" -default ""]
    if {"" == $sort_order} { set sort_order 0 }
    set item_id [db_nextval "im_invoice_items_seq"]

    set insert_invoice_item_sql "
        INSERT INTO im_invoice_items (
                item_id, item_name,
                project_id, invoice_id,
                item_units, item_uom_id,
                price_per_unit, currency,
                sort_order, item_type_id,
                item_material_id,
                item_status_id, description, task_id
        ) VALUES (
                :item_id, :name,
                :project_id, :invoice_id,
                :units, :uom_id,
                :rate, :currency,
                :sort_order, :type_id,
                :material_id,
                null, '', null
        )
    "
    db_dml insert_invoice_items $insert_invoice_item_sql

}

ad_returnredirect $return_url
