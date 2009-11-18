<master>
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">finance</property>

<form action='@return_url;noquote@' method=POST>
@pass_through_html;noquote@

<%= [im_box_header $page_title] %>

		<table>
		@table_header;noquote@
		@table;noquote@
		</table>

<%= [im_box_footer] %>


</form>



