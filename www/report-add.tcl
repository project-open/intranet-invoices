# /www/intranet/projects/report-add.tcl

ad_page_contract {

    Purpose: temporary file to redirect to general comments until we get structured project reports.
    @param group_id group id
    @param return_url the url to return to
    @author mbryzek@arsdigita.com
    @creation-date Tue Jul 11 15:09:09 2000
    @cvs-id report-add.tcl,v 3.9.2.6 2000/08/16 21:25:01 mbryzek Exp

} {
    group_id:naturalnum,notnull
    return_url:optional
}

set item [db_string projects_group_name_query "select group_name from user_groups
where group_id = :group_id"]

set project_type [db_string projects_type_query "select im_category_from_id(project_type_id)
from im_projects
where group_id = :group_id"]

if {![info exist return_url]} {
    set return_url "/intranet/projects/view?[export_url_vars group_id]"
}

set survey_short_name ""
# figure out if this type of project is in the list
foreach type_survey_pair  [ad_parameter_all_values_as_list ProjectReportTypeSurveyNamePair intranet] {
    set type_survey_list [split $type_survey_pair ","]
    set type [lindex $type_survey_list 0]
    set survey [lindex $type_survey_list 1]
    if {[string tolower $project_type] == [string tolower $type]} {
	set survey_short_name $survey
    }
}

if { ![empty_string_p $survey_short_name] } {
    set survey_id [db_string projects_survey_id_query \
	    "select survey_id 
               from survsimp_surveys
              where short_name=:survey_short_name"  -default ""]
    if { [empty_string_p $survey_id] } {
	ns_log error "report-add: Survey named \"$survey_short_name\" could not be found. Defaulting to simple project report"
    } else {
	ad_returnredirect "/survsimp/one?[export_url_vars survey_id group_id return_url]"
	return
    }
}

db_release_unused_handles

ad_returnredirect "/general-comments/comment-add?on_which_table=user_groups&on_what_id=$group_id&module=intranet&[export_url_vars return_url item]&scope=group&group_id=$group_id"
