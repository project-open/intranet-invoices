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

    @param del_action Indicates that the Del button has been pressed
    @param add_project_action Indicates that the "Add Projects" button
           has been pressed
    @author frank.bergmann@project-open.com
} {
    { invoice_id:integer 0 }
    { project_id:integer 0 }
    { del_action "" }
    { add_project_action "" }
    { object_ids:array,optional }
    { return_url "/intranet-invoices/" }
}

# ---------------------------------------------------------------
# Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id view_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------

set page_focus "im_header_form.keywords"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"

set page_title "Associate Invoice with Project"
set context_bar [ad_context_bar [list /intranet/invoices/ "Finance"] $page_title]

# ---------------------------------------------------------------
# Del-Action: Delete the selected associated objects
# ---------------------------------------------------------------

if {"" != $del_action && [info exists object_ids]} {
    foreach object_id [array names object_ids] {
	ns_log Notice "intranet-invoices/invoice-associtation-action: deleting object_id=$object_id"
	db_dml delete_association "
	DECLARE
		v_rel_id	integer;
	BEGIN
		for row in (
			select distinct r.rel_id
			from	acs_rels r
			where	r.object_id_one = :object_id
				and r.object_id_two = :invoice_id
		) loop
			acs_rel.del(row.rel_id);
		end loop;
	END;"
    }
    ad_returnredirect $return_url
    ad_abort_script
}

# ---------------------------------------------------------------
# Get everything about the invoice
# ---------------------------------------------------------------

append query "
select
	i.*,
	ci.*,
	c.*,
	o.*,
	ci.effective_date + ci.payment_days as calculated_due_date,
	pm_cat.category as invoice_payment_method,
	pm_cat.category_description as invoice_payment_method_desc,
	im_name_from_user_id(c.accounting_contact_id) as customer_contact_name,
	im_email_from_user_id(c.accounting_contact_id) as customer_contact_email,
	c.customer_name,
	cc.country_name,
	im_category_from_id(ci.cost_status_id) as cost_status,
	im_category_from_id(ci.cost_type_id) as cost_type,
	im_category_from_id(ci.template_id) as template
from
	im_invoices i,
	im_costs ci,
	im_customers c,
	im_offices o,
	country_codes cc,
	im_categories pm_cat
where
	i.invoice_id = :invoice_id
	and i.invoice_id = ci.cost_id
	and i.payment_method_id=pm_cat.category_id(+)
	and ci.customer_id=c.customer_id(+)
	and c.main_office_id=o.office_id(+)
	and o.address_country_code=cc.iso(+)
"

if { ![db_0or1row projects_info_query $query] } {
    ad_return_complaint 1 "Can't find the document\# $invoice_id"
    return
}


set project_select [im_project_select object_id $project_id "Open" "" "" ""]

db_release_unused_handles
