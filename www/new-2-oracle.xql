<?xml version="1.0"?>
<queryset>
   <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

<fullquery name="create_invoice">
        <querytext>

        BEGIN
	     1:= im_invoice.new (
                invoice_id              => :invoice_id,
                creation_user           => :user_id,
                creation_ip             => '[ad_conn peeraddr]',
                invoice_nr              => :invoice_nr,
                company_id             => :company_id,
                provider_id             => :provider_id,
                invoice_date            => :invoice_date,
                invoice_template_id     => :template_id,
                invoice_status_id       => :cost_status_id,
                invoice_type_id         => :cost_type_id,
                payment_method_id       => :payment_method_id,
                payment_days            => :payment_days,
                amount                  => 0,
                vat                     => :vat,
                tax                     => :tax,
                note                    => :note
            );
        END;

        </querytext>
</fullquery>
<fullquery name="create_rel">
        <querytext>

        begin
          :1 := acs_rel.new (
                 object_id_one => :project_id,
                 object_id_two => :invoice_id
        end;

        </querytext>
</fullquery>
</queryset>
