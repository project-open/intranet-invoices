# /www/intranet/payments/project-payment-ae-2.tcl

ad_page_contract {
    Purpose: records payments

    @param group_id 
    @param payment_id 
    @param start_block 
    @param fee 
    @param fee_type 
    @param due_date 
    @param received_date 
    @param note 

    @author fraber@fraber.de
    @creation-date Aug 2003
} {
    invoice_id:integer
    payment_id:integer
    amount
    currency
    received_date
    payment_type_id
    note
    { return_url "" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
if {[string equal "" $return_url]} {
    set return_url "/intranet/invoices/payments"
}


if {![im_permission $user_id view_finance]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

if { ![ad_var_type_check_number_p $amount] } {
    ad_return_complaint 1 "
    <li>The value \"amount\" entered from previous page must be a valid number."
    return
}

if { $amount < 0 } {
    ad_return_complaint 1 "
    <li>The value \"amount\" entered from previous page must be non-negative."
    return
}
set note [db_nullify_empty_string $note]


# ---------------------------------------------------------------
# Insert data into the DB
# ---------------------------------------------------------------

db_dml payment_update "
update
	im_payments 
set
	invoice_id = :invoice_id,
	amount = :amount,
	currency = :currency,
	received_date = :received_date,
	payment_type_id = :payment_type_id,
	note = :note,
	last_modified = sysdate,
	last_modifying_user = :user_id,
	modified_ip_address = '[ns_conn peeraddr]'
where
	payment_id = :payment_id" 


if {[db_resultrows] == 0} {
    db_dml new_payment_insert "
insert into im_payments ( 
	payment_id, 
	invoice_id,
	amount, 
	currency,
	received_date,
	payment_type_id,
	note, 
	last_modified, 
	last_modifying_user, 
	modified_ip_address
) values ( 
	:payment_id, 
	:invoice_id,
        :amount, 
	:currency,
	:received_date,
	:payment_type_id,
        :note, 
	sysdate, 
	:user_id, 
	'[ns_conn peeraddr]' 
)" 
}

ad_returnredirect $return_url
ns_conn close


# ---------------------------------------------------------------
# # email the people in the billing group
# ---------------------------------------------------------------

db_1row get_user_info "
	select
		first_names || ' ' || last_name as editing_user, 
		email as editing_email
	from users 
	where user_id = :user_id"

set customer_name [db_string get_customer_name "select group_name from user_groups where group_id = :customer_id"]
set invoice_nr [db_string get_invoice_nr "select invoice_nr from im_invoices where invoice_id = :invoice_id"]


set message "

A payment for invoice #$invoice_nr of $customer_name has been changed by $editing_user.

Amount: $amount
Note: $note

To view online: [im_url]/invoices/view-payment?[export_url_vars payment_id]
"

# Whom to send the email?
set billing_group [ad_parameter BillingGroupShortName "intranet"]

set send_to_users_sql "
	select email, first_names, last_name 
	from users, user_group_map
	where users.user_id = user_group_map.user_id 
	      and group_id = (select group_id from user_groups 
	                      where short_name = :billing_group"
	                     )"

db_foreach people_to_notify $send_to_users_sql {
    ns_log Notice "Sending email to $email"
    ns_sendmail $email "$editing_email" "Change to $customer_name payment plan." "$message"
}

db_release_unused_handles