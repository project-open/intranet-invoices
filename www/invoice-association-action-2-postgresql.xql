<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/invoice-association-action-2-postgresql.xql -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->
<!-- @creation-date 2004-10-07 -->
<!-- @arch-tag e5082d5b-edcf-4b26-a9e6-4c729ef96982 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  
  <fullquery name="insert_association">
    <querytext>
      select acs_rel__new (
         null,
         'relationship',
         :object_id,
         :invoice_id,
         null,
         null,
         null
        )
    </querytext>
   </fullquery>
</queryset>
