# /www/intranet/projects/edit-customer-data-2.tcl

ad_page_contract {
    Purpose: verifies and stores project information to db

    @param return_url the url to return to
    @param group_id group id
} {
    return_url:optional
    group_id:integer
    customer_project_nr:optional
    final_customer:optional
    customer_contact_id:integer,optional
    expected_quality_id:integer,optional
}

set user_id [ad_maybe_redirect_for_registration]

set sql "
update im_projects set
"
if {[exists_and_not_null final_customer]} {
    append sql "final_customer=:final_customer,\n"
}
if {[exists_and_not_null customer_project_nr]} {
    append sql "customer_project_nr=:customer_project_nr,\n"
}
if {[exists_and_not_null customer_contact_id]} {
    append sql "customer_contact_id=:customer_contact_id,\n"
}
if {[exists_and_not_null expected_quality_id]} {
    append sql "expected_quality_id=:expected_quality_id,\n"
}
append sql "group_id=:group_id
where group_id=:group_id
"

db_transaction {
    db_dml update_im_projects $sql
}
db_release_unused_handles

if { ![exists_and_not_null return_url] } {
    set return_url "[im_url_stub]/projects/view?[export_url_vars group_id]"
}

ad_returnredirect $return_url




