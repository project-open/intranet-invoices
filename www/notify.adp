<master src="../../intranet-core/www/master">
<property name=title>Add a user</property>
<property name="context">@context;noquote@</property>

<H1>Send @cost_type@ via Email</H1>

<ul>
  <li>Preview @cost_type@
</ul>
</p>

<form method="post" action="notify-2">
@export_vars;noquote@

<textarea name=subject rows=1 cols=70 wrap=hard>
@system_name@: New @cost_type@
</textarea>

<textarea name=message rows=10 cols=70 wrap=hard>
Dear @accountant_name@,

please find attached a @cost_type@ for project(s):

@select_projects;noquote@

Best regards,
@current_user_name@</textarea>

<center>
<input type="submit" value="Send Email" />
</center>

</form>
</p>


