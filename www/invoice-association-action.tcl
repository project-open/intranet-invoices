# /packages/intranet-invoices/www/add-project-to-invoice.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Allows to "associate" a project with a financial document.
    This is useful when the document has been created "from scratch".

    @param del_action Indicates that the Del button has been pressed
    @param add_project_action Indicates that the "Add Projects" button
           has been pressed
    @author frank.bergmann@project-open.com
} {
    { invoice_id:integer 0 }
    { project_id:integer 0 }
    { customer_id:integer 0 }
    { del_action "" }
    { add_project_action "" }
    { object_ids:array,optional }
    { return_url "/intranet-invoices/" }
}

# ---------------------------------------------------------------
# Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
im_cost_permissions $user_id $invoice_id view_p read_p write_p admin_p
if {!$write_p} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."
    ad_script_abort
}

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------

set page_focus "im_header_form.keywords"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"

set page_title "Associate Invoice with a Project"
set context_bar [im_context_bar [list /intranet/invoices/ "Finance"] $page_title]

# ---------------------------------------------------------------
# Del-Action: Delete the selected associated objects
# ---------------------------------------------------------------

if {"" != $del_action && [info exists object_ids]} {
    foreach object_id [array names object_ids] {
	ns_log Notice "intranet-invoices/invoice-associtation-action: deleting object_id=$object_id"
	db_exec_plsql delete_association {}
    }

    # Check if only a single relationship has been left
    # and set the im_costs.project_id field accordingly
    set rel_projects_sql "
	select	p.project_id
	from	acs_rels r,
		im_projects p
	where	object_id_one = p.project_id and
		r.object_id_two = :invoice_id
    "
    set rel_projects [db_list rel_projects $rel_projects_sql]
    if {1 == [llength $rel_projects]} {
	set rel_project_id [lindex $rel_projects 0]
	db_dml update_invoice_project_id "
		update	im_costs
		set	project_id = :rel_project_id
		where	cost_id = :invoice_id
	"
    }

    ad_returnredirect $return_url
    ad_abort_script
}

# ---------------------------------------------------------------
# Get everything about the invoice
# ---------------------------------------------------------------

set customer_id_org $customer_id

append query "
select
	ic.customer_id,
	i.invoice_nr
from
	im_invoices i,
	im_costs ic
where
	i.invoice_id = :invoice_id
	and ic.cost_id = i.invoice_id
"

if { ![db_0or1row projects_info_query $query] } {
    ad_return_complaint 1 "Can't find the document\# $invoice_id"
    return
}

if {0 != $customer_id_org} { set customer_id $customer_id_org }

set customer_name [db_string customer_name "select company_name from im_companies where company_id=:customer_id" -default ""]

set project_select [im_project_select -exclude_subprojects_p 0 object_id $project_id "" "" "" "" $customer_id]
set customer_select [im_company_select customer_id $customer_id "" "Customer"]

db_release_unused_handles

