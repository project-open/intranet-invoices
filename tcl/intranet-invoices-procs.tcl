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

# Frequently used Invoices Stati
ad_proc -public im_invoice_status_in_process {} { return 600 }
ad_proc -public im_invoice_status_created {} { return 602 }
ad_proc -public im_invoice_status_outstanding {} { return 604 }
ad_proc -public im_invoice_status_past_due {} { return 606 }
ad_proc -public im_invoice_status_partially_paid {} { return 608 }
ad_proc -public im_invoice_status_paid {} { return 610 }
ad_proc -public im_invoice_status_deleted {} { return 612 }
ad_proc -public im_invoice_status_filed {} { return 614 }


# Frequently used Invoice Types
ad_proc -public im_invoice_type_invoice {} { return 700 }
ad_proc -public im_invoice_type_quote {} { return 702 }
ad_proc -public im_invoice_type_bill {} { return 704 }
ad_proc -public im_invoice_type_po {} { return 706 }


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

ad_proc -public im_invoices_navbar { default_letter base_url next_page_url prev_page_url export_var_list } {
    Returns rendered HTML code for a horizontal sub-navigation
    bar for /intranet-invoices/.
    The lower part of the navbar also includes an Alpha bar.<br>
    Default_letter==none marks a special behavious, printing no alpha-bar.
} {
    # -------- Defaults -----------------------------
    set user_id [ad_get_user_id]
    set url_stub [ns_urldecode [im_url_with_query]]
    ns_log Notice "im_invoices_navbar: url_stub=$url_stub"

    set sel "<td class=tabsel>"
    set nosel "<td class=tabnotsel>"
    set a_white "<a class=whitelink"
    set tdsp "<td>&nbsp;</td>"

    # -------- Calculate Alpha Bar with Pass-Through params -------
    set bind_vars [ns_set create]
    foreach var $export_var_list {
        upvar 1 $var value
        if { [info exists value] } {
            ns_set put $bind_vars $var $value
            ns_log Notice "im_invoices_navbar: $var <- $value"
        }
    }
    set alpha_bar [im_alpha_bar $base_url $default_letter $bind_vars]
    if {[string equal "none" $default_letter]} { set alpha_bar "&nbsp;" }
    if {![string equal "" $prev_page_url]} {
        set alpha_bar "<A HREF=$prev_page_url>&lt;&lt;</A>\n$alpha_bar"
    }

    if {![string equal "" $next_page_url]} {
        set alpha_bar "$alpha_bar\n<A HREF=$next_page_url>&gt;&gt;</A>\n"
    }

    # Get the Subnavbar
    set parent_menu_sql "select menu_id from im_menus where package_name='intranet-invoices' and label='invoices'"
    set parent_menu_id [db_string parent_admin_menu $parent_menu_sql]
    set navbar [im_sub_navbar $parent_menu_id "" $alpha_bar "tabnotsel"]

    return "<!-- navbar1 -->\n$navbar<!-- end navbar1 -->"
}

ad_proc im_next_invoice_nr { } {
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


ad_proc im_invoices_customer_component { user_id customer_id } {
    Returns a HTML table containing a list of invoices for a particular
    customer.
} {
    return [im_invoices_base_component $user_id $customer_id ""]
}

ad_proc im_invoices_project_component { user_id project_id } {
    Returns a HTML table containing a list of invoices for a particular
    particular project.
} {
    return [im_invoices_base_component $user_id "" $project_id]
}


ad_proc im_invoices_base_component { user_id {customer_id ""} {project_id ""} } {
    Returns a HTML table containing a list of invoices for a particular
    customer or a particular project.
} {
    if {![im_permission $user_id view_invoices]} {
	return ""
    }

    set bgcolor(0) " class=roweven "
    set bgcolor(1) " class=rowodd "
    set max_invoices 5
    set colspan 5

    # ----------------- Compose SQL Query --------------------------------
  
    set where_conds [list]
    if {"" != $customer_id} { lappend where_conds "i.customer_id=:customer_id" }
    if {"" != $project_id} { lappend where_conds "i.invoice_id in (select distinct invoice_id from im_invoice_items where project_id=:project_id)" }
    set where_clause [join $where_conds "\n	and "]
    if {"" == $where_clause} { set where_clause "1=1" }

    set invoices_sql "
select
	i.*,
	ii.invoice_amount,
	ii.invoice_currency,
	pa.payment_amount,
	pa.payment_currency,
        im_category_from_id(i.invoice_status_id) as invoice_status,
	i.invoice_date + payment_days as calculated_due_date
from
	im_invoices i,
        (select
                invoice_id,
                sum(item_units * price_per_unit) as invoice_amount,
		max(currency) as invoice_currency
         from im_invoice_items
         group by invoice_id
        ) ii,
	(select
		sum(amount) as payment_amount, 
		max(currency) as payment_currency,
		invoice_id 
	 from im_payments
	 group by invoice_id
	) pa
where
	$where_clause
	and i.invoice_status_id not in ([im_invoice_status_in_process])
        and i.invoice_id=ii.invoice_id(+)
	and i.invoice_id=pa.invoice_id(+)
order by
	invoice_nr desc
"

    set invoice_html "
<table border=0>
  <tr>
    <td colspan=$colspan class=rowtitle align=center>
      Recent Invoices
    </td>
  </tr>
  <tr class=rowtitle>
    <td align=center class=rowtitle>Invoice #</td>
    <td align=center class=rowtitle>Due</td>
    <td align=center class=rowtitle>Amount</td>
    <td align=center class=rowtitle>Paid</td>
    <td align=center class=rowtitle>Status</td>
  </tr>
"
    set ctr 1
    db_foreach recent_invoices $invoices_sql {
	append invoice_html "
<tr$bgcolor([expr $ctr % 2])>
  <td><A href=/intranet-invoices/view?invoice_id=$invoice_id>$invoice_nr</A></td>
  <td>$calculated_due_date</td>
  <td>$invoice_amount $invoice_currency</td>
  <td>$payment_amount $payment_currency</td>
  <td>$invoice_status</td>
</tr>\n"
	incr ctr
	if {$ctr > $max_invoices} { break }
    }


    if {$ctr > $max_invoices} {
	append invoice_html "
<tr$bgcolor([expr $ctr % 2])>
  <td colspan=$colspan>
    <A HREF=/intranet-invoices/index?status_id=0&[export_url_vars status_id customer_id project_id]>
      more invoices...
    </A>
  </td>
</tr>\n"
    }

    if {$ctr == 1} {
	append invoice_html "
<tr$bgcolor([expr $ctr % 2])>
  <td colspan=$colspan align=center>
    <I>No invoices yet for this project</I>
  </td>
</tr>\n"
	incr ctr
    }

    if {"" != $customer_id && "" == $project_id} {
	append invoice_html "
<tr>
  <td colspan=$colspan align=left>
<!--    <A href=/intranet-invoices/new?customer_id=$customer_id>
      Create a new invoice for this customer
    </A>
-->
  </td>
</tr>\n"
    }

    if {"" != $project_id} {
	append invoice_html "
<tr>
  <td colspan=$colspan align=left>
    <A href=/intranet-invoices/new?project_id=$project_id>
      Create a new invoice for this project
    </A>
  </td>
</tr>\n"
    }

    append invoice_html "</table>\n"
    return $invoice_html
}


ad_proc -public im_invoice_type_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to
    $default with a list of all the invoice_types in the system
} {
    return [im_category_select "Intranet Invoice Type" $select_name $default]
}


ad_proc -public im_invoice_status_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to
    $default with a list of all the invoice status_types in the system
} {
    return [im_category_select "Intranet Invoice Status" $select_name $default]
}


ad_proc im_invoice_payment_method_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to $default 
    with a list of all the partner statuses in the system
} {
    return [im_category_select "Intranet Invoice Payment Method" $select_name $default]
}

ad_proc im_invoice_template_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to $default 
    with a list of all the partner statuses in the system
} {
    return [im_category_select "Intranet Invoice Template" $select_name $default]
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
	append sql " and invoice_status_id=(select invoice_status_id from im_invoice_status where invoice_status=:status)"
    }

    if { ![empty_string_p $exclude_status] } {
	set exclude_string [im_append_list_to_ns_set $bind_vars invoice_status_type $exclude_status]
	append sql " and invoice_status_id in (select invoice_status_id 
                                                  from im_invoice_status 
                                                 where invoice_status not in ($exclude_string)) "
    }
    append sql " order by lower(invoice_nr)"
    return [im_selection_to_select_box $bind_vars "invoice_status_select" $sql $select_name $default]
}



