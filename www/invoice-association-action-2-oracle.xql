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
  
  <fullquery name="insert_association">
    <querytext>
      begin
       :1 := acs_rel.new(
                object_id_one => :object_id,
                object_id_two => :invoice_id
        );
      end;
    </querytext>
  </fullquery>
</queryset>
