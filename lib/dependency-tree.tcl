# Shows a depencency graph for this specific financial document
#
# Expected variables:
# invoice_id

# Try behaving like a page if not called as a portlet (may not work yet)
if {![info exists invoice_id]} {
    ad_page_contract {} {invoice_id:integer ""}
}

set current_user_id [auth::require_login]
set filter_invoice_id $invoice_id
set default_currency [im_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set invoice_base_url "/intranet-invoices/view"
# ad_return_complaint 1 "dependency-tree: invoice_id=$filter_invoice_id"

im_invoice_permissions $current_user_id $filter_invoice_id view_p read_p write_p admin_p
if {!$read_p} {
    ad_return_complaint 1 "You don't have read permissions to see this portlet"
    ad_script_abort
}

# Check if the calling page (invoices/view?invoice_id=123) has a locale set
set locale [uplevel 2 {if {[info exists locale]} { set locale }}]
if {"" eq $locale} { 
    set locale [lang::user::locale]
}

# -------------------------------------------------------------
# Sort a list of invoice_ids according to invoice name
# -------------------------------------------------------------

ad_proc im_invoice_dependency_tree_sort_invoices {
    list
    name_hash_list
} {
    Sort a list of invoice_ids according to invoice name
    (or whatever array provided in 2nd argument)
} {
    array set name_hash $name_hash_list
    # ad_return_complaint 1 $name_hash_list

    set slist [list]
    foreach l $list {
	lappend slist [list $name_hash($l) $l]
    }

    set slist [lsort $slist]

    set list [list]
    foreach l $slist {
	lappend list [lindex $l 1]
    }
    
    return $list
}


# -------------------------------------------------------------
# Main project
# -------------------------------------------------------------

set main_project_ids [db_list pids "
	select	main_p.project_id
	from	acs_rels r,
		im_projects p,
		im_projects main_p
	where	r.object_id_two = :filter_invoice_id and
		p.project_id = r.object_id_one and
		main_p.tree_sortkey = tree_root_key(p.tree_sortkey);
"]
lappend main_project_ids 0

# -------------------------------------------------------------
# Get info about all financial documents of the project
# -------------------------------------------------------------

set costs_sql "
    select	cost_id, item_id, cost_name, cost_nr, cost_type_id, cost_status_id, item_source_invoice_id,
    		coalesce(cost_amount, 0.0) as cost_amount, cost_currency, cost_amount_converted,
    		CASE WHEN item_source_invoice_id = cost_id THEN null ELSE item_source_invoice_id END as source_id
    from 	(
	select	c.*,
		c.amount as cost_amount,
		c.currency as cost_currency,
	        round(c.amount * im_exchange_rate(c.effective_date::date, c.currency, :default_currency)::numeric, 2) as cost_amount_converted,
		i.*,
		ii.*
	from	im_projects p,
		im_projects main_p,
		im_costs c
		LEFT OUTER JOIN im_invoices i ON (c.cost_id = i.invoice_id)
		LEFT OUTER JOIN im_invoice_items ii ON (c.cost_id = ii.invoice_id)
	where	main_p.project_id in ([join $main_project_ids ","]) and
		p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
		c.project_id = p.project_id and
		c.cost_type_id not in (3714, 3718, 3720, 3722, 3726, 3736, 73102)
    UNION
	select	c.*,
		coalesce(c.amount, 0.0) as cost_amount,
		c.currency as cost_currency,
	        round(c.amount * im_exchange_rate(c.effective_date::date, c.currency, :default_currency)::numeric, 2) as cost_amount_converted,
		i.*,
		ii.*
	from	im_projects p,
		im_projects main_p,
		acs_rels r,
		im_costs c
		LEFT OUTER JOIN im_invoices i ON (c.cost_id = i.invoice_id)
		LEFT OUTER JOIN im_invoice_items ii ON (c.cost_id = ii.invoice_id)
	where	main_p.project_id in ([join $main_project_ids ","]) and
		p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
		r.object_id_one = p.project_id and
		r.object_id_two = c.cost_id and
		c.cost_type_id not in (3714, 3718, 3720, 3722, 3726, 3736, 73102)
    ) t 
    order by cost_type_id, cost_id, item_id
"
# ad_return_complaint 1 [im_ad_hoc_query -format html $costs_sql]
set debug_html "<table>"

# predecessor_hash: For every cost_id the list of predecessor documents
# successor_hash: for every cost_id the list of succeeding documents
db_foreach costs $costs_sql { 

    ns_log Notice "dep: cost_id=$cost_id, name=$cost_name, source_id=$source_id"

    set name_hash($cost_id) $cost_name
    set type_hash($cost_id) $cost_type_id
    set status_hash($cost_id) $cost_status_id
    set amount_hash($cost_id) $cost_amount_converted
    set amount_formatted_hash($cost_id) "[lc_numeric $cost_amount "%.2f" $locale] $cost_currency"

    if {"" ne $source_id} {
        set predecessors {}
	if {[info exists predecessor_hash($cost_id)]} { set predecessors $predecessor_hash($cost_id) }
	array unset hash
	array set hash $predecessors
	set hash($source_id) $source_id
        set predecessor_hash($cost_id) [array get hash]

	set successors {}
	if {[info exists successor_hash($source_id)]} { set successors $successor_hash($source_id) }
	array unset hash
	array set hash $successors
	set hash($cost_id) $cost_id
	set successor_hash($source_id) [array get hash]
    }

    append debug_html "<tr>
	<td>id=$cost_id</td>
	<td>$cost_type_id</td>
	<td>nr=$cost_nr</td>
	<td>predecessor=$source_id</td>
    </tr>\n"

}
append debug_html "</table>"

# ad_return_complaint 1 "<br>pred=[array get predecessor_hash]<br>succ=[array get successor_hash]"
# ad_return_complaint 1 $debug_html
# ToDo: Check for any source or succsssor cost_ids that are not included in name_hash

append debug_html "<br>pred=[array get predecessor_hash]\n"
append debug_html "<br>succ=[array get successor_hash]\n"


# -------------------------------------------------------------
# Debug
# -------------------------------------------------------------

set predecessors {}
if {[info exists predecessor_hash($filter_invoice_id)]} { 
    set predecessors $predecessor_hash($filter_invoice_id) 
}
ns_log Notice "dep: id=$filter_invoice_id, predecessors = $predecessors"


set successors {}
if {[info exists successor_hash($filter_invoice_id)]} { 
    set successors $successor_hash($filter_invoice_id) 
}
ns_log Notice "dep: id=$filter_invoice_id, successors = $successors"



# -------------------------------------------------------------
# Show predecessors
# -------------------------------------------------------------

set list [list $filter_invoice_id]
set cnt 0
set predecessor_html ""
set predecessor_num 0
while {[llength $list] > 0 && $cnt < 10000} {
    incr cnt

    set id [lindex $list 0]
    ns_log Notice "dep: predecessors: list='$list', id='$id', len=[llength $list]"
    set list [lreplace $list 0 0]

    if {$id != $filter_invoice_id} {
        incr predecessor_num
        set url [export_vars -base $invoice_base_url {{invoice_id $id}}]
	if {[info exists name_hash($id)]} {
	    set name $name_hash($id)
	    set amount $amount_formatted_hash($id)
	    set type [im_category_from_id $type_hash($id)]
	    set status [im_category_from_id $status_hash($id)]
	    set link "<a href=$url>$name</a>"
	} else {
	    set url ""
	    set name "Deleted #$id"
	    set amount ""
	    set type ""
	    set status ""
	    set link $name
	}
	append predecessor_html "<tr>
          <td>$link</td>
          <td>$amount</td>
          <td>$type</td>
          <td>$status</td>
          </tr>\n
        "
    }

    set predecessors {}
    if {[info exists predecessor_hash($id)]} { set predecessors $predecessor_hash($id) }
    ns_log Notice "dep: predecessors = $predecessors"
    array unset hash
    array set hash $predecessors

    foreach id [array names hash] {
	lappend list $id
    }
    set list [im_invoice_dependency_tree_sort_invoices $list [array get name_hash]]

}



# -------------------------------------------------------------
# Show successors
# -------------------------------------------------------------

# Calculate successors recursively
set list [list $filter_invoice_id]
set cnt 0
array set successor_html_hash {}; # Hash with HTML per cost type
set successor_num 0
set successor_sum 0.0
array set successor_sum_hash {}; # Hash with sum per cost type
while {[llength $list] > 0 && $cnt < 10000} {
    incr cnt

    set id [lindex $list 0]
    ns_log Notice "dep: successors: list='$list', id='$id', len=[llength $list]"
    set list [lreplace $list 0 0]

    if {$id != $filter_invoice_id} {
        incr successor_num
        set url [export_vars -base $invoice_base_url {{invoice_id $id}}]

	if {[info exists name_hash($id)]} {
	    set name $name_hash($id)
	    set amount_formatted $amount_formatted_hash($id)
	    set type_id $type_hash($id)
	    set type [im_category_from_id $type_id]
	    set status [im_category_from_id $status_hash($id)]

	    # Sum up amounts per cost type
	    set amount $amount_hash($id)
	    if {"" eq $amount} { set amount 0.0 }
	    set successor_sum [expr $successor_sum + $amount]; # obsolete ToDo: remove
	    set s 0.0
	    if {[info exists successor_sum_hash($type_id)]} { set s $successor_sum_hash($type_id) }
	    set successor_sum_hash($type_id) [expr $s + $amount]
	} else {
	    set name "Unknown #$id"
	    set amount_formatted ""
	    set type ""
	    set status ""
	}

	set line_html "<tr>
          <td><a href=$url>$name</a></td>
          <td align=right>$amount_formatted</td>
          <td>$type</td>
          <td>$status</td>
          </tr>\n
        "

	set l ""
	if {[info exists successor_html_hash($type_id)]} { set l $successor_html_hash($type_id) }
	append l $line_html
	set successor_html_hash($type_id) $l
    }

    set successors {}
    if {[info exists successor_hash($id)]} { set successors $successor_hash($id) }
    ns_log Notice "dep: successors = $successors"
    array unset hash
    array set hash $successors

    foreach id [array names hash] {
	lappend list $id
    }
    set list [im_invoice_dependency_tree_sort_invoices $list [array get name_hash]]
}

# Display the successors per cost type
set successor_html ""
set type_ids [lsort [array names successor_html_hash]]
foreach type_id $type_ids {
    
    # Add section header if there is more than one section
    if {[llength $type_ids] > 1} {
	append successor_html "<tr><td colspan=4><h4>[im_category_from_id $type_id]</h4></td></tr>\n"
    }

    # Add the HTML fragment for type_id calculated above
    append successor_html $successor_html_hash($type_id)

    # Add sum
    set successor_sum $successor_sum_hash($type_id)
    append successor_html "
      <tr>
          <td><b>[lang::message::lookup "" intranet-core.Sum "Sum"]:</b></td>
          <td align=right><b>[lc_numeric $successor_sum "%.2f" $locale] $default_currency</b></td>
          <td></td>
          <td></td>
      </tr>\n
    "
}


# -------------------------------------------------------------
# Output HTML
# -------------------------------------------------------------

if {"" eq $predecessor_html} { set predecessor_html "<tr><td colspan=99>No predecessors found</td></tr>" }
if {"" eq $successor_html} { set successor_html "<tr><td colspan=99>No successors found</td></tr>" }

set show_html_p [expr ($predecessor_num + $successor_num) > 0]
