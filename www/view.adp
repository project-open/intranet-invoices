<if @enable_master_p@><master></if>
<property name="doc(title)">@page_title;literal@</property>
<property name="main_navbar_label">finance</property>
<property name="sub_navbar">@sub_navbar;literal@</property>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<span style="color:red;font-weight:bold;">@err_mess@</span>

<table cellpadding="1" cellspacing="1" border="0" width="100%">
<tr valign="top" align="left">
    <td>
	<table cellpadding="0" cellspacing="0" border="0">
	<tr>
	    <td valign="top">
		<%= [im_invoices_object_list_component $user_id $invoice_id $read $write $return_url] %>
	    </td>
	    <td>&nbsp;&nbsp;</td>
	    <td valign="top">@payment_list_html;noquote@</td>
	</tr>
	</table>
  </td>

<if @surcharge_enabled_p@>
    <td>
	<table cellpadding=0 cellspacing=0>
	<form action=invoice-discount-surcharge-action method=POST>
	<%= [export_vars -form {{return_url $current_url} invoice_id}] %>
	<tr class=rowtitle>
		<td class=rowtitle align=center colspan=3>@submit_msg@</td>
	</tr>
	<tr>
		<td><input type=checkbox name=line_check.1 @pm_fee_checked@></td>
		<td><input type=textbox size=30 name=line_desc.1 value="@pm_fee_msg@"></td>
		<td><input type=textbox size=3 name=line_perc.1 value="@pm_fee_perc@">%</td>
	</tr>
	<tr>
		<td><input type=checkbox name=line_check.2 @surcharge_checked@></td>
		<td><input type=textbox size=30 name=line_desc.2 value="@surcharge_msg@"></td>
		<td><input type=textbox size=3 name=line_perc.2 value="@surcharge_perc@">%</td>
	</tr>
	<tr>
		<td><input type=checkbox name=line_check.3 @discount_checked@></td>
		<td><input type=textbox size=30 name=line_desc.3 value="@discount_msg@"></td>
		<td><input type=textbox size=3 name=line_perc.3 value="@discount_perc@">%</td>
	</tr>
	<tr>
		<td colspan=3 align=right><input type=submit name=submit value="@submit_msg@"></td>
	</tr>
	</form>
	</table>
    </td>
</if>



    <td align=right>
	<table border="0" cellPadding=1 cellspacing="1">
	<tr class=rowtitle>
	    <td colspan="2" class=rowtitle>#intranet-invoices.Admin_Links#</td>
	</tr>
	<tr>
	    <td>
		<ul>

<if @show_import_from_csv@>
		    <li>
			<A HREF="/intranet-cust-fttx/invoice-import/import-invoice?invoice_id=@invoice_id@"><%= [lang::message::lookup "" intranet-invoices.Import_from_CVS_Ava_Plan "Import from CVS (Ava-Plan)"] %></A>
		    </li>
</if>

		    <li>
			<% set preview_vars [export_vars -url {invoice_id {render_template_id $invoice_template_id} return_url}] %>
			<a HREF="/intranet-invoices/view?@preview_vars@"><%= [lang::message::lookup "" intranet-invoices.Preview_using_template "Preview using template"] %></a>
<if @pdf_enabled_p@>
		    <li>
			<% set preview_vars [export_vars -url {invoice_id {render_template_id $invoice_template_id} return_url}] %>
			<a HREF="/intranet-invoices/view?@preview_vars@&amp;pdf_p=1"><%= [lang::message::lookup "" intranet-invoices.Preview_as_PDF "Preview as PDF"] %></a>
		    </li>
</if>

<if @timesheet_report_enabled_p@>
		    <li>
		        <% 
			set level_of_details [parameter::get -package_id [apm_package_id_from_key intranet-invoices] -parameter LevelOfDetailsTimesheetHoursReport -default 4]
			set ts_url [export_vars -base $timesheet_report_url {{level_of_detail $level_of_details} {invoice_id $invoice_id}}]
			%>
			<a HREF="@ts_url;noquote@"><%= [lang::message::lookup "" intranet-invoices.Show_Included_Timesheet_Hours "Show Included Timesheet Hours"] %></a>
		    </li>
</if>

<if @show_promote_to_timesheet_invoice_p@>
		    <li>
		        <a HREF="<%= [export_vars -base "/intranet-timesheet2-invoices/invoices/promote-invoice-to-timesheet-invoice" {invoice_id return_url}] %>"><%= [lang::message::lookup "" intranet-invoices.Promote_Invoice_to_Timesheet_Invoice "Promote Invoice to Timesheet Invoice"] %></a>
		    </li>
</if>


<if @admin@>
  <if @document_quote_p@ eq "1">
		    <li>
			<% set blurb [lang::message::lookup $user_locale intranet-invoices.Generate_Invoice_from_Quote "Generate Invoice from Quote"] %>
			<% set source_invoice_id $invoice_id %>
			<% set target_cost_type_id [im_cost_type_invoice] %>
			<% set gen_vars [export_vars -url {source_invoice_id target_cost_type_id return_url}] %>
			<A HREF="/intranet-invoices/new-copy?@gen_vars@">@blurb@</A>
		    </li>
		    <li>
			<% set blurb [lang::message::lookup $user_locale intranet-invoices.Generate_Delivery_Note_from_Quote "Generate Delivery Note from Quote"] %>
			<% set source_invoice_id $invoice_id %>
			<% set target_cost_type_id [im_cost_type_delivery_note] %>
			<% set gen_vars [export_vars -url {source_invoice_id target_cost_type_id return_url}] %>
			<A HREF="/intranet-invoices/new-copy?@gen_vars@">@blurb@</A>
		    </li>
  </if>

  <if @document_delnote_p@ eq "1">
		    <li>
			<% set blurb [lang::message::lookup $user_locale intranet-invoices.Generate_Invoice_from_DelNote "Generate Invoice from Delivery Note"] %>
			<% set source_invoice_id $invoice_id %>
			<% set target_cost_type_id [im_cost_type_invoice] %>
			<% set gen_vars [export_vars -url {source_invoice_id target_cost_type_id return_url}] %>
			<A HREF="/intranet-invoices/new-copy?@gen_vars@">@blurb@</A>
		    </li>
  </if>

  <if @document_po_p@ eq "1">
		    <li>
			<% set blurb [lang::message::lookup $user_locale intranet-invoices.Generate_Provider_Bill_from_Purchase_Order "Generate Provider Bill from Purchase Order"] %>
			<% set source_invoice_id $invoice_id %>
			<% set target_cost_type_id [im_cost_type_bill] %>
			<% set gen_vars [export_vars -url {source_invoice_id target_cost_type_id return_url}] %>
			<A HREF="/intranet-invoices/new-copy?@gen_vars@">@blurb@</A>
		    </li>
  </if>

  <if @document_invoice_p@ eq "1">
    		    <li>
			<A HREF="/intranet-invoices/new-copy?target_cost_type_id=3700&amp;source_cost_type_id=3700&amp;source_invoice_id=<%=$invoice_id%>"><%= [lang::message::lookup "" intranet-invoices.Create_Duplicate_Invoice "Create duplicate invoice"] %></a>
		    </li>
		    
 		    <if @cancellation_invoice_enabled_p@ eq "1">
    		    <li>
			<A HREF="/intranet-invoices/new-copy?target_cost_type_id=3752&amp;source_cost_type_id=3700&amp;source_invoice_id=<%=$invoice_id%>&amp;invert_quantities_p=1"><%= [lang::message::lookup "" intranet-invoices.Create_Cancellation_Invoice "Create cancellation invoice"] %></a>
		    </li>
		    </if>
		    
  </if>
</if>


<if @write@>
  <if "adp" eq @invoice_template_type@>
		    <li>
			<% set url [export_vars -base "/intranet-invoices/view" {invoice_id {render_template_id $invoice_template_id} {send_to_user_as "html"} return_url}] %>
			<a HREF="@url@"><%= [lang::message::lookup "" intranet-invoices.Send_document_as_HTML_attachment "Send this %cost_type_l10n% as HTML attachment"] %></a>
		    </li>
  </if>

  <if @pdf_enabled_p@>
		    <li>
			<% set url [export_vars -base "/intranet-invoices/view" {invoice_id {render_template_id $invoice_template_id} {send_to_user_as "pdf"} return_url}] %>
			<a HREF="@url@"><%= [lang::message::lookup "" intranet-invoices.Send_document_as_PDF_attachment "Send this %cost_type_l10n% as PDF attachment"] %></a>
		    </li>
  </if>
</if>

		</ul>
	    </td>
	</tr>
	</table>
    </td>


<!-- End of the top line of components -->
</tr>
</table>

<!-- Invoice Data and Receipient Tables -->
<table cellpadding="0" cellspacing="0" bordercolor="#6699CC" border="0" width="100%">
  <tr valign="top"> 
    <td>

	<table border="0" cellPadding=0 cellspacing="2" width="100%">
        <tr>
	  <td align=middle class=rowtitle colspan="2">#intranet-invoices.cost_type_Data#
          </td>
	</tr>
        <tr>
          <td  class=rowodd>#intranet-invoices.cost_type_nr#</td>
          <td  class=rowodd>@invoice_nr@</td>
        </tr>
        <tr> 
          <td  class=roweven>#intranet-invoices.cost_type_date#</td>
          <td  class=roweven>@invoice_date_pretty@</td>
        </tr>
<if @cost_center_installed_p@ >
    <if @show_cost_center_p@>
        <tr> 
          <td  class=roweven><%= [lang::message::lookup "" intranet-cost.Cost_Center "Cost Center"] %></td>
          <td  class=roweven>@cost_center_name@</td>
        </tr>
    </if>
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
          <td class=roweven>@invoice_template@</td>
	</tr>

	<tr>
          <td class=rowodd>#intranet-invoices.cost_type_type_1#</td>
          <td class=rowodd>@cost_type_l10n@</td>
        </tr>

        <tr> 
          <td class=roweven>#intranet-invoices.cost_type_status#</td>
          <td class=roweven>@cost_status@</td>
        </tr>

<if @timesheet_invoice_p@>
        <tr>
          <td class=rowodd><%= [lang::message::lookup "" intranet-timesheet2-invoices.Invoicing_Period_Start "Invoice Period Start"] %></td>
          <td class=rowodd>@invoice_period_start_pretty@</td>
        </tr>
        <tr>
          <td class=roweven><%= [lang::message::lookup "" intranet-timesheet2-invoices.Invoicing_Period_End "Invoice Period End"] %></td>
          <td class=roweven>@invoice_period_end_pretty@</td>
        </tr>
</if>

	<tr><td colspan="2" align="right">
<if @write@>
	  <form action="/intranet-invoices/new" method=GET>
	    <%= [export_vars -form {return_url invoice_id cost_type_id}] %>
	    <input type="submit" name="edit_invoice" value='#intranet-invoices.Edit#'>
	    <input type="submit" name="del_invoice" value='#intranet-core.Delete#'>
	  </form>
</if>
	</td></tr>
	</table>

    </td>
    <td></td>
    <td align="right">
      <table border="0" cellspacing="2" cellpadding="0" width="100%">

        <tr><td align="center" valign="top" class=rowtitle colspan="2"> #intranet-invoices.Recipient#</td></tr>

<if @invoice_or_quote_p@>
        <tr> 
          <td  class=rowodd>#intranet-invoices.Company_name#</td>
          <td  class=rowodd>
            <A href="/intranet/companies/view?company_id=@customer_id@">@company_name@</A>
          </td>
        </tr>
</if>
<else>
        <tr> 
          <td  class=rowodd>#intranet-invoices.Provider#</td>
          <td  class=rowodd>
            <A href="/intranet/companies/view?company_id=@provider_id@">@company_name@</A>
          </td>
        </tr>
</else>

        <tr> 
          <td  class=roweven>#intranet-invoices.VAT#</td>
          <td  class=roweven>@vat_number@</td>
        </tr>
        <tr> 
          <td  class=rowodd> #intranet-invoices.Contact#</td>
          <td  class=rowodd>
            <A href="/intranet/users/view?user_id=@org_company_contact_id@">@company_contact_name@</A>
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

<table cellpadding="0" cellspacing="2" border="0" width="100%">
<tr valign="top">
<td>&nbsp;</td>
<td align="right">
  <table cellpadding="1" cellspacing="2" border="0">
    @item_list_html;noquote@
  </table>

  <table cellpadding="1" cellspacing="2" border="0">
    @terms_html;noquote@
  </table>

</td></tr>
</table>

<if @show_components_p@>
    <%= [im_component_bay top] %>
    <table width="100%">
	<tr valign="top">
	    <td width="50%"><%= [im_component_bay left] %></td>
	    <td width="50%"><%= [im_component_bay right] %></td>
	</tr>
    </table>
    <%= [im_component_bay bottom] %>
</if>
