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

db_release_unused_handles
ad_returnredirect $return_url
