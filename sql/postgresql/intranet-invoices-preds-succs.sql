

-- Returns a formatted string with links to successor objects
create or replace function im_invoice_predecessor_links(integer)
returns varchar as $body$
declare
	p_invoice_id alias for $1;
	row RECORD;
	v_result varchar;
begin
	v_result := '';
	FOR row IN
		select distinct
			c_pred.cost_id as pred_id, 
			c_pred.cost_name as pred_name
		from	im_invoice_items ii,
			im_costs c_pred
		where	ii.invoice_id = p_invoice_id and
			c_pred.cost_id = item_source_invoice_id
	LOOP
		IF v_result != '' THEN
			v_result = v_result || ', ';    
		END IF;
		v_result = v_result || 
			 '<a href=/intranet-invoices/view?invoice_id=' || row.pred_id ||
			 '>' || row.pred_name || '</a>';
	END LOOP;
	return v_result;
end; $body$ language 'plpgsql';


create or replace function im_invoice_successor_links(integer)
returns varchar as $body$
declare
	p_invoice_id alias for $1;
	row RECORD;
	v_result varchar;
begin
	v_result := '';
	FOR row IN
		select distinct
			c_succ.cost_id as succ_id, 
			c_succ.cost_name as succ_name
		from	im_invoice_items ii,
			im_costs c_succ
		where	ii.invoice_id = c_succ.cost_id and
			ii.item_source_invoice_id = p_invoice_id
	LOOP
		IF v_result != '' THEN
			v_result = v_result || ', ';    
		END IF;
		v_result = v_result || 
			 '<a href=/intranet-invoices/view?invoice_id=' || row.succ_id ||
			 '>' || row.succ_name || '</a>';
	END LOOP;
	return v_result;
end; $body$ language 'plpgsql';



create or replace function im_invoice_successor_sum(integer)
returns numeric as $body$
declare
	p_invoice_id alias for $1;
	row RECORD;
	v_result numeric;
begin
	v_result := 0.0;
	FOR row IN
		select distinct
			c_succ.cost_id as succ_id, 
			c_succ.cost_name as succ_name,
			c_succ.amount
		from	im_invoice_items ii,
			im_costs c_succ
		where	ii.invoice_id = c_succ.cost_id and
			ii.item_source_invoice_id = p_invoice_id
	LOOP
		v_result = v_result + row.amount;
	END LOOP;
	return v_result;
end; $body$ language 'plpgsql';




select im_invoice_predecessor_links(447724);
select im_invoice_successor_links(406832);

