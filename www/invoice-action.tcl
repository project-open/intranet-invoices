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
    del_invoice:multiple,optional
    invoice_status:array,optional
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
	foreach invoice_id [array names invoice_status] {
	    set invoice_status_id $invoice_status($invoice_id)
	    ns_log Notice "set invoice_status($invoice_id) = $invoice_status_id"

	    db_dml update_invoice_status "update im_invoices set invoice_status_id=:invoice_status_id where invoice_id=:invoice_id"
	}

	ad_returnredirect $return_url
	return
    }

    "Del" {
	# "Del" button pressed: delete the marked invoices:
	#	- Mark the associated im_trans_tasks as "delivered"
	#	  and reset their invoice_id (to be able to
	#	  delete the invoice).
	#	- Delete the associated im_invoice_items
	#	- Delete from project-invoice-map!!!
	#
	set in_clause_list [list]
	foreach invoice_id $del_invoice {
	    lappend in_clause_list $invoice_id
	}
	set invoice_where_list "([join $in_clause_list ","])"

	set delete_invoice_items_sql "
		delete from im_invoice_items i
		where i.invoice_id in $invoice_where_list
	"

	# Reset the status of all project to "delivered" that
	# were included in the invoice
	set reset_projects_included_sql "
		update im_projects
		set project_status_id=:project_status_delivered
		where project_id in (
			select distinct
				r.object_id_one
			from
				acs_rels r
			where
				r.object_id_two in $invoice_where_list
		)
	"

	# Set all projects back to "delivered" that have tasks
	# that were included in the invoices to delete.
	set reset_projects_with_tasks_sql "
		update im_projects
		set project_status_id=:project_status_delivered
		where project_id in (
			select distinct
				t.project_id
			from
				im_trans_tasks t
			where
				t.invoice_id in $invoice_where_list
		)
	"

	# Reset the status of all invoiced tasks to delivered.
	set reset_tasks_sql "
		update im_trans_tasks t
		set invoice_id=null
		where t.invoice_id in $invoice_where_list
	"

	set delete_map_sql "
		delete from acs_rels r
		where r.object_id_two in $invoice_where_list
	"

	set delete_invoices_sql "
		delete from im_invoices
		where invoice_id in $invoice_where_list
	"

	db_transaction {
	    # Changing project state back to "delivered" and 
	    # changing im_trans_tasks to not-invoice only for translation...
	    if {[db_table_exists "im_trans_tasks"]} {
		db_dml reset_projects_with_tasks $reset_projects_with_tasks_sql
		db_dml reset_tasks $reset_tasks_sql
	    }

	    db_dml reset_projects_included $reset_projects_included_sql
	    db_dml delete_invoice_items $delete_invoice_items_sql
	    db_dml delete_map $delete_map_sql
	    db_dml delete_invoices $delete_invoices_sql
	}

	ad_returnredirect $return_url
	return
    }

    default {
	set error "Unknown submit command: '$submit'"
	ad_returnredirect "/error?error=$error"
    }
}

