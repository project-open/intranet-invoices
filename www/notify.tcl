# /packages/intranet-invoices/www/notify.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    Purpose: Send an email to the accounting/project contact
    to inform about the invoice.
    The contact can be informed via:
    <ul>
    <li>Link: The user needs to log-in in order to see the invoice
    <li>HTML: The content of the invoice is sent out as a HTML
        page. However, logos or any other included links need to
        be accessible on a webserver URL "from outside the office", 
        otherwise the HTML will not be displayed correctly.
    <li>PDF: If the html2ps/html2pdf converters are installed.
        This is the most stable solution. Howeve, you have to
        make sure the the PDF converter finds all logos and CSS
        for the PO server.
    </ul>

    @param user_id_from_search user_id to add
    @param object_id group to which to add
    @param role_id role in which to add
    @param return_url Return URL
    @param also_add_to_group_id Additional groups to which to add

    @author mbryzek@arsdigita.com    
    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    {invoice_html:allhtml ""}
    {invoice_pdf:allhtml ""}
    {invoice_pdf_file ""}
    {send_to_user_as ""}
    return_url
}

# --------------------------------------------------------
# Security and defaults
# --------------------------------------------------------

set user_id [auth::require_login]
im_cost_permissions $user_id $invoice_id view read write admin
if {!$write} {
    ad_return_complaint "[_ intranet-invoices.lt_Insufficient_Privileg]" "
    <li>[_ intranet-invoices.lt_You_dont_have_suffici]"
}

# Build the name of the attachment
db_1row invoice_info "
	select	c.*,
		im_category_from_id(cost_type_id) as cost_type
	from	im_costs c
	where	cost_id = :invoice_id
"


# create a reasonable name for the attachment.
# Should look like: "invoice.2006_03_0005.html"
set use_invoice_nr_type_prefix_p [im_parameter -package_id [im_package_invoices_id] "UseInvoiceNrTypePrefixP" "" 0]
set attachment_filename "$cost_type."
append attachment_filename [string range $cost_name $use_invoice_nr_type_prefix_p 99]
append attachment_filename ".$send_to_user_as"
set attachment_filename [string tolower $attachment_filename]


# --------------------------------------------------------
# Prepare to send out an email alert
# --------------------------------------------------------

set system_name [ad_system_name]
set object_name [db_string project_name ""]
set page_title "[_ intranet-invoices.Notify_user]"
set context [list $page_title]
set current_user_name [db_string cur_user "select im_name_from_user_id(:user_id) from dual"]
set current_user_email [db_string cur_user "select im_email_from_user_id(:user_id) from dual"]

# Get the SystemUrl without trailing "/"
set system_url [im_parameter -package_id [ad_acs_kernel_id] SystemURL ""]
set sysurl_len [string length $system_url]
set last_char [string range $system_url $sysurl_len-1 $sysurl_len]
if {"/" eq $last_char} {
    set system_url "[string range $system_url 0 $sysurl_len-2]"
}

db_1row invoice_info "
select	i.*,
	i.company_contact_id as invoice_accounting_contact_id,
	ci.*,
	im_category_from_id(ci.cost_type_id) as cost_type
from	im_invoices i,
	im_costs ci
where	i.invoice_id = ci.cost_id
	and i.invoice_id = :invoice_id
"

if {[im_category_is_a $cost_type_id [im_cost_type_quote]] || [im_category_is_a $cost_type_id [im_cost_type_invoice]]} {
    set company_id $customer_id
} else {
    set company_id $provider_id
}

db_1row company_info "
select	c.*,
	c.accounting_contact_id as company_accounting_contact_id
from	im_companies c
where	c.company_id = :company_id
"


# -----------------------------------------
# Logic to determine to whom to send the "accounting contact"
# to send the email.

set accounting_contact_id $invoice_accounting_contact_id

if {"" == $accounting_contact_id} {

    # Check the accounting contact of the company
    if {"" == $company_accounting_contact_id} {
	set link_to_page "<A href=/intranet/companies/view?company_id=$company_id> [_ intranet-invoices.company_name_page]</a>"
	ad_return_complaint 1 "<li>[_ intranet-invoices.lt_No_Accounting_Contact]<p>
		[_ intranet-invoices.lt_The_company_company_n]<br>
		[_ intranet-invoices.lt_Please_visit_the_link]"
	return
    }

    set accounting_contact_id $company_accounting_contact_id
}

# Get accounting contact name & email
db_1row accounting_contact_info "
select
	im_name_from_user_id(:accounting_contact_id) as accounting_contact_name,
	im_email_from_user_id(:accounting_contact_id) as accounting_contact_email
"

set select_projects ""
set select_project_sql "
	select
		p.project_nr,
		p.project_name,
		p.project_id
	from
		acs_rels r,
		im_projects p
	where
		r.object_id_one = p.project_id
		and r.object_id_two = :invoice_id
"
db_foreach select_projects $select_project_sql {
    append select_projects "- $project_nr: $project_name\n  $system_url/intranet/projects/view?project_id=$project_id\n"
}

set user_id_from_search $accounting_contact_id
set export_vars [export_vars -form {user_id_from_search invoice_id return_url}]

switch $send_to_user_as {
    "html" { 
	set attachment $invoice_html
	set attachment_mime_type "text/html" 
	append export_vars [export_vars -form {attachment_mime_type send_to_user_as attachment}]
	ad_return_template
    }
    "pdf" {
	set attachment_mime_type "application/pdf" 
	append export_vars [export_vars -form {attachment_mime_type send_to_user_as {attachment_binary_file $invoice_pdf_file}}]
	ad_return_template
    }
    default {
	ad_return_complaint 1 "Notify: Found invalid send_to_user_as variable with value='$send_to_user_as'"
    }
}
