# /packages/intranet-invoices/www/invoice-action.tcl
#
# Copyright (C) 2003-2004 Project/Open
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
    submit
}

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint 1 "<li>You have insufficient privileges to see this page"
    return
}

set task_status_delivered [db_string task_status_delivered "select task_status_id from im_task_status where upper(task_status)='DELIVERED'"]
set project_status_delivered [db_string project_status_delivered "select project_status_id from im_project_status where upper(project_status)='DELIVERED'"]

ns_log Notice "invoice-action: submit=$submit"
switch $submit {

    "Save" {
	# Save the stati for the invoices on this list
	foreach invoice_id [array names cost_status] {
	    set cost_status_id $cost_status($invoice_id)
	    ns_log Notice "set cost_status($invoice_id) = $cost_status_id"

	    db_dml update_cost_status "update im_costs set cost_status_id=:cost_status_id where cost_id=:invoice_id"
	}

	ad_returnredirect $return_url
	return
    }

    "Del" {
       # Maybe the list of costs was empty...
        if {![info exists del_cost]} {
            ad_returnredirect $return_url
            return
        }

        foreach cost_id $del_cost {
            set otype $object_type($cost_id)
            # ToDo: Security
            db_dml delete_cost_item "
                begin
                        ${otype}.del(:cost_id);
                end;"
            lappend in_clause_list $cost_id
        }
        set cost_where_list "([join $in_clause_list ","])"

        ad_returnredirect $return_url
        return
    }

    default {
	set error "Unknown submit command: '$submit'"
	ad_returnredirect "/error?error=$error"
    }
}

