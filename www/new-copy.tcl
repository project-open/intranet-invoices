# /packages/intranet-invoices/www/new-copy.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Creates a new financial document from an existing one.
    Typically you create:
    - Bill from PO and
    - Invoice from Quote.
    The page allows the user to select the original document
    and creates a copy with the new invoice_type_id.
    Also, a new document nr is created (it's unique).

    @param invoice_id - Indicates a specific financial document
           to be taken as the base for the copy
    @invoice_type_id Document type for the new document
    @from_invoice_type_id Document type of the original
    @project_id Restricts the search for originals to a project
    @customer_id Restricts the search for originals to a company

    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    invoice_type_id:integer
    { return_url "/intranet-invoice/"}
}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id view_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

switch $invoice_type_id {
    702 {
	set to_invoice_type_id [im_invoice_type_invoice]
    }
    706 {
	set to_invoice_type_id [im_invoice_type_bill]
    }
    default {
	ad_return_complaint 1 "<li>Bad Document Type $invoice_type_id:<br>
        We expect either a Quote or a Purchase Order as the document type."
    }
}


set todays_date [db_string get_today "select sysdate from dual"]
set page_focus "im_header_form.keywords"
set view_name "invoice_copy"
set invoice_type_name [db_string invoice_type_name "select im_category_from_id(:invoice_type_id) from dual"]
set from_invoice_type_name [db_string invoice_type_name "select im_category_from_id(:from_invoice_type_id) from dual"]

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"

# ---------------------------------------------------------------
# 3. Gather invoice data
# ---------------------------------------------------------------


# We are editing an already existing invoice
#
db_1row invoices_info_query "
select 
	i.*,
	im_name_from_user_id(i.customer_contact_id) as customer_contact_name,
	im_email_from_user_id(i.customer_contact_id) as customer_contact_email,
	c.customer_name as customer_name,
	c.customer_path as customer_short_name,
	p.customer_name as provider_name,
	p.customer_path as provider_short_name
from
	im_invoices i, 
	im_customers c,
	im_customers p
where 
        i.invoice_id=:invoice_id
	and i.customer_id=c.customer_id(+)
	and i.provider_id=p.customer_id(+)
    "

# Check if there is a single currency being used in the invoice
# and get it.
# This should always be the case, but doesn't need to...

if {"" == $invoice_currency} {
    catch {
	db_1row invoices_currency_query "
select distinct
	currency as invoice_currency
from
	im_invoice_items i
where
	i.invoice_id=:invoice_id"
    } err_msg
}

# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

set invoice_or_quote_p [expr $invoice_type_id == [im_invoice_type_invoice] || $invoice_type_id == [im_invoice_type_quote]]
if {$invoice_or_quote_p} {
    set company_id $customer_id
} else {
    set company_id $provider_id
}

# ---------------------------------------------------------------
# 8. Get the old invoice items for an already existing invoice
# ---------------------------------------------------------------

    set invoice_item_sql "
select
	i.*,
	p.*,
	p.project_nr as project_short_name,
	im_category_from_id(i.item_uom_id) as item_uom,
	im_category_from_id(i.item_type_id) as item_type
from
	im_invoice_items i,
	im_projects p
where
	i.invoice_id=:invoice_id
	and i.project_id=p.project_id(+)
order by
	i.project_id
"

    # start formatting the list of sums with the header...
    set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>Order</td>
          <td class=rowtitle>Description</td>
          <td class=rowtitle>Type</td>
          <td class=rowtitle>Units</td>
          <td class=rowtitle>UOM</td>
          <td class=rowtitle>Rate </td>
        </tr>
    "

    set ctr 1
    set old_project_id 0
    set colspan 6
    set target_language_id ""
    db_foreach invoice_item $invoice_item_sql {

	# insert intermediate headers for every project
	if {$old_project_id != $project_id} {
	    append task_sum_html "
		<tr><td class=rowtitle colspan=$colspan>
	          <A href=/intranet/projects/view?group_id=$project_id>$project_short_name</A>:
	          $project_name
	        </td></tr>\n"
	
	    set old_project_id $project_id
	}

	append task_sum_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>
	    <input type=text name=item_sort_order.$ctr size=2 value='$sort_order'>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value='$item_name'>
	  </td>
          <td>
	    <input type=hidden name=item_type_id.$ctr value='$item_type_id'>
            $item_type
          </td>
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='$item_units'>
	  </td>
          <td align=right>
	    <input type=hidden name=item_uom_id.$ctr value='$item_uom_id'>
	    $item_uom
	  </td>
          <td align=right>
	    <input type=text name=item_rate.$ctr size=3 value='$price_per_unit'>
	    <input type=hidden name=item_currency.$ctr value='$currency'>
	    $currency
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value='$project_id'>
"
	incr ctr
    }
}


# ---------------------------------------------------------------
# Add some empty new lines for editing purposes
# ---------------------------------------------------------------



# Add a fixed number of lines to enter data
#
for {set i 0} {$i < 3} {incr i} {
    
    append task_sum_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>
	    <input type=text name=item_sort_order.$ctr size=2 value=''>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value=''>
	  </td>
          <td>
            [im_category_select "Intranet Project Type" item_type_id.$ctr ""]
          </td>
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='0'>
	  </td>
          <td align=right>
            [im_category_select "Intranet UoM" item_uom_id.$ctr 320]
	  </td>
          <td align=right>
            <!-- rate and currency need to be together so that the line doesn't break -->
	    <input type=text name=item_rate.$ctr size=3 value='0'>[im_currency_select item_currency.$ctr $invoice_currency]
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value=''>
"

    incr ctr
}




# ---------------------------------------------------------------
# Calculate the selects for the ADP page
# ---------------------------------------------------------------

set payment_method_select [im_invoice_payment_method_select payment_method_id $payment_method_id]
set template_select [im_invoice_template_select invoice_template_id $invoice_template_id]
set status_select [im_invoice_status_select invoice_status_id $invoice_status_id]
set type_select [im_invoice_type_select invoice_type_id $invoice_type_id]
set customer_select [im_customer_select customer_id $customer_id "" "Customer"]
set provider_select [im_customer_select provider_id $provider_id "" "Provider"]


db_release_unused_handles

