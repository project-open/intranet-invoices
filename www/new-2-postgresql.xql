<?xml version="1.0"?>
<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="create_invoice">
        <querytext>

  select im_invoice__new (
                :invoice_id,		-- invoice_id
		'im_invoice',		-- object_type
		now(),			-- creation_date 
                :user_id,		-- creation_user
                '[ad_conn peeraddr]',	-- creation_ip
		null,			-- context_id
                :invoice_nr,		-- invoice_nr
                :company_id,		-- company_id
                :provider_id,		-- provider_id
		null,			-- company_contact_id
                :invoice_date,		-- invoice_date
		'EUR',			-- currency
                :template_id,		-- invoice_template_id
                :cost_status_id,	-- invoice_status_id
                :cost_type_id,		-- invoice_type_id
                :payment_method_id,	-- payment_method_id
                :payment_days,		-- payment_days
                0,			-- amount
                :vat,			-- vat
                :tax,			-- tax
                :note			-- note
            )
        </querytext>
</fullquery>
<fullquery name="create_rel">
    <querytext>

      select acs_rel__new (
             null,             -- rel_id
             'relationship',   -- rel_type
             :project_id,      -- object_id_one
             :invoice_id,      -- object_id_two
             null,             -- context_id
             null,             -- creation_user
             null             -- creation_ip
      )

    </querytext>
</fullquery>
</queryset>
