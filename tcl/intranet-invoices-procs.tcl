# /packages/intranet-invoicing/tcl/intranet-invoice.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_library {
    Bring together all "components" (=HTML + SQL code)
    related to Invoices

    @author frank.bergann@project-open.com
}

# Payment Methods
ad_proc -public im_payment_method_undefined {} { return 800 }
ad_proc -public im_payment_method_cash {} { return 802 }


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

ad_proc -public im_next_invoice_nr { } {
    Returns the next free invoice number

    Invoice_nr's look like: 2003_07_123 with the first 4 digits being
    the current year, the next 2 digits the month and the last 3 digits 
    as the current number  within the month.
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
    set sql "
select
	to_char(sysdate, 'YYYY_MM')||'_'||
	trim(to_char(1+max(i.nr),'0000')) as invoice_nr
from
	(select substr(invoice_nr,9,4) as nr from im_invoices
	 where substr(invoice_nr, 1,7)=to_char(sysdate, 'YYYY_MM')
	 UNION 
	 select '0000' as nr from dual
	) i
where
        ascii(substr(i.nr,1,1)) > 47 and
        ascii(substr(i.nr,1,1)) < 58 and
        ascii(substr(i.nr,2,1)) > 47 and
        ascii(substr(i.nr,2,1)) < 58 and
        ascii(substr(i.nr,3,1)) > 47 and
        ascii(substr(i.nr,3,1)) < 58 and
        ascii(substr(i.nr,4,1)) > 47 and
        ascii(substr(i.nr,4,1)) < 58
"
    set invoice_nr [db_string next_invoice_nr $sql -default ""]
    ns_log Notice "im_next_invoice_nr: invoice_nr=$invoice_nr"

    return $invoice_nr
}



# ---------------------------------------------------------------
# Components
# ---------------------------------------------------------------

ad_proc im_invoices_object_list_component { user_id invoice_id return_url } {
    Returns a HTML table containing a list of objects
    associated with a particular financial document.
} {

    set bgcolor(0) "class=roweven"
    set bgcolor(1) "class=rowodd"

    set object_list_sql "
	select distinct
	   	o.object_id,
		acs_object.name(o.object_id) as object_name,
		u.url
	from
	        acs_objects o,
	        acs_rels r,
		im_biz_object_urls u
	where
	        r.object_id_one = o.object_id
	        and r.object_id_two = :invoice_id
		and u.object_type = o.object_type
		and u.url_type = 'view'
    "

    set ctr 0
    set object_list_html ""
    db_foreach object_list $object_list_sql {
	append object_list_html "
        <tr $bgcolor([expr $ctr % 2])>
          <td>
            <A href=\"$url$object_id\">$object_name</A>
          </td>
          <td>
            <input type=checkbox name=object_ids.$object_id>
          </td>
        </tr>\n"
	incr ctr
    }

    if {0 == $ctr} {
	append object_list_html "
        <tr $bgcolor([expr $ctr % 2])>
          <td><i>No objects found</i></td>
        </tr>\n"
    }

    return "
      <form action=invoice-association-action method=post>
      [export_form_vars invoice_id return_url]
      <table border=0 cellspacing=1 cellpadding=1>
        <tr>
          <td align=middle class=rowtitle colspan=2>Related Projects</td>
        </tr>
        $object_list_html
        <tr>
          <td align=right>
            <input type=submit name=add_project_action value='Add a Project'>
            </A>
          </td>
          <td>
            <input type=submit name=del_action value='Del'>
          </td>
        </tr>
      </table>
      </form>
    "
}

ad_proc im_invoice_payment_method_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to $default 
    with a list of all the partner statuses in the system
} {
    return [im_category_select "Intranet Invoice Payment Method" $select_name $default]
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