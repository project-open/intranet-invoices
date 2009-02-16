# /packages/intranet-invoices/www/invoice-action.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_page_contract {
    Purpose: Takes commands from the /intranet/invoices/index
    page and deletes invoices where marked

    @param return_url the url to return to
    @param group_id group id
    @author frank.bergmann@project-open.com
} {
    { return_url "/intranet-invoices/" }
    del_cost:multiple,optional
    cost_status:array,optional
    object_type:array,optional
    submit_del:optional
    submit_save:optional
}

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint 1 "<li>You have insufficient privileges to see this page"
    return
}


if {[info exists submit_save]} {
    # Save the stati for the invoices on this list
    foreach invoice_id [array names cost_status] {
	set cost_status_id $cost_status($invoice_id)
	ns_log Notice "set cost_status($invoice_id) = $cost_status_id"

	# Check CostCenter Permissions
	im_cost_permissions $user_id $invoice_id view_p read_p write_p admin_p
	if {!$write_p} {
	    ad_return_complaint 1 "<li>You have insufficient privileges to perform this action"
	    ad_script_abort
	}

	# Update the invoice
	db_dml update_cost_status "
		update im_costs 
		set cost_status_id=:cost_status_id 
		where cost_id = :invoice_id
	"
    }

    ad_returnredirect $return_url
    return
}

if {[info exists submit_del]}  {
    # Maybe the list of costs was empty...
    if {![info exists del_cost]} {
	ad_returnredirect $return_url
	return
    }

    foreach cost_id $del_cost {
	set otype $object_type($cost_id)

	# Check CostCenter Permissions
	im_cost_permissions $user_id $cost_id view_p read_p write_p admin_p
	if {!$write_p} {
	    ad_return_complaint 1 "<li>You have insufficient privileges to perform this action"
	    ad_script_abort
	}
	db_string delete_cost_item ""
	lappend in_clause_list $cost_id
    }
    set cost_where_list "([join $in_clause_list ","])"

    ad_returnredirect $return_url
    return
}

set error "Unknown command: neither 'sumit_del' nor 'submit_save'"
ad_returnredirect "/error?error=$error"

