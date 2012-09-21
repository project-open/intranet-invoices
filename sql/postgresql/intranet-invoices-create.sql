-- /package/intranet-invoices/sql/postgresql/intranet-invoices-create.sql
--
-- Copyright (c) 2003-2008 ]project-open[
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
--
-- Projects <-> Invoices Map
--
-- Several projects may be invoiced in a single invoice,
-- while a single project may be invoices several times,
-- particularly if it is a big project.
--
-- acs_rels: object_id_one=project_id, object_id_two=invoice_id



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

\i ../common/intranet-invoices-common.sql


---------------------------------------------------------
-- Invoice Object
---------------------------------------------------------

-- Nothing spectactular, just to be able to use acs_rels
-- between projects and invoices and to add custom fields
-- later. We are not even going to use the permission
-- system right now.

select acs_object_type__create_type (
	'im_invoice',		-- object_type
	'Invoice',		-- pretty_name
	'Invoices',		-- pretty_plural
	'im_cost',		-- supertype
	'im_invoices',		-- table_name
	'invoice_id',		-- id_column
	'im_invoice',		-- package_name
	'f',			-- abstract_p
	null,			-- type_extension_table
	'im_invoice.name'	-- name_method
);

update acs_object_types set
	status_type_table = 'im_costs',
	status_column = 'cost_status_id',
	type_column = 'cost_type_id'
where object_type = 'im_invoice';


insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_invoice', 'im_invoices', 'invoice_id');
insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_invoice', 'im_costs', 'cost_id');



create table im_invoices (
	invoice_id		integer
				constraint im_invoices_pk
				primary key
				constraint im_invoices_id_fk
				references im_costs,
	company_contact_id	integer 
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
				references im_invoices,
	invoice_office_id	integer
				constraint im_invoices_office_fk
				references im_offices,

	-- discount and surcharge. These values are applied to the 
	-- subtotal from the invoice lines in order to form the amount
	discount_text		text,
	discount_perc		numeric(12,2) default 0,
	surcharge_text		text,
	surcharge_perc		numeric(12,2) default 0,

	-- deadlines are for invoices with a sliding windows
	-- of time, counted from the start_date.
	deadline_start_date	timestamptz,
	deadline_interval	interval
);



-----------------------------------------------------------
-- Invoice Items
--
-- -	Invoice items reflect the very fuzzy structure of invoices,
--	that may contain basically everything that fits in one line
--	and has a price.
-- -	Invoice items can created manually or generated from
--	"invoicable items".
-- All fields (number of units, price, description) need to be 
-- human editable because invoicing is so messy...



-- Create a fake object type, because im_invoice_item does not
-- "reference" acs_objects.
select acs_object_type__create_type (
	'im_invoice_item',	-- object_type
	'Invoice Item',		-- pretty_name
	'Invoice Items',	-- pretty_plural
	'acs_object',		-- supertype
	'im_invoice_items',	-- table_name
	'item_id',		-- id_column
	'intranet-invoices',	-- package_name
	'f',			-- abstract_p
	null,			-- type_extension_table
	'im_invoice_item__name'	-- name_method
);

update acs_object_types set
	status_type_table = 'im_invoice_items',
	status_column = 'item_status_id',
	type_column = 'item_type_id'
where object_type = 'im_invoice_item';


-- Do not show autmatic links to invoice items at the moment.
-- insert into acs_object_type_tables (object_type,table_name,id_column)
-- values ('im_invoice', 'im_invoices', 'invoice_id');
-- insert into acs_object_type_tables (object_type,table_name,id_column)
-- values ('im_invoice', 'im_costs', 'cost_id');




create sequence im_invoice_items_seq start 1;
create table im_invoice_items (
	item_id			integer
				constraint im_invoices_items_pk
				primary key,
	item_name		text,
				-- not being used yet (V3.0.0).
				-- reserved for adding a reference nr for items
				-- from a catalog or similar
	item_nr			text,
				-- project_id if != null is used to access project details
				-- for invoice generation, such as the company PO# etc.
	project_id		integer
				constraint im_invoices_items_project
				references im_projects,
	invoice_id		integer not null 
				constraint im_invoices_items_invoice
				references im_invoices,
	item_units		numeric(12,1),
	item_uom_id		integer not null 
				constraint im_invoices_items_uom
				references im_categories,
	price_per_unit 		numeric(12,3),
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
	item_material_id	integer
				constraint im_invoice_items_item_material_fk
				references im_materials,
				-- include in VAT calculation?
	apply_vat_p		char(1) default('t')
				constraint im_invoices_apply_vat_p
				check (apply_vat_p in ('t','f')),
	description		text,
				-- Reference for cases where we want to link a copy
				-- back to the original
	created_from_item_id	integer
				constraint im_invoice_items_created_from_fk
				references im_invoice_items,
		-- Make sure we can''t create duplicate entries per invoice
		constraint im_invoice_items_un
		unique (item_name, invoice_id, project_id, sort_order, item_uom_id)
);


------------------------------------------------------
-- Permissions and Privileges
--

select acs_privilege__create_privilege('view_invoices','View Invoices','View Invoices');
select acs_privilege__add_child('admin', 'view_invoices');

select acs_privilege__create_privilege('add_invoices','View Invoices','View Invoices');
select acs_privilege__add_child('admin', 'add_invoices');

select acs_privilege__create_privilege('view_finance','View finance','View finanace');
select acs_privilege__add_child('admin', 'view_finance');

select acs_privilege__create_privilege('add_finance','Add finance','Add finance');
select acs_privilege__add_child('admin', 'add_finance');


select im_priv_create('view_invoices','Accounting');
select im_priv_create('view_invoices','P/O Admins');
select im_priv_create('view_invoices','Senior Managers');

select im_priv_create('add_invoices','Accounting');
select im_priv_create('add_invoices','P/O Admins');
select im_priv_create('add_invoices','Senior Managers');


------------------------------------------------------
-- Views to Business Objects
--
-- all invoices that are not deleted (600) nor that have
-- been lost during creation (612).
create or replace view im_invoices_active as 
select	i.*,
	ci.*,
	to_date(to_char(ci.effective_date,'YYYY-MM-DD'),'YYYY-MM-DD') + ci.payment_days as due_date,
	ci.effective_date as invoice_date,
	ci.cost_status_id as invoice_status_id,
	ci.cost_type_id as invoice_type_id,
	ci.template_id as invoice_template_id
from 
	im_invoices i,
	im_costs ci
where
	ci.cost_id = i.invoice_id
	and ci.cost_status_id not in (3812);


create or replace view im_payment_type as 
select category_id as payment_type_id, category as payment_type
from im_categories 
where category_type = 'Intranet Payment Type';

create or replace view im_invoice_payment_method as 
select	category_id as payment_method_id, 
	category as payment_method, 
	category_description as payment_description
from im_categories 
where category_type = 'Intranet Invoice Payment Method';



-- -------------------------------------------------------------
-- Canned Notes Category Space
--
-- 11600-11699	Intranet Invoice Canned Notes

create or replace view im_invoice_canned_notes as
select	category_id as canned_note_id,
	category as canned_note_category,
	aux_string1 as canned_note
from im_categories
where category_type = 'Intranet Invoice Canned Notes';


select im_dynfield_attribute__new (
	null,			-- widget_id
	'im_dynfield_attribute', -- object_type
	now(),			-- creation_date
	null,			-- creation_user
	null,			-- creation_ip
	null,			-- context_id

	'im_invoice',		-- attribute_object_type
	'canned_note_id',	-- attribute name
	0,
	0,
	null,
	'integer',
	'#intranet-invoices.Canned_Note#',	-- pretty name
	'#intranet-invoices.Canned_Note#',	-- pretty plural
	'integer',		-- Widget (dummy)
	'f',
	'f'
);


SELECT im_category_new(11600, 'Dummy Canned Note', 'Intranet Invoice Canned Note');
SELECT im_category_new(11602, '2nd Dummy Canned Note', 'Intranet Invoice Canned Note');
SELECT im_category_new(11604, '3rd Dummy Canned Note', 'Intranet Invoice Canned Note');
SELECT im_category_new(11606, '4th Dummy Canned Note', 'Intranet Invoice Canned Note');
-- reserved through 11699



-- -------------------------------------------------------------
-- Helper function

create or replace function im_invoice_nr_from_id (integer)
returns varchar as '
DECLARE
	p_id	alias for $1;
	v_name	varchar;
BEGIN
	select i.invoice_nr into v_name from im_invoices i
	where invoice_id = p_id;

	return v_name;
end;' language 'plpgsql';




-- create or replace package body im_invoice
-- is
create or replace function im_invoice__new (
	integer, varchar, timestamptz, integer, varchar, integer,
	varchar, integer, integer, integer, timestamptz, char(3),
	integer, integer, integer, integer, integer, numeric,
	numeric, numeric, varchar
) returns integer as '
declare
	p_invoice_id		alias for $1;		-- invoice_id default null
	p_object_type		alias for $2;		-- object_type default ''im_invoice''
	p_creation_date		alias for $3;		-- creation_date default now()
	p_creation_user		alias for $4;		-- creation_user
	p_creation_ip		alias for $5;		-- creation_ip default null
	p_context_id		alias for $6;		-- context_id default null
	p_invoice_nr		alias for $7;		-- invoice_nr
	p_company_id		alias for $8;		-- company_id
	p_provider_id		alias for $9;		-- provider_id
	p_company_contact_id	alias for $10;		-- company_contact_id default null
	p_invoice_date		alias for $11;		-- invoice_date now()
	p_invoice_currency	alias for $12;		-- invoice_currency default ''EUR''
	p_invoice_template_id	alias for $13;		-- invoice_template_id default null
	p_invoice_status_id	alias for $14;		-- invoice_status_id default 602
	p_invoice_type_id	alias for $15;		-- invoice_type_id default 700
	p_payment_method_id	alias for $16;		-- payment_method_id default null
	p_payment_days		alias for $17;		-- payment_days default 30
	p_amount		alias for $18;		-- amount
	p_vat			alias for $19;		-- vat default 0
	p_tax			alias for $20;		-- tax default 0
	p_note			alias for $21;		-- note

	v_invoice_id		integer;
	begin
	v_invoice_id := im_cost__new (
		p_invoice_id,		-- cost_id
		p_object_type,		-- object_type
		p_creation_date,	-- creation_date
		p_creation_user,	-- creation_user
		p_creation_ip,		-- creation_ip
		p_context_id,		-- context_id
		
		p_invoice_nr,		-- cost_name
		null,			-- parent_id
		null,			--	project_id
		p_company_id,		-- company_id
		p_provider_id,		-- provider_id
		null,			-- investment_id
		
		p_invoice_status_id, -- cost_status_id
		p_invoice_type_id,	-- cost_type_id
		p_invoice_template_id,	-- template_id
		
		p_invoice_date,		-- effective_date
		p_payment_days,		-- payment_days
		p_amount,		-- amount
		p_invoice_currency,	-- currency
		p_vat,			-- vat
		p_tax,			-- tax

		''f'',			-- variable_cost_p
		''f'',			-- needs_redistribution_p
		''f'',			-- redistributed_p
		''f'',			-- planning_p
		null,			-- planning_type_id

		p_note,			-- note
		null			-- description
	);

	insert into im_invoices (
		invoice_id,
		company_contact_id, 
		invoice_nr,
		payment_method_id
	) values (
		v_invoice_id,
		p_company_contact_id, 
		p_invoice_nr,
		p_payment_method_id
	);

	return v_invoice_id;
end;' language 'plpgsql';

-- Delete a single invoice (if we know its ID...)
create or replace function im_invoice__delete (integer)
returns integer as '
declare
	p_invoice_id alias for $1;	-- invoice_id
begin
	-- Erase the im_invoice_item associated with the id
	delete from 	im_invoice_items
	where		invoice_id = p_invoice_id;

	-- Delete canned notes values
	delete from 	im_dynfield_attr_multi_value
	where		object_id = p_invoice_id;

	-- Erase the invoice itself
	delete from 	im_invoices
	where		invoice_id = p_invoice_id;

	-- Erase the CostItem
	PERFORM im_cost__delete(p_invoice_id);
	return 0;
end;' language 'plpgsql';

create or replace function im_invoice__name (integer)
returns varchar as '
declare
	p_invoice_id alias for $1;	-- invoice_id
	v_name	varchar;
begin
	select	invoice_nr
	into	v_name
	from	im_invoices
	where	invoice_id = p_invoice_id;

	return v_name;
end;' language 'plpgsql';





---------------------------------------------------------
-- Invoice Menus
--
-- delete potentially existing menus and plugins if this
-- file is sourced multiple times during development...
-- delete the intranet-payments menus because they are 
-- located below intranet-invoices modules and would
-- cause a RI error.

create or replace function inline_0 ()
returns integer as '
declare
	-- Menu IDs
	v_menu			integer;
	v_main_menu 		integer;
	v_finance_menu		integer;

	-- Groups
	v_employees	integer;
	v_accounting	integer;
	v_senman	integer;
	v_customers	integer;
	v_freelancers	integer;
	v_proman		integer;
	v_admins		integer;
begin
	select group_id into v_admins from groups where group_name = ''P/O Admins'';
	select group_id into v_senman from groups where group_name = ''Senior Managers'';
	select group_id into v_accounting from groups where group_name = ''Accounting'';
	select group_id into v_customers from groups where group_name = ''Customers'';
	select group_id into v_freelancers from groups where group_name = ''Freelancers'';

	select menu_id into v_finance_menu from im_menus
	where label=''finance'';

	-- -----------------------------------------------------
	-- Invoices Submenu
	-- -----------------------------------------------------

	-- needs to be the first submenu in order to get selected
	v_menu := im_menu__new (
		null,				-- menu_id
		''acs_object'',			-- object_type
		now(),				-- creation_date
		null,				-- creation_user
		null,				-- creation_ip
		null,				-- context_id
		''intranet-invoices'',		-- package_name
		''invoices_customers'',		-- label
		''Customers'',			-- name
		''/intranet-invoices/list?cost_type_id=3708'',	-- url
		10,						-- sort_order
		v_finance_menu,					-- parent_menu_id
		null						-- visible_tcl
	);
	PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_customers, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_freelancers, ''read'');


	v_menu := im_menu__new (
		null,				-- menu_id
		''acs_object'',			-- object_type
		now(),				-- creation_date
		null,				-- creation_user
		null,				-- creation_ip
		null,				-- context_id
		''intranet-invoices'',		-- package_name
		''invoices_providers'',		-- label
		''Providers'',			-- name
		''/intranet-invoices/list?cost_type_id=3710'',	-- url
		20,						-- sort_order
		v_finance_menu,					-- parent_menu_id
		null						-- visible_tcl
	);
	PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_customers, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_freelancers, ''read'');
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();


-- Setup the "Invoices New" admin menu for Company Documents
--
create or replace function inline_0 ()
returns integer as '
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

	select group_id into v_admins from groups where group_name = ''P/O Admins'';
	select group_id into v_senman from groups where group_name = ''Senior Managers'';
	select group_id into v_accounting from groups where group_name = ''Accounting'';
	select group_id into v_customers from groups where group_name = ''Customers'';
	select group_id into v_freelancers from groups where group_name = ''Freelancers'';

	select menu_id into v_invoices_new_menu from im_menus
	where label=''invoices_customers'';

	v_finance_menu := im_menu__new (
		null,			-- menu_id
		''acs_object'',		-- object_type
		now(),			-- creation_date
		null,			-- creation_user
		null,			-- creation_ip
		null,			-- context_id
		''intranet-invoices'',		-- package_name
		''invoices_customers_new_invoice'',	-- label
		''New Customer Invoice from scratch'',	-- name
		''/intranet-invoices/new?cost_type_id=3700'',	-- url
		310,						-- sort_order
		v_invoices_new_menu,				-- parent_menu_id
		null						-- visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');

	v_finance_menu := im_menu__new (
		null,				-- menu_id
		''acs_object'',			-- object_type
		now(),				-- creation_date
		null,				-- creation_user
		null,				-- creation_ip
		null,				-- context_id
		''intranet-invoices'',		-- package_name
		''invoices_customers_new_invoice_from_quote'',	-- label
		''New Customer Invoice from Quote'',		-- name
		''/intranet-invoices/new-copy?target_cost_type_id=3700\&source_cost_type_id=3702'',
		320,				-- sort_order
		v_invoices_new_menu,		-- parent_menu_id
		null				-- visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');

	v_finance_menu := im_menu__new (
		null,					-- menu_id
		''acs_object'',				-- object_type
		now(),					-- creation_date
		null,					-- creation_user
		null,					-- creation_ip
		null,					-- context_id
		''intranet-invoices'',			-- package_name
		''invoices_customers_new_quote'',	-- label
		''New Quote from scratch'',		-- name
		''/intranet-invoices/new?cost_type_id=3702'',	-- url
		110,						-- sort_order
		v_invoices_new_menu,				-- parent_menu_id
		null						-- visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();


-- Setup the "Invoices New" admin menu for Company Documents
--
create or replace function inline_0 ()
returns integer as '
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
	select group_id into v_admins from groups where group_name = ''P/O Admins'';
	select group_id into v_senman from groups where group_name = ''Senior Managers'';
	select group_id into v_accounting from groups where group_name = ''Accounting'';
	select group_id into v_customers from groups where group_name = ''Customers'';
	select group_id into v_freelancers from groups where group_name = ''Freelancers'';

	select menu_id into v_invoices_new_menu from im_menus
	where label=''invoices_providers'';

	v_finance_menu := im_menu__new (
		null,				-- menu_id
		''acs_object'',			-- object_type
		now(),				-- creation_date
		null,				-- creation_user
		null,				-- creation_ip
		null,				-- context_id
		''intranet-invoices'',		-- package_name
		''invoices_providers_new_bill'', -- label
		''New Provider Bill from scratch'', -- name
		''/intranet-invoices/new?cost_type_id=3704'',	-- url
		410,				-- sort_order
		v_invoices_new_menu,		-- arent_menu_id
		null				-- visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');

	v_finance_menu := im_menu__new (
		null,					-- menu_id
		''acs_object'',				-- object_type
		now(),					-- creation_date
		null,					-- creation_user
		null,					-- creation_ip
		null,					-- context_id
		''intranet-invoices'',			-- package_name
		''invoices_providers_new_bill_from_po'',	-- label
		''New Provider Bill from Purchase Order'',	-- name
		''/intranet-invoices/new-copy?target_cost_type_id=3704\&source_cost_type_id=3706'',
		520,					-- sort_order
		v_invoices_new_menu,			-- parent_menu_id
		null					-- visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');

	v_finance_menu := im_menu__new (
		null,			-- menu_id
		''acs_object'',		-- object_type
		now(),			-- creation_date
		null,			-- creation_user
		null,			-- creation_ip
		null,			-- context_id
		''intranet-invoices'',		-- package_name
		''invoices_providers_new_po'',	-- label
		''New Purchase Order from scratch'',	-- name
		''/intranet-invoices/new?cost_type_id=3706'', -- url
		410,				-- sort_order
		v_invoices_new_menu,		-- parent_menu_id
		null				-- visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
	PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



-- New Quote from Quote
--
create or replace function inline_0 ()
returns integer as '
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

	v_count			integer;
begin
    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';
    select group_id into v_customers from groups where group_name = ''Customers'';
    select group_id into v_freelancers from groups where group_name = ''Freelancers'';

    select menu_id
    into v_invoices_new_menu
    from im_menus
    where label=''invoices_customers'';

    select count(*) into v_count from im_menus 
    where label = ''invoices_customers_new_quote_from_quote'';

    IF v_count = 0 THEN
	    v_finance_menu := im_menu__new (
		null,					-- menu_id
		''acs_object'',				-- object_type
		now(),					-- creation_date
		null,					-- creation_user
		null,					-- creation_ip
		null,					-- context_id
		''intranet-invoices'',			-- package_name
		''invoices_customers_new_quote_from_quote'',  	-- label
		''New Quote from Quote'',		-- name
		''/intranet-invoices/new-copy?target_cost_type_id=3702\&source_cost_type_id=3702'',
		120,					-- sort_order
		v_invoices_new_menu,			-- parent_menu_id
		null					-- visible_tcl
	    );

	    PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');
    END IF;

    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



create or replace function inline_0 ()
returns integer as '
declare
        v_menu                  integer;
        v_invoices_customers    integer;
        v_accounting            integer;
        v_senman                integer;
        v_admins                integer;
        v_count                 integer;
begin
    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';

    select menu_id into v_invoices_customers from im_menus where label=''invoices_customers'';
    select count(*) into v_count from im_menus
    where label = ''invoices_customers_new_invoice_from_delnote'';
    IF v_count = 0 THEN
            v_menu := im_menu__new (
                null,                      -- menu_id
                ''acs_object'',          -- object_type
                now(),                    -- creation_date
                null,                      -- creation_user
                null,                      -- creation_ip
                null,                      -- context_id
                ''intranet-invoices'',          -- package_name
                ''invoices_customers_new_invoice_from_delnote'',        -- label
                ''New Customer Invoice from Delivery Note'',    -- name
                ''/intranet-invoices/new-copy?target_cost_type_id=3700\&source_cost_type_id=3724'',
                325,                                            -- sort_order
                v_invoices_customers,                           -- parent_menu_id
                null                                            -- visible_tcl
            );
            PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
            PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
            PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
    END IF;
    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-- Setup new Menu links for PO and Delivery Note from scratch
-- and DelNote from Quote
--
create or replace function inline_0 ()
returns integer as '
declare
	-- Menu IDs
	v_menu			integer;
	v_invoices_providers	integer;
	v_invoices_customers	integer;

	-- Groups
	v_employees		integer;
	v_accounting		integer;
	v_senman		integer;
	v_customers		integer;
	v_freelancers		integer;
	v_proman		integer;
	v_admins		integer;

	v_count			integer;
begin

    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_proman from groups where group_name = ''Project Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';
    select group_id into v_employees from groups where group_name = ''Employees'';
    select group_id into v_customers from groups where group_name = ''Customers'';
    select group_id into v_freelancers from groups where group_name = ''Freelancers'';

    select menu_id into v_invoices_customers from im_menus
    where label=''invoices_customers'';

    select menu_id into v_invoices_providers from im_menus
    where label=''invoices_providers'';

    select count(*) into v_count from im_menus 
    where label = ''invoices_providers_new_po'';

    IF v_count = 0 THEN
	    v_menu := im_menu__new (
		null,						-- menu_id
		''acs_object'',					-- object_type
		now(),						-- creation_date
		null,						-- creation_user
		null,						-- creation_ip
		null,						-- context_id
		''intranet-invoices'',				-- package_name
		''invoices_providers_new_po'',			-- label
		''New Purchase Order from scratch'',		-- name
		''/intranet-invoices/new?cost_type_id=3706'',	-- url
		40,						-- sort_order
		v_invoices_providers,				-- parent_menu_id
		null						-- visible_tcl
	    );
	    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
	    PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
	    PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
    END IF;

    select count(*) into v_count from im_menus 
    where label = ''invoices_providers_new_delnote'';

    IF v_count = 0 THEN
	    v_menu := im_menu__new (
		null,			   -- menu_id
		''acs_object'',		 -- object_type
		now(),			  -- creation_date
		null,			   -- creation_user
		null,			   -- creation_ip
		null,			   -- context_id
		''intranet-invoices'',		-- package_name
		''invoices_providers_new_delnote'',	-- label
		''New Delivery Note from scratch'',	-- name
		''/intranet-invoices/new?cost_type_id=3724'',	-- url
		30,						-- sort_order
		v_invoices_customers,				-- parent_menu_id
		null						-- visible_tcl
	    );
	    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
	    PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
	    PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
    END IF;

    select count(*) into v_count from im_menus 
    where label = ''invoices_customers_new_delnote_from_quote'';

    IF v_count = 0 THEN
	    v_menu := im_menu__new (
		null,			   -- menu_id
		''acs_object'',		 -- object_type
		now(),			  -- creation_date
		null,			   -- creation_user
		null,			   -- creation_ip
		null,			   -- context_id
		''intranet-invoices'',		-- package_name
		''invoices_customers_new_delnote_from_quote'',	-- label
		''New Delivery Note from Quote'',		-- name
		''/intranet-invoices/new-copy?target_cost_type_id=3724\&source_cost_type_id=3702'',
		20,				-- sort_order
		v_invoices_customers,		-- parent_menu_id
		null				-- visible_tcl
	    );
	    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
	    PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
	    PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
    END IF;

    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-- Setup new Menu links for PO and Delivery Note from scratch
-- and DelNote from Quote
--
create or replace function inline_0 ()
returns integer as '
declare
	v_menu			integer;
	v_invoices_customers	integer;
	v_accounting		integer;
	v_senman		integer;
	v_admins		integer;
	v_count			integer;
begin
    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';

    select menu_id into v_invoices_customers from im_menus where label=''invoices_customers'';
    select count(*) into v_count from im_menus 
    where label = ''invoices_customers_new_invoice_from_delnote'';
    IF v_count = 0 THEN
	    v_menu := im_menu__new (
		null,			   -- menu_id
		''acs_object'',		 -- object_type
		now(),			  -- creation_date
		null,			   -- creation_user
		null,			   -- creation_ip
		null,			   -- context_id
		''intranet-invoices'',		-- package_name
		''invoices_customers_new_invoice_from_delnote'',	-- label
		''New Customer Invoice from Delivery Note'',	-- name
		''/intranet-invoices/new-copy?target_cost_type_id=3700\&source_cost_type_id=3724'',
		325,						-- sort_order
		v_invoices_customers,				-- parent_menu_id
		null						-- visible_tcl
	    );
	    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
	    PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
	    PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
    END IF;
    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();


-- Setup the "Invoices New" admin menu for Company Documents
--
create or replace function inline_0 ()
returns integer as '
declare
	-- Menu IDs
	v_menu		  integer;
	v_invoices_new_menu	 integer;
	v_finance_menu	  integer;

	-- Groups
	v_employees		 integer;
	v_accounting		integer;
	v_senman		integer;
	v_customers		 integer;
	v_freelancers	   integer;
	v_proman		integer;
	v_admins		integer;

	v_count			integer;
begin
    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';
    select group_id into v_customers from groups where group_name = ''Customers'';
    select group_id into v_freelancers from groups where group_name = ''Freelancers'';

    select menu_id into v_invoices_new_menu from im_menus
    where label=''invoices_providers'';

    select count(*) into v_count from im_menus 
    where label = ''invoices_providers_new_po'';

    IF v_count = 0 THEN
	    v_finance_menu := im_menu__new (
		null,					-- menu_id
		''acs_object'',				-- object_type
		now(),					-- creation_date
		null,					-- creation_user
		null,					-- creation_ip
		null,					-- context_id
		''intranet-invoices'',			-- package_name
		''invoices_providers_new_po'',  	-- label
		''New Purchase Order from scratch'',	-- name
		''/intranet-invoices/new?cost_type_id=3706'', -- url
		30,					-- sort_order
		v_invoices_new_menu,			-- parent_menu_id
		null					-- visible_tcl
	    );
	
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
	    PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');
    END IF;

    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();


-- -------------------------------------------------------------
-- Add a "category_invoice_template" widget to DynField Widgets
-- if not there already.
-- The new widget shows a list of templates.

create or replace function inline_0 ()
returns integer as '
declare
	v_count			integer;
begin
	select count(*)
	into v_count
	from im_dynfield_widgets
	where widget_name = ''category_invoice_template'';

	IF v_count = 0 THEN

		PERFORM im_dynfield_widget__new (
			null, ''im_dynfield_widget'', now()::date,
			null, null, null,
			''category_invoice_template'', ''Invoice Template'', ''Invoice Template'',
			10007, ''integer'', ''im_category_tree'', ''integer'',
			''{custom {category_type "Intranet Cost Template"}}''
		);
	END IF;

	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();





-- -------------------------------------------------------------
-- Add field default_quote_template_id to im_companies
-- Add new attributes to im_companies for default templates

create or replace function inline_0 ()
returns integer as '
declare
	v_attrib_name		varchar;
	v_attrib_pretty		varchar;
	v_acs_attrib_id		integer;
	v_attrib_id		integer;
	v_count			integer;
begin
	v_attrib_name := ''default_bill_template_id'';
	v_attrib_pretty := ''Default Provider Bill Template'';

	select count(*)	into v_count
	from acs_attributes
	where attribute_name = v_attrib_name;
	IF 0 != v_count THEN return 0; END IF;

	v_acs_attrib_id := acs_attribute__create_attribute (
		''im_company'',
		v_attrib_name,
		''integer'',
		v_attrib_pretty,
		v_attrib_pretty,
		''im_companies'',
		NULL, NULL, ''0'', ''1'',
		NULL, NULL, NULL
	);
	v_attrib_id := acs_object__new (
		null,
		''im_dynfield_attribute'',
		now(),
		null, null, null
	);
	insert into im_dynfield_attributes (
		attribute_id, acs_attribute_id, widget_name, deprecated_p
	) values (
		v_attrib_id, v_acs_attrib_id, ''category_invoice_template'', ''f''
	);
    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



create or replace function inline_0 ()
returns integer as '
declare
	v_attrib_name		varchar;
	v_attrib_pretty		varchar;
	v_acs_attrib_id		integer;
	v_attrib_id		integer;
	v_count			integer;
begin
	v_attrib_name := ''default_po_template_id'';
	v_attrib_pretty := ''Default PO Template'';

	select count(*)	into v_count
	from acs_attributes
	where attribute_name = v_attrib_name;
	IF 0 != v_count THEN return 0; END IF;

	v_acs_attrib_id := acs_attribute__create_attribute (
		''im_company'',
		v_attrib_name,
		''integer'',
		v_attrib_pretty,
		v_attrib_pretty,
		''im_companies'',
		NULL, NULL,
		''0'', ''1'',
		NULL, NULL,
		NULL
	);

	v_attrib_id := acs_object__new (
		null,
		''im_dynfield_attribute'',
		now(),
		null,
		null, 
		null
	);

	insert into im_dynfield_attributes (
		attribute_id, acs_attribute_id, widget_name, deprecated_p
	) values (
		v_attrib_id, v_acs_attrib_id, ''category_invoice_template'', ''f''
	);

    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();





create or replace function inline_0 ()
returns integer as '
declare
	v_attrib_name		varchar;
	v_attrib_pretty		varchar;
	v_acs_attrib_id		integer;
	v_attrib_id		integer;
	v_count			integer;
begin
	v_attrib_name := ''default_delnote_template_id'';
	v_attrib_pretty := ''Default Delivery Note Template'';

	select count(*)	into v_count
	from acs_attributes
	where attribute_name = v_attrib_name;
	IF 0 != v_count THEN return 0; END IF;

	v_acs_attrib_id := acs_attribute__create_attribute (
		''im_company'',
		v_attrib_name,
		''integer'',
		v_attrib_pretty,
		v_attrib_pretty,
		''im_companies'',
		NULL, NULL,
		''0'', ''1'',
		NULL, NULL,
		NULL
	);

	v_attrib_id := acs_object__new (
		null,
		''im_dynfield_attribute'',
		now(),
		null,
		null, 
		null
	);

	insert into im_dynfield_attributes (
		attribute_id, acs_attribute_id, widget_name, deprecated_p
	) values (
		v_attrib_id, v_acs_attrib_id, ''category_invoice_template'', ''f''
	);

    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();





-- -------------------------------------------------------------
-- Set permissions for menus

update im_menus
set visible_tcl = '[im_cost_type_write_p $user_id 3700]'
where label = 'invoices_customers_new_invoice';


update im_menus
set visible_tcl = '[im_cost_type_write_p $user_id 3700]'
where label = 'invoices_customers_new_invoice_from_quote';


update im_menus
set visible_tcl = '[im_cost_type_write_p $user_id 3702]'
where label = 'invoices_customers_new_quote';


update im_menus
set visible_tcl = '[im_cost_type_write_p $user_id 3704]'
where label = 'invoices_providers_new_bill_from_po';


update im_menus
set visible_tcl = '[im_cost_type_write_p $user_id 3704]'
where label = 'invoices_providers_new_bill';





-- -------------------------------------------------------------
-- Load other files

\i ../common/intranet-invoices-backup.sql

