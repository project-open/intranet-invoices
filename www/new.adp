<master src="../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">finance</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>

<% 
    # Determine a security token to authenticate the AJAX function
    set auto_login [im_generate_auto_login -user_id [ad_get_user_id]] 
%>

<script type="text/javascript">


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
</script>


<form action=new-2 name=invoice method=POST>
<%= [export_form_vars invoice_id return_url] %>

<!-- Include a list of projects related to this document -->
@select_project_html;noquote@

<if @cost_center_hidden@ defined>
@cost_center_hidden;noquote@
</if>

<table border=0 width="100%">
<tr><td>

  <table cellpadding=0 cellspacing=0 bordercolor=#6699CC border=0 width="100%">
    <tr valign=top> 
      <td>

        <table border=0 cellPadding=0 cellspacing=2 width="100%">


	        <tr><td align=middle class=rowtitle colspan=2>#intranet-invoices.cost_type_Data#</td></tr>
	        <tr>
	          <td class=rowodd>#intranet-invoices.cost_type_nr#</td>
	          <td class=rowodd> 
	            <input type=text name=invoice_nr size=15 value='@invoice_nr@'>
	          </td>
	        </tr>
	        <tr> 
	          <td class=roweven>#intranet-invoices.cost_type_date#</td>
	          <td class=roweven> 
	            <input type=text name=invoice_date size=15 value='@effective_date@'>
	          </td>
	        </tr>
<if @cost_center_select@ defined>
	        <tr> 
	          <td class=roweven>@cost_center_label@</td>
	          <td class=roweven>
		  @cost_center_select;noquote@
	          </td>
	        </tr>
</if>
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
      <td>
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

<if @canned_note_enabled_p@>
		<tr>
		  <td class=roweven><%= [lang::message::lookup "" intranet-invoices.Canned_Note "Canned Note"] %></td>
	          <td class=roweven>
<if 0>
		    <%= [im_category_select -translate_p 0 -include_empty_p 1 -include_empty_name "-- Please Select --" -plain_p 1 -cache_interval 0 "Intranet Invoice Canned Note" canned_note_id $canned_note_id] %>

</if>
<else>
		    <%= [im_category_select_multiple -translate_p 0 "Intranet Invoice Canned Note" canned_note_id $canned_note_id 3] %>
</else>
		  </td>
		</tr>
</if>
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

  <table width="100%" align=right border=0>
    <tr>
      <td align=right>

 	<table border=0 cellspacing=2 cellpadding=1 width="100%">
	<!-- the list of task sums, distinguised by type and UOM -->
	@task_sum_html;noquote@

<if @discount_enabled_p@>
        <tr>
          <td> 
          </td>
          <td colspan=99 align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>#intranet-invoices.Discount# &nbsp;</td>
                <td><input type=text name=discount_text value="@discount_text@"> </td>
                <td><input type=text name=discount_perc value="@discount_perc@" size=4> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
</if>
<if @surcharge_enabled_p@>
        <tr>
          <td> 
          </td>
          <td colspan=99 align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>#intranet-invoices.Surcharge# &nbsp;</td>
                <td><input type=text name=surcharge_text value="@surcharge_text@"> </td>
                <td><input type=text name=surcharge_perc value="@surcharge_perc@" size=4> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
</if>
        <tr>
          <td> 
          </td>
          <td colspan=@vat_colspan@ align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>#intranet-invoices.VATnbsp#</td>
                <td><input type=text name=vat value="@vat@" size=4> % &nbsp;</td>
              </tr>
<if @tax_enabled_p@>
              <tr> 
                <td>#intranet-invoices.TAXnbsp#</td>
                <td><input type=text name=tax value="@tax@" size=4> % &nbsp;</td>
              </tr>
</if>
<else>
              <input type=hidden name=tax value="@tax@">
</else>
            </table>
          </td>
        </tr>
        <tr> 
          <td>&nbsp; </td>
          <td colspan=6 align=right> 
              <input type=submit name=submit value="@button_text@">
          </td>
        </tr>

        </table>
      </td>
    </tr>
  </table>


</td></tr>
</table>

</form>

