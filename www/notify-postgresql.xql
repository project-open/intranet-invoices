<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/notify-postgresql.xql -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->
<!-- @creation-date 2004-10-07 -->
<!-- @arch-tag 16a384f6-aa92-4668-9f42-51b4e1085bc8 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  
  <fullquery name="project_name">
    <querytext>
      select acs_object__name(:invoice_id) from dual
    </querytext>
  </fullquery>
</queryset>
