<master src="../../intranet-core/www/master">
<property name=title>List of @cost_type@</property>
<property name="main_navbar_label">finance</property>


@filter_html;noquote@

<%= [im_costs_navbar $letter "/intranet-invoices/list" $next_page_url $previous_page_url [list invoice_status_id cost_type_id customer_id start_idx order_by how_many view_name letter] $parent_menu_label ] %>

<form action=invoice-action method=POST>
<%= [export_form_vars customer_id invoice_id return_url] %>
  <table width=100% cellpadding=2 cellspacing=2 border=0>
    @table_header_html;noquote@
    @table_body_html;noquote@
    @table_continuation_html;noquote@
    @button_html;noquote@
  </table>
</form>
