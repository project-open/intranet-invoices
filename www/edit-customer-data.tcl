# /www/intranet/projects/edit-customer-data.tcl

ad_page_contract {
    Purpose: form to add a new project or edit an existing one
    
    @param group_id group id
    @param return_url the url to return to
    @author mbryzek@arsdigita.com
    @creation-date Jan 2000

    @cvs-id edit-customer-data.tcl,v 3.15.2.12 2000/09/22 01:38:44 kevin Exp
} {
    group_id:integer
    return_url
}

set user_id [ad_maybe_redirect_for_registration]
set user_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]

db_1row projects_info_query { 
select 
        g.group_name as project_name, 
        g.short_name as project_short_name,
	p.customer_id,
        p.customer_contact_id,
        p.final_customer,
        p.expected_quality_id,
        g2.group_name as customer_name,
        p.customer_project_nr
from
	im_projects p, 
        user_groups g,
        user_groups g2
where 
	p.group_id=:group_id 
        and p.group_id=g.group_id 
	and p.customer_id=g2.group_id(+)
}

    set page_title "Edit Customer Data"
    set context_bar [ad_context_bar_ws [list /intranet/projects/ "Projects"] [list "/intranet/projects/view?[export_url_vars group_id]" "One project"] $page_title]

set page_body "
                <form action=edit-customer-data-2 method=post name=edit-customer-data>
[export_form_vars return_url group_id dp_ug.user_groups.creation_ip_address dp_ug.user_groups.creation_user]
                  <table border=0>
                    <tr> 
                      <td colspan=2 class=rowtitle align=middle>
                        Project Details
                      </td>
                    </tr>
                    <tr> 
                    <tr> 
                      <td>Client project #</td>
                      <td> 
                        <input type=text size=40 name=customer_project_nr value=$customer_project_nr>
                         <img src=/images/help.gif width=16 height=16 alt='An optional field specifying the project reference code of the client. Is used when printing the invoice. Example: 20030310A12478'> 
                      </td>
                    </tr>
                    <tr> 
                      <td>Final User &nbsp;</td>
                      <td> 
                        <input type=text size=20 name=final_customer value=$final_customer>
                         <img src=/images/help.gif width=16 height=16 alt='Who is the final consumer (when working for an agency)? Examples: \"Shell\", \"UBS\", ...'> 
                      </td>
                    </tr>
                    <tr> 
                      <td>Client contact &nbsp;</td>
                      <td>
[im_customer_contact_select "customer_contact_id" $customer_contact_id $customer_id]
                      </td>
                    </tr>
                    <tr> 
                      <td>Quality Level</td>
                      <td> 
[im_category_select "Intranet Quality" "expected_quality_id" $expected_quality_id]
                      </td>
                    </tr>
                    <tr> 
                      <td valign=top> 
                        <div align=right>&nbsp; </div>
                      </td>
                      <td> 
                          <p> 
                            <input type=submit value='Submit changes' name=submit2>
                            <img src=/images/help.gif width=16 height=16 alt='Create the new folder structure'> 
                          </p>
                      </td>
                    </tr>
                  </table>
                </form>
"

doc_return  200 text/html [im_return_template]

