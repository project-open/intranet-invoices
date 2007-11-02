<master src="../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">finance</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>

<table cellpadding=1 cellspacing=1 border=0>
<tr valign=top>
  <td>
	  <%= [im_invoices_object_list_component $user_id $invoice_id $read $write $return_url] %>
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

	<ul>
	<li>
	  <% set render_template_id $template_id %>
	  <% set preview_vars [export_url_vars invoice_id render_template_id return_url] %>
	  <A HREF="/intranet-invoices/view?@preview_vars@">
		<%= [lang::message::lookup "" intranet-invoices.Preview_as_HTML "Preview as HTML"] %>
	  </A>

<if @pdf_enabled_p@>
	<li>
	  <% set render_template_id $template_id %>
	  <% set preview_vars [export_url_vars invoice_id render_template_id return_url] %>
	  <A HREF="/intranet-invoices/view?@preview_vars@&output_format=pdf">
		<%= [lang::message::lookup "" intranet-invoices.Preview_as_PDF "Preview as PDF"] %>
	  </A>
</if>


<if @admin@>
	<if @cost_type_id@ eq @quote_cost_type_id@>
	<li>
		<% set blurb [lang::message::lookup $locale intranet-invoices.Generate_Invoice_from_Quote "Generate Invoice from Quote"] %>
		<% set source_invoice_id $invoice_id %>
		<% set target_cost_type_id [im_cost_type_invoice] %>
		<% set gen_vars [export_url_vars source_invoice_id target_cost_type_id return_url] %>
		<A HREF="/intranet-invoices/new-copy?@gen_vars@">@blurb@</A>
	
	<li>
		<% set blurb [lang::message::lookup $locale intranet-invoices.Generate_Delivery_Note_from_Quote "Generate Delivery Note from Quote"] %>
		<% set source_invoice_id $invoice_id %>
		<% set target_cost_type_id [im_cost_type_delivery_note] %>
		<% set gen_vars [export_url_vars source_invoice_id target_cost_type_id return_url] %>
		<A HREF="/intranet-invoices/new-copy?@gen_vars@">@blurb@</A>
	</if>

	<if @cost_type_id@ eq @delnote_cost_type_id@>
	<li>
		<% set blurb [lang::message::lookup $locale intranet-invoices.Generate_Invoice_from_DelNote "Generate Invoice from Delivery Note"] %>
		<% set source_invoice_id $invoice_id %>
		<% set target_cost_type_id [im_cost_type_invoice] %>
		<% set gen_vars [export_url_vars source_invoice_id target_cost_type_id return_url] %>
		<A HREF="/intranet-invoices/new-copy?@gen_vars@">@blurb@</A>
	</if>


	<if @cost_type_id@ eq @po_cost_type_id@>
	<li>
		<% set blurb [lang::message::lookup $locale intranet-invoices.Generate_Provider_Bill_from_Purchase_Order "Generate Provider Bill from Purchase Order"] %>
		<% set source_invoice_id $invoice_id %>
		<% set target_cost_type_id [im_cost_type_bill] %>
		<% set gen_vars [export_url_vars source_invoice_id target_cost_type_id return_url] %>
		<A HREF="/intranet-invoices/new-copy?@gen_vars@">@blurb@</A>
	</if>
</if>



<if @write@>
<!--
	<li>
	  <% set notify_vars [export_url_vars invoice_id return_url] %>
	  <A HREF="/intranet-invoices/notify?@notify_vars@">
	  <%= [lang::message::lookup "" intranet-invoices.Send_document_as_HTML_link "Send this %cost_type% as HTML link"] %>
	  </A>
-->

	<li>
	  <% set url [export_vars -base "/intranet-invoices/view" {invoice_id {render_template_id $template_id} {send_to_user_as "html"} return_url}] %>
	  <A HREF="@url@">
	  <%= [lang::message::lookup "" intranet-invoices.Send_document_as_HTML_attachment "Send this %cost_type% as HTML attachment"] %>
	  </A>

<if @pdf_enabled_p@>
	<li>
	  <% set url [export_vars -base "/intranet-invoices/view" {invoice_id {render_template_id $template_id} {send_to_user_as "pdf"} return_url}] %>
	  <A HREF="@url@">
	  <%= [lang::message::lookup "" intranet-invoices.Send_document_as_PDF_attachment "Send this %cost_type% as PDF attachment"] %>
	  </A>
</if>

</if>
	</ul>

	    </td>
	  </tr>
	</table>
  </td>
</tr>
</table>

<!-- Invoice Data and Receipient Tables -->
<table cellpadding=0 cellspacing=0 bordercolor=#6699CC border=0 width="100%">
  <tr valign=top> 
    <td>

	<table border=0 cellPadding=0 cellspacing=2 width="100%">
        <tr>
	  <td align=middle class=rowtitle colspan=2>#intranet-invoices.cost_type_Data#
          </td>
	</tr>
        <tr>
          <td  class=rowodd>#intranet-invoices.cost_type_nr#.:</td>
          <td  class=rowodd>@invoice_nr@</td>
        </tr>
        <tr> 
          <td  class=roweven>#intranet-invoices.cost_type_date#:</td>
          <td  class=roweven>@invoice_date_pretty@</td>
        </tr>
<if [apm_package_installed_p "intranet-cost-center"] >
        <tr> 
          <td  class=roweven><%= [lang::message::lookup "" intranet-cost.Cost_Center "Cost Center"] %>:</td>
          <td  class=roweven>@cost_center_name@</td>
        </tr>
</if>

<if @invoice_or_bill_p@>
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

</if>


	<tr>
          <td class=roweven>#intranet-invoices.cost_type_template#</td>
          <td class=roweven>@template@</td>
	</tr>

	<tr>
          <td class=roweven>#intranet-invoices.cost_type_type_1#</td>
          <td class=roweven>@cost_type@</td>
        </tr>

        <tr> 
          <td class=rowodd>#intranet-invoices.cost_type_status#:</td>
          <td class=rowodd>@cost_status@</td>
        </tr>

	<tr><td colspan=2 align=right>
<if @write@>
	  <form action=new method=POST>
	    <%= [export_form_vars return_url invoice_id cost_type_id] %>
	    <input type=submit name=edit_invoice value='#intranet-invoices.Edit#'>
	    <input type=submit name=del_invoice value='#intranet-core.Delete#'>
	  </form>
</if>
	</td></tr>
	</table>

    </td>
    <td></td>
    <td align=right>
      <table border=0 cellspacing=2 cellpadding=0 width="100%">

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
            <A href=/intranet/users/view?user_id=@org_company_contact_id@>@company_contact_name@</A>
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

<table cellpadding=0 cellspacing=2 border=0 width="100%">
<tr><td align=right>
  <table cellpadding=1 cellspacing=2 border=0 width="100%">
    @item_html;noquote@
  </table>
</td></tr>
</table>


