-- /packages/intranet-invoices/sql/oracle/intranet-invoices-backup.sql
--
-- Copyright (C) 2003-2004 Project/Open
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com

-- 100	im_projects
-- 101	im_project_roles
-- 102	im_customers
-- 103	im_customer_roles
-- 104	im_offices
-- 105	im_office_roles
-- 106	im_categories
--
-- 110	users
-- 111	im_profiles
--
-- 120	im_freelancers
--
-- 130	im_forums
--
-- 140	im_filestorage
--
-- 150	im_translation
--
-- 160	im_quality
--
-- 170	im_marketplace
--
-- 180	im_hours
--
-- 190	im_invoices
--
-- 200



---------------------------------------------------------
-- Backup Invoices
--

delete from im_view_columns where view_id = 190;
delete from im_views where view_id = 190;
insert into im_views (view_id, view_name, view_sql
) values (190, 'im_invoices', '
SELECT
	i.*,
	cg.group_name as customer_name,
	im_email_from_user_id(i.creator_id) as creator_email,
	im_email_from_user_id(i.customer_contact_id) as customer_contact_email,
	im_category_from_id(i.template_id) as template,
	im_category_from_id(i.cost_status_id) as cost_status,
	im_category_from_id(i.cost_type_id) as cost_type,
	im_category_from_id(i.payment_method_id) as payment_method,
	im_email_from_user_id(i.last_modifying_user) as last_modifying_user_email
FROM
	im_invoices i,
	user_groups cg
WHERE
	i.customer_id = cg.group_id
');

delete from im_view_columns where column_id > 19004 and column_id < 19099;
--
insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19001,190,NULL,'invoice_nr','$invoice_nr','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19003,190,NULL,'customer_name','$customer_name','','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19005,190,NULL,'creator_email','$creator_email','','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19007,190,NULL,'customer_contact_email','$customer_contact_email','','',7,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19009,190,NULL,'invoice_date','$invoice_date','','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19011,190,NULL,'due_date','$due_date','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19013,190,NULL,'invoice_currency','$invoice_currency','','',13,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19014,190,NULL,'template','$template','','',14,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19015,190,NULL,'invoice_status','$invoice_status','','',15,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19017,190,NULL,'cost_type','$cost_type','','',17,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19019,190,NULL,'payment_method','$payment_method','','',19,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19021,190,NULL,'payment_days','$payment_days','','',21,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19023,190,NULL,'vat','$vat','','',23,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19025,190,NULL,'tax','$tax','','',25,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19027,190,NULL,'note','$note','','',27,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19029,190,NULL,'last_modified','$last_modified','','',29,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19031,190,NULL,'last_modifying_user','$last_modifying_user','','',31,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19033,190,NULL,'modified_ip_address','$modified_ip_address','','',33,'');
--
commit;





---------------------------------------------------------
-- Backup InvoiceItems
--

delete from im_view_columns where view_id = 191;
delete from im_views where view_id = 191;
insert into im_views (view_id, view_name, view_sql
) values (191, 'im_invoice_items', '
SELECT
	i.*,
	pg.group_name as project_name,
	ii.invoice_nr,
	im_category_from_id(i.item_uom_id) as item_uom,
	im_category_from_id(i.item_status_id) as item_status,
	im_category_from_id(i.item_type_id) as item_type
FROM
	im_invoice_items i,
	im_invoices ii,
	user_groups pg
WHERE
	i.project_id = pg.group_id
	and i.invoice_id = ii.invoice_id
');

delete from im_view_columns where column_id > 19104 and column_id < 19199;
--
insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19101,191,NULL,'item_name','$item_name','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19103,191,NULL,'project_name','$project_name','','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19105,191,NULL,'invoice_nr','$invoice_nr','','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19107,191,NULL,'item_units','$item_units','','',7,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19109,191,NULL,'item_uom','$item_uom','','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19111,191,NULL,'price_per_unit','$price_per_unit','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19113,191,NULL,'currency','$currency','','',13,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19114,191,NULL,'sort_order','$sort_order','','',14,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19115,191,NULL,'item_type','$item_type','','',15,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19117,191,NULL,'item_status','$item_status','','',17,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19119,191,NULL,'description','$description','','',19,'');

--
commit;




---------------------------------------------------------
-- Backup Prices
--

delete from im_view_columns where view_id = 192;
delete from im_views where view_id = 192;
insert into im_views (view_id, view_name, view_sql
) values (192, 'im_trans_prices', '
SELECT
	p.*,
	im_category_from_id(p.uom_id) as uom,
	cg.group_name as customer_name,
	im_category_from_id(p.target_language_id) as target_language,
	im_category_from_id(p.source_language_id) as source_language,
	im_category_from_id(p.subject_area_id) as subject_area
FROM
	im_trans_prices p,
	user_groups cg
WHERE
	p.customer_id = cg.group_id
');


delete from im_view_columns where column_id > 19204 and column_id < 19299;
--
insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19201,192,NULL,'uom','$uom','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19203,192,NULL,'customer_name','$customer_name','','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19205,192,NULL,'target_language','$target_language','','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19207,192,NULL,'source_language','$source_language','','',7,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19209,192,NULL,'subject_area','$subject_area','','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19211,192,NULL,'valid_from','$valid_from','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19213,192,NULL,'valid_through','$valid_through','','',13,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19214,192,NULL,'currency','$currency','','',14,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19215,192,NULL,'price','$price','','',15,'');

--
commit;





---------------------------------------------------------
-- Backup Project - Invoice Map
--

delete from im_view_columns where view_id = 193;
delete from im_views where view_id = 193;
insert into im_views (view_id, view_name, view_sql
) values (193, 'im_project_invoice_map', '
SELECT
	p.project_name,
	i.invoice_nr
FROM
	acs_rels r,
	project p,
	im_invoices i
WHERE
	r.object_id_one = p.project_id
	and r.object_id_two = i.invoice_id
');


delete from im_view_columns where column_id > 19304 and column_id < 19399;
--
insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19301,193,NULL,'project_name','$project_name','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19303,193,NULL,'invoice_nr','$invoice_nr','','',3,'');
--
commit;






---------------------------------------------------------
-- Backup Payments
--

delete from im_view_columns where view_id = 194;
delete from im_views where view_id = 194;
insert into im_views (view_id, view_name, view_sql
) values (194, 'im_payments', '
SELECT
	p.*,
	i.invoice_nr,
	im_category_from_id(p.payment_status_id) as payment_status,
	im_category_from_id(p.payment_type_id) as payment_type
FROM
	im_payments p,
	im_invoices i
WHERE
	p.invoice_id = i.invoice_id
');


delete from im_view_columns where column_id > 19404 and column_id < 19499;
--
insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19401,194,NULL,'invoice_nr','$invoice_nr','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19403,194,NULL,'received_date','$received_date','','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19405,194,NULL,'start_block','$start_block','','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19407,194,NULL,'payment_type','$payment_type','','',7,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19409,194,NULL,'payment_status','$payment_status','','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19411,194,NULL,'amount','$amount','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19413,194,NULL,'currency','$currency','','',13,'');

insert into im_view_columns (column_id, view_id, group_id, column_name,
column_render_tcl, extra_select, extra_where, sort_order, visible_for)
values (19414,194,NULL,'note','$note','','',14,'');
--
commit;





