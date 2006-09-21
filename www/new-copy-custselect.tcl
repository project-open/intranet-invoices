# /packages/intranet-invoices/www/new-copy-custselect.tcl
#
# Copyright (C) 2003-2005 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Copy existing financial document to a new one.
    @author frank.bergmann@project-open.com
} {
    source_cost_type_id:integer
    target_cost_type_id:integer
    {customer_id:integer ""}
    {provider_id:integer ""}
    {project_id:integer ""}
    blurb
    return_url
}

# ---------------------------------------------------------------
# Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

# Make sure we can create invoices of target_cost_type_id...
set allowed_cost_type [im_cost_type_write_permissions $user_id]
if {[lsearch -exact $allowed_cost_type $target_cost_type_id] == -1} {
    ad_return_complaint "Insufficient Privileges" "
        <li>You can't create documents of type #$target_cost_type_id."
    ad_script_abort
}

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------

set page_title "[_ intranet-invoices.Select_Customer]"
set context_bar [im_context_bar [list /intranet/invoices/ "[_ intranet-invoices.Finance]"] $page_title]


# ---------------------------------------------------------------
#
# ---------------------------------------------------------------


# Check of customer and provider are already set...
#
if {"" != $customer_id} {
    set company_id $customer_id
    ad_returnredirect new-copy-invoiceselect?[export_url_vars source_cost_type_id target_cost_type_id customer_id provider_id company_id project_id blurb return_url]
    return
}

set customer_select [im_company_select company_id 0 "" "CustOrIntl"]
set provider_select [im_company_select company_id 0 "" "Provider"]


db_release_unused_handles
