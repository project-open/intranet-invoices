-- /packages/intranet-invoices/sql/oracle/intranet-invoices-drop.sql
--
-- Copyright (C) 2003-2004 Project/Open
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


BEGIN
    im_component_plugin.del_module(module_name => 'intranet-invoices');
    im_menu.del_module(module_name => 'intranet-invoices');
END;
/
commit;

delete from acs_permissions where privilege = 'view_invoices';
delete from acs_permissions where privilege = 'add_invoices';
delete from acs_permissions where privilege = 'view_finance';
delete from acs_permissions where privilege = 'add_invoices';

BEGIN
	acs_privilege.remove_child('admin', 'view_invoices');
	acs_privilege.remove_child('admin', 'add_invoices');
	acs_privilege.remove_child('admin', 'view_finance');
	acs_privilege.remove_child('admin', 'add_finance');

	acs_privilege.drop_privilege ('view_invoices');
	acs_privilege.drop_privilege ('add_invoices');
	acs_privilege.drop_privilege ('view_finance');
	acs_privilege.drop_privilege ('add_invoices');
END;
/
commit;


delete from im_biz_object_urls where object_type='im_invoice';

begin
	acs_object_type.drop_type('im_invoice', 'f');
end;
/
show errors

delete from acs_rels r where r.object_id_two in (select invoice_id from im_invoices);
delete from im_invoice_items;
delete from im_invoices;

delete from im_view_columns where view_id >= 30 and view_id <=39;
delete from im_views where view_id >= 30 and view_id <=39;

-- drop sequence im_invoices_seq;
drop sequence im_invoice_items_seq;

drop table im_invoice_items;

-- drop table im_invoices_audit;
drop view im_invoices_active;
drop table im_invoices;

BEGIN
    acs_rel_type.drop_type('im_invoice');
END;
/

