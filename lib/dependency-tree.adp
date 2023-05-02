<if 1 eq @show_html_p@>
<table>
  <tr valign=top>
    <td width='70%'>
	<table cellspaing=2 cellpadding=2>

	  <tr>
	    <td class=rowtitle>Name</td>
	    <td class=rowtitle>Amount</td>
	    <td class=rowtitle>Type</td>
	    <td class=rowtitle>Status</td>
	  </tr>

	  <tr><td colspan=99><h1>Predecessors</h1></td></tr>
	  @predecessor_html;noquote@

	  <tr><td colspan=99><h1>Successors</h1></td></tr>
	  @successor_html;noquote@

	</table>
    </td>
    <td width='30%'>
	<p>This portlet shows predecessors (= financial documents from which this document was created)
	  and successors (= financial documents created based on this one).</p>
    </td>
  </td>
</table>
</if>
