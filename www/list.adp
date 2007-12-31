<master src="../../intranet-core/www/master">
<property name=title>List of @cost_type@</property>
<property name="main_navbar_label">finance</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>

<div class="filter-list">
   <div class="filter">
      <div class="filter-block">
         <div class="filter-title">
            #intranet-invoices.Filter_Documents#
         </div>
         @filter_html;noquote@
      </div>
      <div class="filter-block">
         <div class="filter-title">
	    #intranet-invoices.lt_New_Company_Documents#
	 </div>
         @new_document_menu;noquote@
      </div>

      <%= [im_navbar_tree -label "main"] %>

   </div>

   <div class="fullwidth-list">
      <%= [im_box_header "List of $cost_type"] %>

<form action=invoice-action method=POST>
<%= [export_form_vars company_id invoice_id return_url] %>
  <table width="100%" cellpadding=2 cellspacing=2 border=0>
    @table_header_html;noquote@
    @table_body_html;noquote@
    @table_continuation_html;noquote@
    @button_html;noquote@
  </table>
</form>

     <%= [im_box_footer] %>
   </div>
   <div class="filter-list-footer"></div>

</div>
