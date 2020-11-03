<master src="../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="main_navbar_label">finance</property>
<property name="sub_navbar">@sub_navbar;literal@</property>
<property name="left_navbar">@left_navbar_html;literal@</property>

<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>
	function setAmount(e) { $(e).val($(e).attr("amount")); };
</script>

<!-- Show calendar on start- and end-date -->
<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>
window.addEventListener('load', function() { 
     document.getElementById('list_check_all').addEventListener('click', function() { acs_ListCheckAll('cost',this.checked); });
     document.getElementById('start_date_calendar').addEventListener('click', function() { showCalendar('start_date', 'y-m-d'); });
     document.getElementById('end_date_calendar').addEventListener('click', function() { showCalendar('end_date', 'y-m-d'); });
});
</script>

<form action=invoice-action method=POST>
  <%= [export_vars -form {company_id invoice_id}] %>
  <input type="hidden" name="return_url" value="@return_url;noquote@" />
  <table width="100%" cellpadding="2" cellspacing="2" border="0">
    @table_header_html;noquote@
    @table_body_html;noquote@
    @button_html;noquote@
    @table_continuation_html;noquote@
  </table>
</form>

