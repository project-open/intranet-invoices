# /www/intranet/projects/search.tcl

ad_page_contract {
    searches through intranet projects 

    @param keywords keywords to search for
    @param target the page the see the search results

    @author mbryzek@arsdigita.com
    @creation-date Sat May 20 23:11:34 2000

    @cvs-id search.tcl,v 3.3.2.10 2000/09/22 01:38:45 kevin Exp
} {
    { keywords "" }
    { target "" }
}


if { [empty_string_p keywords] } {
    # Show all employees
    ad_returnredirect index
    return
}

if { [empty_string_p $target] } {
    set target "view"
}

# Get target ready to use
if { [regexp {\?} $target] } {
    append target "&"
} else {
    append target "?"
}

set upper_keywords [string toupper [string trim $keywords]]
# Convert * to oracle wild card
regsub -all {\*} $upper_keywords {%} upper_keywords

append upper_keywords "%"
set upper_keywords "%$upper_keywords"

set columns_to_search [list ug.group_name p.description \
	u.last_name u.first_names u.last_name u.email \
	uc.aim_screen_name u.screen_name]

set query_against ""
foreach col $columns_to_search {
    if { ![empty_string_p $query_against] } {
	append query_against "||' '||"
    }
    append query_against "upper($col)"
}

# Search all projects
set sql \
        "select ug.group_id, ug.group_name
           from im_projects p, user_groups ug, users_active u, users_contact uc
          where ug.group_id = p.group_id
            and p.project_lead_id = u.user_id(+)
            and u.user_id = uc.user_id(+)
            and $query_against like :upper_keywords
          order by lower(ug.group_name)"


set number 0
set results ""
set last_employee_p ""

db_foreach projects_group_info_query $sql {
    incr number    
    append results "  <li> <a href=$target[export_url_vars group_id]>$group_name</a>\n"
}

db_release_unused_handles

if { [empty_string_p $results] } {
    set page_body "
<blockquote>
<b>No projects found.</b><p>
Browse all <a href=index?mine_p=f>projects</a>
</blockquote>
"
} else {
    append results "</ul>\n"
    set page_body "
<b>[util_commify_number $number] [util_decode $number 1 "project was" "projects were"] found</b>
<ul>
$results
</ul>

"
}

set page_title "Project Search"
set context_bar [ad_context_bar_ws [list ./ "Projects"] Search]

doc_return  200 text/html [im_return_template]
