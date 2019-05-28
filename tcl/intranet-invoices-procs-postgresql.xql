<?xml version="1.0"?>
<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="im_invoices_object_list_component.object_list">
    <querytext>
        select distinct
	   	o.object_id,
		o.object_type,
		acs_object__name(o.object_id) as object_name,
		(	select main_p.project_id from im_projects main_p
			where main_p.tree_sortkey = tree_root_key(p.tree_sortkey)
		) as main_project_id,
		u.url
	from
	        acs_objects o,
		im_projects p,
	        acs_rels r,
		im_biz_object_urls u
	where
	        r.object_id_one = o.object_id and
	        r.object_id_two = :invoice_id and
		u.object_type = o.object_type and
		u.url_type = 'view' and
		o.object_id = p.project_id
   </querytext>
</fullquery>
</queryset>
