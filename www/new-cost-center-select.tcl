# /packages/intranet-invoices/www/new-cost-center-select.tcl
#
# Copyright (c) 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Determine the cost center (i.e. Profit Center) for an invoice, 
    if it wasn't defined before.
    @author frank.bergmann@project-open.com
} {
    {pass_through_variables ""}
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


# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------

set page_title "[lang::message::lookup "" intranet-invoices.Cost_Center_Select "Cost Center Select"]"
set context_bar [im_context_bar $page_title]

set cost_center_url "/intranet-cost/cost-centers/new"
set group_url "/admin/groups/one"

set bgcolor(0) " class=rowodd"
set bgcolor(1) " class=roweven"


# -----------------------------------------------------------
# Pass throught the values of pass_through_variables
# We have to take the values of these vars directly
# from the HTTP session.
# -----------------------------------------------------------

set form_vars [ns_conn form]
set pass_through_html ""
foreach var $pass_through_variables {
    set value [ns_set get $form_vars $var]
   append pass_through_html "
        <input type=hidden name=\"$var\" value=\"[ad_quotehtml $value]\">
   "
}

# ---------------------------------------------------------------
#
# ---------------------------------------------------------------

set table_header "
<tr>
  <td></td>
  <td width=20>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td width=20>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td width=20>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td width=20>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td width=20>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td width=20>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td width=20>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td width=20>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
"


# ------------------------------------------------------
# Main SQL: Extract the permissions for all Cost Centers
# ------------------------------------------------------

set main_sql "
	select
		m.*,
		(length(cost_center_code) / 2) -1 as indent_level,
		(10 - (length(cost_center_code)/2)) as colspan_level,
		im_name_from_user_id(m.manager_id) as manager_name
	from
		im_cost_centers m
	where
		m.cost_center_type_id = [im_cost_center_type_profit_center]
	order by 
		cost_center_code
"

set table ""
set ctr 0
db_foreach cost_centers $main_sql {

    incr ctr
    set object_id $cost_center_id

    append table "\n<tr$bgcolor([expr $ctr % 2])>\n"
    append table "<td><input type=radio name=cost_center_id value=$cost_center_id></td>\n"

    if {0 != $indent_level} {
	append table "\n<td colspan=$indent_level>&nbsp;</td>"
    }

    append table "
	  <td colspan=$colspan_level>
	    <nobr>
	    <A href=$cost_center_url?cost_center_id=$cost_center_id&return_url=$return_url
	    >$cost_center_name</A>
	    </nobr>
	  </td>
    "

    append table "</tr>\n"
}

append table "
	<tr>
	  <td colspan=9>
	    <input type=submit value='[_ intranet-core.Submit]'>
	  </td>
	</tr>
"

db_release_unused_handles
