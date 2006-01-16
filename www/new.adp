<master src="../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">finance</property>

<%= [im_costs_navbar "none" "/intranet/invoices/index" "" "" [list]] %>

<form action=new-2 method=POST>
<%= [export_form_vars invoice_id return_url] %>
<if @project_id@ ne 0>
<input type=hidden name=select_project value="@project_id@">
</if>

<!-- Include a list of projects related to this document -->
@select_project_html;noquote@

<table border=0 width="100%">
<tr><td>

  <table cellpadding=0 cellspacing=0 bordercolor=#6699CC border=0 width="100%">
    <tr valign=top> 
      <td>

        <table border=0 cellPadding=0 cellspacing=2 width="100%">


	        <tr><td align=middle class=rowtitle colspan=2>#intranet-invoices.cost_type_Data#</td></tr>
	        <tr>
	          <td  class=rowodd>#intranet-invoices.cost_type_nr#</td>
	          <td  class=rowodd> 
	            <input type=text name=invoice_nr size=15 value='@invoice_nr@'>
	          </td>
	        </tr>
	        <tr> 
	          <td  class=roweven>#intranet-invoices.cost_type_date#</td>
	          <td  class=roweven> 
	            <input type=text name=invoice_date size=15 value='@effective_date@'>
	          </td>
	        </tr>

	        <tr> 
	          <td class=roweven>#intranet-invoices.Payment_terms#</td>
	          <td class=roweven> 
	            <input type=text name=payment_days size=5 value='@payment_days@'>
	            #intranet-invoices.days#</td>
	        </tr>
	        <tr> 
	          <td class=rowodd>#intranet-invoices.Payment_Method#</td>
	          <td class=rowodd>@payment_method_select;noquote@</td>
	        </tr>

	        <tr> 
	          <td class=roweven> #intranet-invoices.cost_type_template#</td>
	          <td class=roweven>@template_select;noquote@</td>
	        </tr>
	        <tr> 
	          <td class=rowodd>#intranet-invoices.cost_type_status#</td>
	          <td class=rowodd>@status_select;noquote@</td>
	        </tr>
	        <tr> 
	          <td class=roweven>#intranet-invoices.cost_type_type#</td>
	          <td class=roweven>@type_select;noquote@</td>
	        </tr>

        </table>

      </td>
      <td></td>
      <td align=right>
        <table border=0 cellspacing=2 cellpadding=0 width="100%">

<if @invoice_or_quote_p@>
<!-- Let the user select the company. Provider=Internal -->

		<tr>
		  <td align=center valign=top class=rowtitle colspan=2>#intranet-invoices.Company#</td>
		</tr>
		<tr>
		  <td class=roweven>#intranet-core.Customer#</td>
		  <td class=roweven>@customer_select;noquote@</td>
		</tr>
		<input type=hidden name=provider_id value=@provider_id@>
</if>
<else>

		<tr>
		  <td align=center valign=top class=rowtitle colspan=2>#intranet-invoices.Provider#</td>
		</tr>
		<tr>
		  <td class=roweven>#intranet-invoices.Provider_1#</td>
		  <td class=roweven>@provider_select;noquote@</td>
		</tr>
		<input type=hidden name=customer_id value=@customer_id@>
</else>


		<tr>
		  <td class=rowodd>@invoice_address_label@</td>
		  <td class=rowodd>@invoice_address_select;noquote@</td>
		</tr>

		<tr>
		  <td class=rowodd>#intranet-core.Contact#</td>
		  <td class=rowodd>@contact_select;noquote@</td>
		</tr>


		<tr>
		  <td class=roweven>#intranet-invoices.Note#</td>
	          <td class=roweven>
		    <textarea name=note rows=6 cols=40 wrap=hard>@cost_note@</textarea>
		  </td>
		</tr>


        </table>
    </tr>
  </table>

</td></tr>
<tr><td>

  <table width="100%">
    <tr>
      <td align=right>
 	<table border=0 cellspacing=2 cellpadding=1 width="100%">

	<!-- the list of task sums, distinguised by type and UOM -->
	@task_sum_html;noquote@

        <tr>
          <td> 
          </td>
          <td colspan=99 align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>#intranet-invoices.VATnbsp#</td>
                <td><input type=text name=vat value='@vat@' size=4> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr> 
          <td> 
          </td>
          <td colspan=99 align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>#intranet-invoices.TAXnbsp#</td>
                <td><input type=text name=tax value='@tax@' size=4> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr> 
          <td>&nbsp; </td>
          <td colspan=6 align=right> 
              <input type=submit name=submit value='@button_text@'>
          </td>
        </tr>

        </table>
      </td>
    </tr>
  </table>


</td></tr>
</table>

</form>

