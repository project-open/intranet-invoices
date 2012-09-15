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



# ---------------------------------------------------------------
# Update the invoice value
# ---------------------------------------------------------------

ad_proc -public im_invoice_update_rounded_amount {
    -invoice_id
    { -discount_perc "" }
    { -surcharge_perc "" }
} {
    Updates the invoice amount, based on funny rounding rules for different currencies.
} {
#    ns_log Notice "im_invoice_update_rounded_amount: invoice=$invoice_id, dis=$discount_perc, sur=$surcharge_perc"

    # Get the rounding factor for the invoice
    set currency [db_string currency "select currency from im_costs where cost_id = :invoice_id" -default ""]
    if {"" == $currency} { ad_return_complaint 1 "Internal Error:<p>Invoice \\#$invoice_id not found." }
    set rf [im_invoice_rounding_factor -currency $currency]

    # Check the discount and surcharge
    if {"" == $discount_perc} { set discount_perc 0.0 }
    if {"" == $surcharge_perc} { set surcharge_perc 0.0 }

    # Calculate the subtotal
    set subtotal [db_string subtotal "
        select  sum(round(price_per_unit * item_units * :rf) / :rf)
        from    im_invoice_items
        where   invoice_id = :invoice_id
    "]

    # Update the total amount, including surcharge and discount
    set update_invoice_amount_sql "
        update im_costs set
                amount = :subtotal
                         + round(:subtotal * :surcharge_perc::numeric) / 100.0
                         + round(:subtotal * :discount_perc::numeric) / 100.0
        where cost_id = :invoice_id
    "
    db_dml update_invoice_amount $update_invoice_amount_sql
    return $invoice_id
}


# ---------------------------------------------------------------
# Get the rounding factor (rf) for a currency
# ---------------------------------------------------------------

ad_proc -public im_invoice_rounding_factor {
    -currency
} {
    Gets the right rounding factor per currency.
    A rf (rounding factor) of 100 indicates two digits after the decimal separator precision.
} {
    return [util_memoize "im_invoice_rounding_factor_helper -currency $currency"]
}

ad_proc -public im_invoice_rounding_factor_helper {
    { -currency "" }
} {
    Gets the right rounding factor per currency
    A rf (rounding factor) of 100 indicates two digits after the decimal separator precision.
} {
    if {"" == $currency} { set currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"] }
    set rf 100
    if {[catch {
        set rf [db_string rf "select rounding_factor from currency_codes where iso = :currency" -default 100]
    } err_msg]} {
        ns_log Error "im_invoice_rounding_factor_helper: Error determining rounding factor: $err_msg"
    }
    return $rf
}


# -----------------------------------------------------------
# 
# -----------------------------------------------------------

ad_proc -public im_next_invoice_nr {
    { -cost_type_id 0}
    { -cost_center_id 0}
} {
    Returns the next free invoice number.

    @param cost_type_id Counter for type of financial document
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
    if {"empty" == $date_format} { set date_format "" }

    # Check for a custom project_nr generator
    set invoice_nr_generator [parameter::get -package_id [im_package_invoices_id] -parameter "CustomInvoiceNrGenerator" -default ""]
    if {"" != $invoice_nr_generator} {
	return [eval $invoice_nr_generator -cost_type_id $cost_type_id -cost_center_id $cost_center_id -date_format $date_format]
    }
    
    # ----------------------------------------------------
    # Set the prefix for financial document type
    set prefix ""
    if {$use_invoice_prefix_p} {
	switch $cost_type_id {
	    3700 { set prefix "I" }
	    3702 { set prefix "Q" }
	    3704 { set prefix "B" }
	    3706 { set prefix "P" }
	    3718 { set prefix "T" }
	    3720 { set prefix "E" }
	    3720 { set prefix "R" }
	    3724 { set prefix "D" }
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

ad_proc im_invoices_default_company_contact { 
	company_id 
	{ project_id ""} 
} {
    Return the most appropriate company contact for an 
    invoice.
} {
    # Determine the preferred company contact
    #
    set primary_contact_id ""
    set accounting_contact_id ""
    set company_info_sql "
	select	primary_contact_id,
		accounting_contact_id
	from	im_companies
	where	company_id = :company_id
		and company_id != 0
    "
    catch {[db_1row company_info $company_info_sql]} errmsg
    set company_contact_id $accounting_contact_id
    if {"" == $company_contact_id} { set company_contact_id $primary_contact_id }


    # Determine the projects' contact (if exists)
    #
    set project_contact_id ""
    if {0 != $project_id && "" != $project_id || [im_column_exists im_projects company_contact_id]} {
	set project_contact_id [db_string project_info "
		select	company_contact_id 
		from	im_projects 
		where	project_id = :project_id
			and :company_id != 0
	" -default ""]
    }

    # Use the company's and project's contacts as default for
    # each other.
    if {"" == $company_contact_id || 0 == $company_contact_id} {
	set company_contact_id $project_contact_id
    }
    if {"" == $project_contact_id || 0 == $project_contact_id} {
	set project_contact_id $company_contact_id
    }

    # Check what we prefer (if there are two options..)
    set prefer_accounting_contact_p [parameter::get -package_id [im_package_invoices_id] -parameter "PreferAccountingContactOverProjectContactP" -default 1]

    if {$prefer_accounting_contact_p} {
	return $company_contact_id
    } else {
	return $project_contact_id
    }

}





# ---------------------------------------------------------------
# Components
# ---------------------------------------------------------------

ad_proc im_invoices_default_company_template { 
    cost_type_id
    company_id
} {
    Business logic to determine the default invoice template
    for the given cost type at the given company. 
    The algorithm checks if there are dedicated fields in the 
    im_companies table. Ugly? Maybe...
} {
    # Get the short_name of the cost_type, a string like "invoice"
    # "bill" or "delnote".
    set short_name [db_string cost_type_short_name "
	select	short_name
	from	im_cost_types 
	where	cost_type_id = :cost_type_id
    " -default "unknown"]

    # Check whether there is column "default_<short_name>_template_id"
    # in the table im_companies:
    set column_name "default_${short_name}_template_id"

    set template_id ""
    catch {
	set template_id [db_string cost_type_short_name "
		select  $column_name
		from    im_companies
		where   company_id = :company_id
	" -default "unknown"]
    } err_msg
    # Ignore error message

    return $template_id
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
# Unify "select_projects" to use the common superproject
# ---------------------------------------------------------------

ad_proc im_invoices_unify_select_projects {
    select_projects
} {
    Input is the list of projects related to a financial document.
    Output is a shortened list of related projects.
    Why? Financial documents related to more then one project
    are counted multiple times in various ]po[ reports and list
    pages. So this procedure deals with the frequent case that
    all projects belong to a single super-project and reduces
    the list of related projects to that super-project.
} {
    # Skip function if there is only a single project or none at all...
    if {[llength $select_projects] <= 1} { return $select_projects }
    
    # Security check because we're going to use non-colon vars below
    foreach p $select_projects {
	if {![string is integer $p]} { im_security_alert -location im_invoices_unify_select_projects -message "select_project not an integer" -value $p }
    }

    # Search for the common superproject
    set sql "
        select distinct
                main_p.project_id
        from
                im_projects main_p,
                im_projects p
        where
                main_p.tree_sortkey = tree_root_key(p.tree_sortkey) and
                p.project_id in ([join $select_projects ","])
    "
    set main_projects [db_list main_ps $sql]
    if {1 == [llength $main_projects]} { return $main_projects }
    
    # Didn't find a common superproject - just return the original
    return $select_projects
}


# ---------------------------------------------------------------
# Check for inconsistent invoices
# ---------------------------------------------------------------

ad_proc im_invoices_check_for_multi_project_invoices {} {
    Check if there are invoices around that are assoicated with
    more then one project.
} {
    set multiples_sql "
        select
                count(*) as cnt,
                cost_id,
                cost_name
        from
                im_projects p,
                acs_rels r,
                im_costs c
        where
                r.object_id_one = p.project_id
                and r.object_id_two = c.cost_id
        group by
                cost_id, cost_name
        having
                count(*) > 1
    "

    set errors ""
    db_foreach multiples $multiples_sql {
        append errors "<li>Financial document <a href=[export_vars -base "/intranet-invoices/view" {{invoice_id $cost_id}}]>$cost_name</a> is associated with more then one project.\n"
    }

    if {"" != $errors} {
        ad_return_complaint 1 "<p>Financial documents related to multiple projects currently cause errors in this report.</p>
        <ul>$errors</ul><p>
        Please assign every financial document to a single project (usually the main project).</p>\n"
        return
    }
}




# ---------------------------------------------------------------
# OpenOffice Integration
# ---------------------------------------------------------------


ad_proc im_invoice_oo_tdom_explore {
    {-level 0}
    -parent:required
} {
    Returns a hierarchical representation of a tDom tree
    representing the content of an OOoo document in this case.
} {
    set name [$parent nodeName]
    set type [$parent nodeType]

    set indent ""
    for {set i 0} {$i < $level} {incr i} { append indent "    " }

    set result "${indent}$name"
    if {$type == "TEXT_NODE"} { return "$result=[$parent nodeValue]\n" }

    if {$type != "ELEMENT_NODE"} { return "$result\n" }

    # Create a key-value list of attributes behind the name of the tag
    append result " ("
    foreach attrib [$parent attributes] {
	# Pull out the attributes identified by name:namespace.
	set attrib_name [lindex $attrib 0]
	set ns [lindex $attrib 1]
#	set value [$parent getAttribute "$ns:$attrib_name"]
	set value ""
	append result "'$ns':'$attrib_name'='$value', "
    }
    append result ")\n"

    # Recursively descend to child nodes
    foreach child [$parent childNodes] { 
	append result [im_invoice_oo_tdom_explore -parent $child -level [expr $level + 1]] 
    }
    return $result
}




ad_proc -public im_invoice_change_oo_content {
    -path:required
    -document_filename:required
    -contents:required
} {
    Takes the provided contents and places them in the content.xml 
    file of the odt file, effectivly changing the content of the file.

    @param path Path to the file containing the content
    @param document_filename The open-office file whose contents will be changed.
    @param contents This is a list of key-values (to be used as an array) of filenames and contents
                    to be replaced in the oo-file.
    @return The path to the new file.
} {
    # Create a temporary directory
    set dir [ns_tmpnam]
    ns_mkdir $dir

    array set content_array $contents
    foreach filename [array names content_array] {
	# Save the content to a file.
	set file [open "${dir}/$filename" w]
	fconfigure $file -encoding "utf-8"

	set content $content_array($filename)
	regsub -all -nocase "<br>" $content "<text:line-break/>" content
        regsub -all -nocase "<p>" $content "<text:line-break/>" content
        regsub -all -nocase "&nbsp;" $content " " content
        regsub -all -nocase "</p>" $content "<text:line-break/>" content
        regsub -all -nocase "a href=" $content "text:a xlink:type=\"simple\" xlink:href=" content
        regsub -all -nocase "/a" $content "/text:a" content
        regsub -all -nocase "<ul>" $content "<text:list text:style-name=\"L1\">" content
        regsub -all -nocase "</ul>" $content "</text:list>" content
	puts $file $content
	flush $file
	close $file
    }

    # copy the document
    ns_cp "${path}/$document_filename" "${dir}/$document_filename"

    # Replace old content in document with new content
    # The zip command should replace the content.xml in the zipfile which
    # happens to be the OpenOffice File. 
    foreach filename [array names content_array] {
	exec zip -j "${dir}/$document_filename" "${dir}/$filename"
    }

    # copy odt file
    set new_file "[ns_tmpnam].odt"
    ns_cp "${dir}/$document_filename" $new_file

    # delete other tmpfiles
    ns_unlink "${dir}/$document_filename"
    foreach filename [array names content_array] {
	ns_unlink "${dir}/$filename"
    }
    ns_rmdir $dir

    return $new_file
}

# ---------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------

ad_proc -public im_invoice_permissions {
    {-debug 0}
    current_user_id
    user_id
    view_var
    read_var
    write_var
    admin_var
} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $current_user_id on $user_id
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin

    set view 0
    set read 0
    set write 0
    set admin 0

    if {"" == $user_id} { return }
    if {"" == $current_user_id} { return }

    # Admins and creators can do everything
    set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
    set creation_user_id [util_memoize "db_string creator {select creation_user from acs_objects where object_id = $user_id} -default 0"]
    if {$user_is_admin_p || $current_user_id == $creation_user_id} {
        set view 1
        set read 1
        set write 1
        set admin 1
        return
    }

    # Get the list of profiles of user_id (the one to be managed)
    # together with the information if current_user_id can read/write
    # it.
    # m.group_id are all the groups to whom user_id belongs
    set profile_perm_sql "
                select
                        m.group_id,
                        im_object_permission_p(m.group_id, :current_user_id, 'view') as view_p,
                        im_object_permission_p(m.group_id, :current_user_id, 'read') as read_p,
                        im_object_permission_p(m.group_id, :current_user_id, 'write') as write_p,
                        im_object_permission_p(m.group_id, :current_user_id, 'admin') as admin_p
                from
                        acs_objects o,
                        group_distinct_member_map m
                where
                        m.member_id = :user_id
                        and m.group_id = o.object_id
                        and o.object_type = 'im_profile'
    "
    set first_loop 1
    db_foreach profile_perm_check $profile_perm_sql {
        if {$debug} { ns_log Notice "im_user_permissions: $group_id: view=$view_p read=$read_p write=$write_p admin=$admin_p" }
        if {$first_loop} {
            # set the variables to 1 if current_user_id is member of atleast
            # one group. Otherwise, an unpriviliged user could read the data
            # of another unpriv user
            set view 1
            set read 1
            set write 1
            set admin 1
        }

        if {[string equal f $view_p]} { set view 0 }
        if {[string equal f $read_p]} { set read 0 }
        if {[string equal f $write_p]} { set write 0 }
        if {[string equal f $admin_p]} { set admin 0 }
        set first_loop 0
    }

    # Myself - I can read and write its data
    if { $user_id == $current_user_id } {
                set read 1
                set write 1
                set admin 0
    }
    if {$admin} {
                set read 1
                set write 1
    }
    if {$read} { set view 1 }

    if {$debug} { ns_log Notice "im_user_permissions: cur=$current_user_id, user=$user_id, view=$view, read=$read, write=$write, admin=$admin" }

}

# ---------------------------------------------------------------
# Driver Function for Various Output formats
# ---------------------------------------------------------------
