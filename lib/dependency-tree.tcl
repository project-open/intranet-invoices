# Shows a depencency graph for this specific financial document
#
# Expected variables:
# invoice_id

# project_id set by portlet TCL
if {![info exists invoice_id]} {
    ad_page_contract {} {invoice_id:integer ""}
}

set filter_invoice_id $invoice_id
# ad_return_complaint 1 "dependency-tree: invoice_id=$filter_invoice_id"

set current_user_id [auth::require_login]
im_invoice_permissions $current_user_id $filter_invoice_id view_p read_p write_p admin_p
if {!$read_p} {
    ad_return_complaint 1 "You don't have read permissions to see this portlet"
    ad_script_abort
}

set invoice_base_url "/intranet-invoices/view"

# -------------------------------------------------------------
# Main project
# -------------------------------------------------------------

set main_project_id [db_list pids "
	select	main_p.project_id
	from	acs_rels r,
		im_projects p,
		im_projects main_p
	where	r.object_id_two = :filter_invoice_id and
		p.project_id = r.object_id_one and
		main_p.tree_sortkey = tree_root_key(p.tree_sortkey);
"]

# ad_return_complaint 1 $main_project_id


# -------------------------------------------------------------
# Get info about all financial documents of the project
# -------------------------------------------------------------

set costs_sql "
    select	cost_id, item_id, cost_name, cost_nr, cost_type_id, cost_status_id, item_source_invoice_id,
    		cost_amount, cost_currency,
    		CASE WHEN item_source_invoice_id = cost_id THEN null ELSE item_source_invoice_id END as source_id
    from 	(
	select	c.*,
		c.amount as cost_amount,
		c.currency as cost_currency,
		i.*,
		ii.*
	from	im_projects p,
		im_projects main_p,
		im_costs c
		LEFT OUTER JOIN im_invoices i ON (c.cost_id = i.invoice_id)
		LEFT OUTER JOIN im_invoice_items ii ON (c.cost_id = ii.invoice_id)
	where	main_p.project_id = :main_project_id and
		p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
		c.project_id = p.project_id and
		c.cost_type_id not in (3714, 3718, 3720, 3722, 3726, 3736, 73102)
    UNION
	select	c.*,
		c.amount as cost_amount,
		c.currency as cost_currency,
		i.*,
		ii.*
	from	im_projects p,
		im_projects main_p,
		acs_rels r,
		im_costs c
		LEFT OUTER JOIN im_invoices i ON (c.cost_id = i.invoice_id)
		LEFT OUTER JOIN im_invoice_items ii ON (c.cost_id = ii.invoice_id)
	where	main_p.project_id = :main_project_id and
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
    set amount_hash($cost_id) "$cost_amount $cost_currency"

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
while {[llength $list] > 0 && $cnt < 10} {
    incr cnt

    set id [lindex $list 0]
    ns_log Notice "dep: predecessors: list='$list', id='$id', len=[llength $list]"
    set list [lreplace $list 0 0]

    if {$id != $filter_invoice_id} {
        incr predecessor_num
        set url [export_vars -base $invoice_base_url {{invoice_id $id}}]
        append predecessor_html "<tr>
          <td><a href=$url>$name_hash($id)</a></td>
          <td>$amount_hash($id)</td>
          <td>[im_category_from_id $type_hash($id)]</td>
          <td>[im_category_from_id $status_hash($id)]</td>
          </tr>\n
        "
    }

    set predecessors {}
    if {[info exists predecessor_hash($id)]} { set predecessors $predecessor_hash($id) }
    ns_log Notice "dep: predecessors = $predecessors"
    array unset hash
    array set hash $predecessors

    foreach id [array names hash] {
        set list [lappend $list $id]
    }

}



# -------------------------------------------------------------
# Show successors
# -------------------------------------------------------------

set list [list $filter_invoice_id]
set cnt 0
set successor_html ""
set successor_num 0
while {[llength $list] > 0 && $cnt < 100} {
    incr cnt

    set id [lindex $list 0]
    ns_log Notice "dep: successors: list='$list', id='$id', len=[llength $list]"
    set list [lreplace $list 0 0]

    if {$id != $filter_invoice_id} {
        incr successor_num
        set url [export_vars -base $invoice_base_url {{invoice_id $id}}]
        append successor_html "<tr>
          <td><a href=$url>$name_hash($id)</a></td>
          <td>$amount_hash($id)</td>
          <td>[im_category_from_id $type_hash($id)]</td>
          <td>[im_category_from_id $status_hash($id)]</td>
          </tr>\n
        "
    }

    set successors {}
    if {[info exists successor_hash($id)]} { set successors $successor_hash($id) }
    ns_log Notice "dep: successors = $successors"
    array unset hash
    array set hash $successors

    foreach id [array names hash] {
        ns_log Notice "dep: successors: id = $id"
	lappend list $id
        ns_log Notice "dep: successors: list = $list"
    }

}


# -------------------------------------------------------------
# 
# -------------------------------------------------------------


if {"" eq $predecessor_html} { set predecessor_html "<tr><td colspan=99>No predecessors found</td></tr>" }
if {"" eq $successor_html} { set successor_html "<tr><td colspan=99>No successors found</td></tr>" }


set html "
<table><tr valign=top>
<td width='70%'>
<table cellspaing=2 cellpadding=2>
<tr>
	<td class=rowtitle>Name</td>
	<td class=rowtitle>Amount</td>
	<td class=rowtitle>Type</td>
	<td class=rowtitle>Status</td>
</tr>
<tr><td colspan=99><h1>Predecessors</h1></td></tr>
$predecessor_html
<tr><td colspan=99><h1>Successors</h1></td></tr>
$successor_html
</table>
</td>
<td width='30%'>
	<p>This portlet shows predecessors (= financial documents from which this document was created)
	and successors (= financial documents created based on this one).</p>
</td>
</td></table>
"


if {[expr $predecessor_num + $successor_num] < 1} { set html "" }
