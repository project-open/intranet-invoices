<master src="../../intranet-core/www/master">
<property name=title>#intranet-invoices.Add_a_user#</property>
<property name="context">@context;noquote@</property>
<property name="main_navbar_label">finance</property>

<H1>#intranet-invoices.lt_Send_cost_type_via_Em#</H1>

#intranet-invoices.From# 
<A HREF=/intranet/users/view?user_id=@user_id@>
  @current_user_name@
</A>
#intranet-invoices.lt_ltcurrent_user_emailg#<br>

#intranet-invoices.To# 
<A HREF=/intranet/users/view?user_id=@accounting_contact_id@>
  @accounting_contact_name@
</A>
#intranet-invoices.lt_ltaccounting_contact_#<br>

<form method="post" action="/intranet/member-notify">
@export_vars;noquote@

<textarea name=subject rows=1 cols=70 wrap=hard>
#intranet-invoices.lt_system_name_New_cost_#
</textarea>

<!-- --------------------------------------------------- -->
<textarea name=message rows=10 cols=70 wrap=hard>
#intranet-invoices.lt_Dear_accounting_conta#</textarea>
<!-- --------------------------------------------------- -->

<center>
<input type="submit" value="Send Email" />
</center>

</form>
</p>



