-- 5.1.0.0.0-5.1.0.0.1.sql
SELECT acs_log__debug('/packages/intranet-invoices/sql/postgresql/upgrade/upgrade-5.1.0.0.0-5.1.0.0.1.sql','');


update	im_view_columns
set	column_render_tcl = '"<div align=right>$invoice_amount_formatted $invoice_currency</div>"'
where	view_id = 30 and -- invoice_list
	column_render_tcl = '"$invoice_amount_formatted $invoice_currency"';


update	im_view_columns
set	column_render_tcl = '"<div align=right>$payment_amount $payment_currency</div>"'
where	view_id = 30 and -- invoice_list
	column_render_tcl = '"$payment_amount $payment_currency"';
