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


create or replace view im_payment_type as 
select category_id as payment_type_id, category as payment_type
from im_categories 
where category_type = 'Intranet Payment Type';

create or replace view im_invoice_payment_method as 
select 
	category_id as payment_method_id, 
	category as payment_method, 
	category_description as payment_description
from im_categories 
where category_type = 'Intranet Invoice Payment Method';



------------------------------------------------------
-- Invoice Views
--
insert into im_views (view_id, view_name, visible_for) 
values (30, 'invoice_list', 'view_finance');
insert into im_views (view_id, view_name, visible_for) 
values (31, 'invoice_new', 'view_finance');
-- 32 reserved for payment_list
insert into im_views (view_id, view_name, visible_for) 
values (33, 'invoice_select', 'view_finance');
-- 34 reserved for CVS export
insert into im_views (view_id, view_name, visible_for) 
values (35, 'invoice_list_subtotal', 'view_finance');




-- Invoice List Page
--
delete from im_view_columns where view_id = 30;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3001,30,NULL,'Document #',
'"<A HREF=/intranet-invoices/view?invoice_id=$invoice_id>$invoice_nr</A>"',
'','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3002,30,NULL,'CC',
'$cost_center_code','','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3003,30,NULL,'Type',
'<nobr>$cost_type</nobr>','','',3,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3004,30,NULL,'Provider',
'"<nobr><A HREF=/intranet/companies/view?company_id=$provider_id>$provider_name</A></nobr>"',
'','',4,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3005,30,NULL,'Customer',
'"<A HREF=/intranet/companies/view?company_id=$customer_id>$customer_name</A>"',
'','',5,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3007,30,NULL,'Due Date',
'<nobr>[if {$overdue > 0} {
	set t "<font color=red>$due_date_calculated</font>"
} else {
	set t "$due_date_calculated"
}]</nobr>','','',7,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3011,30,NULL,'Amount',
'"$invoice_amount_formatted $invoice_currency"','','',11,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3013,30,NULL,'Paid',
'"$payment_amount $payment_currency"','','',13,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3017,30,NULL,'Status',
'$status_select','','',17,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3098,30,NULL,'Del',
'[if {[string equal "" $payment_amount]} {
	set ttt "
		<input type=checkbox name=del_cost value=$invoice_id>
		<input type=hidden name=object_type.$invoice_id value=$object_type>"
}]','','',99,'');




-- Invoice List Page - Subtotals
--
delete from im_view_columns where column_id > 3500 and column_id < 3599;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3501,35,NULL,'Document #',
'','','',1,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3503,35,NULL,'Type',
'','','',3,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3504,35,NULL,'Provider',
'','','',4,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3505,35,NULL,'Customer',
'','','',5,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3507,35,NULL,'Due Date',
'$total_type','','',7,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3511,35,NULL,'Amount',
'"<b>$amount_subtotal</b>"','','',11,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3513,35,NULL,'Paid',
'"<b>$paid_subtotal</b>"','','',13,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3517,35,NULL,'Status',
'','','',17,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3598,35,NULL,'Del',
'','','',99,'');



-- Invoice New Page (shows Projects)
--
delete from im_view_columns where column_id > 3100 and column_id < 3199;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3101,31,NULL,'Project #',
'"<A HREF=/intranet/projects/view?project_id=$project_id>$project_nr</A>"','','',1,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3103,31,NULL,'Client',
'"<A HREF=/intranet/companies/view?company_id=$company_id>$company_name</A>"','','',2,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3107,31,NULL,'Project Name','$project_name','','',4,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3109,31,NULL,'Type','$project_type','','',5,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3111,31,NULL,'Status','$project_status','','',6,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3113,31,NULL,'Delivery Date','$end_date','','',7,'');

-- Now set to sort_order=0
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3115,31,NULL,'Sel',
'"<input type=checkbox name=select_project value=$project_id>"',
'','',0,'');



-- Invoice Select Page
--
delete from im_view_columns where column_id > 3300 and column_id < 3399;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3301,33,NULL,'Document #',
'"<A HREF=/intranet-invoices/view?invoice_id=$invoice_id>$invoice_nr</A>"',
'','',1,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3303,33,NULL,'Type',
'$cost_type','','',3,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3304,33,NULL,'Provider',
'"<A HREF=/intranet/companies/view?company_id=$provider_id>$provider_name</A>"',
'','',4,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3305,33,NULL,'Customer',
'"<A HREF=/intranet/companies/view?company_id=$customer_id>$customer_name</A>"',
'','',5,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3307,33,NULL,'Due Date',
'$due_date_calculated','','',7,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3311,33,NULL,'Amount',
'"$invoice_amount_formatted $invoice_currency"','','',11,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3317,33,NULL,'Status',
'$invoice_status','','',17,'');











-- Invoice Status
delete from im_categories where category_id >= 600 and category_id < 700;
-- now being replaced by "Intranet Cost Status"
-- reserved until 699


-- Invoice Type
delete from im_categories where category_id >= 700 and category_id < 800;
-- now being replaced by "Intranet Cost Type"


-- Invoice Payment Method
delete from im_categories where category_id >= 800 and category_id < 900;

INSERT INTO im_categories VALUES (800,'Undefined',
'Not defined yet','Intranet Invoice Payment Method','category','t','f');
INSERT INTO im_categories VALUES (802,'Cash',
'Cash or cash equivalent','Intranet Invoice Payment Method','category','t','f');

INSERT INTO im_categories VALUES (804,'Cheque EUR',
'Check in EUR payable to company','Intranet Invoice Payment Method','category','t','f');
INSERT INTO im_categories VALUES (806,'Cheque USD',
'Check in US$ payable to company','Intranet Invoice Payment Method','category','t','f');
INSERT INTO im_categories VALUES (808,'Patagon EUR',
'Wire transfer without charges for the beneficiary, IBAN: ..., Patagon Bank S.A. Madrid.',
'Intranet Invoice Payment Method','category','t','f');
INSERT INTO im_categories VALUES (810,'La Caixa EUR',
'Wire transfer without charges for the beneficiary, IBAN: ..., Caja de Ahorros y Pensiones de Barcelona.',
'Intranet Invoice Payment Method','category','t','f');
-- reserved until 899

-- Payment Type
delete from im_categories where category_id >= 1000 and category_id < 1100;
INSERT INTO im_categories VALUES (1000,'Bank Transfer','','Intranet Payment Type','category','t','f');
INSERT INTO im_categories VALUES (1002,'Cheque','','Intranet Payment Type','category','t','f');
-- reserved until 1099



-- Add links to edit im_invoices objects...

insert into im_biz_object_urls (object_type, url_type, url) values (
'im_invoice','view','/intranet-invoices/view?invoice_id=');
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_invoice','edit','/intranet-invoices/new?invoice_id=');

