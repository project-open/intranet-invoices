-- 5.0.5.0.0-5.0.5.0.1.sql
SELECT acs_log__debug('/packages/intranet-core/sql/postgresql/upgrade/upgrade-5.0.5.0.0-5.0.5.0.1.sql','');



ALTER TABLE im_invoice_items DROP CONSTRAINT IF EXISTS im_invoice_items_item_id_fk;

alter table im_invoice_items
add constraint im_invoice_items_item_id_fk
foreign key (item_id)
references acs_objects (object_id);



