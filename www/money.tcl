# /www/intranet/projects/money.tcl

ad_page_contract {
    Purpose: Displays an expense report
    @param start_block
    @param end_block
    @param order_by
    @param status_id
    @param partner_type_id
    @param type_id
    @author berkeley@arsdigita.com
    @creation-date Feb 2000
    @cvs-id money.tcl,v 3.21.2.9 2000/09/22 01:38:44 kevin Exp
} {
  
    start_block:optional 
    end_block:optional
    order_by:sql_identifier,optional
    status_id:integer,optional
    partner_type_id:integer,optional
    type_id:integer,optional
} -validate {
    check_date -requires {start_block end_block} {
	if { [db_string im_date_check "select count(*) from dual where to_date(:end_block, 'YYYY-MM-DD') - to_date(:start_block, 'YYYY-MM-DD') > 0"] <= 0 } {
	    ad_complain "End date must be after start date."
	}
    }
}

set page_title "Expense report"
set context_bar "[ad_context_bar_ws  [list "index" "Projects"] "Expense report"]"

set html [im_header]

if { ![exists_and_not_null partner_type_id] } {
    set partner_type_id ""
}

if { ![exists_and_not_null status_id] } {
    # Default status is OPEN - select the id once and memoize it
    set status_id [im_memoize_one select_project_open_status_id \
	    "select project_status_id
               from im_project_status
              where upper(project_status) = 'OPEN'"]
}

if {$status_id != 0} {
    lappend where_clauses "im_projects.project_status_id = $status_id"
}

if { ![exists_and_not_null type_id] } {
    set type_id 0
} elseif {$type_id != 0} {
    lappend where_clauses "im_projects.project_type_id = $type_id"
}

if { ![exists_and_not_null order_by] } {
    set order_by name
}

# status_types will be a list of pairs of (project_status_id, project_status)
set status_types [im_memoize_list select_project_status_types \
	"select project_status_id, project_status
           from im_project_status
           order by lower(project_status)"]
lappend status_types 0 All

# project_types will be a list of pairs of (project_type_id, project_type)
set project_types [im_memoize_list select_project_types \
	"select project_type_id, project_type
           from im_project_types
          order by lower(project_type)"]
lappend project_types 0 All

switch $order_by {
    "name" { set order_by_clause "order by upper(group_name)" }
    "project_type" { set order_by_clause "order by upper(im_project_types.project_type), upper(group_name)" }
    "status" { set order_by_clause "order by upper(im_project_status.project_status), upper(group_name)" }
    "fee_setup" { set order_by_clause "order by fee_setup, upper(group_name)" }
    "total_monthly" { set order_by_clause "order by total_monthly, upper(group_name)" }
    "total_people" { set order_by_clause "order by total_people, upper(group_name)" }
    #"rev_person" { set order_by_clause "order by rev_person, upper(name)" }
    "default" { set order_by_clause "order by upper(group_name)" }
}

#lappend where_clauses "parent is null"
#lappend where_clauses "project_type <> 'deleted'"

# NOTE: This does not take hours for subprojects into account!!
# This is just to get the demo done

# if not other wise provided, the report will be for the
# last 4 weeks

if { ![info exist end_block] } {
    set end_block [db_string projects_end_block_query {
	select max(start_block)
	from im_start_blocks 
	where start_block < sysdate }]
    set end_block_stub [db_string projects_end_block_stub {
	select max(start_block)
	from im_start_blocks 
	where start_block < sysdate and to_char(start_block, 'W') = 1 }] 
} else {
    set end_block_stub $end_block
}


if { ![info exist start_block] } {
    set start_block  [db_string projects_start_block_query "select max(start_block)
from im_start_blocks where start_block < to_date(:end_block,'yyyy-mm-dd') and to_char(start_block,'W') = 1"]
}

ns_log notice "end block = $end_block"
set select_weeks_form "
<form action=money method=post>
From:
<select name=start_block>
[im_allocation_date_optionlist $start_block "t"]
</select>
To
<select name=end_block>
[im_allocation_date_optionlist $end_block_stub "t"]
</select>
<input type=submit name=submit value=Go>
</form>"

set sliders "
<table border=0 cellspacing=0 cellpadding=0>
 <tr>
  <td>
    <table border=0 cellspacing=0 cellpadding=0>
      <tr>
        <td valign=top>[ad_partner_default_font "size=-1"]
           Project status: 
        </font></td>
        <td valign=top>[ad_partner_default_font "size=-1"]
           [im_slider status_id $status_types]
        </font></td>
      </tr>
      <tr>
        <td valign=top>[ad_partner_default_font "size=-1"]
           Project type:
        </font></td>
        <td valign=top>[ad_partner_default_font "size=-1"]
           [im_slider type_id $project_types]
        </font></td>
      </tr>
    </table>
  </td>
  <td valign=top>
  <td align=right valign=top>[ad_partner_default_font "size=-1"]
    <a href=\"../allocations/index\">Allocations</a> | 
    <a href=\"index\">Summary View</a>
  </font></td>
 </tr>
</table>
"

set num_weeks [db_string projects_num_weeks_query "select count(start_block) from
im_start_blocks where start_block >= :start_block
and start_block < :end_block"]

set num_months [db_string projects_num_months_query "select count(start_block) from
im_start_blocks where start_block >= :start_block
and start_block < :end_block
and start_of_larger_unit_p = 't'"]

lappend where_clauses "im_projects.group_id = im_allocations.group_id(+)"

# Note: Allocation numbers are recorded monthly
# where im_start_blocks.start_of_larger_unit_p = 't'
# Payment data may be recorded for any start block

set sql "
select im_projects.group_id, group_name, 
nvl(im_projects_monthly_fee(im_projects.group_id, :start_block, :end_block),0)  as total_monthly, 
nvl(im_projects_stock_fee(im_projects.group_id, :start_block, :end_block),0)  as stock_fee,  
nvl(im_projects_setup_fee(im_projects.group_id, :start_block, :end_block),0)  as fee_setup, 
im_projects.project_type_id, im_projects.project_status_id, 
nvl(trunc(sum(percentage_time)/(100 * $num_months),2),0) as avg_people_month,
im_project_types.project_type, im_project_status.project_status,
nvl(total_hours,0) total_hours
from im_projects, (select im_allocations.* from im_allocations
,im_start_blocks where 
im_allocations.start_block = im_start_blocks.start_block
and im_start_blocks.start_of_larger_unit_p = 't' 
and (im_allocations.start_block >= :start_block or im_allocations.start_block is null)
and (im_allocations.start_block < :end_block or im_allocations.start_block is null)) im_allocations  , 
(select im_hours.on_what_id, nvl(trunc(sum(hours),0),0) total_hours
  from im_hours
 where day between :start_block and :end_block
 and on_which_table='im_projects'
 group by on_what_id ) im_hours, 
user_groups, 
im_project_status,
im_project_types
where [join $where_clauses " and " ]
and im_hours.on_what_id(+) = im_projects.group_id
and user_groups.group_id = im_projects.group_id
and im_project_status.project_status_id = im_projects.project_status_id
and im_project_types.project_type_id = im_projects.project_type_id
group by im_projects.group_id, im_allocations.group_id, im_hours.on_what_id,  
group_name, im_projects.project_type_id, im_projects.project_status_id, 
fee_setup, fee_monthly, fee_hosting_monthly, project_type, project_status, total_hours
$order_by_clause"

append html "
$select_weeks_form

$sliders
<p>

<center>
<table width=100% cellpadding=2 cellspacing=2 border=0>
<tr>
 <td colspan=5><b>[util_AnsiDatetoPrettyDate $start_block] to [util_AnsiDatetoPrettyDate $end_block]</b></td></tr>
<tr bgcolor=[ad_parameter "TableColorHeader" "intranet"]>"

set order_by_params [list {"name" "Name"} {"project_type" "Type"} {"status" "Status"} {"fee_setup" "Total setup fees"}  {"total_monthly" "Total monthly fees"} {"stock" "Stock"} ]

foreach parameter $order_by_params {
    set pretty_order_by_current [lindex $parameter 1]
    set order_by_current [lindex $parameter 0]
    if {$order_by_current == $order_by} {
	append html "<th>$pretty_order_by_current</th>"
    } else {
	append html "<th><a href=money?order_by=$order_by_current&[export_ns_set_vars "url" "order_by"]>$pretty_order_by_current</a></th>"
    }
}

append html "<th> Total hours logged <br>Self reported<br>Not accurate</th><th> Average People/$num_months month(s)<br> allocations</th><th> (Rev/person)/$num_months month(s)</th>"

set projects ""
set background_tag ""

set fee_setup_sum 0
set total_monthly_sum 0
set avg_people_month_sum 0
set rev_person_month_sum 0
set stock_fee_sum 0

set ctr 0
db_foreach projects_financial_status_query $sql { 
    if { $ctr % 2 == 0 } {
	set background_tag " bgcolor = [ad_parameter "TableColorOdd" "intranet"] "
    } else {
	set background_tag " bgcolor = [ad_parameter "TableColorEven" "intranet"] "
    }
    incr ctr

   
if {$fee_setup != 0 || $total_monthly != 0 || $stock_fee != 0 || $avg_people_month != 0 || $total_hours != 0} {
    
    append projects "
<tr $background_tag>
 <td><A HREF=/intranet/allocations/project?group_id=$group_id>$group_name</A>
 <td>$project_type
 <td>$project_status
 <td>[util_commify_number $fee_setup] &nbsp;
 <td>[util_commify_number $total_monthly] &nbsp;
 <td>[util_commify_number $stock_fee] &nbsp;
 <td>$total_hours &nbsp;
 <td>$avg_people_month &nbsp;
 <td>"

     if {$avg_people_month > 0} {
	set rev_person_month [expr (($fee_setup+$total_monthly + $stock_fee)/$avg_people_month)]
	 append projects "[util_commify_number [expr floor($rev_person_month)]] &nbsp;"
     }  else {
	 set rev_person_month 0
	 append projects "NA"
     }
     append projects "</td></tr>\n"
     set fee_setup_sum [expr $fee_setup_sum + $fee_setup]
     set total_monthly_sum [expr $total_monthly_sum + $total_monthly]
     set avg_people_month_sum [expr $avg_people_month_sum + $avg_people_month]
     #     set rev_person_month_sum [expr $rev_person_month_sum + $rev_person_month]
     set stock_fee_sum [expr $stock_fee_sum + $stock_fee]
 }
} 
# We don't sum the avg_people_month column because we want
# the average

#set rev_person_month_total [expr (($fee_setup_sum + $total_monthly_sum + $stock_fee_sum))/$avg_people_month_sum]

append html "$projects 
<tr>
 <td>Total
 <td>
 <td>
 <td>[util_commify_number $fee_setup_sum]
 <td>[util_commify_number $total_monthly_sum]
 <td>[util_commify_number $stock_fee_sum]
 <td> 
 <td>$avg_people_month_sum
</table>
</center>
<p>

"

append html [im_footer]



doc_return  200 text/html $html
