<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/new-copy-postgresql.xql -->
<!-- @author Frankk Bergmann (frank.bergmann@project-open.com)
<!-- @creation-date 2005-02-07 -->
<!-- @arch-tag 16a384f6-aa92-4668-9f42-51b4e1085bc8 -->
<!-- @cvs-id $Id$ -->

<queryset>
 
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  
  <fullquery name="invoice_items">
    <querytext>

	select
	        i.*,
		i.sort_order as item_sort_order,
		trim(to_char(i.price_per_unit,:price_per_unit_format)) as price_per_unit_formatted,
	        p.*,
	        p.project_nr as project_short_name,
	        im_category_from_id(i.item_uom_id) as item_uom,
	        im_category_from_id(i.item_type_id) as item_type
	from
	        im_invoice_items i 
		LEFT OUTER JOIN im_projects p ON (i.project_id = p.project_id)
	where
	        i.invoice_id in ([join $source_invoice_id ", "])
	order by
	        i.project_id,
		i.sort_order

    </querytext>
  </fullquery>
</queryset>
