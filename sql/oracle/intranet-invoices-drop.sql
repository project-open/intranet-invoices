-- Copyright (C) 1999-2004 ArsDigita, Frank Bergmann and others
--
-- This program is free software. You can redistribute it 
-- and/or modify it under the terms of the GNU General 
-- Public License as published by the Free Software Foundation; 
-- either version 2 of the License, or (at your option) 
-- any later version. This program is distributed in the 
-- hope that it will be useful, but WITHOUT ANY WARRANTY; 
-- without even the implied warranty of MERCHANTABILITY or 
-- FITNESS FOR A PARTICULAR PURPOSE. 
-- See the GNU General Public License for more details.


BEGIN
    im_component_plugin.del_module(module_name => 'intranet-invoices');
    im_menu.del_module(module_name => 'intranet-invoices');
END;
/
commit;

delete from im_project_invoice_map;
delete from im_invoice_items;
delete from im_invoices;

delete from im_view_columns where view_id >= 30 and view_id <=39;
delete from im_views where view_id >= 30 and view_id <=39;


drop sequence im_prices_seq;
drop sequence im_invoices_seq;
drop sequence im_invoice_items_seq;

drop table im_project_invoice_map;
drop table im_invoice_items;

drop table im_invoices_audit;
alter table im_trans_tasks drop column invoice_id;
drop table im_invoices;
drop table im_prices;


