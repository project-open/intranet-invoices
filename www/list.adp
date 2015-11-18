<master src="../../intranet-core/www/master">
<property name=title>@page_title@</property>
<property name="main_navbar_label">finance</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>

<script type="text/javascript">
	function setAmount(e) {
	 $(e).val($(e).attr("amount"));   
	};
</script>

<form action=invoice-action method=POST>
  <%= [export_vars -form {company_id invoice_id}] %>
  <input type="hidden" name="return_url" value="@return_url;noquote@" />
  <table width="100%" cellpadding=2 cellspacing=2 border=0>
    @table_header_html;noquote@
    @table_body_html;noquote@
    @button_html;noquote@
    @table_continuation_html;noquote@
  </table>
</form>

