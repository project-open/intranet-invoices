<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/view-oracle.xql -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->
<!-- @creation-date 2004-10-08 -->
<!-- @arch-tag 873b11b2-60e2-4bbf-9dd5-d6b06c019421 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>oracle</type>
    <version>8.1.6</version>
  </rdbms>
  
  <fullquery name = "invoice_items">
    <querytext>
      select
        i.*,
	p.*,
	im_category_from_id(i.item_type_id) as item_type,
	im_category_from_id(i.item_uom_id) as item_uom,
	p.project_nr as project_short_name,
	i.price_per_unit * i.item_units as amount
      from
	im_invoice_items i,
	im_projects p
      where
	i.invoice_id=:invoice_id
	and i.project_id=p.project_id(+)
      order by
	i.sort_order,
	i.item_type_id
      </querytext>
    </fullquery>
</queryset>
