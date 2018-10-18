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
    line_check:array,optional
    line_perc:array,optional
    line_desc:array,optional
    line_amount:array,optional
}

set current_user_id [auth::require_login]
if {![im_permission $current_user_id add_invoices]} {
    ad_return_complaint 1 "<li>You have insufficient privileges to see this page"
    return
}

db_0or1row invoice_info "
	select	*
	from	im_costs c,
		im_invoices i
	where	c.cost_id = :invoice_id and
		c.cost_id = i.invoice_id
"

foreach i [array names line_perc] {

    set name $line_desc($i)
    set percentage $line_perc($i)
    set amount_line ""
    if {[info exists line_amount($i)]} { set amount_line $line_amount($i) }

    if { "" == [string trim $percentage] && "" == [string trim $amount_line]  } {
	continue
    }

    if { "" != [string trim $percentage] && "" != [string trim $amount_line] } {
	ad_return_complaint 1 [lang::message::lookup "" intranet-invoices.PleaseChooseEitherPercentOrAmount "Please choose either amount or percentage"]
    }

    if { ("" != [string trim $percentage] && ![string is double -strict $percentage]) || ("" != [string trim $amount_line] && ![string is double -strict $amount_line]) } {
	ad_return_complaint 1 [lang::message::lookup "" intranet-invoices.AmountOrPercentageMustBeNumeric "Please make sure that percentage or amount are numeric."]
    }

    set checked ""
    if {[info exists line_check($i)]} { set checked $line_check($i) }
    if {"" == $checked} { continue }

    set units 1
    set uom_id [im_uom_unit]
    if { "" != $percentage } {
	set rate [expr {$amount * $percentage / 100.0}]	
    } else {
	set rate $amount_line
    }

    set type_id ""
    set material_id ""
    set new_project_id ""
    set sort_order [db_string sort_order "select 10 + max(sort_order) from im_invoice_items where invoice_id = :invoice_id" -default ""]
    if {"" == $sort_order} { set sort_order 0 }

    set item_id [db_string new_invoice_item "select im_invoice_item__new (
			null, 'im_invoice_item', now(), :current_user_id, '[ad_conn peeraddr]', null,
			:name, :invoice_id, :sort_order,
			:units, :uom_id, :rate, :currency,
			[im_invoice_item_type_default], [im_invoice_item_status_active]
    )"]
    db_dml update_new_invoice_item "
		    	update im_invoice_items set
			       		project_id = :new_project_id,
			       		item_material_id = :material_id
			where item_id = :item_id
    "
}

# ---------------------------------------------------------------
# Update the invoice value
# ---------------------------------------------------------------

im_invoice_update_rounded_amount -invoice_id $invoice_id

# Audit the action
im_audit -object_type "im_invoice" -object_id $invoice_id -action after_update



ad_returnredirect $return_url
