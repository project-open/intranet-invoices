<master src="../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>

<%= [im_invoices_navbar "none" "/intranet/invoices/index" "" "" [list]] %>

<form method=POST action=invoice-association-action-2.tcl>
<%= [export_form_vars invoice_id return_url] %>
<table border=0 cellspacing=1 cellpadding=1>
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
      Customer.
    </td>
    <td>
      <A href="/intranet/customers/view?customer_id=@customer_id@">@customer_name@</A>
    </td>
  </tr>
  <tr>
    <td>
      Associte with:
    </td>
    <td>
      @project_select;noquote@
    </td>
  </tr>
  <tr>
    <td colspan=2 align=right>
      <input type=submit value="Assoiate">
    </td>
  </tr>
</table>
</form>


<!--
        i.invoice_date + i.payment_days as calculated_due_date,
        pm_cat.category as invoice_payment_method,
        pm_cat.category_description as invoice_payment_method_desc,
        im_name_from_user_id(c.accounting_contact_id) as customer_contact_name,
        im_email_from_user_id(c.accounting_contact_id) as customer_contact_email,
        c.customer_name,
        cc.country_name,
        im_category_from_id(i.invoice_status_id) as invoice_status,
        im_category_from_id(i.invoice_type_id) as invoice_type,
        im_category_from_id(i.invoice_template_id) as invoice_template

--<