<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/invoice-association-action-postgresql.xql -->
<!-- @author Frank Bergmann (frank.bergmann@project-open.com) -->
<!-- @creation-date 2005-01-23 -->
<!-- @arch-tag e5082d5b-edcf-4b26-a9e6-4c729ef96982 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  
  <fullquery name="delete_association">
    <querytext>
      DECLARE
	row record;
      BEGIN
	for row in
		select distinct r.rel_id
		from    acs_rels r
		where   r.object_id_one = :object_id
			and r.object_id_two = :invoice_id
	loop
		PERFORM acs_rel__delete(row.rel_id);
	end loop;
	return 0;
      END;
    </querytext>
   </fullquery>
</queryset>
