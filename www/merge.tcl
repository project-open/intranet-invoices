# /www/intranet/projects/merge.tcl
 
ad_page_contract {
    merge two projects specified by merge_group_id_1 and merge_group_id_2 

    @param merge_group_id_1
    @param merge_group_id_2

    @author Yulin Li (stvliexp@arsdigita.com)
    @creation-date August 2000
    @cvs-id merge.tcl,v 3.3.2.3 2000/09/22 01:38:44 kevin Exp

} {
    merge_group_id_1:naturalnum,notnull
    merge_group_id_2:naturalnum,notnull
} 

set current_user_id [ad_maybe_redirect_for_registration]

########### proc local_get_project_info ##########################
proc local_get_project_info { group_id } {
     
    set col_set [ns_set create]

    db_1row project_info_get  "select 
                g.group_name as project_name, 
                g.short_name,

                p.parent_id, 
                user_group_name_from_id(p.parent_id) as parent_name,

                p.customer_id, 
                g2.group_name as customer_name, 

                p.project_type_id,
                im_category_from_id(p.project_type_id) as project_type, 

                p.project_status_id,
                im_category_from_id(p.project_status_id) as project_status,

                p.description,

                p.project_lead_id,	
                l.first_names||' '||l.last_name as project_lead,

                p.supervisor_id,
                s.first_names||' '||s.last_name as supervisor,

                im_project_ticket_project_id(p.group_id) as ticket_project_id, 
 
                p.requires_report_p,
                decode(p.requires_report_p, 't', 'Yes', 'No') as pretty_req_report,

                p.start_date,
                p.end_date,

                p.billable_type_id,
                (select category from categories where category_id = p.billable_type_id) as billable_type

             from im_projects p, users l, users s, user_groups g, user_groups g2
             where p.group_id=:group_id
               and p.project_lead_id=l.user_id(+)              
               and p.supervisor_id=s.user_id(+)
               and p.group_id=g.group_id
               and p.customer_id=g2.group_id(+)"   -column_set col_set
  
    return $col_set
}

########### proc local_radio_select #####################################
proc local_radio_select { title name display p1 p2 } {

    if { [empty_string_p [ns_set get $p1 $name]] && [empty_string_p [ns_set get $p2 $name]] } {
	return ""
    } else {
	return "
	<tr>
	<td><b>$title</b></td>
	<td><input type=radio name=\"$name\" value=\"[ns_set get $p1 $name]\" CHECKED> [ns_set get $p1 $display]</td>
	<td><input type=radio name=\"$name\" value=\"[ns_set get $p2 $name]\"> [ns_set get $p2 $display]</td>
	</tr>
	"
    }
}


#########################################################################################
#########################################################################################

if { $merge_group_id_1 == $merge_group_id_2 } {
    ad_return_complaint 1 "<li>No need to merge a project with itself. Operation aborted."
    return
}

set project_1 [local_get_project_info $merge_group_id_1]
set project_2 [local_get_project_info $merge_group_id_2]

set page_title "Merge Projects"
set context_bar [ad_context_bar_ws [list index "Projects"] [list view?group_id=$merge_group_id_1 "One project"] "Merge"]

set page_content "
<h3>Configure the new project below:</h3>
<form method=post action=merge-2>
[export_form_vars merge_group_id_1 merge_group_id_2]

<table border>
<tr> <th></th> <th>[ns_set get $project_1 short_name]</th> <th>[ns_set get $project_2 short_name]</th> </tr>

[local_radio_select "Project Name" "project_name" "project_name" $project_1 $project_2]
[local_radio_select "Short Name" "short_name" "short_name" $project_1 $project_2]
[local_radio_select "Parent Project" "parent_id" "parent_name" $project_1 $project_2]
[local_radio_select "Customer" "customer_id" "customer_name" $project_1 $project_2]
[local_radio_select "Project Type" "project_type_id" "project_type" $project_1 $project_2]
[local_radio_select "Project Status" "project_status_id" "project_status" $project_1 $project_2]
[local_radio_select "Project Leader" "project_lead_id" "project_lead" $project_1 $project_2]
[local_radio_select "Project Supervisor" "supervisor_id" "supervisor" $project_1 $project_2]
[local_radio_select "Project Billing Type" "billable_type_id" "billable_type" $project_1 $project_2]
[local_radio_select "Start Date" "start_date" "start_date" $project_1 $project_2]
[local_radio_select "End Date" "end_date" "end_date" $project_1 $project_2]
[local_radio_select "Report Required?" "requires_report_p" "pretty_req_report" $project_1 $project_2]

</table>

<p> 
<table border>
<tr> <th></th> <th>[ns_set get $project_1 short_name]</th> <th>[ns_set get $project_2 short_name]</th> <th>Both Projects</th> </tr>

<tr> <td><b>Payments for the Merged Project</b></td>
 <td><input type=radio name=payments_select value=\"project_1\"></td>
 <td><input type=radio name=payments_select value=\"project_2\"></td>
 <td><input type=radio name=payments_select value=\"both\" CHECKED></td>
</tr>

<tr> <td><b>Hours for the Merged Project</b></td>
 <td><input type=radio name=hours_select value=\"project_1\"></td>
 <td><input type=radio name=hours_select value=\"project_2\"></td>
 <td><input type=radio name=hours_select value=\"both\" CHECKED></td>
</tr>

<tr> <td><b>Notes for the Merged Project</b></td>
 <td><input type=radio name=notes_select value=\"project_1\"></td>
 <td><input type=radio name=notes_select value=\"project_2\"></td>
 <td><input type=radio name=notes_select value=\"both\" CHECKED></td>
</tr>

</table>
<p>
<hr>
<h4>Enter a description for the project. (Prefilled with those of the old projects.)</h4>
<textarea name=description rows=8 cols=60>
===========================================
[ns_set get $project_1 short_name]:
===========================================
[ns_set get $project_1 description]

===========================================
[ns_set get $project_2 short_name]:
===========================================
[ns_set get $project_2 description]

>>>>(Or enter new description here.)
</textarea>

<center>
<input type=submit value=\"Merge\">
</center>
</form>
"

db_release_unused_handles
doc_return 200 text/html [im_return_template]
