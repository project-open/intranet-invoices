<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/invoice-association-action-2-oracle.xql -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->
<!-- @creation-date 2004-10-07 -->
<!-- @arch-tag 48a3aa6c-6b19-4397-97c8-2290ed48cf4a -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>oracle</type>
    <version>8.1.6</version>
  </rdbms>
  
  <fullquery name="delete_association">
    <querytext>
        DECLARE
                v_rel_id        integer;
        BEGIN
                for row in (
                        select distinct r.rel_id
                        from    acs_rels r
                        where   r.object_id_one = :object_id
                                and r.object_id_two = :invoice_id
                ) loop
                        acs_rel.del(row.rel_id);
                end loop;
        END;
    </querytext>
  </fullquery>
</queryset>
