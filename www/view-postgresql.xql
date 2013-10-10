<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/view-postgresql.xql -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->
<!-- @creation-date 2004-10-08 -->
<!-- @arch-tag ffe2b337-c79b-4b45-bfcb-41a371866d36 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  
  <fullquery name = "invoice_items">
    <querytext>
      select
	i.*,
	p.*,
	im_category_from_id(i.item_type_id) as item_type,
	im_category_from_id(i.item_uom_id) as item_uom,
	p.project_nr as project_short_name,
	round(i.price_per_unit * i.item_units * :rf) / :rf as amount,
	to_char(round(i.price_per_unit * i.item_units * :rf) / :rf, :cur_format) as amount_formatted,
        i.currency as item_currency
      from
	im_invoice_items i
	      LEFT JOIN im_projects p on i.project_id=p.project_id
      where
	i.invoice_id=:invoice_id
      order by
	i.sort_order,
	i.item_type_id;
      </querytext>
    </fullquery>


  <fullquery name = "calc_grand_total">
    <querytext>

	select	i.*,
		round(i.grand_total * :vat / 100 * :rf) / :rf as vat_amount,
		round(i.grand_total * :tax / 100 * :rf) / :rf as tax_amount,
		i.grand_total
			+ round(i.grand_total * :vat / 100 * :rf) / :rf
			+ round(i.grand_total * :tax / 100 * :rf) / :rf
		as total_due
	from
		(select
			max(i.currency) as currency,
			sum(i.amount) as subtotal,
			round(sum(i.amount) * :surcharge_perc::numeric) / 100.0 as surcharge_amount,
			round(sum(i.amount) * :discount_perc::numeric) / 100.0 as discount_amount,
			sum(i.amount)
				+ round(sum(i.amount) * :surcharge_perc::numeric) / 100.0
				+ round(sum(i.amount) * :discount_perc::numeric) / 100.0
			as grand_total
		from 
			(select	ii.*,
				round(ii.price_per_unit * ii.item_units * :rf) / :rf as amount
			from	im_invoice_items ii,
				im_invoices i
			where	i.invoice_id = ii.invoice_id
				and i.invoice_id = :invoice_id
			) i
		) i

    </querytext>
  </fullquery>




</queryset>
