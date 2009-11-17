<master>
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">finance</property>

<form action=new method=POST>
<%= [export_form_vars cost_type_id customer_id provider_id project_id invoice_currency create_invoice_from_template return_url] %>

<%= [im_box_header $page_title] %>

		<table>
		@table_header;noquote@
		@table;noquote@
		</table>

<%= [im_box_footer] %>


</form>



