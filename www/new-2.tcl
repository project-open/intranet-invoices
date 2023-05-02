# /packages/intranet-invoices/www/new-2.tcl
#
# Copyright (C) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.


ad_page_contract {
    Saves invoice changes and set the invoice status to "Created".<br>
    Please note that there are different forms to create invoices for
    example in the intranet-trans-invoicing module of the 
    intranet-server-hosting module.
    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    { customer_id:integer "" }
    { provider_id:integer "" }
    { select_project:integer,multiple {} }
    { company_contact_id:integer,trim "" }
    { invoice_office_id "" }
    { project_id:integer "" }
    invoice_nr
    invoice_date
    cost_status_id:integer 
    cost_type_id:integer
    cost_center_id:integer
    { invoice_period_start "" }
    { invoice_period_end "" }
    { payment_days:integer ""}
    { payment_method_id:integer "" }
    template_id:integer
    { vat:trim,float "" }
    { vat_type_id:integer "" }
    tax:trim,float
    { discount_perc "0" }
    { surcharge_perc "0" }
    { discount_text "" }
    { surcharge_text "" }
    { canned_note_id:integer,multiple "" }
    { note ""}
    item_sort_order:array,integer
    item_outline_number:array,optional
    item_name:array
    item_id:integer,array,optional
    item_units:float,array
    item_uom_id:integer,array
    item_type_id:integer,array
    item_material_id:integer,array
    item_project_id:integer,array
    item_rate:trim,float,array
    item_currency:array
    item_task_id:integer,array
    source_invoice_id:array,optional,integer  
    { return_url "" }
    { also_associated_with_object_id "" }
}

set auto_increment_invoice_nr_p [parameter::get -parameter InvoiceNrAutoIncrementP -package_id [im_package_invoices_id] -default 0]
set outline_number_exists_p [im_column_exists im_invoice_items item_outline_number]

# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

if {"" eq $cost_type_id} { ad_return_complaint 1 "You need to specify the cost type" }
# Invoices and Quotes have a "Company" fields.
set invoice_or_quote_p [expr [im_category_is_a $cost_type_id [im_cost_type_invoice]] || [im_category_is_a $cost_type_id [im_cost_type_quote]]]
ns_log Notice "intranet-invoices/new-2: invoice_or_quote_p=$invoice_or_quote_p"

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr [im_category_is_a $cost_type_id [im_cost_type_invoice]] || [im_category_is_a $cost_type_id [im_cost_type_bill]]]
ns_log Notice "intranet-invoices/new-2: invoice_or_bill_p=$invoice_or_bill_p"

if {$invoice_or_quote_p} {
    set company_id $customer_id
    if {"" == $customer_id || 0 == $customer_id} {
	ad_return_complaint 1 "You need to specify a value for customer_id"
	return
    }
} else {
    set company_id $provider_id
    if {"" == $provider_id || 0 == $provider_id} {
	ad_return_complaint 1 "You need to specify a value for provider_id"
	return
    }
}

# rounding precision can be 2 (USD,EUR, ...) .. -5 (Old Turkish Lira).
set rounding_precision 2
set rf [expr {exp(log(10) * $rounding_precision)}]


if {"" == $payment_days} {
    set payment_days [im_parameter -package_id [im_package_cost_id] "DefaultProviderBillPaymentDays" "" 30]
}


# ---------------------------------------------------------------
# Check Currency Consistency
# ---------------------------------------------------------------

set default_currency [im_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
foreach item_nr [array names item_currency] {
    set cur $item_currency($item_nr)
    set name $item_name($item_nr)
    set units $item_units($item_nr)
    ns_log Notice "intranet-invoices/new-2: nr=$item_nr, units=$units, cur=$cur, name=$name"

    # Skip testing if the name or units was empty
    if {"" eq [string trim $name]} { continue }
    if {0 == $units || "" == $units} { continue }

    # Write out error in case of no currency
    if {"" eq $cur} {
        ad_return_complaint 1 "<b>[lang::message::lookup "" intranet-invoices.Error_empty_currency "Empty currency in line %item_nr%"]:</b><br>
        [lang::message::lookup "" intranet-invoices.Blurb_error_empty_currency "You have to select a currency"]"
        ad_script_abort
    }

    # Check for uniqueness
    set currency_hash($cur) $cur
}

set currency_list [array names currency_hash]
if {[llength $currency_list] > 1} {
    ad_return_complaint 1 "<b>[_ intranet-invoices.Error_multiple_currencies]:</b><br>
	[_ intranet-invoices.Blurb_multiple_currencies]"
    ad_script_abort
}

set invoice_currency [lindex $currency_list 0]
if {"" == $invoice_currency} { set invoice_currency $default_currency }


# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------


set current_user_id [auth::require_login]
set admin_p [im_user_is_admin_p $current_user_id]
set user_id $current_user_id
set write_p [im_cost_center_write_p $cost_center_id $cost_type_id $user_id]
# if !$write_p || ![im_permission $user_id add_invoices] || "" == $cost_center_id
if {!$write_p || ![im_permission $user_id add_invoices] } {
    set cost_type_name [db_string ccname "select im_category_from_id(:cost_type_id)" -default "not found"]
    set cost_center_name [db_string ccname "select im_cost_center_name_from_id(:cost_center_id)" -default "not found"]
    ad_return_complaint 1 "<li>You don't have sufficient privileges to create documents of type '$cost_type_name' in CostCenter '$cost_center_name' (id=\#$cost_center_id)."
    ad_script_abort
}


# Invoices and Bills need a payment method, quotes and POs don't.
if {$invoice_or_bill_p && ("" == $payment_method_id || 0 == $payment_method_id)} {
    ad_return_complaint 1 "<li>No payment method specified"
    ad_script_abort
}

if {"" == $provider_id || 0 == $provider_id} { set provider_id [im_company_internal] }
if {"" == $customer_id || 0 == $customer_id} { set customer_id [im_company_internal] }



# ---------------------------------------------------------------
# Check if the invoice_nr is duplicate
# ---------------------------------------------------------------

# Does the invoice already exist?
set invoice_exists_p [db_string invoice_count "select count(*) from im_invoices where invoice_id=:invoice_id"]

# Check if this is a duplicate invoice_nr.
set duplicate_p [db_string duplicate_invoice_nr "
	select	count(*)
	from	im_invoices
	where	invoice_nr = :invoice_nr and
		invoice_id != :invoice_id
"]
if {$duplicate_p} {
    if {$auto_increment_invoice_nr_p} {
	set invoice_nr [im_next_invoice_nr -cost_type_id $cost_type_id -cost_center_id $cost_center_id]
    } else {
	ad_return_complaint 1 "<b>[lang::message::lookup "" intranet-invoices.Duplicate_invoice_nr "Duplicate financial document number"]:</b><br>
	[lang::message::lookup "" intranet-invoices.intranet-invoices.Duplicate_invoice_nr_msg "
		The selected financial document number (Invoice Number, Quote Number, PO Number, ...)
		already exists in the database. Please choose another number.<br>
		This error can occur if another person has been creating another financial
		document right at the same moment as you. In this case please increment your
		financial document number by one, or notify your System Administrator to
		set the parameter 'InvoiceNrAutoIncrementP' to the value '1'.
        "]"
	ad_script_abort
    }
}


# ---------------------------------------------------------------
# Check if there is a workflow ongoing
# ---------------------------------------------------------------

set wf_case_p [db_string wf_case "select count(*) from wf_cases where object_id = :invoice_id"]
if {$wf_case_p > 0 && !$admin_p} {
    ad_return_complaint 1 "<b>[lang::message::lookup "" intranet-invoices.Ongoing_Workflow "Financial Document Controlled by Workflow"]:</b><br>
        [lang::message::lookup "" intranet-invoices.intranet-invoices.Ongoing_Workflow_msg "
                This financial document is controlled by a workflow, 
                so normal users are not allowed to change it anymore.<br>
                Please notify your system administrator if you think this is not correct.
    "]"
    ad_script_abort
}   

# ---------------------------------------------------------------
# Check if there is a single project to which this document refers.
# ---------------------------------------------------------------

# Look for common super-projects for multi-project documents
set select_project [im_invoices_unify_select_projects $select_project]

if {1 == [llength $select_project]} {
    set project_id [lindex $select_project 0]
}

if {[llength $select_project] > 1} {

    # Get the list of all parent projects.
    set parent_list [list]
    foreach pid $select_project {
        set parent_id [db_string pid "select parent_id from im_projects where project_id = :pid" -default ""]
        while {"" != $parent_id} {
            set pid $parent_id
            set parent_id [db_string pid "select parent_id from im_projects where project_id = :pid" -default ""]
        }
        lappend parent_list $pid
    }

    # Check if all parent projects are the same...
    set project_id [lindex $parent_list 0]
    foreach pid $parent_list {
        if {$pid != $project_id} { set project_id "" }
    }

    # Reset the list of "select_project", because we've found the superproject.
    if {"" != $project_id} { set select_project [list $project_id] }
}


# ---------------------------------------------------------------
# Choose the default contact for this invoice.
if {"" == $company_contact_id } {
   set company_contact_id [im_invoices_default_company_contact $company_id $project_id]
}

set canned_note_enabled_p [im_parameter -package_id [im_package_invoices_id] "EnabledInvoiceCannedNoteP" "" 1]

# ---------------------------------------------------------------
# Update invoice base data
# ---------------------------------------------------------------

# Just update the invoice if it already exists:
if {!$invoice_exists_p} {
    # Let's create the new invoice
    set invoice_id [db_exec_plsql create_invoice ""]
}

# Give company_contact_id READ permissions - required for Customer Portal
if {"" ne $company_contact_id} {
    permission::grant -object_id $invoice_id -party_id $company_contact_id -privilege "read"
}

# Audit before update only if the invoice already existed
if {$invoice_exists_p} {
    im_audit -object_type "im_invoice" -object_id $invoice_id -action before_update
}

if {"" ne $vat_type_id} {
    set vat [db_string vat_from_vat_type "select aux_int1 from im_categories where category_id = :vat_type_id" -default ""]
}

# Complaint about missing VAT only in Customer Invoices
if {"" eq $vat && [lsearch [im_sub_categories [im_cost_type_invoice]] $cost_type_id] > -1} {
    ad_return_complaint 1 "<li>No VAT specified"
    ad_script_abort
}

# Determine whether the invoice is related to a specific project or not
set invoice_project_ids [db_list invoice_projects "
                select  p.project_id as rel_project_id
                from    acs_rels r,
			im_projects p
                where   r.object_id_two = :invoice_id and
			r.object_id_one = p.project_id
"]
switch [llength $invoice_project_ids] {
    0 { set invoice_project_id "" }
    1 { set invoice_project_id [lindex $invoice_project_ids 0] }
    default { set invoice_project_id "" }
}
# SALO: 2018-04-10 /Financial Report/Proforma Export/ fails when
# im_costs.project_id is NULL. This only happens when a new invoice
# is created, and it becomes fixed when the invoice is edited and
# saved (indeed if nothing has been changed).
# This fix is of the same kind as the one done later with project_id_item
if { ""==$invoice_project_id } { set invoice_project_id $project_id }



# Update the invoice itself
db_dml update_invoice "
update im_invoices 
set 
	invoice_nr	= :invoice_nr,
	payment_method_id = :payment_method_id,
	company_contact_id = :company_contact_id,
	invoice_office_id = :invoice_office_id,
	discount_perc	= :discount_perc,
	discount_text	= :discount_text,
	surcharge_perc	= :surcharge_perc,
	surcharge_text	= :surcharge_text
where
	invoice_id = :invoice_id
"

db_dml update_costs "
update im_costs
set
	project_id	= :invoice_project_id,
	cost_name	= :invoice_nr,
	customer_id	= :customer_id,
	cost_nr		= :invoice_id,
	provider_id	= :provider_id,
	cost_status_id	= :cost_status_id,
	cost_type_id	= :cost_type_id,
	cost_center_id	= :cost_center_id,
	template_id	= :template_id,
	effective_date	= :invoice_date,
	start_block	= ( select max(start_block) 
			    from im_start_months 
			    where start_block < :invoice_date),
	payment_days	= :payment_days,
	vat		= :vat,
	tax		= :tax,
	vat_type_id	= :vat_type_id,
	note		= :note,
	variable_cost_p = 't',
	amount		= null,
	currency	= :invoice_currency,
	paid_currency	= :invoice_currency
where
	cost_id = :invoice_id
"


db_dml update_timesheet_invoices "
	update im_timesheet_invoices set
		invoice_period_start = :invoice_period_start,
		invoice_period_end = :invoice_period_end
	where invoice_id = :invoice_id
"

if {$canned_note_enabled_p} {

    set attribute_id [db_string attrib_id "
			select	attribute_id 
			from	im_dynfield_attributes
			where	acs_attribute_id = (
					select	attribute_id
					from	acs_attributes
					where	object_type = 'im_invoice'
						and attribute_name = 'canned_note_id'
				)
    " -default 0]

    # Delete the old values
    db_dml del_attr "
	delete from im_dynfield_attr_multi_value 
	where	object_id = :invoice_id
		and attribute_id = :attribute_id
    "

    foreach cid $canned_note_id {
	db_dml insert_note "
		insert into im_dynfield_attr_multi_value (object_id, attribute_id, value) 
		values (:invoice_id, :attribute_id, :cid);
        "
    }
}


# ---------------------------------------------------------------
# Create the im_invoice_items for the invoice
# ---------------------------------------------------------------

set db_item_ids [db_list db_item_ids "select item_id from im_invoice_items where invoice_id = :invoice_id"]
set form_item_nrs [array names item_name]


if {![parameter::get -package_id [apm_package_id_from_key intranet-invoices] -parameter "AllowDuplicateInvoiceItemNames" -default 0] && !$outline_number_exists_p} {
    # sanity check for double item names
    set name_list [list]
    foreach nr $form_item_nrs {
	if {!("" == [string trim $item_name($nr)] && (0 == $item_units($nr) || "" == $item_units($nr)))} {
	    if { -1 != [lsearch $name_list $item_name($nr)] } {
		ad_return_complaint 1 "Found duplicate invoice item: $item_name($nr)<br>
                    Please ensure that item names are unique. Use the back button of your browser to rename item.<br>
                    Consider adding spaces if item can't be renamed
                "
	    } else {
		lappend name_list $item_name($nr)
	    }
	}
    }
}

set form_item_ids {}
foreach nr $form_item_nrs {
    set sort_order $item_sort_order($nr)
    set name $item_name($nr)
    set units $item_units($nr)
    set uom_id $item_uom_id($nr)
    set type_id $item_type_id($nr)
    set material_id $item_material_id($nr)
    set rate $item_rate($nr)
    set task_id $item_task_id($nr)
    
    if {[info exists item_id($nr)]} { set id $item_id($nr) } else { set id "" }
    if {[info exists source_invoice_id($nr)]} { set item_source_invoice_id $source_invoice_id($nr) } else { set item_source_invoice_id "" }
    if {[info exists item_outline_number($nr)]} { set outline_number $item_outline_number($nr) } else { set outline_number "" }

    # project_id is empty when document is created from scratch
    # project_id is required for grouped invoice items 
    set project_id_item $item_project_id($nr)   
    if {"" == $project_id_item } { set project_id_item $project_id }

    ns_log Notice "item($nr, $name, $units, $uom_id, $project_id, $rate)"
    ns_log Notice "KHD: Now creating invoice item: item_name: $name, invoice_id: $invoice_id, project_id: $project_id, sort_order: $sort_order, outline_number: $outline_number, item_uom_id: $uom_id"

    # Skip if invalid data
    if {"" == [string trim $name] || 0 == $units || "" == $units} { continue }

    # Keep track on valid entries in the form, for deleting below
    lappend form_item_ids $id

    # Create or update?
    if {"" eq $id} {
	ns_log Notice "new-2: Creating a new invoice item: id=$id, sort_order=%sort_order, name=$name"
	set id [db_string new_invoice_item "select im_invoice_item__new(
			null, 'im_invoice_item', now(), :current_user_id, '[ad_conn peeraddr]', null,
			:name, :invoice_id, :sort_order,
			:units, :uom_id, :rate, :invoice_currency,
			[im_invoice_item_type_default], [im_invoice_item_status_active]
	)"]
    }
    ns_log Notice "new-2: Updating invoice item: id=$id, sort_order=%sort_order, name=$name"
    db_dml update_new_invoice_item "
	update im_invoice_items set
		item_name = :name,
		sort_order = :sort_order,
		item_units = :units,
		item_uom_id = :uom_id,
		price_per_unit = :rate,
		currency = :invoice_currency,		
		project_id = :project_id,
		item_material_id = :material_id,
		task_id = :task_id,
		item_source_invoice_id = :item_source_invoice_id
	where item_id = :id
    "

    if {$outline_number_exists_p} {
	db_dml outline "update im_invoice_items set item_outline_number = :outline_number where item_id = :id"
    }

    # invoice_items are now objects, so we can audit them.
    ns_log Notice "new-2: Audit item: id=$id, sort_order=%sort_order, name=$name"
    im_audit -object_id $id
}



# ---------------------------------------------------------------
# Delete those items that are in the DB but not in the form anymore
# ---------------------------------------------------------------

foreach id $db_item_ids {
    if {!($id in $form_item_ids)} {
	ns_log Notice "new-2: Deleting item: id=$id"
	db_string del_invoice_item "select im_invoice_item__delete(:id)"
    }
}



# ---------------------------------------------------------------
# Associate the invoice with the project via acs_rels
# ---------------------------------------------------------------

foreach project_id $select_project {
    set v_rel_exists [db_string get_rels "
                select  count(*)
                from    acs_rels r,
                        im_projects p,
                        im_projects sub_p
                where   p.project_id = :project_id and
                        sub_p.tree_sortkey between p.tree_sortkey and tree_right(p.tree_sortkey) and
                        r.object_id_one = sub_p.project_id and
                        r.object_id_two = :invoice_id
    "]

    if {0 == $v_rel_exists} {
	set rel_id [db_exec_plsql create_rel ""]
    }
}


# Should we associate this invoice with another object?
if {"" ne $also_associated_with_object_id} {
    set v_rel_exists [db_string get_rels "
                select  count(*)
                from    acs_rels r
                where   r.object_id_one = :also_associated_with_object_id and
                        r.object_id_two = :invoice_id
    "]

    if {0 == $v_rel_exists} {
	set project_id $also_associated_with_object_id
	set rel_id [db_exec_plsql create_rel ""]
    }
}


# ---------------------------------------------------------------
# Update the invoice amount and currency 
# based on the invoice items
# ---------------------------------------------------------------

set currencies [db_list distinct_currencies "
	select distinct
		currency
	from	im_invoice_items
	where	invoice_id = :invoice_id
		and currency is not null
"]

if {[llength $currencies] > 1} {
	ad_return_complaint 1 "<b>[_ intranet-invoices.Error_multiple_currencies]:</b><br>
	[_ intranet-invoices.Blurb_multiple_currencies] <pre>$currencies</pre>"
	return
}

if {"" == $discount_perc} { set discount_perc 0.0 }
if {"" == $surcharge_perc} { set surcharge_perc 0.0 }


# ---------------------------------------------------------------
# Update the invoice value
# ---------------------------------------------------------------

im_invoice_update_rounded_amount \
    -invoice_id $invoice_id \
    -discount_perc $discount_perc \
    -surcharge_perc $surcharge_perc


# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

# Audit the creation of the invoice
if {!$invoice_exists_p} {
    # Audit creation
    im_audit -object_type "im_invoice" -object_id $invoice_id -action after_create -status_id $cost_status_id -type_id $cost_type_id

    # Start a new workflow case
    im_workflow_start_wf -object_id $invoice_id -object_type_id $cost_type_id -skip_first_transition_p 1

} else {
    # Audit the update
    im_audit -object_type "im_invoice" -object_id $invoice_id -action after_update -status_id $cost_status_id -type_id $cost_type_id
}

# Propagate the audit to the project, because it might be changed by the document
im_audit -object_id $project_id -action after_update



if {"" eq $return_url} { 
    set return_url "/intranet-invoices/view?invoice_id=$invoice_id" 
}

# Fraber 2018-10-17: There are many issues with return-redirect.
set return_url "/intranet-invoices/view?invoice_id=$invoice_id" 


db_release_unused_handles
ad_returnredirect $return_url

