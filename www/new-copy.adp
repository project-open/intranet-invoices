<master src="../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="main_navbar_label">finance</property>
<property name="sub_navbar">@sub_navbar_html;literal@</property>


<% 
    # Determine a security token to authenticate the AJAX function
    set auto_login [im_generate_auto_login -user_id [ad_conn user_id]] 
%>

<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>


function ltrim(str, chars) {
	chars = chars || "\\s";
	return str.replace(new RegExp("^[" + chars + "]+", "g"), "");
}

function ajaxFunction() {
    var xmlHttp1;
    var xmlHttp2;
    try {
	// Firefox, Opera 8.0+, Safari
	xmlHttp1=new XMLHttpRequest();
	xmlHttp2=new XMLHttpRequest();
    }
    catch (e) {
	// Internet Explorer
	try {
	    xmlHttp1=new ActiveXObject("Msxml2.XMLHTTP");
	    xmlHttp2=new ActiveXObject("Msxml2.XMLHTTP");
	}
	catch (e) {
	    try {
		xmlHttp1=new ActiveXObject("Microsoft.XMLHTTP");
		xmlHttp2=new ActiveXObject("Microsoft.XMLHTTP");
	    }
	    catch (e) {
		alert("Your browser does not support AJAX!");
		return false;
	    }
	}
    }

    xmlHttp1.onreadystatechange = function() {
	if(xmlHttp1.readyState==4) {
	    // empty options
	    for (i = document.invoice.invoice_office_id.options.length-1; i >= 0; i--) { 
		document.invoice.invoice_office_id.remove(i); 
	    }

	    // loop through the komma separated list
	    var res1 = xmlHttp1.responseText;
	    var opts1 = res1.split("|");
	    for (i=0; i < opts1.length; i = i+2) {
		var newOpt = new Option(opts1[i+1], opts1[i], false, true);
		document.invoice.invoice_office_id.options[document.invoice.invoice_office_id.options.length] = newOpt;
	    }
	}
    }

    xmlHttp2.onreadystatechange = function() {
	if(xmlHttp2.readyState==4) {
	    // empty options
	    for (i = document.invoice.company_contact_id.options.length-1; i >= 0; i--) { 
		document.invoice.company_contact_id.remove(i); 
	    }
	    // loop through the komma separated list
	    var res2 = xmlHttp2.responseText;
	    var opts2 = res2.split("|");
	    // alert(opts2);	    
	    for (i=0; i < opts2.length; i = i+2) {
		//alert (opts2[i]);
		var newOpt = new Option(opts2[i+1], ltrim(opts2[i]), false, true);
		document.invoice.company_contact_id.options[document.invoice.company_contact_id.options.length] = newOpt;
	    }
	}
    }

    // get the company_id from the customer's drop-down
    var company_id = document.invoice.@ajax_company_widget@.value;
    xmlHttp1.open("GET","/intranet/offices/ajax-offices?user_id=@user_id@&auto_login=@auto_login@&company_id="+company_id,true);
    xmlHttp1.send(null);
    xmlHttp2.open("GET","/intranet/users/ajax-company-contacts?user_id=@user_id@&auto_login=@auto_login@&company_id="+company_id,true);
    xmlHttp2.send(null);
}

window.addEventListener('load', function() {
    var el = document.getElementById('customer_id');
    if (!!el) {
	el.addEventListener('change', function() { ajaxFunction(); });
	el.addEventListener('keyup', function() { ajaxFunction(); });
    }
    var el = document.getElementById('provider_id');
    if (!!el) {
	el.addEventListener('change', function() { ajaxFunction(); });
	el.addEventListener('keyup', function() { ajaxFunction(); });
    }
});

</script>


<form action=new-2 name=invoice method=POST>
<% set invoice_id $new_invoice_id %>
<%= [export_vars -form {invoice_id project_id return_url reference_document_id}] %>
@select_project_html;noquote@
<if @show_cost_center_p@></if><else><input type="hidden" name="cost_center_id" value="@cost_center_id@"></else>

<table border="0" width="100%">
<tr><td>

  <table cellpadding="0" cellspacing="0" bordercolor="#6699CC" border="0">
    <tr valign="top"> 
      <td>

        <table border="0" cellPadding=0 cellspacing="2" width="100%">


	        <tr><td align=middle class=rowtitle colspan="2">@target_cost_type@ Data</td></tr>
	        <tr>
	          <td  class=rowodd>@target_cost_type@ nr.:</td>
	          <td  class=rowodd> 
	            <input type="text" name="invoice_nr" size="15" value='@invoice_nr@'>
	          </td>
	        </tr>
<if @show_cost_center_p@>
                <tr>
                  <td  class=roweven>@cost_center_label@</td>
                  <td  class=roweven>
                  @cost_center_select;noquote@
                  </td>
                </tr>
</if>

	        <tr> 
	          <td  class=roweven>@target_cost_type@ date:</td>
	          <td  class=roweven> 
	            <input type="text" name="invoice_date" size="15" value='@effective_date@'>
	          </td>
	        </tr>
	        <tr> 
	          <td class=roweven>Payment terms</td>
	          <td class=roweven> 
	            <input type="text" name="payment_days" size="5" value='@payment_days@'>
	            days</td>
	        </tr>
<if @invoice_or_bill_p@>
	        <tr> 
	          <td class=rowodd>Payment Method</td>
	          <td class=rowodd>@payment_method_select;noquote@</td>
	        </tr>
</if>
	        <tr> 
	          <td class=roweven> @target_cost_type@ template:</td>
	          <td class=roweven>@template_select;noquote@</td>
	        </tr>
	        <tr> 
	          <td class=rowodd>@target_cost_type@ status</td>
	          <td class=rowodd>@status_select;noquote@</td>
	        </tr>
	        <tr> 
	          <td class=roweven>@target_cost_type@ type</td>
	          <td class=roweven>@type_select;noquote@</td>
	        </tr>

        </table>

      </td>
      <td></td>
      <td align="right">
        <table border="0" cellspacing="2" cellpadding="0" width="100%">

<if @invoice_or_quote_p@>
<!-- Let the user select the company. Provider=Internal -->

		<tr>
		  <td align="center" valign="top" class=rowtitle colspan="2">@company_type@</td>
		</tr>
		<tr>
		  <td class=roweven>@company_type@:</td>
		  <td class=roweven>@company_select;noquote@</td>
		</tr>
		<input type="hidden" name="provider_id" value="@provider_id@">

</if>
<else>

		<tr>
		  <td align="center" valign="top" class=rowtitle colspan="2">Provider</td>
		</tr>
		<tr>
		  <td class=roweven>Provider:</td>
		  <td class=roweven>@provider_select;noquote@</td>
		</tr>
		<input type="hidden" name="company_id" value="@company_id@">

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
                    <textarea name=note rows=6 cols=40 wrap="<%=[im_html_textarea_wrap]%>">@cost_note@</textarea>
                  </td>
                </tr>

        </table>
    </tr>
  </table>

</td></tr>
<tr><td>

  <table width="100%">
    <tr>
      <td align="right">
 	<table border="0" cellspacing="2" cellpadding="1" width="100%">

	<!-- the list of task sums, distinguised by type and UOM -->
        <tr align="center"> 
          <td class=rowtitle>#intranet-invoices.Line#</td>
<if @outline_number_enabled_p@>
          <td class=rowtitle><%= [lang::message::lookup "" intranet-invoices.Outline Outline] %></td>
</if>
          <td class=rowtitle>#intranet-invoices.Description#</td>

<if @material_enabled_p@>
          <td class=rowtitle>#intranet-invoices.Material#</td>
</if>
<if @project_type_enabled_p@>
          <td class=rowtitle>#intranet-invoices.Type#</td>
</if>
          <td class=rowtitle>#intranet-invoices.Units#</td>
          <td class=rowtitle>#intranet-invoices.UOM#</td>
          <td class=rowtitle>#intranet-invoices.Rate#</td>
        </tr>
	@task_sum_html;noquote@

<if @discount_enabled_p@>
        <tr>
          <td>
          </td>
          <td colspan="99" align="right">
            <table border="0" cellspacing="1" cellpadding="0">
              <tr>
                <td>#intranet-invoices.Discount# &nbsp;</td>
                <td><input type="text" name="discount_text" value="@discount_text@"> </td>
                <td><input type="text" name="discount_perc" value="@discount_perc@" size="4"> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
</if>
<if @surcharge_enabled_p@>
        <tr>
          <td>
          </td>
          <td colspan="99" align="right">
            <table border="0" cellspacing="1" cellpadding="0">
              <tr>
                <td>#intranet-invoices.Surcharge# &nbsp;</td>
                <td><input type="text" name="surcharge_text" value="@surcharge_text@"> </td>
                <td><input type="text" name="surcharge_perc" value="@surcharge_perc@" size="4"> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
</if>

        <tr>
          <td> 
          </td>
          <td colspan="99" align="right"> 
            <table border="0" cellspacing="1" cellpadding="0">
              <tr> 
                <td>#intranet-invoices.VAT#&nbsp;</td>
		<td>
<if @vat_type_id_enabled_p@ gt 0>                                                                                                           
                @vat_type_select;noquote@                                                                                                   
</if>                                                                                                                                       
<else>                                                                                                                                      
                <input type="text" name="vat" value="@vat@" size="4"> % &nbsp;                                                              
</else>
		</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr> 
          <td> 
          </td>
          <td colspan="99" align="right"> 
            <table border="0" cellspacing="1" cellpadding="0">
              <tr> 
                <td>#intranet-invoices.TAX#&nbsp;</td>
                <td><input type="text" name="tax" value='@tax@' size="4"> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr> 
          <td>&nbsp; </td>
          <td colspan="6" align="right"> 
              <input type="submit" name="submit" value='@button_text@'>
          </td>
        </tr>

        </table>
      </td>
    </tr>
  </table>


</td></tr>
</table>

</form>
