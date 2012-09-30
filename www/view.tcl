# /packages/intranet-invoices/www/view.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    View all the info about a specific project

    @param render_template_id specifies whether the invoice should be show
	   in plain HTML format or formatted using an .adp template
    @param show_all_comments whether to show all comments
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
} {
    { invoice_id:integer 0}
    { object_id:integer 0}
    { show_all_comments 0 }
    { render_template_id:integer 0 }
    { return_url "" }
    { send_to_user_as ""}
    { output_format "html" }
    { err_mess "" }
    { item_list_type:integer 0 }
    { pdf_p 0 }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# Get user parameters
set user_id [ad_maybe_redirect_for_registration]
set user_locale [lang::user::locale]
set locale $user_locale
set page_title ""

# Security is defered after getting the invoice information
# from the database, because the customer's users should
# be able to see this invoice even if they don't have any
# financial view permissions otherwise.

if {0 == $invoice_id} {set invoice_id $object_id}
if {0 == $invoice_id} {
    ad_return_complaint 1 "<li>[lang::message::lookup $locale intranet-invoices.lt_You_need_to_specify_a]"
    return
}

if {"" == $return_url} { set return_url [im_url_with_query] }

set bgcolor(0) "class=invoiceroweven"
set bgcolor(1) "class=invoicerowodd"

set required_field "<font color=red size=+1><B>*</B></font>"

# ---------------------------------------------------------------
# Set default values from parameters
# ---------------------------------------------------------------

# Type of the financial document
set cost_type_id [db_string cost_type_id "select cost_type_id from im_costs where cost_id = :invoice_id" -default 0]

# Number formats
set cur_format [im_l10n_sql_currency_format]
set vat_format $cur_format
set tax_format $cur_format

# Rounding precision can be between 2 (USD,EUR, ...) and -5 (Old Turkish Lira, ...).
set rounding_precision 2
set rounding_factor [expr exp(log(10) * $rounding_precision)]
set rf $rounding_factor

# Default Currency
set default_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set invoice_currency [db_string cur "select currency from im_costs where cost_id = :invoice_id" -default $default_currency]
set rf 100
catch {set rf [db_string rf "select rounding_factor from currency_codes where iso = :invoice_currency" -default 100]}

# Where is the template found on the disk?
set invoice_template_base_path [ad_parameter -package_id [im_package_invoices_id] InvoiceTemplatePathUnix "" "/tmp/templates/"]

# Invoice Variants showing or not certain fields.
# Please see the parameters for description.
set surcharge_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceSurchargeFieldP" "" 0]
set surcharge_enabled_p 1
set canned_note_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceCannedNoteP" "" 0]
set show_qty_rate_p [ad_parameter -package_id [im_package_invoices_id] "InvoiceQuantityUnitRateEnabledP" "" 0]
set show_our_project_nr [ad_parameter -package_id [im_package_invoices_id] "ShowInvoiceOurProjectNr" "" 1]
set show_our_project_nr_first_column_p [ad_parameter -package_id [im_package_invoices_id] "ShowInvoiceOurProjectNrFirstColumnP" "" 1]
set show_leading_invoice_item_nr [ad_parameter -package_id [im_package_invoices_id] "ShowLeadingInvoiceItemNr" "" 0]

# Should we show the customer's PO number in the document?
# This makes only sense in "customer documents", i.e. quotes, invoices and delivery notes
set show_company_project_nr [ad_parameter -package_id [im_package_invoices_id] "ShowInvoiceCustomerProjectNr" "" 1]
if {![im_category_is_a $cost_type_id [im_cost_type_customer_doc]]} { set show_company_project_nr 0 }


# Show or not "our" and the "company" project nrs.
set company_project_nr_exists [im_column_exists im_projects company_project_nr]
set show_company_project_nr [expr $show_company_project_nr && $company_project_nr_exists]


# Which report to show for timesheet invoices as the detailed list of hours
set timesheet_report_url [ad_parameter -package_id [im_package_invoices_id] "TimesheetInvoiceReport" "" "/intranet-reporting/timesheet-invoice-hours.tcl"]

# Check if (one of) the PDF converter(s) is installed
set pdf_enabled_p [llength [info commands im_html2pdf]]

# Unified Business Language?
set ubl_enabled_p [llength [info commands im_ubl_invoice2xml]]


# ---------------------------------------------------------------
# Audit
# ---------------------------------------------------------------

# Check if the invoices was changed outside of ]po[...
# Normally, the current values of the invoice should match
# exactly the last registered audit version...
im_audit -object_type "im_invoice" -object_id $invoice_id -action before_update


# ---------------------------------------------------------------
# Determine if it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Customer" fields.
set invoice_or_quote_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_quote] || $cost_type_id == [im_cost_type_delivery_note] || $cost_type_id == [im_cost_type_interco_quote] || $cost_type_id == [im_cost_type_interco_invoice]]

# Vars for ADP (can't use the commands in ADP)
set quote_cost_type_id [im_cost_type_quote]
set delnote_cost_type_id [im_cost_type_delivery_note]
set po_cost_type_id [im_cost_type_po]
set invoice_cost_type_id [im_cost_type_invoice]
set bill_cost_type_id [im_cost_type_bill]

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]]

# CostType for "Generate Invoice from Quote" or "Generate Bill from PO"
set target_cost_type_id ""
set generation_blurb ""
if {$cost_type_id == [im_cost_type_quote]} {
    set target_cost_type_id [im_cost_type_invoice]
    set generation_blurb "[lang::message::lookup $locale intranet-invoices.lt_Generate_Invoice_from]"
}
if {$cost_type_id == [im_cost_type_po]} {
    set target_cost_type_id [im_cost_type_bill]
    set generation_blurb "[lang::message::lookup $locale intranet-invoices.lt_Generate_Provider_Bil]"
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
    if {$cost_type_id == [im_cost_type_invoice]} {
	set timesheet_report_enabled_p 1
    }
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
		trim(both p.company_project_nr) as customer_project_nr
	from
	        acs_rels r,
		im_projects p
	where
		r.object_id_one = p.project_id
	        and r.object_id_two = :invoice_id
"

set related_projects {}
set related_project_nrs {}
set related_project_names {}
set related_customer_project_nrs {}

set num_related_projects 0
db_foreach related_projects $related_projects_sql {
    lappend related_projects $project_id
    if {"" != $project_nr} { 
	lappend related_project_nrs $project_nr 
    }
    if {"" != $project_name} { 
	lappend related_project_names $project_name 
    }

    # Check of the "customer project nr" of the superproject, as the PMs
    # are probably too lazy to maintain it in the subprojects...
    set cnt 0
    while {[string equal "" $customer_project_nr] && ![string equal "" $parent_id] && $cnt < 10} {
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
}


# ---------------------------------------------------------------
# Get everything about the "internal" company
# ---------------------------------------------------------------

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
		c.company_path = 'internal'
"


# ---------------------------------------------------------------
# Get everything about the invoice
# ---------------------------------------------------------------

set query "
	select
		c.*,
		i.*,
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
		im_category_from_id(ci.template_id) as template
	from
		im_invoices i,
		im_costs ci,
	        im_companies c
	where 
		i.invoice_id=:invoice_id
		and ci.cost_id = i.invoice_id
		$customer_or_provider_join
"

if { ![db_0or1row invoice_info_query $query] } {

    # Check if there is a cost item with this ID and forward
    set cost_exists_p [db_string cost_ex "select count(*) from im_costs where cost_id = :invoice_id"]
    if {$cost_exists_p} { 
	ad_returnredirect [export_vars -base "/intranet-cost/costs/new" {{form_mode display} {cost_id $invoice_id}}] 
    } else {
	ad_return_complaint 1 "[lang::message::lookup $locale intranet-invoices.lt_Cant_find_the_documen]"
    }
    return
}


# ---------------------------------------------------------------
# Get information about start- and end time of invoicing period
# ---------------------------------------------------------------

set invoice_period_start ""
set invoice_period_end ""
set timesheet_invoice_p 0

set query "
	select	ti.*,
		1 as timesheet_invoice_p
	from	im_timesheet_invoices ti
	where 	ti.invoice_id = :invoice_id
"
catch { db_1row timesheet_invoice_info_query $query } err_msg


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

# Fields normally available from intranet-contacts.
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
# Determine the language of the template from the template name
# ---------------------------------------------------------------

set template_type ""
if {0 != $render_template_id} {

    # Maintain compatibility with old convention "invoice-english.adp"
    # ToDo: Remove this compatibility with V4.0
    if {[regexp {english} $template]} { set locale en }
    if {[regexp {spanish} $template]} { set locale es }
    if {[regexp {german} $template]} { set locale de }
    if {[regexp {french} $template]} { set locale fr }
    
    # New convention, "invoice.en_US.adp"
    if {[regexp {(.*)\.([_a-zA-Z]*)\.([a-zA-Z][a-zA-Z][a-zA-Z])} $template match body loc template_type]} {
	set locale $loc
    }
}

# Check if the given locale throws an error
# Reset the locale to the default locale then
if {[catch {
    lang::message::lookup $locale "dummy_text"
} errmsg]} {
    set locale $user_locale
}

ns_log Notice "view.tcl: locale=$locale"
ns_log Notice "view.tcl: template_type=$template_type"


# ---------------------------------------------------------------
# OOoo ODT Function
# Split the template into the outer template and the one for
# formatting the invoice lines.
# ---------------------------------------------------------------


if {"odt" == $template_type} {

    # Special ODT functionality: We need to parse the ODT template
    # in order to extract the table row that needs to be formatted
    # by the loop below.

    # ------------------------------------------------
    # Create a temporary directory for our contents
    set odt_tmp_path [ns_tmpnam]
    ns_log Notice "view.tcl: odt_tmp_path=$odt_tmp_path"
    ns_mkdir $odt_tmp_path
    
    # The document 
    set odt_zip "${odt_tmp_path}.odt"
    set odt_content "${odt_tmp_path}/content.xml"
    set odt_styles "${odt_tmp_path}/styles.xml"
    
    # ------------------------------------------------
    # Create a copy of the ODT
    
    # Determine the location of the template
    set invoice_template_path "$invoice_template_base_path/$template"
    ns_log Notice "view.tcl: invoice_template_path='$invoice_template_path'"

    # Create a copy of the template into the temporary dir
    ns_cp $invoice_template_path $odt_zip
    
    # Unzip the odt into the temorary directory
    exec unzip -d $odt_tmp_path $odt_zip 

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

    # Seach for the 2nd table:table-row tag
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
    ad_return_complaint "[lang::message::lookup $locale intranet-invoices.lt_Insufficient_Privileg]" "
    <li>[lang::message::lookup $locale intranet-invoices.lt_You_have_insufficient_1]<BR>
    [lang::message::lookup $locale intranet-invoices.lt_Please_contact_your_s]"
    ad_script_abort
}

# ---------------------------------------------------------------
# Page Title and Context Bar
# ---------------------------------------------------------------

set page_title [lang::message::lookup $locale intranet-invoices.One_cost_type]
set context_bar [im_context_bar [list /intranet-invoices/ "[lang::message::lookup $locale intranet-invoices.Finance]"] $page_title]


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
if { ![db_0or1row category_info_query $query] } {
    set invoice_payment_method ""
    set invoice_payment_method_desc ""
}

set invoice_payment_method_key [lang::util::suggest_key $invoice_payment_method]
set invoice_payment_method_l10n [lang::message::lookup $locale intranet-core.$invoice_payment_method_key $invoice_payment_method]


# ---------------------------------------------------------------
# Determine the country name and localize
# ---------------------------------------------------------------

set country_name ""
if {"" != $address_country_code} {
    set query "
	select	cc.country_name
	from	country_codes cc
	where	cc.iso = :address_country_code"
    if { ![db_0or1row country_info_query $query] } {
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
	[export_form_vars cost_id return_url]
	<table border=0 cellPadding=1 cellspacing=1>
        <tr>
          <td align=middle class=rowtitle colspan=3>
	    [lang::message::lookup $locale intranet-invoices.Related_Payments]
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
        <tr $bgcolor([expr $payment_ctr % 2])>
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
	append payment_list_html "<tr class=roweven><td colspan=2 align=center><i>[lang::message::lookup $locale intranet-invoices.No_payments_found]</i></td></tr>\n"
    }


    if {$write} {
	append payment_list_html "
        <tr $bgcolor([expr $payment_ctr % 2])>
          <td align=right colspan=3>
	    <input type=submit name=add value=\"[lang::message::lookup $locale intranet-invoices.Add_a_Payment]\">
	    <input type=submit name=del value=\"[lang::message::lookup $locale intranet-invoices.Del]\">
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

set decoration_item_nr [ad_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleItemNr" "" "align=center"]
set decoration_description [ad_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleDescription" "" "align=left"]
set decoration_quantity [ad_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleQuantity" "" "align=right"]
set decoration_unit [ad_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleUnit" "" "align=left"]
set decoration_rate [ad_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleRate" "" "align=right"]
set decoration_po_number [ad_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitlePoNumber" "" "align=center"]
set decoration_our_ref [ad_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleOurRef" "" "align=center"]
set decoration_amount [ad_parameter -package_id [im_package_invoices_id] "InvoiceDecorationTitleAmount" "" "align=right"]


# start formatting the list of sums with the header...
set invoice_item_html "<tr align=center>\n"

if {$show_our_project_nr && $show_leading_invoice_item_nr} {
    append invoice_item_html "
          <td class=rowtitle $decoration_item_nr>[lang::message::lookup $locale intranet-invoices.Line_no "#"]</td>
    "
}

append invoice_item_html "
          <td class=rowtitle $decoration_description>[lang::message::lookup $locale intranet-invoices.Description]&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
"

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
	set colspan [expr 2 + 3*$show_qty_rate_p + 1*$show_company_project_nr + $show_our_project_nr]

set oo_table_xml ""

if { 0 == $item_list_type } {
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
	
	    append invoice_item_html "
		<tr $bgcolor([expr $ctr % 2])>
	    "
	
	    if {$show_leading_invoice_item_nr} {
	        append invoice_item_html "
	          <td $bgcolor([expr $ctr % 2]) align=right>$sort_order</td>\n"
	    }
	
	    append invoice_item_html "
	          <td $bgcolor([expr $ctr % 2])>$item_name</td>
	    "
	    if {$show_qty_rate_p} {
	        append invoice_item_html "
	          <td $bgcolor([expr $ctr % 2]) align=right>$item_units_pretty</td>
	          <td $bgcolor([expr $ctr % 2]) align=left>[lang::message::lookup $locale intranet-core.$item_uom $item_uom]</td>
	          <td $bgcolor([expr $ctr % 2]) align=right>$price_per_unit_pretty&nbsp;$currency</td>
	        "
	    }

	    if {$show_company_project_nr} {
		# Only if intranet-translation has added the field
		append invoice_item_html "
	          <td $bgcolor([expr $ctr % 2]) align=left>$company_project_nr</td>\n"
	    }
	
	    if {$show_our_project_nr} {
		append invoice_item_html "
	          <td $bgcolor([expr $ctr % 2]) align=left>$project_short_name</td>\n"
	    }
	
	    append invoice_item_html "
	          <td $bgcolor([expr $ctr % 2]) align=right>$amount_pretty&nbsp;$currency</td>
		</tr>"
	
	
	    # Insert a new XML table row into OpenOffice document
	    if {"odt" == $template_type} {
		set item_uom [lang::message::lookup $locale intranet-core.$item_uom $item_uom]
		# Replace placeholders in the OpenOffice template row with values
		eval [template::adp_compile -string $odt_row_template_xml]
		set odt_row_xml $__adp_output
	
		# Parse the new row and insert into OOoo document
		set row_doc [dom parse $odt_row_xml]
		set new_row [$row_doc documentElement]
		$odt_template_table_node insertBefore $new_row $odt_template_row_node
	
	    }
	
	    incr ctr
	}

} elseif { 100 == $item_list_type } {
	# item_list_type: Translation Project Hirarchy   
    	set invoice_items_sql "
                        select
                                ii.project_id as parent_id,
				p.project_id as project_id,
                                item_name as parent_name,
                                item_name as project_name,
                                item_units,
                                item_type_id,
                                item_uom_id,
                                price_per_unit,
				trunc((price_per_unit * item_units) :: numeric, 2) as line_total,
				(select category from im_categories where category_id = item_uom_id) as item_uom
                        from
                                im_invoice_items ii 
				left outer join im_projects p on (p.project_id in (select c.project_id from im_costs c where cost_id=:invoice_id) )
                        where
                                invoice_id=:invoice_id
			order by 
				ii.project_id; 
	"

        set old_parent_id -1
	set amount_total 0
        set amount_sub_total 0

        db_foreach related_projects $invoice_items_sql {
	    	if { ![info exists parent_id] || "" == $parent_id } {
			ad_return_complaint 1 "Preview not supported, maybe you created the invoice with an older version of PO" 
		}
                # SUBTOTALS
                if { ("0"!=$ctr && $old_parent_id!=$parent_id && 0!=$amount_sub_total) } {
	                append invoice_item_html "
        	                <tr><td class='invoiceroweven' colspan ='100' align='right'>
                                [lc_numeric [im_numeric_add_trailing_zeros [expr $amount_sub_total+0] $rounding_precision] "" $locale]&nbsp;$currency</td></tr>
                	"
                        set amount_sub_total 0
                }		

                if { $old_parent_id != $parent_id } {
			set parent_project_name [db_string get_parent_project_name "select project_name from im_projects where project_id = $parent_id" -default 0]
                        append invoice_item_html "<tr><td class='invoiceroweven'></td></tr>"
                        append invoice_item_html "<tr><td class='invoiceroweven'><b>$parent_project_name</b></td></tr>"
                        set old_parent_id $parent_id
                }
                set amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $amount+0] $rounding_precision] "" $locale]
                set item_units_pretty [lc_numeric [expr $item_units+0] "" $locale]
                set price_per_unit_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $price_per_unit+0] $rounding_precision] "" $locale]
                append invoice_item_html "<tr>"
                append invoice_item_html "<td class='invoiceroweven'>$parent_name</td>"
                if {$show_qty_rate_p} {
                	append invoice_item_html "
                        	<td $bgcolor([expr $ctr % 2]) align=right>$item_units_pretty</td>
                                <td $bgcolor([expr $ctr % 2]) align=left>[lang::message::lookup $locale intranet-core.$item_uom $item_uom]</td>
                                <td $bgcolor([expr $ctr % 2]) align=right>$price_per_unit_pretty&nbsp;$currency</td>
                        "
                }

                if {$show_our_project_nr} {
	                append invoice_item_html "
        	        <td $bgcolor([expr $ctr % 2]) align=left>$project_short_name</td>\n"
                }
		
                append invoice_item_html "<td $bgcolor([expr $ctr % 2]) align=right>$line_total&nbsp;$currency</td></tr>"
                set amount_sub_total [expr $amount_sub_total + $line_total]
		set amount_total [expr $amount_sub_total + $amount_total]
	       	incr ctr
	} if_no_rows {
                append invoice_item_html "<tr><td>[lang::message::lookup $locale intranet-timesheet2-invoices.No_Information]</td></tr>"
        }

} elseif { 110 == $item_list_type } {
	# Get Sub-Projects
	set invoice_items_sql "
		select distinct
                	ii.project_id,
			ii.currency
		from
			im_invoice_items ii
			left outer join im_projects p on (p.project_id in (select c.project_id from im_costs c where cost_id=:invoice_id) )
		where
			invoice_id=:invoice_id
		order by
			ii.project_id
	"

	set old_project_id -1
	set amount_total 0
	set amount_sub_total 0
	set ctr 0

	db_foreach related_projects $invoice_items_sql {
		# SUBTOTALS
		if { $old_project_id != $project_id } {
			# Customer Project Number of sub-project, internal Project-Nr of sub-project, internal Project Name of sub-project
			db_1row get_project_attributes "
				select
					company_project_nr,
					project_nr,
					project_name
				from
					im_projects
				where
					project_id = $project_id
			"

			# Write header
			append invoice_item_html "
				<tr><td class='invoiceroweven' colspan ='100' align='left'>$company_project_nr - $project_nr - $project_name</td></tr>
			"
			set old_project_id $project_id
		}

		# Get all quotes for sub-project
		set quotes_sql "
                        select distinct
                                item_source_invoice_id,
				currency
                        from
                                im_invoice_items
                        where
                                project_id = $project_id and
                                invoice_id = $invoice_id
                "

		db_foreach quotes $quotes_sql {
			if { ![info exists item_source_invoice_id] || "" == $item_source_invoice_id  } {
                                ad_return_complaint 1 "Preview not supported.<br>Maybe you have created a quote for project <a href='/intranet/projects/view?project_id=$project_id'>$project_id</a> with an earlier version of PO"
			}
                        set sum_sql "
                                select
                                        sum(a.line_total) as sum_quote
                                from
                                        (select
                                                trunc((ii.price_per_unit * ii.item_units) :: numeric, 2) as line_total
                                        from
                                                im_invoice_items ii
                                        where
                                                project_id = $project_id and
                                                item_source_invoice_id = $item_source_invoice_id
                                        ) a
                        "
			set sum_quote [db_string get_sum_quote $sum_sql -default 0]
			set quote_name [db_string get_quote_name "select cost_name from im_costs where cost_id = $item_source_invoice_id" -default 0]
                        # Write Quote
                        append invoice_item_html "
                                <tr>
                                <td $bgcolor([expr $ctr % 2]) align=right>$quote_name</td>
                                <td $bgcolor([expr $ctr % 2]) align=left colspan='2'>&nbsp;</td>
                                <td $bgcolor([expr $ctr % 2]) align=right>$sum_quote</td>
                                </tr>
                        "
			set amount_sub_total [expr $amount_sub_total + $sum_quote]
		} if_no_rows {
                	append invoice_item_html "<tr><td>[lang::message::lookup $locale intranet-timesheet2-invoices.No_Information]</td></tr>"
            	}

		# Subtotal for sub-project
		append invoice_item_html "
                                <tr><td class='invoiceroweven' colspan ='100' align='right'>
                                [lc_numeric [im_numeric_add_trailing_zeros [expr $amount_sub_total+0] $rounding_precision] "" $locale]&nbsp;$currency</td></tr>
		"
		set amount_total [expr $amount_sub_total + $amount_total]
                set amount_sub_total 0
                incr ctr
	} if_no_rows {
		ad_return_complaint 1 "Preview not supported, maybe you created the invoice with an older version of PO"
        }

	if { 0 != $amount_sub_total } {
		append invoice_item_html "
                        <tr><td class='invoiceroweven' colspan ='100' align='right'>
                        [lc_numeric [im_numeric_add_trailing_zeros [expr $amount_sub_total+0] $rounding_precision] "" $locale]&nbsp;$currency</td></tr>
                "
        }

} else {

	set indent_level [db_string get_view_id "
			select 
				tree_level(children.tree_sortkey) - tree_level(parent.tree_sortkey) as level
		 	from
				im_projects parent,
				im_projects children
			where
				children.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey) and
				children.project_id in (select task_id from im_invoice_items where invoice_id=$invoice_id)
			order by 
				level DESC
			limit 1
	" -default 0]

	set invoice_items_sql "
		select 
			all_items.*,
			im_category_from_id(item_type_id) as item_type,
			im_category_from_id(item_uom_id) as item_uom,
			round(price_per_unit * item_units * $rf) / $rf as amount,
			to_char(round(price_per_unit * item_units * $rf) / $rf, '$cur_format' ) as amount_formatted
		from 
			(
			select
				parent.project_id as parent_id,
				parent.project_nr as parent_nr,
				parent.project_name as parent_name,
				children.project_id,
				children.project_nr,
				children.project_name,
				tree_level(children.tree_sortkey) - tree_level(parent.tree_sortkey) as level,
				t.task_id,
				(select item_units from im_invoice_items i where (t.task_id = i.task_id and i.invoice_id=$invoice_id)) as item_units,
				(select item_type_id from im_invoice_items i where (t.task_id = i.task_id and i.invoice_id=$invoice_id)) as item_type_id,
				(select i.item_uom_id from im_invoice_items i where (t.task_id = i.task_id and i.invoice_id=$invoice_id)) as item_uom_id,
				(select i.price_per_unit from im_invoice_items i where (t.task_id = i.task_id and i.invoice_id=$invoice_id)) as price_per_unit,
				parent.tree_sortkey as parent_tree_sortkey,
				children.tree_sortkey as children_tree_sortkey
		 	from
				im_projects parent,
				im_projects children
				LEFT OUTER JOIN im_timesheet_tasks t ON (children.project_id = t.task_id)
			where
				children.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey) and
				children.project_id in (select task_id from im_invoice_items where invoice_id=$invoice_id)
			UNION 
			select 
				0 as parent_id,
				'' as parent_nr,
				item_name as parent_name,
				0 as project_id,
				'' as project_nr,
				item_name as project_name,
				0 as level,
				task_id,
				item_units,
				item_type_id,
				item_uom_id,
				price_per_unit,
				'1111111111111111111111111111111111111' as parent_tree_sortkey,
				'1111111111111111111111111111111111111' as children_tree_sortkey
			from 
				im_invoice_items
			where  
				invoice_id=:invoice_id
				-- and task_id=-1
			) all_items
		
		ORDER BY 
			parent_tree_sortkey,
			children_tree_sortkey,
			project_id;
	"

	set old_parent_id -1
	set amount_sub_total 0

	db_foreach related_projects $invoice_items_sql {
		# if {"" == $material_name} { set material_name $default_material_name }
   		if { ("0"!=$ctr && $old_parent_id!=$parent_id && "0"!=$level && 0!=$amount_sub_total) || "-1"==$task_id } {
			 if { "NULL"!=$task_id } {
	    			append invoice_item_html "
					<tr><td class='invoiceroweven' colspan ='100' align='right'>
					[lc_numeric [im_numeric_add_trailing_zeros [expr $amount_sub_total+0] $rounding_precision] "" $locale]&nbsp;$currency</td></tr>
				"
				set amount_sub_total 0    		
			} else {
                                append invoice_item_html "<tr><td>[lang::message::lookup $locale intranet-timesheet2-invoices.No_Information]</td></tr>"
			}
   		}
		set indent ""
		set indent_level_item [expr $indent_level - $level]  
		for {set i 0} {$i < $indent_level_item} {incr i} { 
		    	append indent "&nbsp;&nbsp;" 
		}
		# this items is not related to a task; it has been created as part of the financial document
		if { "-1" == $task_id } { 
			set indent ""
		}
		# insert headers for every project
		if { $old_parent_id != $parent_id } {
		    if { 0 != $level } {
     			    append invoice_item_html "<tr><td class='invoiceroweven'></td></tr>"
		    		append invoice_item_html "<tr><td class='invoiceroweven'>$indent$parent_name </td></tr>"
		    		set old_parent_id $parent_id
				} else {
				    set amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $amount+0] $rounding_precision] "" $locale]
			    	set item_units_pretty [lc_numeric [expr $item_units+0] "" $locale]
		    		set price_per_unit_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $price_per_unit+0] $rounding_precision] "" $locale]
				append invoice_item_html "<tr>" 
				append invoice_item_html "<td class='invoiceroweven'>$indent$parent_name</td>" 
				if {$show_qty_rate_p} {
					append invoice_item_html "
					<td $bgcolor([expr $ctr % 2]) align=right>$item_units_pretty</td>
					<td $bgcolor([expr $ctr % 2]) align=left>[lang::message::lookup $locale intranet-core.$item_uom $item_uom]</td>
					<td $bgcolor([expr $ctr % 2]) align=right>$price_per_unit_pretty&nbsp;$currency</td>
		       			"
				}

				if {$show_company_project_nr} {
					# Only if intranet-translation has added the field
					# append invoice_item_html "<td align=left>$company_project_nr</td>\n"
		    		}
				if {$show_our_project_nr} {
					append invoice_item_html "
					<td $bgcolor([expr $ctr % 2]) align=left>$project_short_name</td>\n"
		    		}
				append invoice_item_html "<td $bgcolor([expr $ctr % 2]) align=right>$amount_pretty&nbsp;$currency</td></tr>"
					set amount_sub_total [expr $amount_sub_total + $amount]				
				}
		}
	    incr ctr
	} if_no_rows {
		append invoice_item_html "<tr><td>[lang::message::lookup $locale intranet-timesheet2-invoices.No_Information]</td></tr>"
    	}
	append invoice_item_html "<tr><td class='invoiceroweven' colspan ='100' align='right'>[lc_numeric [im_numeric_add_trailing_zeros [expr $amount_sub_total+0] $rounding_precision] "" $locale]&nbsp;$currency</td></tr>"
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

set colspan_sub [expr $colspan - 1]

# Add a subtotal
set subtotal_item_html "
        <tr> 
          <td class=roweven colspan=$colspan_sub align=right><B>[lang::message::lookup $locale intranet-invoices.Subtotal]</B></td>
          <td class=roweven align=right><B><nobr>$subtotal_pretty $currency</nobr></B></td>
        </tr>
"


if {"" != $vat && 0 != $vat} {
    append subtotal_item_html "
        <tr>
          <td class=roweven colspan=$colspan_sub align=right>[lang::message::lookup $locale intranet-invoices.VAT]: $vat_perc_pretty %&nbsp;</td>
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
          <td valign=top colspan=[expr $colspan-1] class=rowplain> 
            [lang::message::lookup $locale intranet-invoices.lt_This_invoice_is_past_]
          </td>
        </tr>
"

set payment_method_html "
        <tr>
	  <td valign=top class=rowplain>[lang::message::lookup $locale intranet-invoices.Payment_Method_1]</td>
          <td valign=top colspan=[expr $colspan-1] class=rowplain> $invoice_payment_method_desc</td>
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
          <td valign=top colspan=[expr $colspan-1]>
	    <pre><span style=\"font-family: verdana, arial, helvetica, sans-serif\">$canned_notes</font></pre>
	  </td>
        </tr>
    "
}


set note_html "
        <tr>
	  <td valign=top class=rowplain>[lang::message::lookup $locale intranet-invoices.Note]</td>
          <td valign=top colspan=[expr $colspan-1]>
	    <pre><span style=\"font-family: verdana, arial, helvetica, sans-serif\">$cost_note</font></pre>
	  </td>
        </tr>
"

set terms_html ""
if {$cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]} {
    set terms_html [concat $payment_terms_html $payment_method_html]
}
append terms_html "$canned_note_html $note_html"

set item_list_html [concat $invoice_item_html $subtotal_item_html]
set item_html [concat $item_list_html $terms_html]


# ---------------------------------------------------------------
# Special Output: Format using a template and/or send out as PDF
# ---------------------------------------------------------------

# Use a specific template ("render_template_id") to render the "preview"
# of this invoice
if {0 != $render_template_id || "" != $send_to_user_as} {

    # New template type: OpenOffice document
    if {"odt" == $template_type} { set output_format "odt" }

    if {"" == $template} {
	ad_return_complaint "$cost_type Template not specified" "
	<li>You haven't specified a template for your $cost_type."
	return
    }

    set invoice_template_path "$invoice_template_base_path/$template"
    if {![file isfile $invoice_template_path] || ![file readable $invoice_template_path]} {
	ad_return_complaint "Unknown $cost_type Template" "
	<li>$cost_type template '$invoice_template_path' doesn't exist or is not readable
	for the web server. Please notify your system administrator."
	return
    }

    # Render the page using the template
    # Always, as HTML is the input for the PDF converter
    set invoices_as_html [ns_adp_parse -file $invoice_template_path]

    if {$output_format == "html" } {

	# HTML preview or email
	if {"" != $send_to_user_as} {
	    # Redirect to mail sending page:
	    # Add the rendered invoice to the form variables
	    ns_log Notice "view.tcl: html sending email"
	    rp_form_put invoice_html $invoices_as_html
	    rp_internal_redirect notify
	    ad_script_abort
	    
	} else {
	    
	    # Show invoice using template
	    ns_log Notice "view.tcl: html showing template"
	    db_release_unused_handles
	    ns_return 200 text/html $invoices_as_html
	    ad_script_abort
	}

    }


    # PDF output
    if {$output_format == "pdf" && $pdf_enabled_p} {
	
	ns_log Notice "view.tcl: pdf output format"
	set result [im_html2pdf $invoices_as_html]
	set tmp_pdf_file [lindex $result 0]
	set errlist [lindex $result 1]
	
	if {[llength $errlist] > 0} {
	    # Delete the temp file
	    im_html2pdf_read_file -delete_file_p 1 $tmp_pdf_file
	    
	    # Return the error
	    ad_return_complaint 1 $errlist
	    ad_script_abort
	}
	
	# Write PDF out - either as preview or as email
	if {"" != $send_to_user_as} {
	    # Redirect to mail sending page:
	    # Add the rendered invoice to the form variables
	    ns_log Notice "view.tcl: pdf send out"
	    rp_form_put invoice_pdf $binary_content
	    rp_internal_redirect notify
	    ad_script_abort
	    
	} else {
	    
	    # PDF Preview
	    ns_log Notice "view.tcl: pdf preview"
	    db_release_unused_handles
	    ns_returnfile 200 application/pdf $tmp_pdf_file
	    catch { file delete $tmp_pdf_file } err
	    ad_script_abort
	}
    }

    # OpenOffice Output
    if {$output_format == "odt"} {
       
	ns_log Notice "view.tcl: odf formatting"
	# ------------------------------------------------
        # setup and constants
	
	if {$internal_path != "internal"} {
	    set internal_tax_id "208 171 00202"
	} else {
	    set internal_tax_id "208 120 20138"
	}

	# ------------------------------------------------
	# Delete the original template row, which is duplicate
	$odt_template_table_node removeChild $odt_template_row_node

	# ------------------------------------------------
        # Process the content.xml file

	set odt_template_content [$root asXML -indent none]

	# Perform replacements
        eval [template::adp_compile -string $odt_template_content]
        set content $__adp_output

	# Save the content to a file.
	set file [open $odt_content w]
	fconfigure $file -encoding "utf-8"
	puts $file $content
	flush $file
	close $file


	# ------------------------------------------------
        # Process the styles.xml file

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
	ns_log Notice "view.tcl: before zipping"
	exec zip -j $odt_zip $odt_content
	exec zip -j $odt_zip $odt_styles

        db_release_unused_handles

	# ------------------------------------------------
        # Return the file

	if {$pdf_p} {
	    if { ![db_string memorized_transaction_installed_p "select count(*) from apm_packages where package_key = 'intranet-openoffice'"]  } {
		ad_return_complaint 1 "Please contact your System Administrator. Package 'intranet-openoffice' is missing."
	    }
	    set pdf_filename "[file rootname $odt_zip].pdf"
	    intranet_oo::jodconvert -oo_file $odt_zip -output_file $pdf_filename
	    set outputheaders [ns_conn outputheaders]
	    ns_set cput $outputheaders "Content-Disposition" "attachment; filename=${invoice_nr}.pdf"
	    ns_returnfile 200 application/pdf $pdf_filename
	} else {
	    ns_log Notice "view.tcl: before returning file"
	    set outputheaders [ns_conn outputheaders]
	    ns_set cput $outputheaders "Content-Disposition" "attachment; filename=${invoice_nr}.odt"
	    ns_returnfile 200 application/odt $odt_zip
	}

	# ------------------------------------------------
        # Delete the temporary files

	# delete other tmpfiles
	# ns_unlink "${dir}/$document_filename"
	# ns_unlink "${dir}/$content.xml"
	# ns_unlink "${dir}/$style.xml"
	# ns_unlink "${dir}/document.odf"
	# ns_rmdir $dir
	ad_script_abort
	    
    }

    ad_return_complaint 1 "Internal Error - No output format specified"

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
set pm_fee_msg [lang::message::lookup "" intranet-invoicing.PM_Fee_Msg "Project Management %pm_fee_perc%%"]

# Surcharge. 
set surcharge_checked ""
set surcharge_perc ""
if {[info exists default_surcharge_perc]} { set surcharge_perc $default_surcharge_perc }
if {"" == $surcharge_perc} { set surcharge_perc [ad_parameter -package_id [im_package_invoices_id] "DefaultSurchargePercentage" "" "10.0"] }
if {[info exists default_surcharge_percentage]} { set surcharge_perc $default_surcharge_percentage }
set surcharge_msg [lang::message::lookup "" intranet-invoicing.Surcharge_Msg "Rush Surcharge %surcharge_perc%%"]

# Discount
set discount_checked ""
set discount_perc ""
if {[info exists default_discount_perc]} { set discount_perc $default_discount_perc }
if {"" == $discount_perc} { set discount_perc [ad_parameter -package_id [im_package_invoices_id] "DefaultDiscountPercentage" "" "10.0"] }
if {[info exists default_discount_percentage]} { set discount_perc $default_discount_percentage }
set discount_msg [lang::message::lookup "" intranet-invoicing.Discount_Msg "Discount %discount_perc%%"]

set submit_msg [lang::message::lookup "" intranet-invoicing.Add_Discount_Surcharge_Lines "Add Discount/Surcharge Lines"]


# ---------------------------------------------------------------------
# Sub-Navbar
# ---------------------------------------------------------------------

# Choose the right subnavigation bar
#
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

if {$cost_type_id == [im_cost_type_po]} {
   set customer_id $comp_id
}


# ---------------------------------------------------------------------
# Allow Memorized Transaction if package is installed 
# ---------------------------------------------------------------------

set memorized_transaction_installed_p [db_string memorized_transaction_installed_p "select count(*) from apm_packages where package_key = 'intranet-memorized-transaction'"]

# ---------------------------------------------------------------------
# ERR mess from intranet-trans-invoices
# ---------------------------------------------------------------------

if { "" != $err_mess } {
    set err_mess [lang::message::lookup "" $err_mess "Document Nr. not available anymore, please note and verify newly assigned number"]
}

