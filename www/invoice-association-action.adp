<master src="../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="main_navbar_label">finance</property>

<%= [im_costs_navbar "none" "/intranet/invoices/index" "" "" [list]] %>

<table border="0" cellspacing="5" cellpadding="5">
<tr valign="top">
<td>
	<form method=POST action=invoice-association-action-2.tcl>
	<%= [export_vars -form {invoice_id return_url}] %>
	<table border="0" cellspacing="1" cellpadding="1">
	  <tr>
	    <td colspan="2" class=rowtitle align="center">
	     <%= [lang::message::lookup "" intranet-invoices.Associate_with_project "Associate with Project"] %>
	    </td>
	  </tr>
	  <tr>
	    <td>#intranet-invoices.Customer_Invoice#</td>
	    <td>@invoice_nr@</td>
	  </tr>
	  <tr><td>#intranet-core.Company#</td>
	    <td><A href="/intranet/companies/view?company_id=@company_id@">@company_name@</A></td>
	  </tr>
	  <tr>
	    <td><%= [lang::message::lookup "" intranet-invoices.Associate_with "Associate with"] %></td>
	    <td>@project_select;noquote@</td>
	  </tr>
	  <tr>
	    <td colspan="2" align="right"><input type="submit" value="<%= [lang::message::lookup "" intranet-core.Associate "Associate"] %>"></td>
	  </tr>
	</table>
	</form>
</td></tr>
<tr><td>&nbsp;</td></tr>

<table border="0" cellspacing="5" cellpadding="5">
<tr valign="top">
<td>
	<form method=POST action=invoice-association-action-2.tcl>
	<%= [export_vars -form {invoice_id return_url}] %>
	<table border="0" cellspacing="1" cellpadding="1">
	  <tr>
	    <td colspan="2" class=rowtitle align="center">
	     <%= [lang::message::lookup "" intranet-invoices.Associate_with_task "Associate with Task"] %>
	    </td>
	  </tr>
	  <tr>
	    <td>#intranet-invoices.Customer_Invoice#</td>
	    <td>@invoice_nr@</td>
	  </tr>
	  <tr><td>#intranet-core.Company#</td>
	    <td><A href="/intranet/companies/view?company_id=@company_id@">@company_name@</A></td>
	  </tr>
	  <tr>
	    <td><%= [lang::message::lookup "" intranet-invoices.Associate_with "Associate with"] %></td>
	    <td>@task_select;noquote@</td>
	  </tr>
	  <tr>
	    <td colspan="2" align="right"><input type="submit" value="<%= [lang::message::lookup "" intranet-core.Associate "Associate"] %>"></td>
	  </tr>
	</table>
	</form>
</td></tr>
<tr><td>&nbsp;</td></tr>

<tr><td>
	<form method=POST action=invoice-association-action.tcl>
	<%= [export_vars -form {invoice_id return_url}] %>
	<table border="0" cellspacing="1" cellpadding="1">
	  <tr> 
	    <td colspan="2" class=rowtitle align="center">
	     Associate with a different company
	    </td>
	  </tr>
	  <tr>
	    <td>
	      Invoice Nr:
	    </td>
	    <td>
	      @invoice_nr@
	    </td>
	  </tr>
	  <tr>
	    <td>
	      Associate with:
	    </td>
	    <td>
	      @company_select;noquote@
	    </td>
	  </tr>
	  <tr>
	    <td colspan="2" align="right">
	      <input type="submit" value="Select Company">
	    </td>
	  </tr>
	</table>
	</form>
</td>
</tr>
</tr>
</table>
