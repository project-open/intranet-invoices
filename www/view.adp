<master src="../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>

<%= [im_costs_navbar "none" "/intranet-invoices/index" "" "" [list] ""] %>

<table cellpadding=1 cellspacing=1 border=0>
<tr valign=top>
  <td>
	  <%= [im_invoices_object_list_component $user_id $invoice_id $return_url] %>
  </td>
  <td>
	    @payment_list_html;noquote@
  </td>
  <td>
	<table border=0 cellPadding=1 cellspacing=1>
	  <tr class=rowtitle>
	    <td colspan=2 class=rowtitle>#intranet-invoices.Admin_Links#</td>
	  </tr>
	  <tr>
	    <td>
		<li>
		  <% set render_template_id $template_id %>
		  <% set preview_vars [export_url_vars invoice_id render_template_id return_url] %>
		  <A HREF="/intranet-invoices/view?@preview_vars@">#intranet-invoices.Preview#</A>
<if "" ne @generation_blurb@>
		<li>
		  <% set blurb $generation_blurb %>
		  <% set source_invoice_id $invoice_id %>
		  <% set gen_vars [export_url_vars source_invoice_id target_cost_type_id return_url] %>
		  <A HREF="/intranet-invoices/new-copy?@gen_vars@">@generation_blurb@</A>
</if>
		<li>
		  <% set notify_vars [export_url_vars invoice_id return_url] %>
		  <A HREF="/intranet-invoices/notify?@notify_vars@">#intranet-invoices.lt_Send_as_email_to_prov#</A>
	    </td>
	  </tr>
	</table>
  </td>
</tr>
</table>

<!-- Invoice Data and Receipient Tables -->
<table cellpadding=0 cellspacing=0 bordercolor=#6699CC border=0 width=100%>
  <tr valign=top> 
    <td>

	<table border=0 cellPadding=0 cellspacing=2 width=100%>
        <tr>
	  <td align=middle class=rowtitle colspan=2>#intranet-invoices.cost_type_Data#
          </td>
	</tr>
        <tr>
          <td  class=rowodd>@cost_type@ Nr.:</td>
          <td  class=rowodd>@invoice_nr@</td>
        </tr>
        <tr> 
          <td  class=roweven>@cost_type@ Date:</td>
          <td  class=roweven>@invoice_date_pretty@</td>
        </tr>

        <tr> 
          <td  class=rowodd>#intranet-invoices.cost_type_due_date#</td>
          <td  class=rowodd>@due_date@</td>
	</tr>

        <tr> 
          <td class=roweven>#intranet-invoices.Payment_terms#</td>
          <td class=roweven>#intranet-invoices.lt_payment_days_days_dat#</td>
	</tr>

	<tr>
          <td class=rowodd>#intranet-invoices.Payment_Method#</td>
          <td class=rowodd>@invoice_payment_method@</td>
	</tr>

	<tr>
          <td class=roweven>#intranet-invoices.cost_type_template#</td>
          <td class=roweven>@template@</td>
	</tr>

	<tr>
          <td class=roweven>#intranet-invoices.cost_type_type_1#</td>
          <td class=roweven>@cost_type@</td>
        </tr>

        <tr> 
          <td class=rowodd>@cost_type@ Status:</td>
          <td class=rowodd>@cost_status@</td>
        </tr>

	<tr><td colspan=2 align=right>
	  <form action=new method=POST>
	    <%= [export_form_vars return_id invoice_id cost_type_id] %>
	    <input type=submit name=edit_invoice value='#intranet-invoices.Edit#'>
	  </form>
	</td></tr>
	</table>

    </td>
    <td></td>
    <td align=right>
      <table border=0 cellspacing=2 cellpadding=0 width=100%>

        <tr><td align=center valign=top class=rowtitle colspan=2> #intranet-invoices.Recipient#</td></tr>
        <tr> 
          <td  class=rowodd>#intranet-invoices.Company_name#</td>
          <td  class=rowodd>
            <A href="/intranet/companies/view?company_id=@comp_id@">@company_name@</A>
          </td>
        </tr>
        <tr> 
          <td  class=roweven>#intranet-invoices.VAT#</td>
          <td  class=roweven>@vat_number@</td>
        </tr>
        <tr> 
          <td  class=rowodd> #intranet-invoices.Contact#</td>
          <td  class=rowodd>
            <A href=/intranet/users/view?user_id=@accounting_contact_id@>@company_contact_name@</A>
          </td>
        </tr>
        <tr> 
          <td  class=roweven>#intranet-invoices.Adress#</td>
          <td  class=roweven>@address_line1@ <br> @address_line2@</td>
        </tr>
        <tr> 
          <td  class=rowodd>#intranet-invoices.Zip#</td>
          <td  class=rowodd>@address_postal_code@</td>
        </tr>
        <tr> 
          <td  class=roweven>#intranet-invoices.Country#</td>
          <td  class=roweven>@country_name@</td>
        </tr>
        <tr> 
          <td  class=rowodd>#intranet-invoices.Phone#</td>
          <td  class=rowodd>@phone@</td>
        </tr>
        <tr> 
          <td  class=roweven>#intranet-invoices.Fax#</td>
          <td  class=roweven>@fax@</td>
        </tr>
        <tr> 
          <td  class=rowodd>#intranet-invoices.Email#</td>
          <td  class=rowodd>@company_contact_email@</td>
        </tr>
      </table>
  </tr>
</table>

<table cellpadding=0 cellspacing=2 border=0 width=100%>
<tr><td align=right>
  <table cellpadding=1 cellspacing=2 border=0 width=100%>
    @item_html;noquote@
  </table>
</td></tr>
</table>


