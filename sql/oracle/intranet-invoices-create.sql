-- /package/intranet-invoices/sql/oracle/intranet-invoices-create.sql
--
-- Invoices module for Project/Open
--
-- (c) 2003 Frank Bergmann (fraber@fraber.de)
--
-- Defines:
--	im_invoices			Invoice biz object container
--	im_invoice_items		Invoice lines
--	im_projects_invoices_map	Maps projects -> invoices
--	im_prices			List of prices with defaults
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
create sequence im_invoices_seq start with 1;
create table im_invoices (
	invoice_id		integer
				constraint im_invoices_pk
				primary key,
				-- who should pay?
	customer_id		not null
				constraint im_invoices_customer
				references im_customers,
				-- who get paid?
	provider_id		not null
				constraint im_invoices_provider
				references im_customers,
	creator_id		integer
				constraint im_invoices_creator
				references users,
	customer_contact_id	integer 
				constraint im_invoices_contact
				references users,
	invoice_nr		varchar(40)
				constraint im_invoices_nr_un unique,
	invoice_date		date,
	due_date		date,
	invoice_currency	char(3) 
				constraint im_invoices_currency
				references currency_codes(ISO),
	invoice_template_id	integer
				constraint im_invoices_template
				references im_categories,
	invoice_status_id	not null 
				constraint im_invoices_status
				references im_categories,
	invoice_type_id		not null 
				constraint im_invoices_type
				references im_categories,
	payment_method_id	integer	
				constraint im_invoices_payment
				references im_categories,
	payment_days		integer,
	vat			number,
	tax			number,
	note			varchar(4000),
	last_modified		date not null,
	last_modifying_user	not null 
				constraint im_invoices_mod_user
				references users,
	modified_ip_address	varchar(20) not null
);

create table im_invoices_audit (
	invoice_id		integer,
	customer_id		integer not null,
	creator_id		integer,
	customer_contact_id	integer,
	invoice_nr		varchar(40),
	invoice_date		date,
	due_date		date,
	invoice_template_id	integer,
	invoice_status_id	integer,
	invoice_type_id		integer,
	payment_method_id	integer,
	payment_days		integer,
	vat			number,
	tax			number,
	note			varchar(4000),
	last_modified		date,
	last_modifying_user	integer,
	modified_ip_address	varchar(20)
);
create index im_invoices_aud_id_idx on im_invoices_audit(invoice_id);

create or replace trigger im_invoices_audit_tr
	before update or delete on im_invoices
	for each row
	begin
		insert into im_invoices_audit (
			invoice_id,
			customer_id,
			creator_id,
			customer_contact_id,
			invoice_nr,
			invoice_date,
			due_date,
			invoice_template_id,
			invoice_status_id,
			invoice_type_id,
			payment_method_id,
			payment_days,
			vat,
			tax,
			note,
			last_modified,
			last_modifying_user,
			modified_ip_address
		) values (
			:old.invoice_id,
			:old.customer_id,
			:old.creator_id,
			:old.customer_contact_id,
			:old.invoice_nr,
			:old.invoice_date,
			:old.due_date,
			:old.invoice_template_id,
			:old.invoice_status_id,
			:old.invoice_type_id,
			:old.payment_method_id,
			:old.payment_days,
			:old.vat,
			:old.tax,
			:old.note,
			:old.last_modified,
			:old.last_modifying_user,
			:old.modified_ip_address
		);
end im_invoices_audit_tr;
/
show errors




-----------------------------------------------------------
-- Invoice Items
--
-- - Invoice items reflect the very fuzzy structure of invoices,
--   that may contain basicly everything that fits in one line
--   and has a price.
-- - Invoice items are generated typically from im_tasks, plus
--   a invoice price, derived(!) from the price list.
--   However, all elements (number of units, price, description)
--   need to be human editable.
--
-- Tasks and Invoice Items are similar because they both represent
-- substructures of an invoice or a project. However, im_tasks
-- are supposed to be more strongly formalized (type, status, ...),
-- while Invoice Items contain the actually billed price and 
-- represent the dirty reality.
--

create sequence im_invoice_items_seq start with 1;
create table im_invoice_items (
	item_id			integer
				constraint im_invoices_items_pk
				primary key,
	item_name		varchar(200),
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
	description		varchar(4000)
);

------------------------------------------------------
-- Projects <-> Invoices Map
--
-- Several projects may be invoiced in a single invoice,
-- while a single project may be invoices several times,
-- particularly if it is a big project.
--
-- So there is a N:M relation between these two, and we
-- need a mapping table. Also, this table allows us to
-- avoid inserting a "invoice_id" column in the im_projects
-- table, thus reducing the dependency between the "core"
-- module and the "invoices" module, allowing for example
-- for several different invoices modules.
--

create table im_project_invoice_map (
	project_id		integer not null 
				constraint im_proj_inv_map_project
				references im_projects,
	invoice_id		integer not null 
				constraint im_proj_inv_map_invoice
				references im_invoices
);

-- keep the project-invoice-map clean!
create unique index im_project_invoice_map_idx on im_project_invoice_map (
	project_id, 
	invoice_id
);


------------------------------------------------------
-- Views to Business Objects
--


-- all invoices that are not deleted (600) nor that have
-- been lost during creation (612).
create or replace view im_invoices_active as 
select i.*
from im_invoices i
where i.invoice_status_id not in (600, 612);


create or replace view im_invoice_templates as 
select 
	category_id as invoice_template_id, 
	category as invoice_template, 
	category_description as invoice_template_description
from im_categories 
where category_type = 'Intranet Invoice Template';

create or replace view im_invoice_status as 
select
	category_id as invoice_status_id, 
	category as invoice_status
from im_categories 
where category_type = 'Intranet Invoice Status' and
	category_id not in (600, 612);

create or replace view im_invoice_type as 
select category_id as invoice_type_id, category as invoice_type
from im_categories 
where category_type = 'Intranet Invoice Type';

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
-- Procedures
--


-- Calculate a match value between a price list item and an invoice_item
-- The higher the match value the better the fit.
create or replace function im_calculate_price_relevancy ( 
	v_price_customer_id IN integer,		v_item_customer_id IN integer,
	v_price_task_type_id IN integer,	v_item_task_type_id IN integer,
	v_price_subject_area_id IN integer,	v_item_subject_area_id IN integer,
	v_price_target_language_id IN integer,	v_item_target_language_id IN integer,
	v_price_source_language_id IN integer,	v_item_source_language_id IN integer
)
RETURN number IS
	match_value		number;
BEGIN
	match_value := 0;

	if v_price_task_type_id = v_item_task_type_id then
	match_value := match_value + 4;
	end if;
	if not(v_price_task_type_id is null) and v_price_task_type_id != v_item_task_type_id then
	match_value := match_value - 4;
	end if;
	if v_price_source_language_id = v_item_source_language_id then
	match_value := match_value + 3;
	end if;
	if not(v_price_source_language_id is null) and v_price_source_language_id != v_item_source_language_id then
	match_value := match_value - 10;
	end if;
	if v_price_target_language_id = v_item_target_language_id then
	match_value := match_value + 2;
	end if;
	if not(v_price_target_language_id is null) and v_price_target_language_id != v_item_target_language_id then
	match_value := match_value - 10;
	end if;
	if v_price_subject_area_id = v_item_subject_area_id then
	match_value := match_value + 1;
	end if;
	if not(v_price_subject_area_id is null) and v_price_subject_area_id != v_item_subject_area_id then
	match_value := match_value - 10;
	end if;
	if v_price_customer_id = v_item_customer_id then
	match_value := (match_value + 6)*2;
	end if;
	if v_price_customer_id = 17 then
	match_value := match_value + 1;
	end if;
	if v_price_customer_id != 17 and v_price_customer_id != v_item_customer_id then
	match_value := match_value -10;
	end if;
	return match_value;
END;
/
show errors;

-- Calculate the price for a task_type/customer
create or replace function im_invoice_calculate_price ( 
	v_customer_id IN integer,
	v_project_id IN integer,
	v_task_type_id IN integer,
	v_task_uom_id IN integer
)
RETURN number IS
BEGIN
	if v_task_uom_id = 320 then
	return 30.00;
	end if;
	if v_task_uom_id = 324 then
	return 0.085;
	end if;
	return 1.000;
END;
/
show errors;

-- What currency to use?
create or replace function im_invoice_calculate_currency (v_customer_id IN integer)
RETURN varchar IS
BEGIN
	return 'EUR';
END;
/
show errors;




-- Invoice Views
--
insert into im_views (view_id, view_name, visible_for) 
values (30, 'invoice_list', 'view_finance');
insert into im_views (view_id, view_name, visible_for) 
values (31, 'invoice_new', 'view_finance');
insert into im_views (view_id, view_name, visible_for) 
values (32, 'payment_list', 'view_finance');



-- Invoice List Page
--
delete from im_view_columns where column_id > 3000 and column_id < 3099;
--
insert into im_view_columns values (3001,30,NULL,'Invoice #',
'"<A HREF=/intranet-invoices/view?invoice_id=$invoice_id>$invoice_nr</A>"',
'','',1,'');

insert into im_view_columns values (3003,30,NULL,'Preview',
'"<A HREF=/intranet-invoices/view?invoice_id=$invoice_id${amp}render_template_id=$invoice_template_id>
$invoice_nr</A>"','','',2,'');

insert into im_view_columns values (3005,30,NULL,'Client',
'"<A HREF=/intranet/customers/view?customer_id=$customer_id>$customer_name</A>"',
'','',3,'');

insert into im_view_columns values (3007,30,NULL,'Due Date',
'[if {$overdue > 0} {
	set t "<font color=red>$due_date_calculated</font>"
} else {
	set t "$due_date_calculated"
}]','','',4,'');

insert into im_view_columns values (3011,30,NULL,'Amount',
'$invoice_amount_formatted $invoice_currency','','',6,'');

insert into im_view_columns values (3013,30,NULL,'Paid',
'$payment_amount $payment_currency','','',7,'');

insert into im_view_columns values (3017,30,NULL,'Status',
'[im_invoice_status_select "invoice_status.$invoice_id" $invoice_status_id]','','',13,'');

insert into im_view_columns values (3098,30,NULL,'Del',
'[if {[string equal "" $payment_amount]} {
	set ttt "<input type=checkbox name=del_invoice value=$invoice_id>"
}]','','',99,'');

--
commit;


-- Invoice New Page (shows Projects)
--
delete from im_view_columns where column_id > 3100 and column_id < 3199;
--
insert into im_view_columns values (3101,31,NULL,'Project #',
'"<A HREF=/intranet/projects/view?project_id=$project_id>$project_nr</A>"','','',1,'');
insert into im_view_columns values (3103,31,NULL,'Client',
'"<A HREF=/intranet/customers/view?customer_id=$customer_id>$customer_name</A>"','','',2,'');
insert into im_view_columns values (3107,31,NULL,'Project Name','$project_name','','',4,'');
insert into im_view_columns values (3109,31,NULL,'Type','$project_type','','',5,'');
insert into im_view_columns values (3111,31,NULL,'Status','$project_status','','',6,'');
insert into im_view_columns values (3113,31,NULL,'Delivery Date','$end_date','','',7,'');
insert into im_view_columns values (3115,31,NULL,'Sel',
'"<input type=checkbox name=select_project value=$project_id>"',
'','',8,'');

--
commit;


-- Invoice Status
delete from im_categories where category_id >= 600 and category_id < 700;
INSERT INTO im_categories VALUES (600,'In Process',
'Needs pruning periodically.',
'Intranet Invoice Status','category','t','f');
INSERT INTO im_categories VALUES (602,'Created',
'Set after the successful creation',
'Intranet Invoice Status','category','t','f');
INSERT INTO im_categories VALUES (604,'Outstanding',
'Set after sending the invoice to the client',
'Intranet Invoice Status','category','t','f');
INSERT INTO im_categories VALUES (606,'Past Due',
'Set when an outstanding invoice gets past due',
'Intranet Invoice Status','category','t','f');
INSERT INTO im_categories VALUES (608,'Partially Paid',
'','Intranet Invoice Status','category','t','f');
INSERT INTO im_categories VALUES (610,'Paid',
'','Intranet Invoice Status','category','t','f');
INSERT INTO im_categories VALUES (612,'Deleted',
'','Intranet Invoice Status','category','t','f');
INSERT INTO im_categories VALUES (614,'Filed',
'','Intranet Invoice Status','category','t','f');
-- reserved until 699




-- Invoice Type
delete from im_categories where category_id >= 700 and category_id < 800;
INSERT INTO im_categories VALUES (700,'Normal','','Intranet Invoice Type','category','t','f');
-- reserved until 799


-- Invoice Payment Method
delete from im_categories where category_id >= 800 and category_id < 900;
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

-- Invoice Templates
delete from im_categories where category_id >= 900 and category_id < 1000;
INSERT INTO im_categories VALUES (900,'invoice-english.adp','','Intranet Invoice Template','category','t','f');
INSERT INTO im_categories VALUES (902,'invoice-spanish.adp','','Intranet Invoice Template','category','t','f');
-- reserved until 999

-- Payment Type
delete from im_categories where category_id >= 1000 and category_id < 1100;
INSERT INTO im_categories VALUES (1000,'Bank Transfer','','Intranet Payment Type','category','t','f');
INSERT INTO im_categories VALUES (1002,'Cheque','','Intranet Payment Type','category','t','f');
commit;
-- reserved until 1099


---------------------------------------------------------
-- Register the component in the core TCL pages
--
-- These DB-entries allow the pages of Project/Open Core
-- to render the forum components in the Home, Users, Projects
-- and Customer pages.
--
-- The TCL code in the "component_tcl" field is executed
-- via "im_component_bay" in an "uplevel" statemente, exactly
-- as if it would be written inside the .adp <%= ... %> tag.
-- I know that's relatively dirty, but TCL doesn't provide
-- another way of "late binding of component" ...


-- delete potentially existing menus and plugins if this
-- file is sourced multiple times during development...

BEGIN
    im_component_plugin.del_module(module_name => 'intranet-invoices');
    im_menu.del_module(module_name => 'intranet-invoices');
END;
/
commit;


-- Setup the "Invoice" main menu entry
--
declare
        -- Menu IDs
        v_menu                  integer;
        v_main_menu 	        integer;
	v_invoices_menu		integer;

        -- Groups
        v_employees             integer;
        v_accounting            integer;
        v_senman                integer;
        v_customers             integer;
        v_freelancers           integer;
        v_proman                integer;
        v_admins                integer;
begin

    select group_id into v_admins from groups where group_name = 'P/O Admins';
    select group_id into v_senman from groups where group_name = 'Senior Managers';
    select group_id into v_accounting from groups where group_name = 'Accounting';
    select group_id into v_customers from groups where group_name = 'Customers';
    select group_id into v_freelancers from groups where group_name = 'Freelancers';

    select menu_id
    into v_main_menu
    from im_menus
    where url='/';

    v_invoices_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices',
	name =>		'Invoices',
	url =>		'/intranet-invoices/',
	sort_order =>	80,
	parent_menu_id => v_main_menu
    );

    acs_permission.grant_permission(v_invoices_menu, v_admins, 'read');
    acs_permission.grant_permission(v_invoices_menu, v_senman, 'read');
    acs_permission.grant_permission(v_invoices_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_invoices_menu, v_customers, 'read');
    acs_permission.grant_permission(v_invoices_menu, v_freelancers, 'read');

    -- -----------------------------------------------------
    -- Invoices Submenus
    -- -----------------------------------------------------

    -- needs to be the first submenu in order to get selected
    v_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_list',
	name =>		'Invoices',
	url =>		'/intranet-invoices/index',
	sort_order =>	10,
	parent_menu_id => v_invoices_menu
    );
    acs_permission.grant_permission(v_menu, v_admins, 'read');
    acs_permission.grant_permission(v_menu, v_senman, 'read');
    acs_permission.grant_permission(v_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_menu, v_customers, 'read');
    acs_permission.grant_permission(v_menu, v_freelancers, 'read');


    v_menu := im_menu.new (
	package_name =>	'intranet-invoices',
	label =>	'invoices_new',
	name =>		'New Invoice',
	url =>		'/intranet-invoices/new',
	sort_order =>	80,
	parent_menu_id => v_invoices_menu
    );
    acs_permission.grant_permission(v_menu, v_admins, 'read');
    acs_permission.grant_permission(v_menu, v_senman, 'read');
    acs_permission.grant_permission(v_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_menu, v_customers, 'read');
end;
/
commit;
	

-- Show the invoice component in project page
--
declare
    v_plugin            integer;
begin
    v_plugin := im_component_plugin.new (
	plugin_name =>	'Project Invoice Component',
	package_name =>	'intranet-invoices',
        page_url =>     '/intranet/projects/view',
        location =>     'right',
        sort_order =>   10,
        component_tcl => 
	'im_table_with_title "Invoices" \
		[im_invoice_component \
			$user_id \
			$project_id
		]'
    );
end;
/
commit;


