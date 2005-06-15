<?xml version="1.0"?>
<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="im_invoices_object_list_component.object_list">
    <querytext>
        select distinct
	   	o.object_id,
		o.object_type,
		acs_object__name(o.object_id) as object_name,
		u.url
	from
	        acs_objects o,
	        acs_rels r,
		im_biz_object_urls u
	where
	        r.object_id_one = o.object_id
	        and r.object_id_two = :invoice_id
		and u.object_type = o.object_type
		and u.url_type = 'view'
   </querytext>
</fullquery>
</queryset>
