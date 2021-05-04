-- 5.0.5.0.0-5.0.5.0.1.sql
SELECT acs_log__debug('/packages/intranet-invoices/sql/postgresql/upgrade/upgrade-5.0.5.0.0-5.0.5.0.1.sql','');



ALTER TABLE im_invoice_items DROP CONSTRAINT IF EXISTS im_invoice_items_item_id_fk;

alter table im_invoice_items
add constraint im_invoice_items_item_id_fk
foreign key (item_id)
references acs_objects (object_id);


SELECT  im_component_plugin__new (
        null, 'im_component_plugin', now(), null, null, null,
        'Dependency Tree',                              -- plugin_name
        'intranet-invoices',                            -- package_name
        'right',                                        -- location
        '/intranet-invoices/view',                      -- page_url
        null,                                           -- view_name
        20,                                             -- sort_order
        'im_invoices_dependency_tree_component $invoice_id' -- component_tcl
);

SELECT im_grant_permission(
        (select plugin_id from im_component_plugins where package_name = 'intranet-invoices' and plugin_name = 'Dependency Tree'),
        (select group_id from groups where group_name = 'Employees'),
	'read'
);


