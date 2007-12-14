<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/new-postgresql.xql -->
<!-- @author  (avila@digiteix.com) -->
<!-- @creation-date 2004-09-22 -->
<!-- @arch-tag b7ff6546-a6ca-45d8-8dac-339969d91235 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  <fullquery name = "invoices_info_query">
    <querytext>
      select
	i.*,
	ci.customer_id,
	ci.provider_id,
	to_char(ci.effective_date,'YYYY-MM-DD') as effective_date,
	ci.cost_center_id,
	ci.payment_days,
	to_char(ci.vat, :vat_format) as vat,
	to_char(ci.tax, :tax_format) as tax,
	ci.note as cost_note,
	ci.template_id,
	ci.cost_status_id,
	ci.cost_type_id,
	ci.read_only_p,
	im_category_from_id(ci.cost_type_id) as cost_type,
	im_name_from_user_id(i.company_contact_id) as company_contact_name,
	im_email_from_user_id(i.company_contact_id) as company_contact_email,
	c.company_name as company_name,
	c.company_path as company_short_name,
	c.default_vat as company_vat,
	c.default_invoice_template_id as company_template_id,
	p.company_name as provider_name,
	p.company_path as provider_short_name
      from
	im_invoices i, 
	im_costs ci
        LEFT JOIN
             im_companies c ON ci.customer_id = c.company_id
        LEFT JOIN
             im_companies p ON ci.provider_id = p.company_id
      where 
        i.invoice_id=:invoice_id
	and i.invoice_id = ci.cost_id
    </querytext>
</fullquery>

<fullquery name="invoice_item">
    <querytext>
      select
	i.*,
	p.project_name,
	p.project_nr as project_short_name,
	im_category_from_id(i.item_uom_id) as item_uom,
	im_category_from_id(i.item_type_id) as item_type
      from
	im_invoice_items i
        LEFT JOIN
          im_projects p ON i.project_id=p.project_id
      where
	i.invoice_id = :invoice_id
      order by
	i.project_id
    </querytext>
</fullquery>
  
</queryset>
