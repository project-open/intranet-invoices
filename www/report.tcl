# /www/intranet/projects/report.tcl

ad_page_contract {
    List all hours in a projects-employees matrix.

    @param from_date
    @param to_date

    @author jruiz@competitiveness.com
} {

    from_date:array,date
    to_date:array,date 
}

# User id already verified by filters
set user_id [ad_get_user_id]

set sql "select email, im.user_id as id_of_user
                from im_hours im, users u
                where im.user_id = u.user_id
                and im.day between to_date('$from_date(date)') and to_date('$to_date(date)')
                group by email, im.user_id
                order by email"

set sql2 "select group_name, on_what_id
                from im_hours im, user_groups ug, im_projects ip
                where im.on_what_id = ug.group_id
                and im.day between to_date('$from_date(date)') and to_date('$to_date(date)')
                group by group_name, on_what_id
                order by on_what_id"

set file_stream [open [ns_info pageroot]/intranet/projects/report.csv w+]

ns_log Notice "--------------------------> $file_stream, [ns_info pageroot]"

set list_of_users [list]

set page_content "
[ad_header "Excel hour report"]
<h2>Excel hour report</h2>

<hr>
[ad_context_bar_ws_or_index "hour report"]

<table border=1 cellpadding=2>
<tr><td></td>"

puts -nonewline $file_stream " ;"

db_foreach mi_etiqueta $sql {
    regsub {@[^ ]+} $email "" email 
    append page_content "<td>$email</td>"
    puts -nonewline $file_stream "$email;"
    lappend list_of_users $id_of_user
} 

puts $file_stream ""

db_foreach mi_etiqueta $sql2 {

    if { [db_0or1row mi_etiqueta "select parent_id from im_projects where group_id = :on_what_id"] } {
	if { ![empty_string_p $parent_id] } {
	    set group_name "  -- $group_name"
	}
    }
    append page_content "<tr><td bgcolor=#ffffff>$group_name</td>"
    puts -nonewline $file_stream "$group_name;"

    foreach id $list_of_users {
	set sql_query "select email, sum(im.hours) as horas
               from im_hours im, users u
               where im.user_id = u.user_id
	       and im.user_id = :id
               and im.on_what_id = :on_what_id
               and im.day between to_date('$from_date(date)') and to_date('$to_date(date)')
               group by email
               order by email"

	if { [db_0or1row mi_etiqueta $sql_query] } { 
	    regsub {[.]} $horas "," horas
	    append page_content "<td>$horas</td>"
	    puts -nonewline $file_stream "$horas;"
	} else {
	    append page_content "<td></td>"
	    puts -nonewline $file_stream " ;"
	}
	 
    }
    puts $file_stream ""
}

append page_content "<br><br><a href=\"report.csv\">Click me for download the report.csv file.</a>
                     </table><br><br>[ad_footer]"

ns_return 200 text/html $page_content

