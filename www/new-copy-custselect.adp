<master src="../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="main_navbar_label">finance</property>

<%= [im_costs_navbar "none" "/intranet/invoices/index" "" "" [list]] %>

<form action=new-copy-invoiceselect method=POST>
<%= [export_vars -form {source_cost_type_id target_cost_type_id blurb return_url}] %>
        <table border="0" cellPadding=0 cellspacing="2">
                <tr><td align='left' class='rowtitle' colspan='2'>@company_select_label;noquote@</td></tr>
	        <tr>
	          <td  class=rowodd> 
		    @company_select;noquote@
	          </td>
	        </tr>
	        <tr class=roweven>
	          <td align='right'>
		    <input type="submit" name="#intranet-core.Submit#">
		  </td>
	        </tr>
        </table>
</form>
