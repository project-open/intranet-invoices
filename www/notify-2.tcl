# /packages/intranet-core/www/member-notify.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Sends a notification message to a member
    @author frank.bergmann@project-open.com
} {
    user_id_from_search:integer
    object_id:integer
    role_id:integer
    subject
    message
    { send_me_a_copy "" }
    return_url
}


######### Not being used anymore (?) ##############


# ToDo: Delete this file






# --------------------------------------------------------
# Security and defaults
# --------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
im_cost_permissions $user_id $invoice_id view read write admin
if {!write} {
    ad_return_complaint "[_ intranet-invoices.lt_Insufficient_Privileg]" "
    <li>[_ intranet-invoices.lt_You_dont_have_suffici]"
}


# --------------------------------------------------------
# Send out an email alert
# --------------------------------------------------------

im_send_alert $user_id_from_search "hourly" $subject $message

# Send a CC
im_send_alert $user_id "hourly" $subject $message

ad_returnredirect $return_url
