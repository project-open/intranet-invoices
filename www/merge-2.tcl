# /www/intranet/projects/merge-2.tcl

ad_page_contract {
    
    Merges the two specified groups

    @param merge_group_id_1 First project to merge
    @param merge_group_id_2 Second project to merge
    @param payments_select  Whether the payments of the new project be that of the first, the second, or both
    @param hours_select     Whether the hours of the new project be that of the first, the second, or both
    @param notes_select     Whether the notes of the new project be that of the first, the second, or both
    @param project_name
    @param short_name
    @param parent_id
    @param customer_id
    @param project_type_id
    @param project_status_id
    @param project_lead_id
    @param supervisor_id
    @param start_date
    @param end_date
    @param requires_report_p
    @param description 
    @param billable_type_id

    @author Yulin Li (stvliexp@arsdigita.com)
    @creation-date August 2000
    @cvs-id merge-2.tcl,v 3.3.2.2 2000/09/16 19:08:48 kevin Exp
} {
    merge_group_id_1:naturalnum,notnull
    merge_group_id_2:naturalnum,notnull
    payments_select
    hours_select
    notes_select
    project_name
    short_name
    { parent_id:naturalnum "" }
    { customer_id:naturalnum "" }
    { project_type_id:naturalnum "" }
    { project_status_id:naturalnum "" }
    { project_lead_id:naturalnum "" }
    { supervisor_id:naturalnum "" }
    { start_date "" }
    { end_date "" }
    { requires_report_p "" }
    { description "" }
    { billable_type_id:naturalnum "" }
}

################## proc local_field_update_clause ######################################
proc local_field_update_clause { field_name } {
    upvar $field_name field_value

    if { [empty_string_p $field_value] } {
	return "$field_name = null"
    } else {
	return "$field_name = :$field_name"
    }
}

################ proc local_set_payments ##############################################
proc local_set_payments { opt merge_group_id_1 merge_group_id_2 } {
    ## have to delete rows from the audit tables below to avoid referential integrity constraint violations
    switch $opt {
	"both" { 
#by jruiz 20010529: these table doesn't exist, but casex exists.

	    db_dml payments_update \
		    "update im_project_payments set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"
	    db_dml payments_audit_update \
		    "update im_project_payments_audit set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"

	    db_dml casex_input_update \
		    "update casex_input set project = :merge_group_id_1 where project = :merge_group_id_2"
	    db_dml casex_audit_update \
                    "update casex_audit set project = :merge_group_id_1 where project = :merge_group_id_2"


#	    db_dml payments_receivable_update \
		    "update im_project_payments_receivable set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"
#	    db_dml payments_receivable_update_2 \
		    "update im_project_payments_received set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"
#	    db_dml bills_audit_update \
		    "update im_proj_pay_bills_audit set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"
#	    db_dml payments_audit_update_2 \
		    "update im_proj_pay_payments_audit set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"   
	}

	"project_1" {
	    db_dml delete_payment "delete from im_project_payments where group_id = :merge_group_id_2"
	    db_dml delete_payment_audit "delete from im_project_payments_audit where group_id = :merge_group_id_2"

	    db_dml delete_payment_receivable "delete from im_project_payments_receivable where group_id = :merge_group_id_2"
	    db_dml delete_payment_received "delete from im_project_payments_received where group_id = :merge_group_id_2"
	    db_dml delete_bills_audit "delete from im_proj_pay_bills_audit where group_id = :merge_group_id_2"
	    db_dml delete_payment_audit_2 "delete from im_proj_pay_payments_audit where group_id = :merge_group_id_2"
	}

	"project_2" {
	    local_set_payments "project_1" $merge_group_id_2 $merge_group_id_1
	    local_set_payments "both" $merge_group_id_1 $merge_group_id_2
	}
    }
}


################ local_proc set_hours ##############################################
proc local_set_hours { opt merge_group_id_1 merge_group_id_2 } {
    switch $opt {
	"both" {
	    db_dml hours_update "update im_hours h1 set on_what_id = :merge_group_id_1 
                    where on_which_table = 'im_projects' 
                      and on_what_id = :merge_group_id_2
                      and not exists (select * from im_hours h2 where h1.user_id = h2.user_id 
                                                                 and h2.on_which_table = 'im_projects'
                                                                 and h2.on_what_id = :merge_group_id_1
                                                                 and h1.day = h2.day)" 
	
	    db_dml hours_delete "delete from im_hours where on_which_table = 'im_projects' and on_what_id = :merge_group_id_2"
	}

	"project_1" {
	    db_dml hours_delete_1 "delete from im_hours where on_which_table = 'im_projects' and on_what_id = :merge_group_id_2"
	}

	"project_2" {
	    db_dml hours_delete_2 "delete from im_hours where on_which_table = 'im_projects' and on_what_id = :merge_group_id_1"
	    
	    db_dml hours_update_1 "update im_hours set on_what_id = :merge_group_id_1 
                    where on_which_table = 'im_projects' 
                      and on_what_id = :merge_group_id_2"
	}
    }
}


################ proc local_set_notes ##############################################
proc local_set_notes { opt merge_group_id_1 merge_group_id_2 } {
    switch $opt {
	"both" {
	    db_dml comments_update "update general_comments set group_id = :merge_group_id_1, on_what_id = :merge_group_id_1 
                    where group_id = :merge_group_id_2"
	}

	"project_1" {
	    db_dml comments_delete "delete from general_comments where group_id = :merge_group_id_2"
	}

	"project_2" {
	    local_set_notes "project_1" $merge_group_id_2 $merge_group_id_1
	    local_set_notes "both" $merge_group_id_1 $merge_group_id_2
	}
    }
}



######################### Script Starts ######################################
set update_clause_im_projects [list \
	[local_field_update_clause "parent_id"] \
	[local_field_update_clause "customer_id"] \
	[local_field_update_clause "project_type_id"] \
	[local_field_update_clause "project_status_id"] \
	[local_field_update_clause "project_lead_id"] \
	[local_field_update_clause "supervisor_id"] \
	[local_field_update_clause "start_date"] \
	[local_field_update_clause "end_date"] \
	[local_field_update_clause "requires_report_p"] \
	[local_field_update_clause "description"] \
        [local_field_update_clause "billable_type_id"]]


db_transaction {
    ## make project 1 the parent of all of the subprojects of project 2
    db_dml projects_update "update im_projects set parent_id = :merge_group_id_1 where parent_id = :merge_group_id_2"

    ## update/delete records in "im_*" tables

    # set the new allocations records for the merged project to include both of the old projects
    db_dml allocations_update \
	    "update im_allocations set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"
    db_dml allocations_audit_update \
	    "update im_allocations_audit set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"    

    # merge the project payments records
    local_set_payments $payments_select $merge_group_id_1 $merge_group_id_2

    # merge the project hour logs
    local_set_hours $hours_select $merge_group_id_1 $merge_group_id_2
    
    # update urls
    set form [ns_getform]
    set form_size [ns_set size $form]
    set form_counter_i 0
    while { $form_counter_i < $form_size } {
	set variable [ns_set key $form $form_counter_i]
	set value [ns_set value $form $form_counter_i]
	
	incr form_counter_i
    }


    ## update/delete records in non "im_*" tables 
    # merge the project notes
    local_set_notes $notes_select $merge_group_id_1 $merge_group_id_2

    db_dml content_sections_delete "delete from content_sections where group_id = :merge_group_id_2"
    
    db_dml user_group_map_update "update user_group_map u1 set group_id = :merge_group_id_1 
            where group_id = :merge_group_id_2
              and not exists (select * from user_group_map u2 where u1.user_id = u2.user_id 
                                                               and u1.role = u2.role and u2.group_id = :merge_group_id_1)"
    db_dml user_group_map_delete "delete from user_group_map where group_id = :merge_group_id_2"

    db_dml survsimp_responses_update "update survsimp_responses set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"
    db_dml general_permissions_update "update general_permissions set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"

    db_dml ticket_projects_update "update ticket_projects set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"
    db_dml ticket_domains_update "update ticket_domains set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"  
    db_dml newsgroups_update "update newsgroups set group_id = :merge_group_id_1 where group_id = :merge_group_id_2"  
    db_dml events_activities_update "update events_activities set group_id = :merge_group_id_1 where group_id = :merge_group_id_2" 
#    db_dml downtime_group_map_update "update downtime_group_map set group_id = :merge_group_id_1 where group_id = :merge_group_id_2" 
    db_dml group_spam_history_update "update group_spam_history set group_id = :merge_group_id_1 where group_id = :merge_group_id_2" 
#    db_dml project_intranet_group_map_update "update dt_project_intranet_group_map set intranet_group_id = :merge_group_id_1 where intranet_group_id = :merge_group_id_2" 
    db_dml fs_files_update "update fs_files set group_id = :merge_group_id_1 where group_id = :merge_group_id_2" 
    db_dml bboard_topics_update "update bboard_topics set group_id = :merge_group_id_1 where group_id = :merge_group_id_2" 

    ## delete project 2
    db_dml im_projects_delete "delete from im_projects where group_id = :merge_group_id_2"
    db_dml user_groups_delete "delete from user_groups where group_id = :merge_group_id_2"


    ## make project 1 the merged project
    db_dml im_projects_update "update im_projects
            set [join $update_clause_im_projects ", "]
            where group_id = :merge_group_id_1"

    db_dml user_groups_update "update user_groups
            set group_name = :project_name,
                short_name = :short_name
            where group_id = :merge_group_id_1"
} on_error {
    ad_return_error "Transaction Problem" "<li>There are problems with your database transaction. Merge aborted."
}

db_release_unused_handles
ns_returnredirect index



