# /www/intranet/projects/import-project-txt.tcl

ad_page_contract {
    @author fraber@fraber.de
    @creation-date July 2003
} {
    { return_url "/intranet/" }
}

set user_id [ad_maybe_redirect_for_registration]
set todays_date [db_string projects_get_date "select sysdate from dual"]
set base_path_unix [ad_parameter "ProjectBasePathUnix" intranet "/tmp/"]
set context_bar [ad_context_bar_ws "Import Projects"]
set page_body "<PRE>\n"

set sql "
select
	c.group_id as customer_id,
	cg.short_name as customer_short_name
from
	im_customers c,
	user_groups cg
where
	c.group_id=cg.group_id
"

db_foreach customer_project_import $sql  {
    set customer_path "$base_path_unix/$customer_short_name"
    append page_body "customer_path=$customer_path\n"
    if {![file exists $customer_path]} {
	# Cancel importing projects for a customer that doesn't exist
	continue
    }

    # Get the list of all projects for this customer
    if { [catch {
	set project_list [exec /usr/bin/find $customer_path -maxdepth 1]
    } err_msg] } {
	# Permission error or something similar
	append page_body "\n$err_msg\n"
    }

    set customer_path_comps [split $customer_path "/"]
    foreach project_dir $project_list {
	append page_body "	project_dir=$project_dir\n"

	set path_comps [split $project_dir "/"]
	if {[llength $customer_path_comps] == [llength $path_comps]} {
	    # First element of a find: the path itself
	    continue
	}
	set project_short_name [lindex $path_comps [expr [llength $path_comps] - 1]]
	append page_body "	project_short_name=$project_short_name\n"
	
	# Check that the project_short_name is well build:
	if {![regexp {[0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9]} $project_short_name match]} {
	    set err_msg "A bad project short name has been found: $project_short_name"
	    append page_body "\n$err_msg\n"
	}

	# Check if the project already exists
	set short_name_count [db_string short_name_taken "
select count(*) 
from 
	im_projects p, 
	user_groups ug 
where 
	p.group_id=ug.group_id 
	and ug.short_name=:project_short_name
"]
	if {$short_name_count > 0} {
	append page_body "	$project_short_name already exists\n"
	    continue
	}

	# At this point we have found a new project for the current customer
	# Now check for "project.txt" and let's import the values
	if { [catch {
	    set project_txt_list [exec /usr/bin/find $project_dir -name project.txt]
	} err_msg] } {
	    # Permission error or something similar
	    append page_body "\n$err_msg\n"
	}
	append page_body "	project_txt_list=$project_txt_list\n"
	if {[llength $project_txt_list] == 0} {
	    set err_msg "Didn't find a 'project.txt' in $project_dir"
	    append page_body "\n$err_msg\n"
	}
	if {[llength $project_txt_list] > 1} {
	    set err_msg "Found several 'project.txt' in $project_dir: <BR>
	                $project_txt_list"
	    append page_body "\n$err_msg\n"
	}

	set project_txt [lindex $project_txt_list 0]
	# We have found a single 'project.txt' for the project
	if { [catch {
	    set project_txt_content [exec /bin/cat $project_txt]
	} err_msg] } {
	    # Permission error or something similar
	    append page_body "\n$err_msg\n"
	}

	set project_txt_lines [split $project_txt_content "\n"]

	set name ""
	set final_user ""
	set start_date ""
	set end_date ""
	set source_language ""
	set source_language_id ""
	set target_language ""
	set client_project_number ""
	set expected_quality ""
	set project_status ""
	set project_type ""

	foreach line1 $project_txt_lines {
	    set line [string trim $line1]
	    if {[regexp {^#} $line match]} {
		# we have found a comment line
		continue
	    }
	    if {[regexp {^([a-zA-Z0-9_]*)=(.*)} $line match key value]} {
		# we have found a comment line
		append page_body "		'$key' = '$value'\n"

		set cmd {set $key $value}
		eval $cmd
	    }
	}
	
	# We have now set all required environment variables
	# We can now insert the project into the database

	set project_leader_id "5"
	set project_supervisor_id "4"
	set group_id [db_nextval "user_group_sequence"]

	set source_language_id ""
	append page_body "		source_language=$source_language\n"
	if { [catch {
	    set source_language_id [db_string get_source_lang "select category_id from categories where category=:source_language"]
	} err_msg] } {
	    # Permission error or something similar
	    append page_body "\n$err_msg\n"
	}


	# get the "project_group_id in case the group was created the
	# last time that this script ran
	set project_group_id ""
	if { [catch {
		set project_group_id [db_string get_project_group_id "
select group_id from user_groups where short_name=:project_short_name"]
	} err_msg] } {
	    # The project group doesn't exist yet. Let's create it:

	    append page_body  "INSERT INTO user_groups VALUES (
	$group_id,'intranet',$name,$project_short_name,
	'root@localhost',sysdate,$user_id,'0.0.0.0','t','t',
	'f','closed','open','f','f','f','f',null,'f',sysdate,
	$user_id,7)\n"
	
	    set sql "
INSERT INTO user_groups VALUES (
	:group_id,
	'intranet',
	:name,
	:project_short_name,
	'root@localhost',
	sysdate,
	:user_id,
	'0.0.0.0',
	't','t','f','closed','open','f','f','f','f',null,'f',sysdate,
	:user_id,
	7
)"

	    if { [catch {
		db_dml insert_ug_project $sql
	    } err_msg] } {
		append page_body "\n$err_msg\n"
	    }
	    set project_group_id [db_string get_project_group_id "
select group_id from user_groups where short_name=:project_short_name"]

	}
        append page_body "		project_group_id=$project_group_id\n"

        append page_body  "INSERT INTO im_projects VALUES (
        $customer_id,$project_type,$project_status,$project_leader_id, 
	$project_supervisor_id,'', '',$name,'f',$start_date,$end_date,
	$project_group_id,$final_user,$source_language_id,$expected_quality,
        $client_project_number
)\n"


	set sql "
INSERT INTO im_projects (
        customer_id, project_type_id, project_status_id, project_lead_id,
	supervisor_id, parent_id, project_budget, description, 
	requires_report_p, start_date, end_date, group_id,
        final_customer, source_language_id, expected_quality_id,
        customer_project_nr
) VALUES (
        :customer_id,
	:project_type,
	:project_status, 
	:project_leader_id, 
	:project_supervisor_id,
	'', '',
	:name,
	'f',
	:start_date,
	:end_date,
	:project_group_id,
	:final_user,
        :source_language_id,
	:expected_quality,
	:client_project_number
)"
	if { [catch {
	    db_dml insert_project_project $sql
	} err_msg] } {
	    append page_body "\n$err_msg\n"
	}

	set sql "
INSERT INTO user_group_map VALUES (:project_group_id, :project_leader_id, 'administrator', sysdate, 1, '0,0,0,0')"
	if { [catch {
	    db_dml insert_leader $sql
	} err_msg] } {
	    append page_body "\n$err_msg\n"
	}

	set sql "
INSERT INTO user_group_map VALUES (:project_group_id, :project_supervisor_id, 'administrator', sysdate, 1, '0,0,0,0')"
	if { [catch {
	    db_dml insert_supervisor $sql
	} err_msg] } {
	    append page_body "\n$err_msg\n"
	}
    }
}

append page_body "\n</PRE>\n"

doc_return  200 text/html [im_return_template]
