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
    return_url
}

set user_id [ad_maybe_redirect_for_registration]

# Send out an email alert
im_send_alert $user_id_from_search "hourly" $subject $message

ad_returnredirect $return_url
