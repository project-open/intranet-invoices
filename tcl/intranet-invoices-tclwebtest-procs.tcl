ad_library {
    Automated tests.

    @author Frank Bergmann
    @creation-date 14 June 2024
}

namespace eval im_invoice::twt {

    ad_proc new { 
	{-name ""}
	{-amount ""}
	{-type_id 3700}
	{-status_id 3802}
	{-cost_center_id 0}
	{-predecessor_id 0}
	{-effective_date "2024-01-01" }
    } {
	Create a new invoice 
    } {
	set cost_type [im_category_from_id $type_id]
	if {"" eq $name} { set name [ad_generate_random_string 10] }
	set full_name "[string toupper [string range $cost_type 0 0]]$name"
	if {"" eq $amount} { set amount [randomRange 10000.0] }

	# Check if invoice already there
	set invoice_id [db_string invoice_p "select cost_id from im_costs where cost_name = :full_name" -default 0]
	if {0 != $invoice_id} { return $invoice_id }

	# Create invoice plus item
	set invoice_id [db_string cf_invoice "select im_invoice__new(
			null, 'im_invoice', now(), 624, '1.1.1.1', null,
			'I$name', 8720, 8720, null, :effective_date, 'EUR', 
                        null, :status_id, :type_id, null, 30, :amount, 0.0, 0.0, ''
		    )
        "]
	set invoice_item_id [db_string cf_i_item "select im_invoice_item__new(
			null, 'im_invoice_item', now(), 624, '1.1.1.1', null,
			'item name', :invoice_id, 0, 1.0, 322, :amount, 'EUR', 47100, 47000
        )"]

	if {0 != $cost_center_id} {
	    db_dml cf_update "update im_costs set cost_center_id = :cost_center_id where cost_id = :invoice_id"
	}
	if {0 != $predecessor_id} {
	    db_dml pred_update "update im_invoice_items set item_source_invoice_id = :predecessor_id where invoice_id = :invoice_id"
	}

	return $invoice_id
    }

}


namespace eval im_cost_center::twt {

    ad_proc new { 
	{-name "TestCC"}
	{-code "CoTe"}
	{-parent_id 0}
	{-type_id 3001}
	{-status_id 3101}
    } {
	Create a new cost center
    } {
	if {"" eq $name} { set name [string tolower [ad_generate_random_string 10]] }
	if {0 == $parent_id} { set parent_id [db_string cc_top "select min(cost_center_id) from im_cost_centers where parent_id is null" -default 0]}

	# Check if cost_center already there
	set cost_center_id [db_string cc_p "select cost_center_id from im_cost_centers where cost_center_name = :name" -default 0]
	if {0 != $cost_center_id} { return $cost_center_id }

	set cost_center_id [db_string cc "select im_cost_center__new(
		        null, 'im_cost_center', now(), 0, '1.1.1.1', :parent_id::integer,
		        :name, :name, :code, :type_id::integer, :status_id::integer, :parent_id::integer, null, 't', 'desc', 'note'
	)"]

	return $cost_center_id
    }

}
