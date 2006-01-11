# /packages/intranet-invoicing/tcl/intranet-invoice.tcl
#
# Copyright (C) 2003-2005 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_library {
    Bring together all "components" (=HTML + SQL code)
    related to Invoices

    @author frank.bergann@project-open.com
}


# -----------------------------------------------------------
# Package Routines
# -----------------------------------------------------------

ad_proc -public im_package_invoices_id { } {
} {
    return [util_memoize "im_package_invoices_id_helper"]
}

ad_proc -private im_package_invoices_id_helper {} {
    return [db_string im_package_core_id {
        select package_id from apm_packages
        where package_key = 'intranet-invoices'
    } -default 0]
}



# -----------------------------------------------------------
# 
# -----------------------------------------------------------

ad_proc -public im_next_invoice_nr {
    { -invoice_type_id 0}
} {
    Returns the next free invoice number.

    @param invoice_type_id Counter for type of financial document
           to be generated.

    Invoice_nr's look like: 2003_07_0123 with the first 4 digits being
    the current year, the next 2 digits the month and the last 4 digits 
    as the current number within the month.
    Returns "" if there was an error calculating the number.

    The SQL query works by building the maximum of all numeric (the 8 
    substr comparisons of the last 4 digits) invoice numbers
    of the current year/month, adding "+1", and contatenating again with 
    the current year/month.

    This procedure has to deal with the case that
    two user are invoices projects concurrently. In this case there may
    be a "raise condition", that two invoices are created at the same
    moment. This is possible, because we take the invoice numbers from
    im_invoices_ACTIVE, which excludes invoices in the process of
    generation.
    To deal with this situation, the calling procedure has to double check
    before confirming the invoice.
} {
    # ----------------------------------------------------
    # Get some parameters that influence the counters:

    # Prefix the numbers with a "I", "Q", "B" and "P" for Invoices, Quotes, ...?
    set use_invoice_prefix_p [parameter::get -package_id [im_package_invoices_id] -parameter "UseInvoiceNrTypePrefixP" -default 0]

    # Determine the date format that specifies whether to 
    # restart the invoice every year ("YYYY") or every month
    # ("YYYY_MM")
    set date_format [parameter::get -package_id [im_package_invoices_id] -parameter "InvoiceNrDateFormat" -default "YYYY_MM"]

    
    # ----------------------------------------------------
    # Set the prefix for financial document type
    set prefix ""
    if {$use_invoice_prefix_p} {
	switch $invoice_type_id {
	    3700 { set prefix "I" }
	    3702 { set prefix "Q" }
	    3704 { set prefix "B" }
	    3706 { set prefix "P" }
	    default { set prefix "" }
	}
    }

    # ----------------------------------------------------
    # Calculate the next invoice Nr by finding out the last
    # one +1

    # Adjust the position of the start of date and nr in the invoice_nr
    set prefix_len [string length $prefix]
    set date_start_idx [expr 1+$prefix_len]
    set date_format_len [string length $date_format]
    set nr_start_idx [expr 2+$date_format_len+$prefix_len]

    set prefix_where ""
    if {$prefix_len} {
	set prefix_where "and substr(invoice_nr, 1, 1) = :prefix"
    }

    set sql "
select
	trim(max(i.nr)) as last_invoice_nr
from
	(select	substr(invoice_nr, :nr_start_idx,4) as nr 
	 from	im_invoices, dual
	 where	
		substr(invoice_nr, :date_start_idx, :date_format_len) = to_char(sysdate, :date_format)
		$prefix_where
	UNION
	 select '0000' as nr from dual
	) i
where
        ascii(substr(i.nr,1,1)) > 47 and ascii(substr(i.nr,1,1)) < 58 and
        ascii(substr(i.nr,2,1)) > 47 and ascii(substr(i.nr,2,1)) < 58 and
        ascii(substr(i.nr,3,1)) > 47 and ascii(substr(i.nr,3,1)) < 58 and
        ascii(substr(i.nr,4,1)) > 47 and ascii(substr(i.nr,4,1)) < 58
"

    set last_invoice_nr [db_string max_invoice_nr $sql -default ""]
    set last_invoice_nr [string trimleft $last_invoice_nr "0"] 
    if {[empty_string_p $last_invoice_nr]} {
	set last_invoice_nr 0
    }
    set next_number [expr $last_invoice_nr + 1]


    # ----------------------------------------------------
    # Put together the new invoice_nr
    set sql "
	select
	        to_char(sysdate, :date_format)||'_'||
	        trim(to_char($next_number,'0000')) as invoice_nr
	from
	        dual
    "
    set invoice_nr [db_string next_invoice_nr $sql -default ""]

    return "$prefix$invoice_nr"
}



ad_proc -public im_invoice_nr_variant { invoice_nr } {
    Returns the next available "variant" of an invoice number.
    Example: 
    <ul>
      <li>2004_08_002 -> 2004_08_002a or
      <li>2004_08_002a -> 2004_08_002b etc.
    </ul>
} {
    # ToDo: May become slow with a rising number of invoices (> 10.000)
    set max_extension [db_string max_extension "
	select max(i.invoice_nr_extension)
	from
	        (select
	                substr(i.invoice_nr,13,13) as invoice_nr_extension
	        from
	                im_invoices i
	        where
	                substr(i.invoice_nr,1,12) = :invoice_nr	                
	        ) i
    "]

    # simple case: no extension yet
    if {"" == $max_extension} { 
	ns_log Notice "im_invoice_nr_variant: $invoice_nr: no extension yet"
	return "${invoice_nr}a" 
    }

    # second case: "a" .. "y"
    if {1 == [string length $max_extension] && [string compare $max_extension "z"] < 0} { 
	ns_log Notice "im_invoice_nr_variant: $invoice_nr: 1 digit: '$max_extension': incrementing"
	set chr [string first $max_extension "abcdefghijklmnopqrstuvwxyz"]
	incr chr
	set new_extension [string range "abcdefghijklmnopqrstuvwxyz" $chr $chr]
	return "${invoice_nr}$new_extension" 
    }

    ad_return_complaint 1 "<li>System Error: too many invoice copies<br>
    This error occurs because you have more then 26 variants of a sinlge
    financial document (invoice, quote, purchase order, ...).<br>
    Please change your invoice number and/or notify the 
    &\#93;project-open&\#91;
    team."
    return ""
}




# ---------------------------------------------------------------
# Logic to choose the most appropriate company contact for an invoice
# ---------------------------------------------------------------

ad_proc im_invoices_default_company_contact { company_id { project_id ""} } {
    Return the most appropriate company contact for an 
    invoice.
} {
    set primary_contact_id ""
    set accounting_contact_id ""

    set company_info_sql "
	select	primary_contact_id,
		accounting_contact_id
	from	im_companies
	where	company_id = :company_id
    "
    catch {[db_1row company_info $company_info_sql]} errmsg

    set prefer_accounting_contact_p [parameter::get -package_id [im_package_invoices_id] -parameter "PreferAccountingContactOverProjectContactP" -default 1]
    
    if {$prefer_accounting_contact_p} {
	if {"" != $accounting_contact_id} { return $accounting_contact_id }
	if {"" != $primary_contact_id} { return $primary_contact_id }
    }

    if {0 != $project_id && "" != $project_id || [db_column_exists im_project company_contact_id]} {

	set contact_id [db_string project_info "select company_contact_id from im_projects where project_id = :project_id" -default ""]
	if {"" != $contact_id} { return $contact_id }
    }

    # No particular user found - return NULL
    return ""
}

# ---------------------------------------------------------------
# Components
# ---------------------------------------------------------------

ad_proc im_invoices_object_list_component { user_id invoice_id read write return_url } {
    Returns a HTML table containing a list of objects
    associated with a particular financial document.
} {
    if {!$read} { return "" }

    set bgcolor(0) "class=roweven"
    set bgcolor(1) "class=rowodd"

    db_1row invoice_company_id "
	select	customer_id,
		provider_id
	from	im_costs
	where	cost_id = :invoice_id
    "
    
    # ---------------------- Format the list ------------------
    #
    set ctr 0
    set object_list_html ""
    db_foreach object_list {} {

	# Allow us to add some extra stuff for certain know object
	# types such as projects...
	switch $object_type {
	    im_project { set extra_url "&view_name=finance" }
	    default { set extra_url "" }
	}

	append object_list_html "
        <tr $bgcolor([expr $ctr % 2])>
          <td>
            <A href=\"$url$object_id$extra_url\">$object_name</A>
          </td>\n"
	if {$write} {
	    append object_list_html "
          <td>
            <input type=checkbox name=object_ids.$object_id>
          </td>\n"
	}
	append object_list_html "
        </tr>\n"
	incr ctr
    }

    if {0 == $ctr} {
	append object_list_html "
        <tr $bgcolor([expr $ctr % 2])>
          <td><i>[_ intranet-invoices.No_objects_found]</i></td>
        </tr>\n"
    }

    set return_html "
      <form action=invoice-association-action method=post>
      [export_form_vars invoice_id return_url]
      <table border=0 cellspacing=1 cellpadding=1>
        <tr>
          <td align=middle class=rowtitle colspan=2>[_ intranet-invoices.Related_Projects]</td>
        </tr>
        $object_list_html
    "
    if {$write} {
	append return_html "
        <tr>
          <td align=right>
            <input type=submit name=add_project_action value='[_ intranet-invoices.Add_a_Project]'>
            </A>
          </td>
          <td>
            <input type=submit name=del_action value='[_ intranet-invoices.Del]'>
          </td>
        </tr>\n"
    }
    append return_html "
      </table>
      </form>
    "

    return $return_html
}

ad_proc im_invoice_payment_method_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to $default 
    with a list of all the partner statuses in the system
} {
    return [im_category_select_plain "Intranet Invoice Payment Method" $select_name $default]
}

ad_proc im_invoices_select { select_name { default "" } { status "" } { exclude_status "" } } {
    
    Returns an html select box named $select_name and defaulted to
    $default with a list of all the invoices in the system. If status is
    specified, we limit the select box to invoices that match that
    status. If exclude status is provided, we limit to states that do not
    match exclude_status (list of statuses to exclude).

} {
    set bind_vars [ns_set create]

    set sql "
select
	i.invoice_id,
	i.invoice_nr
from
	im_invoices i
where
	1=1
"

    if { ![empty_string_p $status] } {
	ns_set put $bind_vars status $status
	append sql " and cost_status_id=(select cost_status_id from im_cost_status where cost_status=:status)"
    }

    if { ![empty_string_p $exclude_status] } {
	set exclude_string [im_append_list_to_ns_set $bind_vars cost_status_type $exclude_status]
	append sql " and cost_status_id in (select cost_status_id 
                                                  from im_cost_status 
                                                 where cost_status not in ($exclude_string)) "
    }
    append sql " order by lower(invoice_nr)"
    return [im_selection_to_select_box $bind_vars "cost_status_select" $sql $select_name $default]
}


# ---------------------------------------------------------------
# Workflow
# ---------------------------------------------------------------

ad_proc -private im_invoice_po_workflow {} {
    Create a workflow for invoices between the states
    created, confirmed and filed.
} {
    set spec {
        purchase-order {
            pretty_name "Purchase Order"
            package_key "intranet-invoices"
            object_type "im_invoice"
            callbacks { 
		# leave these blank for now
                # bug-tracker.FormatLogTitle 
                # bug-tracker.BugNotificationInfo
            }
            roles {
                provider {
                    pretty_name "Provider"
                    callbacks { 
			workflow.CreationUser 
			# leave these blank for now
                        # workflow.Role_DefaultAssignees_CreationUser
                    }
                }
                manager {
                    pretty_name "Manager"
                    callbacks { 
			# leave these blank for now
                        # workflow.Role_DefaultAssignees_CreationUser
                    }
                }
            }
            states {
                open {
                    pretty_name "Open"
                    # hide_fields { resolution fixed_in_version }
                }
                confirmed {
                    pretty_name "Confirmed"
                }
                closed {
                    pretty_name "Closed"
                }
                deleted {
                    pretty_name "Deleted"
                }
            }
            actions {
                create {
                    pretty_name "Create"
                    pretty_past_tense "Created"
                    new_state "open"
                    initial_action_p t
                }
                confirm {
                    pretty_name "Confirm"
                    pretty_past_tense "Confirmed"
                    privileges { write }
                    always_enabled_p t
                    edit_fields { 
			# not sure what to do here
                        #component_id 
                        #summary 
                        #found_in_version
                        #role_assignee
                        #fix_for_version
                        #resolution 
                        #fixed_in_version 
                    }
                }
                modify {
                    pretty_name "Modify"
                    pretty_past_tense "Modified"
                    privileges { write }
                    enabled_states { confirmed }
                    modify_fields { 
			# not sure what to do here
                        #component_id 
                        #summary 
                        #found_in_version
                        #role_assignee
                        #fix_for_version
                        #resolution 
                        #fixed_in_version 
                    }
                    privileges { write }
                    new_state "open"
                }
                close {
                    pretty_name "Close"
                    pretty_past_tense "Closed"
                    # what is this doing?
		        assigned_role "submitter"
                    assigned_states { resolved }
                    new_state "closed"
                    privileges { write }
                }
            }
        }
    }
    return workflow_id [workflow::fsm::new_from_spec -spec $spec]
}

ad_proc -public im_invoice_po_workflow_start {} {
    Start a workflow for a specific purchase order
} {
    set workflow_spec [im_invoice_po_workflow]
    set workflow_id [workflow::fsm::new_from_spec -spec $workflow_spec]
    return $workflow_id
}

