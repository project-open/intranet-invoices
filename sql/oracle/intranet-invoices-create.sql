-- /package/intranet-invoices/sql/oracle/intranet-invoices-create.sql
--
-- Copyright (c) 2003-2004 Project/Open
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com

-- Invoices module for Project/Open
--
-- Defines:
--	im_invoices			Invoice biz object container
--	im_invoice_items		Invoice lines
--	im_projects_invoices_map	Maps projects -> invoices
--

-- An invoice basically is a container of im_invoice_lines.
-- The problem is that invoices can be vastly different 
-- from business to business, and that invoices may emerge
-- as a result of negotiations between the comapany and the
-- client, so that basically nothing is really fixed or
-- consistent with the project data.
--
-- So the idea of this module is to _generate_ the invoices
-- automatically and consistently from the project data,
-- but to allow invoices to be edit manually in every respect.
--
-- Options to create invoices include:
--	- exactly one invoice for each project
--	- include multipe projects in one invoice
--	- multiple invoices per project (partial invoices)
--	- invoices without project
--
-- As a side effect of creating an invoice, the status of
-- the associated projects may be set to "invoiced", as
-- well as the status of the projects tasks of those 
-- projects (if the project-tasks module is installed).

set escape \

---------------------------------------------------------
-- Invoices
--
-- Invoices group together several "Tasks" (possibly from different
-- projects). 
--
-- Access permissions to invoices are granted to members
-- of owners of the "view_finance" permission token, and
-- to group members of the client.
--
-- Please note that it is a manual task to set the invoice
-- status to "paid", because the due_amount 
-- (sum(invoice_lines.amount)) is almost never going to
-- match the paid amount (sum(im_payments.fee)).
--
create table im_invoices (
	invoice_id		integer
				constraint im_invoices_pk
				primary key
				constraint im_invoices_id_fk
				references im_costs,
	customer_contact_id	integer 
				constraint im_invoices_contact
				references users,
	invoice_nr		varchar(40)
				constraint im_invoices_nr_un unique,
	payment_method_id	integer
				constraint im_invoices_payment
				references im_categories,
	-- the PO of a provider bill or the quote of an invoice
	reference_document_id	integer
				constraint im_invoices_reference_doc
				references im_invoices
);



-----------------------------------------------------------
-- Invoice Items
--
-- - Invoice items reflect the very fuzzy structure of invoices,
--   that may contain basicly everything that fits in one line
--   and has a price.
-- - Invoice items can created manually or generated from
--   "invoicable items" such as im_trans_tasks, timesheet information
--    or similar.
-- All fields (number of units, price, description) need to be 
-- human editable because invoicing is so messy...

create sequence im_invoice_items_seq start with 1;
create table im_invoice_items (
	item_id			integer
				constraint im_invoices_items_pk
				primary key,
	item_name		varchar(200),
				-- project_id if != null is used to access project details
				-- for invoice generation, such as the customer PO# etc.
	project_id		integer
				constraint im_invoices_items_project
				references im_projects,
	invoice_id		not null 
				constraint im_invoices_items_invoice
				references im_invoices,
	item_units		number(12,1),
	item_uom_id		not null 
				constraint im_invoices_items_uom
				references im_categories,
	price_per_unit 		number(12,3),
	currency		char(3) 
				constraint im_invoices_items_currency
				references currency_codes(ISO),
	sort_order		integer,
	item_type_id		integer
				constraint im_invoices_items_item_type
				references im_categories,
	item_status_id		integer
				constraint im_invoices_items_item_status
				references im_categories,
	description		varchar(4000),
		-- Make sure we can't create duplicate entries per invoice
		constraint im_invoice_items_un
		unique (item_name, invoice_id, project_id, item_uom_id)
);



---------------------------------------------------------
-- Invoice Object
---------------------------------------------------------

-- Nothing spectactular, just to be able to use acs_rels
-- between projects and invoices and to add custom fields
-- later. We are not even going to use the permission
-- system right now.

begin
    acs_object_type.create_type (
	supertype =>		'acs_object',
	object_type =>		'im_invoice',
	pretty_name =>		'Invoice',
	pretty_plural =>	'Invoices',
	table_name =>		'im_invoices',
	id_column =>		'invoice_id',
	package_name =>		'im_invoice',
	type_extension_table => null,
	name_method =>		'im_invoice.name'
    );
end;
/
show errors


create or replace package im_invoice
is
    function new (
	invoice_id		in integer default null,
	object_type		in varchar default 'im_invoice',
	creation_date		in date default sysdate,
	creation_user		in integer,
	creation_ip		in varchar default null,
	context_id		in integer default null,
	invoice_nr		in varchar,
	customer_id		in integer,
	provider_id		in integer,
	customer_contact_id	in integer default null,
	invoice_date		in date default sysdate,
	invoice_currency	in char default 'EUR',
	invoice_template_id	in integer default null,
	invoice_status_id	in integer default 602,
	invoice_type_id		in integer default 700,
	payment_method_id	in integer default null,
	payment_days		in integer default 30,
	amount			in number default 0,
	vat			in number default 0,
	tax			in number default 0,
	note			in varchar default null
    ) return im_invoices.invoice_id%TYPE;

    procedure del (invoice_id in integer);
    function name (invoice_id in integer) return varchar;
end im_invoice;
/
show errors


create or replace package body im_invoice
is
    function new (
	invoice_id		in integer default null,
	object_type		in varchar default 'im_invoice',
	creation_date		in date default sysdate,
	creation_user		in integer,
	creation_ip		in varchar default null,
	context_id		in integer default null,
	invoice_nr		in varchar,
	customer_id		in integer,
	provider_id		in integer,
	customer_contact_id	in integer default null,
	invoice_date		in date default sysdate,
	invoice_currency	in char default 'EUR',
	invoice_template_id	in integer default null,
	invoice_status_id	in integer default 602,
	invoice_type_id		in integer default 700,
	payment_method_id	in integer default null,
	payment_days		in integer default 30,
	amount			in number,
	vat			in number default 0,
	tax			in number default 0,
	note			in varchar default null
    ) return im_invoices.invoice_id%TYPE
    is
	v_invoice_id	im_invoices.invoice_id%TYPE;
    begin
	v_invoice_id := im_cost.new (
		cost_id		=> invoice_id,
		object_type	=> object_type,
		creation_date	=> creation_date,
		creation_user	=> creation_user,
		creation_ip	=> creation_ip,
		context_id	=> context_id,
		cost_name	=> invoice_nr,
		customer_id	=> customer_id,
		provider_id	=> provider_id,
		cost_status_id	=> invoice_status_id,
		cost_type_id	=> invoice_type_id,
		template_id	=> invoice_template_id,
		effective_date	=> invoice_date,
		payment_days	=> payment_days,
		amount		=> amount,
		currency	=> invoice_currency,
		vat		=> vat,
		tax		=> tax,
		note		=> note
	);

	insert into im_invoices (
		invoice_id,
		customer_contact_id, 
		invoice_nr,
		payment_method_id
	) values (
		v_invoice_id,
		new.customer_contact_id, 
		new.invoice_nr,
		new.payment_method_id
	);

	return v_invoice_id;
    end new;

    -- Delete a single invoice (if we know its ID...)
    procedure del (invoice_id in integer)
    is
    begin
	-- Erase the im_invoice_item associated with the id
	delete from 	im_invoice_items
	where		invoice_id = del.invoice_id;

	-- Delete relationships with projects and other objects
	delete from	acs_rels
	where		object_id_one = del.invoice_id
			or object_id_two = del.invoice_id;

	-- Erase the invoice itself
	delete from 	im_invoices
	where		invoice_id = del.invoice_id;

	-- Erase the CostItem
	im_cost.del(del.invoice_id);
    end del;

    function name (invoice_id in integer) return varchar
    is
	v_name	varchar(40);
    begin
	select	invoice_nr
	into	v_name
	from	im_invoices
	where	invoice_id = name.invoice_id;

	return v_name;
    end name;

end im_invoice;
/
show errors

------------------------------------------------------
-- Projects <-> Invoices Map
--
-- Several projects may be invoiced in a single invoice,
-- while a single project may be invoices several times,
-- particularly if it is a big project.
--
-- So there is a N:M relation between these two, and we
-- need a mapping table. This table allows us to
-- avoid inserting a "invoice_id" column in the im_projects
-- table, thus reducing the dependency between the "core"
-- module and the "invoices" module, allowing for example
-- for several different invoices modules.
--
-- 040403 fraber: We are now using acs_rels instead of
-- im_project_invoice_map:
-- acs_rels: object_id_one=project_id, object_id_two=invoice_id




------------------------------------------------------
-- Permissions and Privileges
--

begin
    acs_privilege.create_privilege('view_invoices','View Invoices','View Invoices');
    acs_privilege.create_privilege('add_invoices','View Invoices','View Invoices');
end;
/
show errors;


BEGIN
    im_priv_create('view_invoices','Accounting');
    im_priv_create('view_invoices','P/O Admins');
    im_priv_create('view_invoices','Senior Managers');
END;
/
show errors;

BEGIN
    im_priv_create('add_invoices','Accounting');
    im_priv_create('add_invoices','P/O Admins');
    im_priv_create('add_invoices','Senior Managers');
END;
/
show errors;


------------------------------------------------------
-- Views to Business Objects
--
-- all invoices that are not deleted (600) nor that have
-- been lost during creation (612).
create or replace view im_invoices_active as 
select	i.*,
	ci.*,
	ci.effective_date + ci.payment_days as due_date,
	ci.effective_date as invoice_date,
	ci.cost_status_id as invoice_status_id,
	ci.cost_type_id as invoice_type_id,
	ci.template_id as invoice_template_id
from 
	im_invoices i,
	im_costs ci
where
	ci.cost_id = i.invoice_id
	and ci.cost_status_id not in (3712);
commit;


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


-- Invoice List Page
--
delete from im_view_columns where column_id > 3000 and column_id < 3099;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3001,30,NULL,'Document #',
'"<A HREF=/intranet-invoices/view?invoice_id=$invoice_id>$invoice_nr</A>"',
'','',1,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3002,30,NULL,'Preview',
'"<A HREF=/intranet-invoices/view?invoice_id=$invoice_id${amp}render_template_id=$template_id>
$invoice_nr</A>"','','',2,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3003,30,NULL,'Type',
'$cost_type','','',3,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3004,30,NULL,'Provider',
'"<A HREF=/intranet/customers/view?customer_id=$provider_id>$provider_name</A>"',
'','',4,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3005,30,NULL,'Client',
'"<A HREF=/intranet/customers/view?customer_id=$customer_id>$customer_name</A>"',
'','',5,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3007,30,NULL,'Due Date',
'[if {$overdue > 0} {
	set t "<font color=red>$due_date_calculated</font>"
} else {
	set t "$due_date_calculated"
}]','','',7,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3011,30,NULL,'Amount',
'"$invoice_amount_formatted $invoice_currency"','','',11,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3013,30,NULL,'Paid',
'"$payment_amount $payment_currency"','','',13,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3017,30,NULL,'Status',
'[im_cost_status_select "cost_status.$invoice_id" $invoice_status_id]','','',17,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3098,30,NULL,'Del',
'[if {[string equal "" $payment_amount]} {
	set ttt "
		<input type=checkbox name=del_cost value=$invoice_id>
		<input type=hidden name=object_type.$invoice_id value=$object_type>"
}]','','',99,'');
--
commit;


-- Invoice New Page (shows Projects)
--
delete from im_view_columns where column_id > 3100 and column_id < 3199;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3101,31,NULL,'Project #',
'"<A HREF=/intranet/projects/view?project_id=$project_id>$project_nr</A>"','','',1,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3103,31,NULL,'Client',
'"<A HREF=/intranet/customers/view?customer_id=$customer_id>$customer_name</A>"','','',2,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3107,31,NULL,'Project Name','$project_name','','',4,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3109,31,NULL,'Type','$project_type','','',5,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3111,31,NULL,'Status','$project_status','','',6,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3113,31,NULL,'Delivery Date','$end_date','','',7,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3115,31,NULL,'Sel',
'"<input type=checkbox name=select_project value=$project_id>"',
'','',8,'');

--
commit;


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
commit;
-- reserved until 899

-- Payment Type
delete from im_categories where category_id >= 1000 and category_id < 1100;
INSERT INTO im_categories VALUES (1000,'Bank Transfer','','Intranet Payment Type','category','t','f');
INSERT INTO im_categories VALUES (1002,'Cheque','','Intranet Payment Type','category','t','f');
commit;
-- reserved until 1099



---------------------------------------------------------
-- Invoice Menus
--
-- delete potentially existing menus and plugins if this
-- file is sourced multiple times during development...
-- delete the intranet-payments menus because they are 
-- located below intranet-invoices modules and would
-- cause a RI error.

BEGIN
    im_component_plugin.del_module(module_name => 'intranet-invoices');
    im_menu.del_module(module_name => 'intranet-payments');
    im_menu.del_module(module_name => 'intranet-invoices');
END;
/
commit;


prompt *** Setup the invoice menus
--
declare
	-- Menu IDs
	v_menu			integer;
	v_main_menu 		integer;
	v_finance_menu		integer;

	-- Groups
	v_employees	integer;
	v_accounting	integer;
	v_senman		integer;
	v_customers	integer;
	v_freelancers	integer;
	v_proman		integer;
	v_admins		integer;
begin

    select group_id into v_admins from groups where group_name = 'P/O Admins';
    select group_id into v_senman from groups where group_name = 'Senior Managers';
    select group_id into v_accounting from groups where group_name = 'Accounting';
    select group_id into v_customers from groups where group_name = 'Customers';
    select group_id into v_freelancers from groups where group_name = 'Freelancers';

    select menu_id
    into v_finance_menu
    from im_menus
    where label='finance';

    -- -----------------------------------------------------
    -- Invoices Submenu
    -- -----------------------------------------------------

    -- needs to be the first submenu in order to get selected
    v_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_customers',
	name =>		'Customers',
	url =>		'/intranet-invoices/list?cost_type_id=3708',
	sort_order =>	10,
	parent_menu_id => v_finance_menu
    );
    acs_permission.grant_permission(v_menu, v_admins, 'read');
    acs_permission.grant_permission(v_menu, v_senman, 'read');
    acs_permission.grant_permission(v_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_menu, v_customers, 'read');
    acs_permission.grant_permission(v_menu, v_freelancers, 'read');


    v_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_providers',
	name =>		'Providers',
	url =>		'/intranet-invoices/list?cost_type_id=3710',
	sort_order =>	20,
	parent_menu_id => v_finance_menu
    );
    acs_permission.grant_permission(v_menu, v_admins, 'read');
    acs_permission.grant_permission(v_menu, v_senman, 'read');
    acs_permission.grant_permission(v_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_menu, v_customers, 'read');
    acs_permission.grant_permission(v_menu, v_freelancers, 'read');
end;
/
commit;


-- Setup the "Invoices New" admin menu for Customer Documents
--
declare
	-- Menu IDs
	v_menu			integer;
	v_invoices_new_menu	integer;
	v_finance_menu		integer;

	-- Groups
	v_employees		integer;
	v_accounting		integer;
	v_senman		integer;
	v_customers		integer;
	v_freelancers		integer;
	v_proman		integer;
	v_admins		integer;
begin

    select group_id into v_admins from groups where group_name = 'P/O Admins';
    select group_id into v_senman from groups where group_name = 'Senior Managers';
    select group_id into v_accounting from groups where group_name = 'Accounting';
    select group_id into v_customers from groups where group_name = 'Customers';
    select group_id into v_freelancers from groups where group_name = 'Freelancers';

    select menu_id
    into v_invoices_new_menu
    from im_menus
    where label='invoices_customers';

    v_finance_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_customers_new_invoice',
	name =>		'New Customer Invoice from scratch',
	url =>		'/intranet-invoices/new?cost_type_id=3700',
	sort_order =>	10,
	parent_menu_id => v_invoices_new_menu
    );

    acs_permission.grant_permission(v_finance_menu, v_admins, 'read');
    acs_permission.grant_permission(v_finance_menu, v_senman, 'read');
    acs_permission.grant_permission(v_finance_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_finance_menu, v_customers, 'read');
    acs_permission.grant_permission(v_finance_menu, v_freelancers, 'read');

    v_finance_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_customers_new_invoice_from_quote',
	name =>		'New Customer Invoice from Quote',
	url =>		'/intranet-invoices/new-copy?cost_type_id=3700\&from_cost_type_id=3702',
	sort_order =>	20,
	parent_menu_id => v_invoices_new_menu
    );

    acs_permission.grant_permission(v_finance_menu, v_admins, 'read');
    acs_permission.grant_permission(v_finance_menu, v_senman, 'read');
    acs_permission.grant_permission(v_finance_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_finance_menu, v_customers, 'read');
    acs_permission.grant_permission(v_finance_menu, v_freelancers, 'read');

    v_finance_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_customers_new_quote',
	name =>		'New Quote from scratch',
	url =>		'/intranet-invoices/new?cost_type_id=3702',
	sort_order =>	30,
	parent_menu_id => v_invoices_new_menu
    );

    acs_permission.grant_permission(v_finance_menu, v_admins, 'read');
    acs_permission.grant_permission(v_finance_menu, v_senman, 'read');
    acs_permission.grant_permission(v_finance_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_finance_menu, v_customers, 'read');
    acs_permission.grant_permission(v_finance_menu, v_freelancers, 'read');

end;
/
commit;



-- Setup the "Invoices New" admin menu for Customer Documents
--
declare
	-- Menu IDs
	v_menu			integer;
	v_invoices_new_menu	integer;
	v_finance_menu		integer;

	-- Groups
	v_employees		integer;
	v_accounting		integer;
	v_senman		integer;
	v_customers		integer;
	v_freelancers		integer;
	v_proman		integer;
	v_admins		integer;
begin

    select group_id into v_admins from groups where group_name = 'P/O Admins';
    select group_id into v_senman from groups where group_name = 'Senior Managers';
    select group_id into v_accounting from groups where group_name = 'Accounting';
    select group_id into v_customers from groups where group_name = 'Customers';
    select group_id into v_freelancers from groups where group_name = 'Freelancers';

    select menu_id
    into v_invoices_new_menu
    from im_menus
    where label='invoices_providers';

    v_finance_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_providers_new_bill',
	name =>		'New Provider Bill from scratch',
	url =>		'/intranet-invoices/new?cost_type_id=3704',
	sort_order =>	10,
	parent_menu_id => v_invoices_new_menu
    );

    acs_permission.grant_permission(v_finance_menu, v_admins, 'read');
    acs_permission.grant_permission(v_finance_menu, v_senman, 'read');
    acs_permission.grant_permission(v_finance_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_finance_menu, v_customers, 'read');
    acs_permission.grant_permission(v_finance_menu, v_freelancers, 'read');

    v_finance_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_providers_new_bill_from_po',
	name =>		'New Provider Bill from Purchase Order',
	url =>		'/intranet-invoices/new-copy?cost_type_id=3704\&from_cost_type_id=3706',
	sort_order =>	20,
	parent_menu_id => v_invoices_new_menu
    );

    acs_permission.grant_permission(v_finance_menu, v_admins, 'read');
    acs_permission.grant_permission(v_finance_menu, v_senman, 'read');
    acs_permission.grant_permission(v_finance_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_finance_menu, v_customers, 'read');
    acs_permission.grant_permission(v_finance_menu, v_freelancers, 'read');

    v_finance_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_providers_new_po',
	name =>		'New Purchase Order from scratch',
	url =>		'/intranet-invoices/new?cost_type_id=3706',
	sort_order =>	30,
	parent_menu_id => v_invoices_new_menu
    );

    acs_permission.grant_permission(v_finance_menu, v_admins, 'read');
    acs_permission.grant_permission(v_finance_menu, v_senman, 'read');
    acs_permission.grant_permission(v_finance_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_finance_menu, v_customers, 'read');
    acs_permission.grant_permission(v_finance_menu, v_freelancers, 'read');

end;
/
commit;

-- Add links to edit im_invoices objects...

insert into im_biz_object_urls (object_type, url_type, url) values (
'im_invoice','view','/intranet-invoices/view?invoice_id=');
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_invoice','edit','/intranet-invoices/new?invoice_id=');



---------------------------------------------------------
-- Import backup views
--

-- 100  im_projects
-- 101  im_project_roles
-- 102  im_customers
-- 103  im_customer_roles
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
insert into im_views (view_id, view_name, view_sql
) values (192, 'im_invoices', '
SELECT
	i.*,
	c.start_block,
	c.cost_nr,
	im_email_from_user_id(i.customer_contact_id) as company_contact_email,
	im_category_from_id(i.payment_method_id) as payment_method,
	refi.invoice_nr as reference_document_nr
FROM
	im_invoices i,
	im_costs c,
	im_invoices refi
WHERE
	i.invoice_id = c.cost_id
	and i.reference_document_id = refi.invoice_id(+)
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
--
commit;





---------------------------------------------------------
-- Backup InvoiceItems
--

delete from im_view_columns where view_id = 193;
delete from im_views where view_id = 193;
insert into im_views (view_id, view_name, view_sql
) values (193, 'im_invoice_items', '
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

--
commit;




---------------------------------------------------------
-- Backup Project - Invoice Map
--

delete from im_view_columns where view_id = 194;
delete from im_views where view_id = 194;
insert into im_views (view_id, view_name, view_sql
) values (194, 'im_project_invoice_map', '
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
--
commit;


