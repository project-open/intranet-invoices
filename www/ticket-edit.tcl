# /www/intranet/projects/ticket-edit.tcl

ad_page_contract {
    Purpose: sets up environment to edit a ticket tracker project without being in the ticket admin group
    @param group_id group id

    @author berkeley@arsdigita.com
    @creation-date Tue Jul 11 16:27:18 2000
    @cvs-id ticket-edit.tcl,v 3.3.2.8 2000/08/16 21:25:01 mbryzek Exp

} {
    group_id:integer
   
}

set form_setid [ns_getform]

set selection [db_1row projects_group_name "select group_name from user_groups where group_id=:group_id"]

db_release_unused_handles

ns_set put $form_setid target "[im_url_stub]/projects/ticket-edit-2"
ns_set put $form_setid owning_group_id $group_id
ns_set put $form_setid preset_title $group_name
ns_set put $form_setid preset_title_long $group_name
ns_set put $form_setid return_url "[im_url]/projects/view?[export_url_vars group_id]"

source "[ns_info pageroot]/ticket/admin/project-edit.tcl"




