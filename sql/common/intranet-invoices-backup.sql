-- /package/intranet-invoices/sql/common/intranet-invoices-backup.sql
--
-- Copyright (c) 2003 - 2009 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com

-- Invoices module
--
-- Defines:
--	im_invoices			Invoice biz object container
--	im_invoice_items		Invoice lines
--	im_projects_invoices_map	Maps projects -> invoices
--


---------------------------------------------------------
-- Import backup views
--

-- 100  im_projects
-- 101  im_project_roles
-- 102  im_companies
-- 103  im_company_roles
-- 104  im_offices
-- 105  im_office_roles
-- 106  im_categories
--
-- 110  users
-- 111  im_profiles
--
-- 120  im_freelancers
-- 121	im_freelance_skills
--
-- 130  im_forums
--
-- 140  im_filestorage
--
-- 150  im_translation
--
-- 160  im_quality
--
-- 170  im_marketplace
--
-- 180  im_hours
-- 181	im_absences
--
-- 190  im_costs
-- 191  im_payments
-- 192  im_invoices
-- 193  im_invoice_items
-- 194	im_project_invoice_map
-- 195	im_trans_prices
--
-- 199	end of range



---------------------------------------------------------
-- Backup Invoices
--

delete from im_view_columns where view_id = 192;
delete from im_views where view_id = 192;
insert into im_views (
	view_id, view_name, view_type_id, sort_order, view_sql
) values (
	192, 'im_invoices', 1410, 230, '
SELECT
	i.*,
	c.start_block,
	c.cost_nr,
	im_email_from_user_id(i.company_contact_id) as company_contact_email,
	im_category_from_id(i.payment_method_id) as payment_method,
	im_invoice_nr_from_id(i.reference_document_id) as reference_document_nr
FROM
	im_invoices i,
	im_costs c
WHERE
	i.invoice_id = c.cost_id
');

delete from im_view_columns where column_id > 19200 and column_id < 19299;
--
insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19201,192,NULL,'invoice_nr','$invoice_nr','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19203,192,NULL,'start_block','$start_block','','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (192035,192,NULL,'cost_nr','$cost_nr','','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19207,192,NULL,'company_contact_email','$company_contact_email',
'','',7,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19219,192,NULL,'payment_method','$payment_method','','',19,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19221,192,NULL,'reference_document_nr','$reference_document_nr','','',21,'');






---------------------------------------------------------
-- Backup InvoiceItems
--

delete from im_view_columns where view_id = 193;
delete from im_views where view_id = 193;
insert into im_views (
	view_id, view_name, view_type_id, sort_order, view_sql
) values (
	193, 'im_invoice_items', 1410, 240, '
SELECT
	i.*,
	p.project_name,
	ii.invoice_nr,
	im_category_from_id(i.item_uom_id) as item_uom,
	im_category_from_id(i.item_status_id) as item_status,
	im_category_from_id(i.item_type_id) as item_type
FROM
	im_invoice_items i,
	im_invoices ii,
	im_projects p
WHERE
	i.project_id = p.project_id
	and i.invoice_id = ii.invoice_id
');

delete from im_view_columns where column_id > 19304 and column_id < 19399;
--
insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19301,193,NULL,'item_name','[ns_urlencode $item_name]','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19303,193,NULL,'project_name','$project_name','','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19305,193,NULL,'invoice_nr','$invoice_nr','','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19307,193,NULL,'item_units','$item_units','','',7,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19309,193,NULL,'item_uom','$item_uom','','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19311,193,NULL,'price_per_unit','$price_per_unit','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19313,193,NULL,'currency','$currency','','',13,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19314,193,NULL,'sort_order','$sort_order','','',14,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19315,193,NULL,'item_type','$item_type','','',15,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19317,193,NULL,'item_status','$item_status','','',17,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19319,193,NULL,'description','[ns_urlencode $description]','','',19,'');





---------------------------------------------------------
-- Backup Project - Invoice Map
--

delete from im_view_columns where view_id = 194;
delete from im_views where view_id = 194;
insert into im_views (
	view_id, view_name, view_type_id, sort_order, view_sql
) values (
	194, 'im_project_invoice_map', 1410, 250, '
SELECT
	p.project_name,
	i.invoice_nr
FROM
	acs_rels r,
	im_projects p,
	im_invoices i
WHERE
	r.object_id_one = p.project_id
	and r.object_id_two = i.invoice_id
');


delete from im_view_columns where column_id > 19400 and column_id < 19499;
--
insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19401,194,NULL,'project_name','$project_name','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19403,194,NULL,'invoice_nr','$invoice_nr','','',3,'');


