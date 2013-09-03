# /packages/intranet-invoices/www/add-project-to-invoice-2.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_page_contract {
    Associates an object with an invoice (financial document)

    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    object_id:integer
    return_url
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
im_cost_permissions $user_id $invoice_id view_p read_p write_p admin_p
if {!$write_p} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."
    ad_script_abort
}

# ---------------------------------------------------------------
# Update association
# ---------------------------------------------------------------

# Check if the association already exists.
# Otherwise we might violate a unique constraint
# if somebody uses this page several times...
set count [db_string count_associations "
	select count(*)
	from	acs_rels
	where	object_id_one = :object_id
		and object_id_two = :invoice_id
"]

if {!$count} {
    set association_id [db_exec_plsql insert_association {} ]
}



# ---------------------------------------------------------------
# Update im_costs.project_id
# ---------------------------------------------------------------

# Check if only a single relationship has been left
# and set the im_costs.project_id field accordingly
set rel_projects_sql "
        select  p.project_id
        from    acs_rels r,
                im_projects p
        where   object_id_one = p.project_id and
                r.object_id_two = :invoice_id
"
set rel_projects [db_list rel_projects $rel_projects_sql]

# Calculate the im_costs.project_id.
# This field should only have a value if there is
# exactly one relationship with a project.
set rel_project_id ""
if {1 == [llength $rel_projects]} {
    set rel_project_id [lindex $rel_projects 0]
}

db_dml update_invoice_project_id "
        update  im_costs
        set     project_id = :rel_project_id
        where   cost_id = :invoice_id
"
im_audit -object_type "im_invoice" -object_id $invoice_id -action after_update



db_release_unused_handles
ad_returnredirect $return_url
