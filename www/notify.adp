<master src="../../intranet-core/www/master">
<property name=title>#intranet-invoices.Add_a_user#</property>
<property name="context">@context;noquote@</property>
<property name="main_navbar_label">finance</property>

<H1>#intranet-invoices.lt_Send_cost_type_via_Em#</H1>


<form method="post" action="/intranet/member-notify">
@export_vars;noquote@

<table>
<tr class=roweven>
<td>#intranet-invoices.From#</td>
<td>
<A HREF=/intranet/users/view?user_id=@user_id@>
  @current_user_name@
  #intranet-invoices.lt_ltcurrent_user_emailg#<br>
</A>
</td>
</tr>

<tr class=rowodd>
<td>#intranet-invoices.To#</td>
<td>
<A HREF=/intranet/users/view?user_id=@accounting_contact_id@>
  @accounting_contact_name@
</A>
#intranet-invoices.lt_ltaccounting_contact_#<br>
</td>
</tr>

<tr class=roweven>
<td>Subject</td>
<td>
<input type=text name=subject value="#intranet-invoices.lt_system_name_New_cost_#" size=70>
</td>

<tr class=rowodd>
<td>Message</td>
<td>
<textarea name=message rows=10 cols=70 wrap=hard>
#intranet-invoices.lt_Dear_accounting_conta#</textarea>
</td>
</tr>

<if @send_to_user_as@ ne "">
<tr class=roweven valign=center>
<td>Attachment</td>
<td>
  <input type=text name=attachment_filename value="@attachment_filename@" size=40>
  <%= [im_gif "exp-$send_to_user_as" $send_to_user_as] %>
</td>
</tr>
</if>

<tr valign=top>
<td>&nbsp;</td>
<td align=center>

  <input type=checkbox name=send_me_a_copy value=1>
  Send me a copy
  <input type="submit" value="Send Email" />

</td>
</tr>
</table>
</form>




