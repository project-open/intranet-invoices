
# project_id set by portlet TCL
if {![info exists project_id]} {
    ad_page_contract {} {project_id:integer}
}

set current_user_id [auth::require_login]
im_project_permissions $current_user_id $project_id view_p read_p write_p admin_p
if {!$read_p} {
    ad_return_complaint 1 "You don't have read permissions on #$project_id"
    ad_script_abort
}

set html [im_ad_hoc_query -format html "
	select	i.item_outline_number as outline,
		i.item_name,
		im_category_from_id(i.item_uom_id) as uom,
		(	
			select	sum(tii.item_units)
			from	im_costs tc,
				im_invoice_items tii,
				im_projects p
			where	tii.invoice_id = tc.cost_id and
				tii.item_outline_number = i.item_outline_number and
				tii.item_uom_id = i.item_uom_id and
				tc.cost_type_id = 3702 and
				tc.project_id = p.project_id and
				p.tree_sortkey between i.tree_sortkey and tree_right(i.tree_sortkey)
		) as quotes,
		(	
			select	sum(tii.item_units)
			from	im_costs tc,
				im_invoice_items tii,
				im_projects p
			where	tii.invoice_id = tc.cost_id and
				tii.item_outline_number = i.item_outline_number and
				tii.item_uom_id = i.item_uom_id and
				tc.cost_type_id = 3700 and
				tc.project_id = p.project_id and
				p.tree_sortkey between i.tree_sortkey and tree_right(i.tree_sortkey)
		) as invoices,
		(
			select	sum(tii.item_units)
			from	im_costs tc,
				im_invoice_items tii,
				im_projects p
			where	tii.invoice_id = tc.cost_id and
				tii.item_outline_number = i.item_outline_number and
				tii.item_uom_id = i.item_uom_id and
				tc.cost_type_id = 3706 and
				tc.project_id = p.project_id and
				p.tree_sortkey between i.tree_sortkey and tree_right(i.tree_sortkey)
		) as pos,
		(
			select	sum(tii.item_units)
			from	im_costs tc,
				im_invoice_items tii,
				im_projects p
			where	tii.invoice_id = tc.cost_id and
				tii.item_outline_number = i.item_outline_number and
				tii.item_uom_id = i.item_uom_id and
				tc.cost_type_id = 3704 and
				tc.project_id = p.project_id and
				p.tree_sortkey between i.tree_sortkey and tree_right(i.tree_sortkey)
		) as bills

	from	(select distinct
			ii.item_outline_number,
			ii.item_uom_id,
			ii.item_name,
			main_p.tree_sortkey
		from	im_costs c,
			im_invoices i,
			im_invoice_items ii,
			im_projects sub_p,
			im_projects main_p
		where	c.cost_id = i.invoice_id and
			ii.invoice_id = i.invoice_id and
			c.project_id = sub_p.project_id and
			sub_p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
			main_p.project_id = :project_id
		) i

	order by i.item_outline_number
"]
