<master src="../../intranet-core/www/master">
<property name=title>Add a user</property>
<property name="context">@context;noquote@</property>

<H1>Send @cost_type@ via Email</H1>

From: 
<A HREF=/intranet/users/view?user_id=@user_id@>
  @current_user_name@
</A>
&lt;@current_user_email@&gt;<br>

To: 
<A HREF=/intranet/users/view?user_id=@accounting_contact_id@>
  @accounting_contact_name@
</A>
&lt;@accounting_contact_email@&gt;<br>

<form method="post" action="/intranet/member-notify">
@export_vars;noquote@

<textarea name=subject rows=1 cols=70 wrap=hard>
@system_name@: New @cost_type@
</textarea>

<!-- --------------------------------------------------- -->
<textarea name=message rows=10 cols=70 wrap=hard>
Dear @accounting_contact_name@,

A new @cost_type@ has been created for you at:
@system_url@/intranet-invoices/view?invoice_id=@invoice_id@

The new document is related to the project(s):
@select_projects;noquote@
Please visit the link above and print out the document
for your personal reference.

Best regards,
@current_user_name@</textarea>
<!-- --------------------------------------------------- -->

<center>
<input type="submit" value="Send Email" />
</center>

</form>
</p>


