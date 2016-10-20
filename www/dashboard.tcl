# /packages/intranet-invoices/www/index.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Offers a menu to create new Invoices, Quotes, POs
    and Bills

    @author frank.bergmann@project-open.com
} {
    { project_id 0 }
    { company_id 0 }
}
set user_id [auth::require_login]
set page_title "[_ intranet-cost.Finance_Home]"
set context_bar [im_context_bar $page_title]
set return_url [im_url_with_query]

if {![im_permission $user_id view_costs]} {
    ad_return_complaint 1 "<li>You have insufficiente privileges to view this page"
    return
}

if {"" == $project_id} { set project_id 0}
if {"" == $company_id} { set company_id 0}

# select the "Finance" Menu
set parent_menu_sql "select menu_id from im_menus where label='finance'"
set parent_menu_id [util_memoize [list db_string parent_admin_menu $parent_menu_sql -default 0]]
set menu_select_sql "
        select  m.*
        from    im_menus m
        where   parent_menu_id = :parent_menu_id
		and enabled_p = 't'
                and im_object_permission_p(m.menu_id, :user_id, 'read') = 't'
        order by sort_order"


# ---------------------------------------------------------------
# Sub-Navbar
# ---------------------------------------------------------------

set sub_navbar [im_costs_navbar "none" "/intranet/invoices/index" "" "" [list] "costs_home"] 


# ---------------------------------------------------------------
# Format the admin menu
# ---------------------------------------------------------------

set admin_html ""
set exchange_rates_url "/intranet-exchange-rate/index"
append admin_html "<li><a href='$exchange_rates_url'>[lang::message::lookup "" intranet-cost.Exchange_Rates "Exchange Rates"]</a></li>\n"

set admin_html "<ul>$admin_html</ul>"

# ---------------------------------------------------------------
# Format the Provider Document Creation Menu
# ---------------------------------------------------------------

set parent_menu_sql "select menu_id from im_menus where label= 'invoices_providers'"
set parent_menu_id [util_memoize [list db_string parent_admin_menu $parent_menu_sql -default ""]]

set menu_select_sql "
        select  m.*
        from    im_menus m
        where   parent_menu_id = :parent_menu_id
		and enabled_p = 't'
                and im_object_permission_p(m.menu_id, :user_id, 'read') = 't'
        order by sort_order
"

# Start formatting the menu bar
set provider_menu "<ul>"
set ctr 0
db_foreach menu_select $menu_select_sql {
    
    ns_log Notice "im_sub_navbar: menu_name='$name'"
    regsub -all " " $name "_" name_key
    set wrench_url [export_vars -base "/intranet/admin/menus/index" {menu_id return_url}]
    append provider_menu "<li><a href=\"$url\">[_ intranet-invoices.$name_key]</a>
                              <a href='$wrench_url'>[im_gif wrench]</a></li>
    "
    incr ctr
}
append provider_menu "</ul>"
set provider_ctr $ctr



# ---------------------------------------------------------------
# Format the Customer Document Creation Menu
# ---------------------------------------------------------------

set parent_menu_sql "select menu_id from im_menus where label= 'invoices_customers'"
set parent_menu_id [util_memoize [list db_string parent_admin_menu $parent_menu_sql -default ""]]

set menu_select_sql "
        select  m.*
        from    im_menus m
        where   parent_menu_id = :parent_menu_id
		and enabled_p = 't'
                and im_object_permission_p(m.menu_id, :user_id, 'read') = 't'
        order by sort_order
"

# Start formatting the menu bar
set customers_menu "<ul>"
set ctr 0
db_foreach menu_select $menu_select_sql {
    ns_log Notice "im_sub_navbar: menu_name='$name'"
    regsub -all " " $name "_" name_key
    set wrench_url [export_vars -base "/intranet/admin/menus/index" {menu_id return_url}]
    append customers_menu "<li><a href=\"$url\">[_ intranet-invoices.$name_key]</a>
                               <a href='$wrench_url'>[im_gif wrench]</a></li>
    "
    incr ctr
}
append customers_menu "</ul>"
set customer_ctr $ctr




# ---------------------------------------------------------------
# Format the Report Creation Menu
# ---------------------------------------------------------------

set parent_menu_sql "select menu_id from im_menus where label = 'reporting-finance'"
set parent_menu_id [util_memoize [list db_string parent_admin_menu $parent_menu_sql -default ""]]

set menu_select_sql "
        select  m.*
        from    im_menus m
        where   parent_menu_id = :parent_menu_id
		and enabled_p = 't'
                and im_object_permission_p(m.menu_id, :user_id, 'read') = 't'
        order by sort_order
"

# Start formatting the menu bar
set reports_menu "<ul>"
set ctr 0
db_foreach menu_select $menu_select_sql {
    ns_log Notice "im_sub_navbar: menu_name='$name'"
    set name_key [string map {" " "_" "(" "" ")" ""} $name]
    set wrench_url [export_vars -base "/intranet/admin/menus/index" {menu_id return_url}]
    append reports_menu "<li><a href=\"$url\">[lang::message::lookup "" intranet-reporting.$name_key $name]</a>
                               <a href='$wrench_url'>[im_gif wrench]</a></li>
    "
    incr ctr
}
append reports_menu "</ul>"
set reports_ctr $ctr



# ---------------------------------------------------------------
# Left-Navbar Filter
# ---------------------------------------------------------------

set form_id "cost_filter"
set action_url "/intranet-invoices/list"
set form_mode "edit"
set object_type "im_invoice"

set cost_creator_options [list "" ""]
db_foreach creator_option "
	select	distinct
		im_name_from_user_id(creation_user) as creator_name,
		creation_user as creator_id
	from	acs_objects
	where	object_type in ('im_cost', 'im_invoice')
	order by creator_name
" { lappend cost_creator_options [list $creator_name $creator_id] }

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {start_idx order_by how_many view_name letter } \
    -form {
	{cost_status_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-cost.Status Status]"} {custom {category_type "Intranet Cost Status" translate_p 1 package_key "intranet-core"}} }
	{cost_type_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-cost.Type Type]"} {custom {category_type "Intranet Cost Type" translate_p 1 package_key "intranet-core"} } }
	{cost_creator_id:text(select),optional {label "[lang::message::lookup {} intranet-cost.Creator Creator]"} {options $cost_creator_options}}
    }

im_dynfield::append_attributes_to_form \
    -object_type $object_type \
    -form_id $form_id \
    -object_id 0 \
    -advanced_filter_p 1 \
    -search_p 1

# Set the form values from the HTTP form variable frame
im_dynfield::set_form_values_from_http -form_id $form_id
im_dynfield::set_local_form_vars_from_http -form_id $form_id

array set extra_sql_array [im_dynfield::search_sql_criteria_from_form \
			       -form_id $form_id \
			       -object_type $object_type
]


# Compile and execute the formtemplate if advanced filtering is enabled.
eval [template::adp_compile -string {<formtemplate style="tiny-plain-po" id="cost_filter"></formtemplate>}]
set filter_html $__adp_output


set left_navbar_html "
	    <div class=\"filter-block\">
		<div class=\"filter-title\">
		    [lang::message::lookup "" intranet-cost.Filter_Costs "Filter Costs"]
		</div>
		$filter_html
	    </div>
	    <hr/>
"


append left_navbar_html "
	    <div class=\"filter-block\">
		<div class=\"filter-title\">
		    [lang::message::lookup "" intranet-cost.New_Customer_Documents "New Customer Docs"]
		</div>
		$customers_menu
	    </div>
	    <hr/>
"



append left_navbar_html "
	    <div class=\"filter-block\">
		<div class=\"filter-title\">
		    [lang::message::lookup "" intranet-cost.New_Provider_Documents "New Provider Docs"]
		</div>
		$provider_menu
	    </div>
	    <hr/>
"



append left_navbar_html "
	    <div class=\"filter-block\">
		<div class=\"filter-title\">
		    [lang::message::lookup "" intranet-cost.Admin "Administration"]
		</div>
		$admin_html
	    </div>
	    <hr/>
"


append left_navbar_html "
	    <div class=\"filter-block\">
		<div class=\"filter-title\">
		    [lang::message::lookup "" intranet-cost.Reports "Reports"]
		</div>
		$reports_menu
	    </div>
	    <hr/>
"

