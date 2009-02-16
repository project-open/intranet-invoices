# /packages/intranet-invoices/www/delete.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_page_contract {
    Purpose: Delete a single invoice

    @param return_url the url to return to
    @author frank.bergmann@project-open.com
} {
    { return_url "/intranet-invoices/list" }
    invoice_id:integer
}

set cost_id $invoice_id

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint 1 "<li>You have insufficient privileges to see this page"
    return
}

# Need to go through object type, because we may
# have to delete a "translation invoice", which
# requires different cleanup then "im_invoice".
#
set otype [db_string object_type "select object_type from acs_objects where object_id=:invoice_id"]

db_string delete_cost_item ""

ad_returnredirect $return_url
return
