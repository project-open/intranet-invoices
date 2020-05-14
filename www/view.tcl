# /packages/intranet-invoices/www/view.tcl
#
# Copyright (C) 2003 - 2013 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# Skip if this page is called as part of a Workflow panel
if {![info exists task]} {

    ad_page_contract {
	View all the info about a specific project
	
	@param render_template_id specifies whether the invoice should be
	show in GUI mode (view/edit) or formatted using some template.
	@param send_to_user_as "html" or "pdf".
	Indicates that the content of the
	invoice should be rendered using the default template
	and sent to the default contact.
	The difficulty is that it's not sufficient just to redirect
	to a mail sending page, because it is only this page that
	"knows" how to render an invoice. So in order to send the
	PDF we first need to redirect to this page, render the invoice
	and then redirect to the mail sending page.
	
	@author frank.bergmann@project-open.com
	@author klaus.hofeditz@project-open.com
    } {
	{ invoice_id:integer 0}
	{ render_template_id:integer 0 }
	{ send_to_user_as ""}
	{ pdf_p 0 }
	{ err_mess "" }
	{ return_url "" }
    }

    set show_components_p 1
    set enable_master_p 1
    set task_id 0
    set case_id 0

    # Custom redirect? Only here in "page mode"
    set redirect_package_url [parameter::get_from_package_key -package_key "intranet-invoices" -parameter "InvoicesRedirectPackageUrl" -default ""]
    if {"" != $redirect_package_url} {
	set form_vars [ns_conn form]
	if {"" == $form_vars} { set form_vars [ns_set create] }
	set var_list [ns_set array $form_vars]
	set redirect_url [export_vars -base "$redirect_package_url/view" $var_list]
	ad_returnredirect $redirect_url
    }

} else {
    
    set show_components_p 0
    set enable_master_p 0
    set task_id $task(task_id)
    set case_id $task(case_id)

    set invoice_id [db_string pid "select object_id from wf_cases where case_id = :case_id" -default ""]
    set render_template_id 0
    set send_to_user_as ""
    set pdf_p 0
    set err_mess ""
    set return_url [im_url_with_query]
}

# ---------------------------------------------------------------
# Helper Procs
# ---------------------------------------------------------------

proc encodeXmlValue {value} {
    regsub -all {&} $value {&amp;} value
    regsub -all {<} $value {&lt;} value
    regsub -all {>} $value {&gt;} value
    return $value
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# Get user parameters
set current_user_id [auth::require_login]
set user_id $current_user_id

set user_locale [lang::user::locale]
set locale $user_locale
set page_title ""

set gen_vars ""
set blurb ""
set notify_vars ""
set url ""

set current_url [im_url_with_query]

# We have to avoid that already escaped vars in the item section will be escaped again
set vars_escaped [list]

if {0 == $invoice_id} {
    ad_return_complaint 1 "<li>[lang::message::lookup $user_locale intranet-invoices.lt_You_need_to_specify_a]"
    return
}

if {"pdf" eq $send_to_user_as} { set pdf_p 1 }

if {"" == $return_url} { set return_url [im_url_with_query] }

set bgcolor(0) "class=invoiceroweven"
set bgcolor(1) "class=invoicerowodd"

set required_field "<font color=red size=+1><B>*</B></font>"
set cost_type_id [db_string cost_type_id "select cost_type_id from im_costs where cost_id = :invoice_id" -default 0]

set document_quote_p [im_category_is_a $cost_type_id [im_cost_type_quote]]
set document_invoice_p [im_category_is_a $cost_type_id [im_cost_type_invoice]]
set document_bill_p [im_category_is_a $cost_type_id [im_cost_type_bill]]
set document_po_p [im_category_is_a $cost_type_id [im_cost_type_po]]
set document_delnote_p [im_category_is_a $cost_type_id [im_cost_type_delivery_note]]

set document_customer_doc_p [im_category_is_a $cost_type_id [im_cost_type_customer_doc]]
set document_provider_doc_p [im_category_is_a $cost_type_id [im_cost_type_provider_doc]]


# ---------------------------------------------------------------
# Redirect to other page if this is not an invoice
# ---------------------------------------------------------------

# Custom redirection by cost_type
set redirect_cost_type_list [parameter::get_from_package_key -package_key "intranet-invoices" -parameter "InvoicesRedirectCostTypeUrlMap" -default {3741 "/intranet-cust-fttx/construction-estimates/view"}]
array set redirect_cost_type_hash $redirect_cost_type_list
if {[info exists redirect_cost_type_hash($cost_type_id)]} {
    set base_url $redirect_cost_type_hash($cost_type_id)
    set redirect_url [export_vars -base $base_url {invoice_id return_ur}]
    ad_returnredirect $redirect_url
}

# What to do if this is not an invoice (but another cost type...)
set invoice_p [db_string invoice_p "select count(*) from im_invoices where invoice_id = :invoice_id"]
if {!$invoice_p} {
    # This tends to happen in error situations.
    # First check if this is really a financial document suitable to be displayed by this page:
    if {$cost_type_id ni [im_cost_financial_document_type_ids]} {
	# This is a cost item different from a financial document - redirect
	ad_returnredirect [export_vars -base "/intranet-cost/costs/new" {{form_mode display} {cost_id $invoice_id}}]
    } else {
	# This seems to be an inconsistent object...
	ad_return_complaint 1 "<b>[lang::message::lookup $user_locale intranet-invoices.lt_Cant_find_the_documen]</b>:<br>
        This situation usually happens when there is inconsistent data<br>
        in the database with an im_costs entry of type 'im_invoice',<br>
        but no entry in the 'im_invoices' table."
	ad_script_abort
    }
}

# ---------------------------------------------------------------
# Set default values from parameters
# ---------------------------------------------------------------

set internal_tax_id ""

# Number formats
set cur_format [im_l10n_sql_currency_format -style separators]
set vat_format $cur_format
set tax_format $cur_format

# Rounding precision can be between 2 (USD,EUR, ...) and -5 (Old Turkish Lira, ...).
set rounding_precision 2
set rounding_factor [expr {exp(log(10) * $rounding_precision)}]
set rf $rounding_factor

# Default Currency
set default_currency [im_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set invoice_currency [db_string cur "select currency from im_costs where cost_id = :invoice_id" -default $default_currency]
set rf 100
catch {set rf [db_string rf "select rounding_factor from currency_codes where iso = :invoice_currency" -default 100]}

# Where is the template found on the disk?
set invoice_template_base_path [im_parameter -package_id [im_package_invoices_id] InvoiceTemplatePathUnix "" "/tmp/templates/"]

# Invoice Variants showing or not certain fields.
# Please see the parameters for description.
set surcharge_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceSurchargeFieldP" "" 0]
set canned_note_enabled_p [im_parameter -package_id [im_package_invoices_id] "EnabledInvoiceCannedNoteP" "" 0]
set show_qty_rate_p [im_parameter -package_id [im_package_invoices_id] "InvoiceQuantityUnitRateEnabledP" "" 0]
set show_our_project_nr [im_parameter -package_id [im_package_invoices_id] "ShowInvoiceOurProjectNr" "" 1]
set show_our_project_nr_first_column_p [im_parameter -package_id [im_package_invoices_id] "ShowInvoiceOurProjectNrFirstColumnP" "" 1]
set show_leading_invoice_item_nr [im_parameter -package_id [im_package_invoices_id] "ShowLeadingInvoiceItemNr" "" 0]
set show_outline_number [im_column_exists im_invoice_items item_outline_number]
set show_import_from_csv $show_outline_number
set show_promote_to_timesheet_invoice_p [im_parameter -package_id [im_package_invoices_id] "ShowPromoteInvoiceToTimesheetInvoiceP" "" 0]

# Should we show the customer's PO number in the document?
# This makes only sense in "customer documents", i.e. quotes, invoices and delivery notes
set show_company_project_nr [im_parameter -package_id [im_package_invoices_id] "ShowInvoiceCustomerProjectNr" "" 1]
if {!$document_customer_doc_p} {
    set show_company_project_nr 0
    set invoice_or_quote_p 0
} else {
    set invoice_or_quote_p 1
}


# Show or not "our" and the "company" project nrs.
set company_project_nr_exists [im_column_exists im_projects company_project_nr]
set show_company_project_nr [expr {$show_company_project_nr && $company_project_nr_exists}]


# Which report to show for timesheet invoices as the detailed list of hours
set timesheet_report_url [im_parameter -package_id [im_package_invoices_id] "TimesheetInvoiceReport" "" "/intranet-reporting/timesheet-invoice-hours.tcl"]

# Check if ooffice is installed
set status [util_memoize [list catch {set ooversion [im_exec ooffice --version]}] 3600]
if {$status} { set pdf_enabled_p 0 } else { set pdf_enabled_p 1 }

# Show CC ?
set show_cost_center_p [im_parameter -package_id [im_package_invoices_id] "ShowCostCenterP" "" 0]
set cost_center_installed_p [apm_package_installed_p "intranet-cost-center"]

# Is there already a workflow controlling the lifecycle of the invoice?
set wf_case_p [db_string wf_case "select count(*) from wf_cases where object_id = :invoice_id"]
set wf_transition_key [db_string wf_transition "select transition_key from wf_tasks where task_id = :task_id" -default ""]
if {"modify" eq $wf_transition_key} { set wf_case_p 0 }
if {[im_user_is_admin_p $user_id]} { set wf_case_p 0 }



# ---------------------------------------------------------------
# Audit
# ---------------------------------------------------------------

# Check if the invoices was changed outside of ]po[...
# Normally, the current values of the invoice should match
# exactly the last registered audit version...
if {[catch {
    im_audit -object_type "im_invoice" -object_id $invoice_id -action before_update
} err_msg]} {
    ns_log Error "intranet-invoice/view: im_audit: Error action: 'before update' for invoice_id: $invoice_id"
}

# ---------------------------------------------------------------
# Determine if it's an Invoice or a Bill
# ---------------------------------------------------------------

# Vars for ADP (can't use the commands in ADP)
set quote_cost_type_id [im_cost_type_quote]
set delnote_cost_type_id [im_cost_type_delivery_note]
set po_cost_type_id [im_cost_type_po]
set invoice_cost_type_id [im_cost_type_invoice]
set bill_cost_type_id [im_cost_type_bill]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $document_invoice_p || $document_bill_p]

# CostType for "Generate Invoice from Quote" or "Generate Bill from PO"
set target_cost_type_id ""
set generation_blurb ""
if {$document_quote_p} {
    set target_cost_type_id [im_cost_type_invoice]
    set generation_blurb "[lang::message::lookup $user_locale intranet-invoices.lt_Generate_Invoice_from]"
}
if {$document_po_p} {
    set target_cost_type_id [im_cost_type_bill]
    set generation_blurb "[lang::message::lookup $user_locale intranet-invoices.lt_Generate_Provider_Bil]"
}

if {$invoice_or_quote_p} {
    # A Customer document
    set customer_or_provider_join "and ci.customer_id = c.company_id"
    set provider_company "Customer"
} else {
    # A provider document
    set customer_or_provider_join "and ci.provider_id = c.company_id"
    set provider_company "Provider"
}

if {!$invoice_or_quote_p} { set company_project_nr_exists 0}


# Check if this is a timesheet invoice and enable the timesheet report link.
# This links allows the user to extract a detailed list of included hours.
set cost_object_type [db_string cost_object_type "select object_type from acs_objects where object_id = :invoice_id" -default ""]
set timesheet_report_enabled_p 0
if {"im_timesheet_invoice" == $cost_object_type} {
    if {$document_invoice_p} {
	set timesheet_report_enabled_p 1
    }

    # Don't show the link to make this invoice a timesheet invoice
    # if it's already a timesheet invoice.
    set show_promote_to_timesheet_invoice_p 0
}


# ---------------------------------------------------------------
# Find out if the invoice is associated with a _single_ project
# or with more then one project. Only in the case of exactly one
# project we can access the "customer_project_nr" for the invoice.
# ---------------------------------------------------------------

set related_projects_sql "
        select distinct
	   	r.object_id_one as project_id,
		p.project_name,
		p.project_nr,
		p.parent_id,
		p.description,
		trim(both p.company_project_nr) as customer_project_nr,
		main_p.project_id as main_project_id,
		main_p.project_nr as main_project_nr,
		main_p.project_name as main_project_name
	from
	        acs_rels r,
		im_projects p,
		im_projects main_p
	where
		r.object_id_one = p.project_id and
	        r.object_id_two = :invoice_id and
		tree_root_key(p.tree_sortkey) = main_p.tree_sortkey
"

set related_projects {}
set related_main_projects {}
set related_project_nrs {}
set related_project_names {}
set related_project_descriptions ""
set related_customer_project_nrs {}

set num_related_projects 0
db_foreach related_projects $related_projects_sql {
    lappend related_projects $project_id
    lappend related_main_projects $main_project_id
    if {"" != $project_nr} {
	lappend related_project_nrs $project_nr
    }
    if {"" != $project_name} {
	lappend related_project_names $project_name
    }

    if {"" != $description && 0 == $num_related_projects} {
        append related_project_descriptions $description
    } else {
	append related_project_descriptions ", $description"
    }

    set main_project_nr [string trim $main_project_nr]
    set main_project_name [string trim $main_project_name]
    set related_main_projects_hash($main_project_id) $main_project_id
    set related_main_project_nrs_hash($main_project_nr) $main_project_nr
    set related_main_project_names_hash($main_project_name) $main_project_name

    # Check of the "customer project nr" of the superproject, as the PMs
    # are probably too lazy to maintain it in the subprojects...
    set cnt 0
    while {"" eq $customer_project_nr && "" ne $parent_id && $cnt < 10} {
	set customer_project_nr [db_string custpn "select company_project_nr from im_projects where project_id = :parent_id" -default ""]
	set parent_id [db_string parentid "select parent_id from im_projects where project_id = :parent_id" -default ""]
	incr cnt
    }
    if {"" != $customer_project_nr} {
	lappend related_customer_project_nrs $customer_project_nr
    }
    incr num_related_projects
}

set rel_project_id 0
if {1 == [llength $related_projects]} {
    set rel_project_id [lindex $related_projects 0]
    set related_project_names [lindex $related_project_names 0]
}

set related_main_projects [lsort [array names related_main_projects_hash]]
set related_main_project_nrs [lsort [array names related_main_project_nrs_hash]]
set related_main_project_names [lsort [array names related_main_project_names_hash]]
if {1 == [llength $related_main_projects]} {
    set related_main_project_nrs [lindex $related_main_project_nrs 0]
    set related_main_project_names [lindex $related_main_project_names 0]
}








# ---------------------------------------------------------------
# Find out if there is a Customer Purchase Order in one of the related projects.
# ---------------------------------------------------------------

if {[llength $related_main_projects] == 0} { lappend related_main_projects 0 }
set customer_pos_sql "
        select distinct
		c.cost_id,
		c.cost_nr
	from	im_projects main_p,
		im_projects p,
		im_costs c
	where	main_p.project_id in ([join $related_main_projects ","]) and
		p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
		c.project_id = p.project_id and
		c.cost_type_id in (select * from im_sub_categories([im_cost_type_customer_po]))
	order by c.cost_id
"

set customer_pos {}
set customer_po_nrs {}
set num_customer_pos 0
db_foreach customer_pos $customer_pos_sql {
    lappend customer_pos $cost_id
    lappend customer_po_nrs $cost_nr
    incr num_customer_pos
}

set customer_po [lindex $customer_pos 0]
set customer_po_nr [lindex $customer_po_nrs 0]

# ad_return_complaint 1 "[im_ad_hoc_query -format html $customer_pos_sql]<br><pre>customer_pos=$customer_pos\n$customer_po_nrs=$customer_po_nrs</pre>"


# ---------------------------------------------------------------
# Get everything about the "internal" company
# ---------------------------------------------------------------

set internal_company_id [im_company_internal]
db_1row internal_company_info "
	select
		c.company_name as internal_name,
		c.company_path as internal_path,
		c.vat_number as internal_vat_number,
		c.site_concept as internal_web_site,
		im_name_from_user_id(c.manager_id) as internal_manager_name,
		im_email_from_user_id(c.manager_id) as internal_manager_email,
		c.primary_contact_id as internal_primary_contact_id,
		im_name_from_user_id(c.primary_contact_id) as internal_primary_contact_name,
		im_email_from_user_id(c.primary_contact_id) as internal_primary_contact_email,
		c.accounting_contact_id as internal_accounting_contact_id,
		im_name_from_user_id(c.accounting_contact_id) as internal_accounting_contact_name,
		im_email_from_user_id(c.accounting_contact_id) as internal_accounting_contact_email,
		o.office_name as internal_office_name,
		o.fax as internal_fax,
		o.phone as internal_phone,
		o.address_line1 as internal_address_line1,
		o.address_line2 as internal_address_line2,
		o.address_city as internal_city,
		o.address_state as internal_state,
		o.address_postal_code as internal_postal_code,
		o.address_country_code as internal_country_code,
		cou.country_name as internal_country_name,
		paymeth.category_description as internal_payment_method_desc
	from
		im_companies c
		LEFT OUTER JOIN im_offices o ON (c.main_office_id = o.office_id)
		LEFT OUTER JOIN country_codes cou ON (o.address_country_code = iso)
		LEFT OUTER JOIN im_categories paymeth ON (c.default_payment_method_id = paymeth.category_id)
	where
		c.company_id = :internal_company_id
"


# ---------------------------------------------------------------
# Get everything about the invoice
# ---------------------------------------------------------------

set query "
	select
		c.*,
		i.*,
		now()::date as todays_date,
		ci.effective_date::date + ci.payment_days AS due_date,
		ci.effective_date AS invoice_date,
		ci.cost_status_id AS invoice_status_id,
		ci.cost_type_id AS invoice_type_id,
		ci.template_id AS invoice_template_id,
		ci.*,
		ci.note as cost_note,
		ci.project_id as cost_project_id,
		to_date(to_char(ci.effective_date, 'YYYY-MM-DD'), 'YYYY-MM-DD') + ci.payment_days as calculated_due_date,
		im_cost_center_name_from_id(ci.cost_center_id) as cost_center_name,
		im_category_from_id(ci.cost_status_id) as cost_status,
		im_category_from_id(ci.cost_type_id) as cost_type,
		im_category_from_id(ci.template_id) as invoice_template,
		(select object_type from acs_objects o where o.object_id = i.invoice_id) as object_type
	from
		im_invoices i,
		im_costs ci,
	        im_companies c
	where
		i.invoice_id=:invoice_id
		and ci.cost_id = i.invoice_id
		$customer_or_provider_join
"
if {![db_0or1row invoice_info_query $query]} {
    # We couldn't get the base information for this invoice.
    # fraber 151210: This happened today with an invoice with
    # a deleted customer company. No idea how that could happen...
    ad_return_complaint 1 [lang::message::lookup $user_locale intranet-invoices.Unable_to_get_invoice_info_inconsistent_data "We are unable to get the invoice information for this object. This should never happen. In the past this happened once, after deleting the customer company of an invoice."]
    ad_script_abort
}



# ---------------------------------------------------------------
# Determine the locale
# ---------------------------------------------------------------

# Check for invoice_template using the convention "invoice.en_US.adp"
set invoice_template_type ""
if {[regexp {(.*)\.([_a-zA-Z]*)\.([a-zA-Z][a-zA-Z][a-zA-Z])} $invoice_template match body loc invoice_template_type]} {
    set locale $loc
}
set invoice_template_type [string tolower $invoice_template_type]

set two_letter_locales [db_list two_letter_locales "select substring(locale for 2) from ad_locales where enabled_p = 't'"]
if {$locale in $two_letter_locales || $locale in [lang::system::get_locales]} {
    # Locale is part of the system locales - OK
} else {
    # invalid locale - revert to the user's locale
    set locale $user_locale
}

if {"adp" eq $invoice_template_type} {
    # We don't support the conversion of ADP templates to PDF anymore.
    # Instead, please use .odt templates
    # So this line disables the link in the GUI to download as PDF
    set pdf_enabled_p 0
}


set render_template [im_category_from_id -translate_p 0 $render_template_id]
set render_template_type ""
if {[regexp {(.*)\.([_a-zA-Z]*)\.([a-zA-Z][a-zA-Z][a-zA-Z])} $render_template match body loc render_template_type]} {
    # nothing...
}
set render_template_type [string tolower $render_template_type]


# ---------------------------------------------------------------
# Get information about start- and end time of invoicing period
# ---------------------------------------------------------------

set invoice_period_start ""
set invoice_period_end ""
set invoice_period_start_pretty ""
set invoice_period_end_pretty ""
set timesheet_invoice_p 0

if {"im_timesheet_invoice" eq $object_type} {
    set query "
	select	ti.*,
		1 as timesheet_invoice_p
	from	im_timesheet_invoices ti
	where 	ti.invoice_id = :invoice_id
    "
    if {[catch {db_1row timesheet_invoice_info_query $query } err_msg]} {
        ad_return_complaint 1 "<pre>$err_msg</pre>"
    }
}


# ---------------------------------------------------------------
# Get everything about our "internal" Office -
# identified as the "main_office_id" of the Internal company.
# ---------------------------------------------------------------

# ToDo: Isn't this included in the Internal company query above?

set cost_type_mapped [string map {" " "_"} $cost_type]
set cost_type_l10n [lang::message::lookup $locale intranet-invoices.$cost_type_mapped $cost_type]

# Fallback for empty office_id: Main Office
if {"" == $invoice_office_id} {
    set invoice_office_id $main_office_id
}

db_1row office_info_query "
	select *
	from im_offices
	where office_id = :invoice_office_id
"


# ---------------------------------------------------------------
# Get everything about the contact person.
# ---------------------------------------------------------------

# Use the "company_contact_id" of the invoices as the main contact.
# Fallback to the accounting_contact_id and primary_contact_id
# if not present.

if {![info exists company_contact_id]} { set company_contact_id ""}

if {"" == $company_contact_id} {
    set company_contact_id $accounting_contact_id
}
if {"" == $company_contact_id} {
    set company_contact_id $primary_contact_id
}
set org_company_contact_id $company_contact_id

set company_contact_name ""
set company_contact_email ""
set company_contact_first_names ""
set company_contact_last_name ""

db_0or1row accounting_contact_info "
	select
		im_name_from_user_id(person_id) as company_contact_name,
		im_email_from_user_id(person_id) as company_contact_email,
		first_names as company_contact_first_names,
		last_name as company_contact_last_name
	from	persons
	where	person_id = :company_contact_id
"

# Set these fields if contacts is not installed:
if {![info exists salutation]} { set salutation "" }
if {![info exists user_position]} { set user_position "" }

# Get contact person's contact information
set contact_person_work_phone ""
set contact_person_work_fax ""
set contact_person_email ""
db_0or1row contact_info "
	select
		work_phone as contact_person_work_phone,
		fax as contact_person_work_fax,
		im_email_from_user_id(user_id) as contact_person_email
	from
		users_contact
	where
		user_id = :company_contact_id
"

# Set the email and name of the current user as internal contact
db_1row accounting_contact_info "
    select
	im_name_from_user_id(:user_id) as internal_contact_name,
	im_email_from_user_id(:user_id) as internal_contact_email,
	uc.work_phone as internal_contact_work_phone,
	uc.home_phone as internal_contact_home_phone,
	uc.cell_phone as internal_contact_cell_phone,
	uc.fax as internal_contact_fax,
	uc.wa_line1 as internal_contact_wa_line1,
	uc.wa_line2 as internal_contact_wa_line2,
	uc.wa_city as internal_contact_wa_city,
	uc.wa_state as internal_contact_wa_state,
	uc.wa_postal_code as internal_contact_wa_postal_code,
	uc.wa_country_code as internal_contact_wa_country_code
    from
	users u
	LEFT OUTER JOIN users_contact uc ON (u.user_id = uc.user_id)
    where
	u.user_id = :user_id
"

# ---------------------------------------------------------------
# OOoo ODT Function
# Split the template into the outer template and the one for
# formatting the invoice lines.
# ---------------------------------------------------------------

if {"odt" == $render_template_type} {

    # Special ODT functionality: We need to parse the ODT template
    # in order to extract the table row that needs to be formatted
    # by the loop below.

    # ------------------------------------------------
    # Create a temporary directory for our contents
    set odt_tmp_path [ad_tmpnam]
    ns_log Notice "intranet-invoice/view: odt_tmp_path=$odt_tmp_path"
    ns_mkdir $odt_tmp_path

    # The document
    set odt_zip "${odt_tmp_path}.odt"
    set odt_content "${odt_tmp_path}/content.xml"
    set odt_styles "${odt_tmp_path}/styles.xml"

    # ------------------------------------------------
    # Create a copy of the ODT

    # Determine the location of the template
    set invoice_template_path "$invoice_template_base_path/$invoice_template"
    ns_log Notice "intranet-invoice/view: invoice_template_path='$invoice_template_path'"

    # Create a copy of the template into the temporary dir
    ns_cp $invoice_template_path $odt_zip

    # Unzip the odt into the temorary directory
    im_exec unzip -d $odt_tmp_path $odt_zip

    # ------------------------------------------------
    # Read the content.xml file
    set file [open $odt_content]
    fconfigure $file -encoding "utf-8"
    set odt_template_content [read $file]
    close $file

    # ------------------------------------------------
    # Search the <row> ...<cell>..</cell>.. </row> line
    # representing the part of the template that needs to
    # be repeated for every template.

    # Get the list of all "tables" in the document
    set odt_doc [dom parse $odt_template_content]
    set root [$odt_doc documentElement]
    set odt_table_nodes [$root selectNodes "//table:table"]

    # Search for the table that contains "@item_name_pretty"
    set odt_template_table_node ""
    foreach table_node $odt_table_nodes {
	set table_as_list [$table_node asList]
	if {[regexp {item_units_pretty} $table_as_list match]} { set odt_template_table_node $table_node }
    }

    # Deal with the the situation that we didn't find the line
    if {"" == $odt_template_table_node} {
	ad_return_complaint 1 "
		<b>Didn't find table including '@item_units_pretty'</b>:<br>
		We have found a valid OOoo template at '$invoice_template_path'.
		However, this template does not include a table with the value
		above.
	"
	ad_script_abort
    }

    # Search for the 2nd table:table-row tag
    set odt_table_rows_nodes [$odt_template_table_node selectNodes "//table:table-row"]
    set odt_template_row_node ""
    set odt_template_row_count 0
    foreach row_node $odt_table_rows_nodes {
	set row_as_list [$row_node asList]
	if {[regexp {item_units_pretty} $row_as_list match]} { set odt_template_row_node $row_node }
	incr odt_template_row_count
    }

    if {"" == $odt_template_row_node} {
	ad_return_complaint 1 "
		<b>Didn't find row including '@item_units_pretty'</b>:<br>
		We have found a valid OOoo template at '$invoice_template_path'.
		However, this template does not include a row with the value
		above.
	"
	ad_script_abort
    }

    # Convert the tDom tree into XML for rendering
    set odt_row_template_xml [$odt_template_row_node asXML]
}

# ---------------------------------------------------------------
# Format Invoice date information according to locale
# ---------------------------------------------------------------

set invoice_date_pretty [lc_time_fmt $invoice_date "%x" $locale]
set calculated_due_date_pretty [lc_time_fmt $calculated_due_date "%x" $locale]
set todays_date_pretty [lc_time_fmt $todays_date "%x" $locale]

set invoice_period_start_pretty [lc_time_fmt $invoice_period_start "%x" $locale]
set invoice_period_end_pretty [lc_time_fmt $invoice_period_end "%x" $locale]


# ---------------------------------------------------------------
# Get more about the invoice's project
# ---------------------------------------------------------------

# We give priority to the project specified in the cost item,
# instead of associated projects.
if {"" != $cost_project_id && 0 != $cost_project_id} {
    set rel_project_id $cost_project_id
}

set project_short_name_default [db_string short_name_default "select project_nr from im_projects where project_id=:rel_project_id" -default ""]
set customer_project_nr_default ""

if {$company_project_nr_exists && $rel_project_id} {

    db_0or1row project_info_query "
    	select
    		p.company_project_nr as customer_project_nr_default
    	from
    		im_projects p
    	where
    		p.project_id = :rel_project_id
    "
}

# ---------------------------------------------------------------
# Check permissions
# ---------------------------------------------------------------

im_cost_permissions $user_id $invoice_id view read write admin
if {!$read} {
    ad_return_complaint "[lang::message::lookup $user_locale intranet-invoices.lt_Insufficient_Privileg]" "
    <li>[lang::message::lookup $user_locale intranet-invoices.lt_You_have_insufficient_1]<BR>
    [lang::message::lookup $user_locale intranet-invoices.lt_Please_contact_your_s]"
    ad_script_abort
}
if {$wf_case_p} { 
    set write 0
    set admin 0
}

# user_admin_p is used by the "Object Member Portlet" to determine
# if the current_user can add new members to the object etc
set user_admin_p $write


# ---------------------------------------------------------------
# Page Title and Context Bar
# ---------------------------------------------------------------

set page_title [lang::message::lookup $user_locale intranet-invoices.One_cost_type]
set context_bar [im_context_bar [list /intranet-invoices/ "[lang::message::lookup $user_locale intranet-invoices.Finance]"] $page_title]


# ---------------------------------------------------------------
#
# ---------------------------------------------------------------

set comp_id $company_id
set query "
select
        pm_cat.category as invoice_payment_method,
	pm_cat.category_description as invoice_payment_method_desc
from
        im_categories pm_cat
where
        pm_cat.category_id = :payment_method_id
"
if {![db_0or1row category_info_query $query]} {
    set invoice_payment_method ""
    set invoice_payment_method_desc ""
}

set invoice_payment_method_l10n $invoice_payment_method
set invoice_payment_method_key [lang::util::suggest_key $invoice_payment_method]
if {"" ne $invoice_payment_method_key} {
    set invoice_payment_method_l10n [lang::message::lookup $locale intranet-core.$invoice_payment_method_key $invoice_payment_method]
}


set internal_country_name_l10n [lang::message::lookup $locale intranet-core.$internal_country_name $internal_country_name]


# ---------------------------------------------------------------
# Determine the country name and localize
# ---------------------------------------------------------------

set country_name ""
if {"" != $address_country_code} {
    set query "
	select	cc.country_name
	from	country_codes cc
	where	cc.iso = :address_country_code"
    if {![db_0or1row country_info_query $query]} {
	    set country_name $address_country_code
    }
    set country_name [lang::message::lookup $locale intranet-core.$country_name $country_name]
}

# ---------------------------------------------------------------
# Update the amount paid for this cost_item
# ---------------------------------------------------------------

# This is redundant now - The same calculation is done
# when adding/removing costs. However, there may be cases
# with manually added costs. ToDo: Not very, very clean
# solution.
im_cost_update_payments $invoice_id


# ---------------------------------------------------------------
# Payments list
# ---------------------------------------------------------------

set payment_list_html ""
if {[im_table_exists im_payments]} {

    set cost_id $invoice_id
    set payment_list_html "
	<form action=payment-action method=post>
	[export_vars -form {cost_id return_url}]
	<table border=0 cellPadding=1 cellspacing=1>
        <tr>
          <td align=middle class=rowtitle colspan=3>
	    [lang::message::lookup $user_locale intranet-invoices.Related_Payments]
	  </td>
        </tr>"

    set payment_list_sql "
select
	p.*,
        to_char(p.received_date,'YYYY-MM-DD') as received_date_pretty,
	im_category_from_id(p.payment_type_id) as payment_type
from
	im_payments p
where
	p.cost_id = :invoice_id
"

    set payment_ctr 0
    db_foreach payment_list $payment_list_sql {
	append payment_list_html "
        <tr $bgcolor([expr {$payment_ctr % 2}])>
          <td>
	    <A href=/intranet-payments/view?payment_id=$payment_id>
	      $received_date_pretty
 	    </A>
	  </td>
          <td>
	      $amount $currency
          </td>\n"
	if {$write} {
	    append payment_list_html "
            <td>
	      <input type=checkbox name=payment_id value=$payment_id>
            </td>\n"
	}
	append payment_list_html "
        </tr>\n"
	incr payment_ctr
    }

    if {!$payment_ctr} {
	append payment_list_html "<tr class=roweven><td colspan=2 align=center><i>[lang::message::lookup $user_locale intranet-invoices.No_payments_found]</i></td></tr>\n"
    }


    if {$write} {
	append payment_list_html "
        <tr $bgcolor([expr {$payment_ctr % 2}])>
          <td align=right colspan=3>
	    <input type=submit name=add value=\"[lang::message::lookup $user_locale intranet-invoices.Add_a_Payment]\">
	    <input type=submit name=del value=\"[lang::message::lookup $user_locale intranet-invoices.Del]\">
          </td>
        </tr>\n"
    }
    append payment_list_html "
	</table>
        </form>\n"
}

# ---------------------------------------------------------------
# 3. Select and format Invoice Items
# ---------------------------------------------------------------

set decoration_item_nr [im_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleItemNr" "" "align=center"]
set decoration_description [im_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleDescription" "" "align=left"]
set decoration_quantity [im_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleQuantity" "" "align=right"]
set decoration_unit [im_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleUnit" "" "align=left"]
set decoration_rate [im_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleRate" "" "align=right"]
set decoration_po_number [im_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitlePoNumber" "" "align=center"]
set decoration_our_ref [im_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleOurRef" "" "align=center"]
set decoration_amount [im_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleAmount" "" "align=right"]


# start formatting the list of sums with the header...
set invoice_item_html "<tr align=center>\n"

if {$show_leading_invoice_item_nr} { append invoice_item_html "<td class=rowtitle $decoration_item_nr>[lang::message::lookup $locale intranet-invoices.Line_no "#"]</td>" }
if {$show_outline_number} { append invoice_item_html "<td class=rowtitle $decoration_item_nr>[lang::message::lookup $locale intranet-invoices.Outline "Outline"]</td>" }

append invoice_item_html "<td class=rowtitle $decoration_description>[lang::message::lookup $locale intranet-invoices.Description]&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>"

if {$show_qty_rate_p} {
    append invoice_item_html "
          <td class=rowtitle $decoration_quantity>[lang::message::lookup $locale intranet-invoices.Qty]</td>
          <td class=rowtitle $decoration_unit>[lang::message::lookup $locale intranet-invoices.Unit]</td>
          <td class=rowtitle $decoration_rate>[lang::message::lookup $locale intranet-invoices.Rate]</td>
    "
}

if {$show_company_project_nr} {
    # Only if intranet-translation has added the field and param is set
    append invoice_item_html "
          <td class=rowtitle $decoration_po_number>[lang::message::lookup $locale intranet-invoices.Yr_Job__PO_No]</td>\n"
}

if {$show_our_project_nr} {
    # Only if intranet-translation has added the field and param is set
    append invoice_item_html "
          <td class=rowtitle $decoration_our_ref>[lang::message::lookup $locale intranet-invoices.Our_Ref]</td>
    "
}

append invoice_item_html "
          <td class=rowtitle $decoration_amount>[lang::message::lookup $locale intranet-invoices.Amount]</td>
        </tr>
"

set ctr 1
set colspan [expr 2 + 3*$show_qty_rate_p + 1*$show_company_project_nr + $show_our_project_nr + $show_leading_invoice_item_nr + $show_outline_number]
set oo_table_xml ""
db_foreach invoice_items {} {
    # $company_project_nr is normally related to each invoice item,
    # because invoice items can be created based on different projects.
    # However, frequently we only have one project per invoice, so that
    # we can use this project's company_project_nr as a default
    if {$company_project_nr_exists && "" == $company_project_nr} {
	set company_project_nr $customer_project_nr_default
    }
    if {"" == $project_short_name} {
	set project_short_name $project_short_name_default
    }

    set amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $amount+0] $rounding_precision] "" $locale]
    set item_units_pretty [lc_numeric [expr $item_units+0] "" $locale]
    set price_per_unit_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $price_per_unit+0] $rounding_precision] "" $locale]

    append invoice_item_html "<tr $bgcolor([expr {$ctr % 2}])>"
    if {$show_leading_invoice_item_nr} { append invoice_item_html "<td $bgcolor([expr {$ctr % 2}]) align=right>$item_sort_order</td>\n" }
    if {$show_outline_number} { append invoice_item_html "<td $bgcolor([expr {$ctr % 2}]) align=left>$item_outline_number</td>\n" }
    append invoice_item_html "<td $bgcolor([expr {$ctr % 2}])>[string range $item_name 0 100]</td>"
    if {$show_qty_rate_p} {
	set uom_l10n [lang::message::lookup $locale intranet-core.$item_uom $item_uom]
	if {"" eq $item_uom} { set uom_l10n "" }
	append invoice_item_html "
	          <td $bgcolor([expr {$ctr % 2}]) align=right>$item_units_pretty</td>
	          <td $bgcolor([expr {$ctr % 2}]) align=left>$uom_l10n</td>
	          <td $bgcolor([expr {$ctr % 2}]) align=right>$price_per_unit_pretty&nbsp;$currency</td>
	        "
    }

    if {$show_company_project_nr} {
	# Only if intranet-translation has added the field
	append invoice_item_html "
	          <td $bgcolor([expr {$ctr % 2}]) align=left>$company_project_nr</td>\n"
    }

    if {$show_our_project_nr} {
	append invoice_item_html "
	          <td $bgcolor([expr {$ctr % 2}]) align=left>$project_short_name</td>\n"
    }

    append invoice_item_html "
	          <td $bgcolor([expr {$ctr % 2}]) align=right>$amount_pretty&nbsp;$currency</td>
		</tr>"

    # Insert a new XML table row into OpenOffice document
    if {"odt" == $render_template_type} {
	ns_log Notice "intranet-invoice/view: Now escaping vars for rows newly added. Row# $ctr"
	set lines [split $odt_row_template_xml \n]
	foreach line $lines {
	    set var_to_be_escaped ""
	    regexp -nocase {@(.*?)@} $line var_to_be_escaped
	    regsub -all "@" $var_to_be_escaped "" var_to_be_escaped
	    regsub -all ";noquote" $var_to_be_escaped "" var_to_be_escaped

	    # lappend vars_escaped $var_to_be_escaped
	    if {"" != $var_to_be_escaped} {
		set value [eval "set value \"$$var_to_be_escaped\""]

		# KH: 160701 - Seems not be required anymore - tested with LibreOffice 5.0.2.2
		# set value [string map {\[ "\\[" \] "\\]"} $value]

		ns_log Notice "intranet-invoice/view: Escape vars for rows added - Value: $value"
		set cmd "set $var_to_be_escaped {[encodeXmlValue $value]}"
		ns_log Notice "intranet-invoice/view: Escape vars for rows added - cmd: $cmd"
		eval $cmd
	    }
	}

	set item_uom [lang::message::lookup $locale intranet-core.$item_uom $item_uom]
	# Replace placeholders in the OpenOffice template row with values
	eval [template::adp_compile -string $odt_row_template_xml]
	set odt_row_xml $__adp_output

	# Add a valid xmlns XML NameSpace declaration, otherwise the new version of tDom produces an errors
	set odt_row_xml "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<office:document-content xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" xmlns:style=\"urn:oasis:names:tc:opendocument:xmlns:style:1.0\" xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\" xmlns:table=\"urn:oasis:names:tc:opendocument:xmlns:table:1.0\" xmlns:draw=\"urn:oasis:names:tc:opendocument:xmlns:drawing:1.0\" xmlns:fo=\"urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:meta=\"urn:oasis:names:tc:opendocument:xmlns:meta:1.0\" xmlns:number=\"urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0\" xmlns:svg=\"urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0\" xmlns:chart=\"urn:oasis:names:tc:opendocument:xmlns:chart:1.0\" xmlns:dr3d=\"urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0\" xmlns:math=\"http://www.w3.org/1998/Math/MathML\" xmlns:form=\"urn:oasis:names:tc:opendocument:xmlns:form:1.0\" xmlns:script=\"urn:oasis:names:tc:opendocument:xmlns:script:1.0\" xmlns:ooo=\"http://openoffice.org/2004/office\" xmlns:ooow=\"http://openoffice.org/2004/writer\" xmlns:oooc=\"http://openoffice.org/2004/calc\" xmlns:dom=\"http://www.w3.org/2001/xml-events\" xmlns:xforms=\"http://www.w3.org/2002/xforms\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:rpt=\"http://openoffice.org/2005/report\" xmlns:of=\"urn:oasis:names:tc:opendocument:xmlns:of:1.2\" xmlns:xhtml=\"http://www.w3.org/1999/xhtml\" xmlns:grddl=\"http://www.w3.org/2003/g/data-view#\" xmlns:officeooo=\"http://openoffice.org/2009/office\" xmlns:tableooo=\"http://openoffice.org/2009/table\" xmlns:drawooo=\"http://openoffice.org/2010/draw\" xmlns:calcext=\"urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0\" xmlns:loext=\"urn:org:documentfoundation:names:experimental:office:xmlns:loext:1.0\" xmlns:field=\"urn:openoffice:names:experimental:ooo-ms-interop:xmlns:field:1.0\" xmlns:formx=\"urn:openoffice:names:experimental:ooxml-odf-interop:xmlns:form:1.0\" xmlns:css3t=\"http://www.w3.org/TR/css3-text/\" office:version=\"1.2\">
$odt_row_xml
</office:document-content>
"

	# Parse the new row and insert into OOoo document
	set row_doc [dom parse $odt_row_xml]
	ns_log Notice "intranet-invoice/view: doc_row parsed: [$row_doc asXML]"

	set row_doc_root [$row_doc documentElement]

	set row_table_nodes [$row_doc_root selectNodes "//table:table-row"]
	set row_table_node ""
	foreach table_node $row_table_nodes { set row_table_node $table_node }

	ns_log Notice "intranet-invoice/view: row_table_node: [$row_table_node asXML]"
	$odt_template_table_node insertBefore $row_table_node $odt_template_row_node

    }

    incr ctr
}

# ---------------------------------------------------------------
# Add subtotal + VAT + TAX = Grand Total
# ---------------------------------------------------------------


# Set these values to 0 in order to allow to calculate the
# formatted grand total
if {"" == $vat} { set vat 0}
if {"" == $tax} { set tax 0}

# Calculate grand total based on the same inner SQL
db_1row calc_grand_total ""

set subtotal_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $subtotal+0] $rounding_precision] "" $locale]
set vat_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $vat_amount+0] $rounding_precision] "" $locale]
set tax_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $tax_amount+0] $rounding_precision] "" $locale]

set vat_perc_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $vat+0] $rounding_precision] "" $locale]
set tax_perc_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $tax+0] $rounding_precision] "" $locale]
set grand_total_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $grand_total+0] $rounding_precision] "" $locale]
set total_due_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $total_due+0] $rounding_precision] "" $locale]

set discount_perc_pretty $discount_perc
set surcharge_perc_pretty $surcharge_perc

set discount_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $discount_amount+0] $rounding_precision] "" $locale]
set surcharge_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $surcharge_amount+0] $rounding_precision] "" $locale]

set colspan_sub [expr {$colspan - 1}]

# Add a subtotal
set subtotal_item_html "
        <tr>
          <td class=roweven colspan=$colspan_sub align=right><B>[lang::message::lookup $locale intranet-invoices.Subtotal]</B></td>
          <td class=roweven align=right><B><nobr>$subtotal_pretty $currency</nobr></B></td>
        </tr>
"


if {"" != $vat && 0 != $vat} {

    set vat_type_l10n ""
    if {"" ne $vat_type_id} { set vat_type_l10n " ([im_category_from_id $vat_type_id])" }

    append subtotal_item_html "
        <tr>
          <td class=roweven colspan=$colspan_sub align=right>[lang::message::lookup $locale intranet-invoices.VAT]$vat_type_l10n: $vat_perc_pretty %&nbsp;</td>
          <td class=roweven align=right>$vat_amount_pretty $currency</td>
        </tr>
    "
} else {
    append subtotal_item_html "
        <tr>
          <td class=roweven colspan=$colspan_sub align=right>[lang::message::lookup $locale intranet-invoices.VAT]: 0 %&nbsp;</td>
          <td class=roweven align=right>0 $currency</td>
        </tr>
    "
}

if {"" != $tax && 0 != $tax} {
    append subtotal_item_html "
        <tr>
          <td class=roweven colspan=$colspan_sub align=right>[lang::message::lookup $locale intranet-invoices.TAX]: $tax_perc_pretty  %&nbsp;</td>
          <td class=roweven align=right>$tax_amount_pretty $currency</td>
        </tr>
    "
}

append subtotal_item_html "
        <tr>
          <td class=roweven colspan=$colspan_sub align=right><b>[lang::message::lookup $locale intranet-invoices.Total_Due]</b></td>
          <td class=roweven align=right><b><nobr>$total_due_pretty $currency</nobr></b></td>
        </tr>
"

set payment_terms_html "
        <tr>
	  <td valign=top class=rowplain>[lang::message::lookup $locale intranet-invoices.Payment_Terms]</td>
          <td valign=top colspan=[expr {$colspan-1}] class=rowplain>
            [lang::message::lookup $locale intranet-invoices.lt_This_invoice_is_past_]
          </td>
        </tr>
"

set payment_method_html "
        <tr>
	  <td valign=top class=rowplain>[lang::message::lookup $locale intranet-invoices.Payment_Method_1]</td>
          <td valign=top colspan=[expr {$colspan-1}] class=rowplain> $invoice_payment_method_desc</td>
        </tr>
"

set canned_note_html ""
if {$canned_note_enabled_p} {

    set canned_note_sql "
                select  c.aux_string1 as canned_note
                from    im_dynfield_attr_multi_value v,
			im_categories c
                where   object_id = :invoice_id
			and v.value::integer = c.category_id
    "
    set canned_notes ""
    db_foreach canned_notes $canned_note_sql {
	append canned_notes "$canned_note\n"
    }

    set canned_note_html "
        <tr>
	  <td valign=top class=rowplain>[lang::message::lookup $locale intranet-invoices.Canned_Note "Canned Note"]</td>
          <td valign=top colspan=[expr {$colspan-1}]>
	    <pre><span style=\"font-family: verdana, arial, helvetica, sans-serif\">$canned_notes</font></pre>
	  </td>
        </tr>
    "
}


set note_html "
        <tr>
	  <td valign=top class=rowplain>[lang::message::lookup $locale intranet-invoices.Note]</td>
          <td valign=top colspan=[expr {$colspan-1}]>
	    <pre><span style=\"font-family: verdana, arial, helvetica, sans-serif\">$cost_note</font></pre>
	  </td>
        </tr>
"

set terms_html ""
if {$document_invoice_p || $document_bill_p} {
    set terms_html [concat $payment_terms_html $payment_method_html]
}
append terms_html "$canned_note_html $note_html"

set item_list_html [concat $invoice_item_html $subtotal_item_html]
set item_html [concat $item_list_html $terms_html]



# ---------------------------------------------------------------
# ADP Template
# ---------------------------------------------------------------

# Use an ADP template ("invoice_template") to render the preview of this invoice
if {"adp" eq $render_template_type} {

    # Render the page using the template
    # Always, as HTML is the input for the PDF converter
    set render_template_path "$invoice_template_base_path/$render_template"
    set invoices_as_html [ns_adp_parse -file $render_template_path]

    if {"html" eq $send_to_user_as} {
	# Redirect to mail sending page: Add the rendered invoice to the form variables
	ns_log Notice "intranet-invoice/view: sending email with html attachment"
	rp_form_put invoice_html $invoices_as_html
	rp_internal_redirect notify
	ad_script_abort
    }

    if {"" eq $send_to_user_as} {
	# Show invoice using template
	ns_log Notice "intranet-invoice/view: showing html template"
	db_release_unused_handles
	ns_return 200 text/html $invoices_as_html
	ad_script_abort
    }

}


# ---------------------------------------------------------------
# ODT Template
# ---------------------------------------------------------------

# Use an ODT template ("invoice_template") to render the preview of this invoice
if {"odt" eq $render_template_type} {

    ns_log Notice "intranet-invoice/view: odf formatting"

    # Delete the original template row, which is duplicate
    $odt_template_table_node removeChild $odt_template_row_node

    # Process the content.xml file
    set odt_template_content [$root asXML -indent 1]

    # Escaping other vars used, skip vars already escaped for multiple lines
    ns_log Notice "intranet-invoice/view: Now escaping all other vars used in template"
    set lines [split $odt_template_content \n]
    set vars_already_escaped {item_name item_units_pretty item_uom price_per_unit amount_formatted}

    foreach line $lines {
	ns_log Notice "intranet-invoice/view: Line: $line"
	set var_to_be_escaped ""
	regexp -nocase {@(.*?)@} $line var_to_be_escaped
	regsub -all "@" $var_to_be_escaped "" var_to_be_escaped
	regsub -all ";noquote" $var_to_be_escaped "" var_to_be_escaped
	ns_log Notice "intranet-invoice/view: var_to_be_escaped: $var_to_be_escaped"
	if {-1 == [lsearch $vars_already_escaped $var_to_be_escaped] } {
	    if {"" != $var_to_be_escaped} {
		if {[info exists $var_to_be_escaped]} {
		    set value [eval "set value \"$$var_to_be_escaped\""]
		    ns_log Notice "intranet-invoice/view: Other vars - Value: $value"

		    # Fraber 2020-05-10: Don't Quote variables in the body of the documents
		    if {0} {
			set cmd "set $var_to_be_escaped \"[encodeXmlValue $value]\""
			eval $cmd
		    } else {
			set $var_to_be_escaped $value
		    }
		    lappend vars_already_escaped $var_to_be_escaped
		}
	    }
	} else {
	    ns_log Notice "intranet-invoice/view: Other vars: Skipping $var_to_be_escaped "
	}
    }

    # Perform replacements
    regsub -all "&lt;%" $odt_template_content "<%" odt_template_content
    regsub -all "%&gt;" $odt_template_content "%>" odt_template_content

    # ------------------------------------------------
    # Rendering
    #
    if {[catch {
	eval [template::adp_compile -string $odt_template_content]
    } err_msg]} {
	set err_info $::errorInfo
	set err_txt [lang::message::lookup "" intranet-invoices.Error_rendering_template_blurb "Error rendering Template. You might have used a placeholder that is not available. Here's a detailed error message:"]
	append err_txt "<br/><br/> <strong>[ns_quotehtml $err_msg]</strong><br/>&nbsp;<br/><pre>[ns_quotehtml $err_info]</pre>"
	append err_txt [lang::message::lookup "" intranet-invoices.Check_the_config_manual_blurb "Please check the configuration manual for a list of placeholders available and more information on configuring templates:"]
	append err_txt "<br>&nbsp;<br><a href='www.project-open.com/en/'>www.project-open.com/en/</a>"
	ad_return_complaint 1 [lang::message::lookup "" intranet-invoices $err_txt]
	ad_script_abort
    }
    set content $__adp_output
    ns_log Notice "intranet-invoice/view: content=$content"

    # Save the content to a file.
    set file [open $odt_content w]
    fconfigure $file -encoding "utf-8"
    puts $file $content
    flush $file
    close $file

    # ------------------------------------------------
    # Process the styles.xml file
    #
    set file [open $odt_styles]
    fconfigure $file -encoding "utf-8"
    set style_content [read $file]
    close $file

    # Perform replacements
    eval [template::adp_compile -string $style_content]
    set style $__adp_output

    # Save the content to a file.
    set file [open $odt_styles w]
    fconfigure $file -encoding "utf-8"
    puts $file $style
    flush $file
    close $file

    # ------------------------------------------------
    # Replace the files inside the odt file by the processed files

    # The zip -j command replaces the specified file in the zipfile
    # which happens to be the OpenOffice File.
    ns_log Notice "intranet-invoice/view: before zipping"
    im_exec zip -j $odt_zip $odt_content
    im_exec zip -j $odt_zip $odt_styles
    db_release_unused_handles


    # ------------------------------------------------
    # Convert to PDF if requested
    #
    if {$pdf_p} {
	set result ""
	set err_msg ""
	set status [catch {
	    ns_log Notice "intranet-invoice/view: im_exec bash -l -c \"export HOME=~\$\{whoami\}; ooffice --headless --convert-to pdf --outdir /tmp/ $odt_zip\""
	    set result [im_exec bash -l -c "export HOME=~\$\{whoami\}; ooffice --headless --convert-to pdf --outdir /tmp/ $odt_zip"]
	} err_msg]
	
	ns_log Notice "intranet-invoice/view: result=$result"
	ns_log Notice "intranet-invoice/view: err_msg=$err_msg"
	ns_log Notice "intranet-invoice/view: status=$status"
	
	set odt_pdf "${odt_tmp_path}.pdf"
	set readable_msg ""
	if {![file readable $odt_pdf]} { set readable_msg "File=$odt_pdf was not created.<br>Maybe you didn't install LibreOffice?" }
	
	if {0 != $status || "" ne $readable_msg} {
	    ad_return_complaint 1 "<b>Error converting ODT to PDF</b>:<br><pre>$readable_msg<br>$err_msg</pre>"
	    ad_script_abort
	}
    }


    # ------------------------------------------------
    # Redirect to mail sending page:
    # Add the rendered invoice to the form variables
    #
    if {"pdf" eq $send_to_user_as} {
	ns_log Notice "intranet-invoice/view: sending PDF email"
	rp_form_put invoice_pdf_file $odt_pdf
	rp_internal_redirect notify
	ad_script_abort
    }

    # ------------------------------------------------
    # Simple return of ODT file
    #
    if {!$pdf_p} {
	ns_log Notice "intranet-invoice/view: before returning file as ODT"
	set outputheaders [ns_conn outputheaders]
	ns_set cput $outputheaders "Content-Disposition" "attachment; filename=${invoice_nr}.odt"
	ns_returnfile 200 "application/odt" $odt_zip
	ad_script_abort
    }

    # ------------------------------------------------
    # Return of ODT file as PDF
    #
    if {$pdf_p} {
	ns_log Notice "intranet-invoice/view: before returning file as PDF"
	set outputheaders [ns_conn outputheaders]
	ns_set cput $outputheaders "Content-Disposition" "attachment; filename=${invoice_nr}.pdf"
	ns_returnfile 200 "application/odt" $odt_pdf
	ad_script_abort
    }



    # ------------------------------------------------
    # Delete the temporary files

    delete other tmpfiles
    ns_unlink "${dir}/$document_filename"
    ns_unlink "${dir}/$content.xml"
    ns_unlink "${dir}/$style.xml"
    ns_unlink "${dir}/document.odf"
    ns_rmdir $dir

    ad_script_abort

}


# ---------------------------------------------------------------------
# Surcharge / Discount section
# ---------------------------------------------------------------------

# PM Fee. Set to "checked" if the customer has a default_pm_fee_percentage != ""
set pm_fee_checked ""
set pm_fee_perc ""
if {[info exists default_pm_fee_perc]} { set pm_fee_perc $default_pm_fee_perc }
if {"" == $pm_fee_perc} { set pm_fee_perc [ad_parameter -package_id [im_package_invoices_id] "DefaultProjectManagementFeePercentage" "" "10.0"] }
if {[info exists default_pm_fee_percentage] && "" != $default_pm_fee_percentage} {
    set pm_fee_perc $default_pm_fee_percentage 
    set pm_fee_checked "checked"
}
set pm_fee_msg [lang::message::lookup "" intranet-invoices.PM_Fee_Msg "Project Management %pm_fee_perc%%"]

# Surcharge. 
set surcharge_checked ""
set surcharge_perc ""
if {[info exists default_surcharge_perc]} { set surcharge_perc $default_surcharge_perc }
if {"" == $surcharge_perc} { set surcharge_perc [ad_parameter -package_id [im_package_invoices_id] "DefaultSurchargePercentage" "" "10.0"] }
if {[info exists default_surcharge_percentage]} { set surcharge_perc $default_surcharge_percentage }
set surcharge_msg [lang::message::lookup "" intranet-invoices.Surcharge_Msg "Rush Surcharge %surcharge_perc%%"]

# Discount
set discount_checked ""
set discount_perc ""
if {[info exists default_discount_perc]} { set discount_perc $default_discount_perc }
if {"" == $discount_perc} { set discount_perc [ad_parameter -package_id [im_package_invoices_id] "DefaultDiscountPercentage" "" "10.0"] }
if {[info exists default_discount_percentage]} { set discount_perc $default_discount_percentage }

set discount_msg [lang::message::lookup "" intranet-invoices.Discount_Msg "Discount %discount_perc%%"]
set submit_msg [lang::message::lookup "" intranet-invoices.Add_Discount_Surcharge_Lines "Add Discount/Surcharge Lines"]



# ---------------------------------------------------------------------
# Sub-Navbar
# ---------------------------------------------------------------------

# Choose the right subnavigation bar
#
set sub_navbar ""
if {[llength $related_projects] != 1} {
    set sub_navbar [im_costs_navbar "none" "/intranet-invoices/index" "" "" [list] ""]
} else {
    set project_id [lindex $related_projects 0]
    set bind_vars [ns_set create]
    ns_set put $bind_vars project_id $project_id
    set parent_menu_id [db_string parent_menu "select menu_id from im_menus where label='project'" -default 0]
    set menu_label "project_finance"
    set sub_navbar [im_sub_navbar \
                        -components \
                        -base_url "/intranet/projects/view?project_id=$project_id" \
                        $parent_menu_id \
                        $bind_vars "" "pagedesriptionbar" $menu_label]
}

# ---------------------------------------------------------------------
# correct problem created by -r 1.33 view.adp
# ---------------------------------------------------------------------

if {$document_po_p} {
   set customer_id $comp_id
}


# ---------------------------------------------------------------------
# ERR mess from intranet-trans-invoices
# ---------------------------------------------------------------------

if {"" != $err_mess} {
    set err_mess [lang::message::lookup "" $err_mess "Document Nr. not available anymore, please note and verify newly assigned number"]
}
