CREATE OR replace PROCEDURE Disprp_pz_getorders (p_reqshipdate IN DATE, 
pzdatacur     OUT stdutl_ref_cursor.generic_cur) 
IS 
  --------------------------------------------------------------------------------   
  -- Procedure Name....:  DISPRP_PZ_GETORDERS   
  -- Creation Date.....:  06/06/2017   
  -- Copyright.........:  XPO Logistics Supply Chain   
  -- Author............:  Paul Wright   
  -- Purpose...........:  Retrieve new PZ orders   
  --------------------------------------------------------------------------------   
  -- Version History   
  --                            Author's   
  -- VI#   Version#  Date       Initials   Change Description   
  --------------------------------------------------------------------------------   
  --  1.   1.0      07/06/2017   PRW    Created   
  --------------------------------------------------------------------------------   
  lv_error_msg wm_db_error_log.message%TYPE; 
BEGIN 
    OPEN pzdatacur FOR 
      SELECT o.storerkey                       AS storerkey, 
             o.orderkey                        AS orderkey, 
             od.orderlinenumber                AS orderlinenumber, 
             o.requestedshipdate               AS requestedshipdate, 
             od.sku                            AS sku, 
             od.openqty                        AS qty, 
             odattr.refchar1                   AS to_msg, 
             odattr.refchar2                   AS frm_msg, 
             odattr.refchar3                   AS msg1, 
             odattr.refchar4                   AS msg2, 
             odattr.refchar5                   AS msg3, 
             Nvl (sl.loc, '***')               AS loc, 
             od.orderkey 
             || Substr (od.orderlinenumber, 2) AS jobno, 
             odattr.attr_type 
      FROM   orders o, 
             wm_orderdetail_attributes odattr, 
             wm_orderdetail_ext odpz, 
             wm_orderdetail_ext odmain, 
             orderdetail od, 
             skuxloc sl 
      WHERE  Trunc (o.requestedshipdate) = Trunc(p_reqshipdate) 
             --'user entered date'   
             AND o.ordergroup LIKE ( 'P%' ) 
             AND o.status IN ( '02', '92' ) 
             -- SUSR3 value which app is updating after printing   
             --    NULL to start with,   
             --    3 to be printed   
             --    5 is printed   
             --    9 is all put wall assignment done   
             AND Nvl (Trim (o.susr3), '0') <= '3' 
             -- join attributes table to get PZ line with attribute type = EB   
             AND o.orderkey = odattr.orderkey 
             AND odattr.attr_type = 'EB' 
             -- join attribute to order extension with orderkey and line number of PZ line   
             AND odpz.orderkey = odattr.orderkey 
             AND odpz.orderlinenumber = odattr.orderlinenumber 
             -- join od ext of PZ line with od ext of main line with orderkey and refchar2 1, 3 
             AND odmain.orderkey = odpz.orderkey 
             AND Substr (odmain.refchar2, 1, 3) = Substr (odpz.refchar2, 1, 3) 
             -- join orderdetail with od ext of main line with orderkey and order line number   
             AND od.orderkey = odmain.orderkey 
             AND od.orderlinenumber = odmain.orderlinenumber 
             AND od.openqty > 0 
             -- outer join to skuxloc   
             -- get skuxloc where loc like 'PZ%' and locationtype = 'PICK'   
             AND sl.storerkey(+) = od.storerkey 
             AND sl.sku(+) = od.sku 
             AND sl.loc(+) LIKE 'PZ%' 
             AND sl.locationtype(+) = 'PICK' 
             AND NOT EXISTS (SELECT '1' 
                             FROM   wm_pz_stage pz 
                             WHERE  pz.orderkey = O.orderkey 
                                    AND pz.jobno = od.orderkey 
                                                   || 
                                        Substr (od.orderlinenumber, 2) 
                                    AND adddate > SYSDATE - 30) 
      ORDER  BY odattr.orderkey, 
                odattr.orderlinenumber; 
EXCEPTION 
  WHEN OTHERS THEN 
             lv_error_msg := Substr(SQLERRM, 1, 300); 

             Raise_application_error(-20000, lv_error_msg); 
END disprp_pz_getorders; 
