# /packages/intranet-invoices/www/add-project-to-invoice-2.tcl
#
# Copyright (C) 2003-2004 Project/Open
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
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint 1 "<li>You don't have sufficient privileges to see this page."
    return
}

# ---------------------------------------------------------------
# Update association
# ---------------------------------------------------------------
set association_id [db_exec_plsql insert_association {} ]

db_release_unused_handles
ad_returnredirect $return_url
