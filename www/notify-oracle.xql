<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-invoices/www/notify-oracle.xql -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->
<!-- @creation-date 2004-10-07 -->
<!-- @arch-tag 5a4d66ad-c18d-46bf-b150-8ff2c1fbb877 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>oracle</type>
    <version>8.1.6</version>
  </rdbms>
  
  <fullquery name="project_name">
    <querytext>
      select acs_object.name(:invoice_id) from dual
    </querytext>
  </fullquery>
</queryset>
