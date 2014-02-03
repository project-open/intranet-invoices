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
    { cost:multiple "" }
    { cost_status:array "" }
    { new_payment_amount:array "" }
    { new_payment_currency:array "" }
    { new_payment_type_id:array "" }
    { new_payment_company_id:array "" }
    { invoice_action "" }

}

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint 1 "<li>You have insufficient privileges to see this page"
    return
}

# ad_return_complaint 1 "$cost - $invoice_action"

set invoice_status_id ""
if {[regexp {status_([0-9]*)} $invoice_action match id]} {
    set invoice_action "status"
    set invoice_status_id $id
}

# No matter what action had been choosen, we handle payments 
foreach {invoice_id invoice_amount} [array get new_payment_amount] {

    if { "" != $invoice_amount } {

	set payment_id [db_nextval "im_payments_id_seq"]
	set cost_id $invoice_id

	set _new_payment_currency $new_payment_currency($invoice_id)
	set _new_payment_company_id $new_payment_company_id($invoice_id) 
	set _new_payment_type_id $new_payment_type_id($invoice_id)
	
	set received_date [clock format [clock seconds] -format {%Y-%m-%d}]
	
	set sql "
        insert into im_payments (
                payment_id,
                cost_id,
                company_id,
                provider_id,
                amount,
                currency,
                received_date,
                payment_type_id,
                note,
                last_modified,
                last_modifying_user,
                modified_ip_address
    	) values (
                :payment_id,
                :cost_id,
                :_new_payment_company_id,
                :_new_payment_company_id,
                :invoice_amount,
                :_new_payment_currency,
                :received_date,
                :_new_payment_type_id,
                'Bulk Processing: Field \"Payment received\" had been set with date of payment registration',
                (select sysdate from dual),
                :user_id,
                '[ns_conn peeraddr]'
    	)"
	
	if {[catch {
	    db_dml register_payment $sql 
	    im_cost_update_payments $invoice_id
	} err_msg]} {
	    global errorInfo
	    ad_return_complaint 1 "[lang::message::lookup "" intranet-invoices.UnableToRegisterPayment "Unable to register payment"] $errorInfo"
	    return
	}
    }
}

switch $invoice_action {
    save {
	# Save the states for the invoices on this list
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

	    im_audit -object_id $invoice_id
	}
    }
    del {
	foreach cost_id $cost {
	    set otype [db_string object_type "select object_type from acs_objects where object_id = :cost_id" -default ""]
	    if {"" == $otype} { continue }
	    
	    # Check CostCenter Permissions
	    im_cost_permissions $user_id $cost_id view_p read_p write_p admin_p
	    if {!$write_p} {
		ad_return_complaint 1 "<li>You have insufficient privileges to perform this action"
		ad_script_abort
	    }
	    im_audit -object_id $cost_id -action before_delete
	    db_string delete_cost_item ""
	}
    }
    status {
	foreach cost_id $cost {
	    
	    # Check CostCenter Permissions
	    im_cost_permissions $user_id $cost_id view_p read_p write_p admin_p
	    if {!$write_p} {
		ad_return_complaint 1 "<li>You have insufficient privileges to perform this action"
		ad_script_abort
	    }
	    db_dml update_status "update im_costs set cost_status_id = :invoice_status_id where cost_id = :cost_id"
	}
	
    }
}

ad_returnredirect $return_url


