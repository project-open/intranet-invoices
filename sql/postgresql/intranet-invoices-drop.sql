-- /packages/intranet-invoices/sql/oracle/intranet-invoices-drop.sql
--
-- Copyright (C) 2003 - 2009 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


-- BEGIN
    select im_component_plugin__del_module('intranet-invoices');
    select im_menu__del_module('intranet-invoices');
-- END;
-- 
-- commit;
-- before remove priviliges remove granted permissions
create or replace function inline_revoke_permission (varchar)
returns integer as '
DECLARE
        p_priv_name     alias for $1;
BEGIN
     lock table acs_permissions_lock;

     delete from acs_permissions
     where privilege = p_priv_name;

     delete from acs_privilege_hierarchy 
     where child_privilege = p_priv_name;
     
     return 0;

end;' language 'plpgsql';


-- begin
   select inline_revoke_permission ('view_invoices');
   select acs_privilege__drop_privilege ('view_invoices');
   select inline_revoke_permission ('add_invoices');
   select acs_privilege__drop_privilege ('add_invoices');
   select inline_revoke_permission ('view_finance');
   select acs_privilege__drop_privilege ('view_finance');
   select inline_revoke_permission ('add_finance');
   select acs_privilege__drop_privilege ('add_finance');
-- end;

delete from im_biz_object_urls where object_type='im_invoice';

delete from acs_rels where object_id_two in (select invoice_id from im_invoices);
delete from im_invoice_items;
delete from im_payments where cost_id in (select invoice_id from im_invoices);
delete from im_costs where cost_id in (select invoice_id from im_invoices); 
delete from im_invoices;
delete from acs_objects where object_type = 'im_invoice';
select acs_object_type__drop_type('im_invoice', 'f');

delete from im_view_columns where view_id >= 30 and view_id <=39;
delete from im_views where view_id >= 30 and view_id <=39;

-- drop sequence im_invoices_seq;
drop sequence im_invoice_items_seq;

drop table im_invoice_items;

-- drop table im_invoices_audit;
drop view im_invoices_active;
drop table im_invoices;


