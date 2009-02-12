<master src="../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">finance</property>

<%= [im_costs_navbar "none" "/intranet/invoices/index" "" "" [list]] %>

<div id="fullwidth-list" class="fullwidth-list-no-side-bar">
<form action=new-copy method=POST>
<%= [export_form_vars cost_type_id blurb company_id source_cost_type_id target_cost_type_id return_url] %>

  <table width=100% cellpadding=2 cellspacing=2 border=0>
    @table_header_html;noquote@
    @table_body_html;noquote@

    <tr><td colspan=@colspan@ class=rowplain align=right>
	<input type=submit value="@submit_button_text@">
    </td></tr>

    @table_continuation_html;noquote@
  </table>
</form>
</div>