# /packages/intranet-invoices/www/add-project-to-invoice.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Allows to "associate" a project with a financial document.
    This is useful when the document has been created "from scratch".

    @author frank.bergmann@project-open.com
} {
    { invoice_id:integer 0}
    { project_id:integer 0}
    { return_url "/intranet-invoices/"}
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id view_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

set page_focus "im_header_form.keywords"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"

set page_title "Associate Invoice with Project"
set context_bar [ad_context_bar [list /intranet/invoices/ "Finance"] $page_title]

# ---------------------------------------------------------------
# Get everything about the invoice
# ---------------------------------------------------------------

append query "
select
        i.*,
        c.*,
        o.*,
        i.invoice_date + i.payment_days as calculated_due_date,
        pm_cat.category as invoice_payment_method,
        pm_cat.category_description as invoice_payment_method_desc,
        im_name_from_user_id(c.accounting_contact_id) as customer_contact_name,
        im_email_from_user_id(c.accounting_contact_id) as customer_contact_email,
        c.customer_name,
        cc.country_name,
        im_category_from_id(i.invoice_status_id) as invoice_status,
        im_category_from_id(i.invoice_type_id) as invoice_type,
        im_category_from_id(i.invoice_template_id) as invoice_template
from
        im_invoices i,
        im_customers c,
        im_offices o,
        country_codes cc,
        im_categories pm_cat
where
        i.invoice_id=:invoice_id
        and i.payment_method_id=pm_cat.category_id(+)
        and i.customer_id=c.customer_id(+)
        and c.main_office_id=o.office_id(+)
        and o.address_country_code=cc.iso(+)
"

if { ![db_0or1row projects_info_query $query] } {
    ad_return_complaint 1 "Can't find the document\# $invoice_id"
    return
}


set project_select [im_project_select object_id $project_id "Open" "" "" ""]

db_release_unused_handles

