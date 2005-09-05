# /packages/intranet-invoices/www/notify.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Purpose: Confirms adding of person to group

    @param user_id_from_search user_id to add
    @param object_id group to which to add
    @param role_id role in which to add
    @param return_url Return URL
    @param also_add_to_group_id Additional groups to which to add

    @author mbryzek@arsdigita.com    
    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    return_url
}

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
# Prepare to send out an email alert
# --------------------------------------------------------

set system_name [ad_system_name]
set object_name [db_string project_name ""]
set page_title "[_ intranet-invoices.Notify_user]"
set context [list $page_title]
set current_user_name [db_string cur_user "select im_name_from_user_id(:user_id) from dual"]
set current_user_email [db_string cur_user "select im_email_from_user_id(:user_id) from dual"]

# Get the SystemUrl without trailing "/"
set system_url [ad_parameter -package_id [ad_acs_kernel_id] SystemURL ""]
set sysurl_len [string length $system_url]
set last_char [string range $system_url [expr $sysurl_len-1] $sysurl_len]
if {[string equal "/" $last_char]} {
    set system_url "[string range $system_url 0 [expr $sysurl_len-2]]"
}

db_1row invoice_info "
select 
	i.*,
	ci.*,
	im_category_from_id(ci.cost_type_id) as cost_type
from
	im_invoices i,
	im_costs ci
where
	i.invoice_id = ci.cost_id
	and i.invoice_id = :invoice_id
"


if {$cost_type_id == [im_cost_type_quote] || $cost_type_id == [im_cost_type_invoice]} {
    set company_id $customer_id
} else {
    set company_id $provider_id
}

db_1row company_info "
select
	c.*,
	im_name_from_user_id(c.accounting_contact_id) as accounting_contact_name,
	im_email_from_user_id(c.accounting_contact_id) as accounting_contact_email
from
	im_companies c
where
	c.company_id = :company_id
"

if {"" == $accounting_contact_id} {
    set link_to_page "<A href=/intranet/companies/view?company_id=$company_id> [_ intranet-invoices.company_name_page]</a>"
    ad_return_complaint 1 "<li>[_ intranet-invoices.lt_No_Accounting_Contact]<p>
	[_ intranet-invoices.lt_The_company_company_n]<br>
	[_ intranet-invoices.lt_Please_visit_the_link]"
}

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
set export_vars [export_form_vars user_id_from_search invoice_id return_url]

