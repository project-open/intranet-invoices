# /packages/intranet-invoices/www/notify-2.tcl
#
# Copyright (C) 1998-2004 various parties
# The code is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_page_contract {
    Sends a notification message to a member
    @author frank.bergmann@project-open.com
} {
    subject
    message
    return_url
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "Insufficient permissions"
    return
}

# ---------------------------------------------------------------
# Create Multipart MIME-Message
# ---------------------------------------------------------------

# create the multipart message ('multipart/mixed')
set multipart_id [acs_mail_multipart_new -multipart_kind "mixed"]

# create an acs_mail_body (with content_item_id = multipart_id )
set body_id [acs_mail_body_new \
	-header_subject $subject \
	-content_item_id $multipart_id \
]

# create a new text/plain item
set content_item_id [db_exec_plsql create_text_item "
begin
    :1 := content_item.new (
	name =>		'acs-mail message $body_id-1',
	title => 	:subject,
	mime_type =>	'text/plain',
	text =>		:message
    );
end;
"]

acs_mail_multipart_add_content \
	-multipart_id $multipart_id \
	-content_item_id $content_item_id

# create a new text/html item
set content_item_id [db_string create_html_item "
begin
    select content_item.new (
	name =>		'acs-mail message $body_id-2',
	title =>	'html message',
	mime_type =>	text/html',
	text =>		'HTML <b>message</b> content',
    );
end;
"]

acs_mail_multipart_add_content \
	-multipart_id $multipart_id \
	-content_item_id $content_item_id



set mail_link_id [db_string queue_message "
begin
	acs_mail_queue_message.new (
		p_mail_link_id =>	null,
		p_body_id =>		:body_id,
		p_context_id =>		null,
		p_object_type =>	'acs_mail_link'
	);
end;
"]



db_dml outgoing_queue "
    insert into acs_mail_queue_outgoing ( 
	message_id, 
	envelope_from, 
	envelope_to 
    ) values ( 
	:mail_link_id, 
	:from_addr, 
	:to_addr 
)"



ad_return_complaint 1 "<li> Sent"



# Send out an email alert
# im_send_alert $user_id_from_search "hourly" $subject $message

# ad_returnredirect $return_url
