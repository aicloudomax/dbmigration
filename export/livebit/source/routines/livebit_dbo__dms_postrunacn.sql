create   PROC [dbo].[DMS_PostRunACN] AS


--Select 'PRE Row Base Count P07 ACN' as 'RowType', Count(1) 'RowCount',Count(Distinct ZLKUNNR ) 'DistinctACN'  From SAPX07_R_YMDM_ACN_P07_NEW UNION
--Select 'PRE Row Base Count INFA ACN' as 'RowType', Count(1) 'RowCount',Count(Distinct ZLKUNNR ) 'DistinctBP'  From INFA_C_BO_LEGACY_ACN_XREF_NEW 

IF OBJECT_ID('dbo.SAPX07_R_YMDM_ACN_P07_NEW_Base', 'U')	IS NOT NULL BEGIN	DROP TABLE dbo.SAPX07_R_YMDM_ACN_P07_NEW_Base	END 
IF OBJECT_ID('dbo.INFA_C_BO_LEGACY_ACN_XREF_NEW_Base', 'U')	IS NOT NULL BEGIN	DROP TABLE dbo.INFA_C_BO_LEGACY_ACN_XREF_NEW_Base	END 

Select * INTO	 SAPX07_R_YMDM_ACN_P07_NEW_Base				from SAPX07_R_YMDM_ACN_P07_NEW
Select * INTO	 INFA_C_BO_LEGACY_ACN_XREF_NEW_Base			from INFA_C_BO_LEGACY_ACN_XREF_NEW  

--Select 'PRE Row Base Count P07 ACN' as 'RowType', Count(1) 'RowCount',Count(Distinct ZLKUNNR ) 'DistinctACN'  From SAPX07_R_YMDM_ACN_P07_NEW_Base UNION
--Select 'PRE Row Base Count INFA ACN' as 'RowType', Count(1) 'RowCount',Count(Distinct ZLKUNNR ) 'DistinctBP'  From INFA_C_BO_LEGACY_ACN_XREF_NEW_Base 

--Select Top 100 * from SAPX07_R_YMDM_ACN_P07_NEW
--Select Top 100 * from INFA_C_BO_LEGACY_ACN_XREF_NEW
--Select Top 100 * from [dbo].[INFA_Q11_SAP_INFA_REF_TBL]



/* VP 06/06 Tries with normal join 
Alter table  SAPX07_R_YMDM_ACN_P07_NEW add CUST_NBR nvarchar(100) -- added Sandeep 18/05/2023
 
Select 'PRE Row Count DIH Sales ORG' as 'RowType', Count(1) 'RowCount',Count(Distinct ZLKUNNR ) 'DistinctACN',Count(Distinct CUST_NBR ) 'DistinctBP'  From SAPX07_R_YMDM_ACN_P07_NEW
-- added Sandeep 18/05/2023
Update a
SET a.CUST_NBR = b.BP_NBR
--Select Top 10 a.*,b.* 
from SAPX07_R_YMDM_ACN_P07_NEW a
Left join [dbo].[INFA_Q11_SAP_INFA_REF_TBL] b
on a.ZLKUNNR =b.SAP_P07_MTR_NBR 

Select 'Post Row Count DIH Sales ORG' as 'RowType', Count(1) 'RowCount',Count(Distinct ZLKUNNR ) 'DistinctACN',Count(Distinct CUST_NBR ) 'DistinctBP'  From SAPX07_R_YMDM_ACN_P07_NEW
*/

Alter table  SAPX07_R_YMDM_ACN_P07_NEW add CUST_NBR nvarchar(100)

Select 'PRE Row Count DIH Sales ORG' as 'RowType', Count(1) 'RowCount',Count(Distinct ZLKUNNR ) 'DistinctACN',Count(Distinct CUST_NBR ) 'DistinctBP'  From SAPX07_R_YMDM_ACN_P07_NEW
-- added Sandeep 06/06/2023
Update a
SET a.CUST_NBR = b.CUST_NBR
--Select Top 10 a.*,b.* 
from SAPX07_R_YMDM_ACN_P07_NEW a
Left join [dbo].INFA_C_BO_LEGACY_ACN_XREF_NEW_Base b
on a.ZLKUNNR =b.ZLKUNNR 

Select 'Post Row Count DIH Sales ORG' as 'RowType', Count(1) 'RowCount',Count(Distinct ZLKUNNR ) 'DistinctACN',Count(Distinct CUST_NBR ) 'DistinctBP'  From SAPX07_R_YMDM_ACN_P07_NEW

--ADD new required column 
Alter table  SAPX07_R_YMDM_ACN_P07_NEW add FormattedCon_Term Varchar(99)
Alter table  INFA_C_BO_LEGACY_ACN_XREF_NEW add FormattedCon_Term Varchar(99)
Alter table  SAPX07_R_YMDM_ACN_P07_NEW add FormattedCust_Type Varchar(99)
Alter table  INFA_C_BO_LEGACY_ACN_XREF_NEW add FormattedCust_Type Varchar(99)
Alter table  SAPX07_R_YMDM_ACN_P07_NEW add MKTCombo Varchar(99)
Alter table  INFA_C_BO_LEGACY_ACN_XREF_NEW add MKTCombo Varchar(99)

--Alter column 
Alter table  SAPX07_R_YMDM_ACN_P07_NEW	   Alter Column MKT_PGM_IND_REQ Varchar(10)
Alter table  INFA_C_BO_LEGACY_ACN_XREF_NEW Alter Column MKT_PGM_IND_REQ Varchar(10)
Alter Table  SAPX07_R_YMDM_ACN_P07_NEW     Alter Column FTN_MKT_PLAN Varchar(100)
Alter Table  SAPX07_R_YMDM_ACN_P07_NEW     Alter Column OTL_BVDT_PG_CD Varchar(100)
Alter Table  SAPX07_R_YMDM_ACN_P07_NEW     Alter Column FTN_CO_EQUIP Varchar(100)
Alter Table  INFA_C_BO_LEGACY_ACN_XREF_NEW     Alter Column FTN_MKT_PLAN Varchar(100)
Alter Table  INFA_C_BO_LEGACY_ACN_XREF_NEW     Alter Column OTL_BVDT_PG_CD Varchar(100)
Alter Table  INFA_C_BO_LEGACY_ACN_XREF_NEW     Alter Column FTN_CO_EQUIP Varchar(100)

-- Update columne 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_CONCESS_NO	='NULL' Where FTN_CONCESS_NO	='' OR FTN_CONCESS_NO	IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_CHAIN			='NULL' Where FTN_CHAIN			='' OR FTN_CHAIN		IS NULL 	
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_HDQTRS		='NULL' Where FTN_HDQTRS		='' OR FTN_HDQTRS		IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_FTN_MKT_ID	='NULL' Where FTN_FTN_MKT_ID	='' OR FTN_FTN_MKT_ID	IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_EXP_DEPT		='NULL' Where FTN_EXP_DEPT		='' OR FTN_EXP_DEPT		IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET OTL_DSTR_ACN		='NULL' Where OTL_DSTR_ACN		='' OR OTL_DSTR_ACN		IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_MKT_PLAN		='NULL' Where FTN_MKT_PLAN		='' OR FTN_MKT_PLAN		IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET OTL_BVDT_PG_CD	='NULL' Where OTL_BVDT_PG_CD	='' OR OTL_BVDT_PG_CD IS NULL
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_PLAN_ENT		='NULL' Where FTN_PLAN_ENT		='' OR FTN_PLAN_ENT		IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_CO_EQUIP		='NULL' Where FTN_CO_EQUIP		='' OR FTN_CO_EQUIP		IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET MKT_PGM_CD		='NULL' Where MKT_PGM_CD		='' OR MKT_PGM_CD		IS NULL 
Update	SAPX07_R_YMDM_ACN_P07_NEW SET MKT_PGM_IND_REQ	='NULL' Where MKT_PGM_IND_REQ	='' OR MKT_PGM_IND_REQ	IS NULL 
--Update	SAPX07_R_YMDM_ACN_P07_NEW SET CON_TERM			='NULL' Where CON_TERM			='' OR CON_TERM			IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_CONCESS_NO	='NULL' Where FTN_CONCESS_NO	='' OR FTN_CONCESS_NO	IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_CHAIN			='NULL' Where FTN_CHAIN			='' OR FTN_CHAIN		IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_HDQTRS		='NULL' Where FTN_HDQTRS		='' OR FTN_HDQTRS		IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_FTN_MKT_ID	='NULL' Where FTN_FTN_MKT_ID	='' OR FTN_FTN_MKT_ID	IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_EXP_DEPT		='NULL' Where FTN_EXP_DEPT		='' OR FTN_EXP_DEPT		IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET OTL_DSTR_ACN		='NULL' Where OTL_DSTR_ACN		='' OR OTL_DSTR_ACN		IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_MKT_PLAN		='NULL' Where FTN_MKT_PLAN		='' OR FTN_MKT_PLAN		IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET OTL_BVDT_PG_CD	='NULL' Where OTL_BVDT_PG_CD	='' OR OTL_BVDT_PG_CD	IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_PLAN_ENT		='NULL' Where FTN_PLAN_ENT		='' OR FTN_PLAN_ENT		IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_CO_EQUIP		='NULL' Where FTN_CO_EQUIP		='' OR FTN_CO_EQUIP		IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET MKT_PGM_CD		='NULL' Where MKT_PGM_CD		='' OR MKT_PGM_CD		IS NULL 
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET MKT_PGM_IND_REQ	='NULL' Where MKT_PGM_IND_REQ	='' OR MKT_PGM_IND_REQ	IS NULL
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FTN_EXP_DEPT=CAST(CAST(FTN_EXP_DEPT as INTEGER) as VARCHAR(50))
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FTN_EXP_DEPT=CAST(CAST(FTN_EXP_DEPT as INTEGER) as VARCHAR(50))

/*

Select top 10 * from SAPX07_R_YMDM_ACN_P07_NEW where ZLKUNNR='0000115597'
Select top 10 * from INFA_C_BO_LEGACY_ACN_XREF_NEW where ZLKUNNR='0000115597'

*/

Update	INFA_C_BO_LEGACY_ACN_XREF_NEW	SET MKTCombo		=ISNULL(ISNULL(MKT_PGM_CD,'NULL')+'-'+ISNULL(MKT_PGM_IND_REQ,'NULL')      	 ,'NULL-NULL)')
Update	SAPX07_R_YMDM_ACN_P07_NEW		SET MKTCombo		=ISNULL(ISNULL(MKT_PGM_CD,'NULL')+'-'+ISNULL(MKT_PGM_IND_REQ,'NULL')       	 ,'NULL-NULL)')
Update SAPX07_R_YMDM_ACN_P07_NEW Set FormattedCon_Term = ISNULL(Cast(CONVERT(VARCHAR, CON_TERM, 110) as Varchar(99)),'NULL')
Update INFA_C_BO_LEGACY_ACN_XREF_NEW Set FormattedCon_Term = ISNULL(Cast(CONVERT(VARCHAR, CON_TERM, 110) as Varchar(99)),'NULL')
Update	SAPX07_R_YMDM_ACN_P07_NEW SET FormattedCust_Type	=ISNULL(con_type_rec,'NULL')
Update	INFA_C_BO_LEGACY_ACN_XREF_NEW SET FormattedCust_Type	=ISNULL(SS_CUST_TYPE,'NULL')

Exec FactL2PerConfig 15
Exec FactL2PerConfig 16
Exec FactL2PerConfig 17
Exec FactL2PerConfig 18
Exec FactL2PerConfig 19
Exec FactL2PerConfig 20
Exec FactL2PerConfig 23
Exec FactL2PerConfig 24
Exec FactL2PerConfig 121
Exec FactL2PerConfig 69
Exec FactL2PerConfig 21
Exec FactL2PerConfig 22
Exec FactL2PerConfig 122
Exec FactL2PerConfig 123
Exec FactL2PerConfig 124

--Select Count(1) from [FactL2Monitor] Where ConfigID in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124)
--Select top 10 * from [FactL2Monitor] Where ConfigID in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124)
--Select top 10  * From SAPX07_R_YMDM_ACN_P07_NEW
--Select top 10  * From INFA_C_BO_LEGACY_ACN_XREF_NEW
--Select top 10 * from [ZDCV_BRIM_RELEVANCY] 

Update l2
SET l2.KUNNR_P07			=rl.KUNNR_P07
,	l2.PARTNER_S4			=rl.PARTNER_S4
,	l2.CLASSIFICATION		=rl.CLASSIFICATION
,	l2.CONCLUSION_NEEDS_CC	=rl.CONCLUSION_NEEDS_CC
,l2.Filter9 = 'BP Exist in ZDCV_BRIM_RELEVANCY DIH'
--Select Count(*) 
from [FactL2Monitor] l2 
Inner Join dbo.C_BO_BP_Cross_ref As Ref    on l2.BusinessPartner= Ref.ZLKUNNR
Inner join [dbo].[ZDCV_BRIM_RELEVANCY] rl  on REf.KUNNR_P07 = rl.KUNNR_P07 
--Select distinct  CONCLUSION_NEEDS_CC,count(1) from [FactL2Monitor] as l2
Where l2.ConfigID in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124) 

--group by CONCLUSION_NEEDS_CC

---Get Filter1,Filter2 -Conterm  and Filter3,4 Type 

Update [FactL2Monitor]  
SET IsFilter = 'N'
Where ConfigID in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124)

Update l2
SET l2.Filter1 = n.FormattedCon_Term,l2.Filter3 = n.FormattedCust_Type
from [FactL2Monitor] l2 
Inner join SAPX07_R_YMDM_ACN_P07_NEW N on l2.BusinessPartner = n.ZLKUNNR
Where ConfigID in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124)

Update l2
SET l2.Filter2 = n.FormattedCon_Term,l2.Filter4 = n.FormattedCust_Type,l2.Filter5= n.ROWID_SYSTEM 
from [FactL2Monitor] l2 
Inner join INFA_C_BO_LEGACY_ACN_XREF_NEW N on l2.BusinessPartner = n.ZLKUNNR
Where ConfigID in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124)


Update  [FactL2Monitor]
SET IsFilter = 'Y', FilterDetails ='ACN Con_Term >=01/01/2020' --Filter Y show this
Where 1=1 
 and  ConfigID in (15,16,17,18,19,20,23,121,21,22,122,123,124)
 and Filter1 <> 'NULL'
 and Cast(Case When Filter1 ='NULL' then '01/01/1901' Else Filter1 END as Date)>=Cast('01/01/2020' as date)
 and Filter2 <> 'NULL'
 and Cast(Case When Filter2 ='NULL' then '01/01/1901' Else Filter2 END as Date)>=Cast('01/01/2020' as date)
 and Filter5 = 'INFA'

Update  [FactL2Monitor]
SET IsFilter = 'N'
Where 1=1 
 and  ConfigID in (24,69)

Update  [FactL2Monitor]
SET IsFilter = 'Y', FilterDetails ='ACN Cust Type =55' --Filter Y show this
Where 1=1 
 and  ConfigID in (24,69)
 and Filter3 <> 'NULL'
 and Filter3 ='55'
 and Filter4 <> 'NULL'
 and Filter4 ='55'
 and Filter5 = 'INFA'

 
Update l2
SET l2.PARTNER_S4			=Ref.PARTNER_S4
from [FactL2Monitor] l2 --where ConfigID in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124)
Inner Join dbo.C_BO_BP_Cross_ref As Ref    on l2.BusinessPartner= Ref.ZLKUNNR
Where l2.PARTNER_S4 is null and  ConfigID in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124)

 DELETE
--Select COunt(*)
from [FactL2Monitor] 
Where ConfigValue='NULL' and IsINFA='1' and IsP40='1' and IsDIH='1' and IsP07='1'

DELETE
--Select COunt(*)
from [FactL2Monitor] 
Where ConfigID IN (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124) and ConfigValue Like 'NULL-%'

DELETE
--Select COunt(*)
from [FactL2Monitor] 
Where ConfigID IN (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124) and ConfigValue='NULL' and IsINFA='0' and IsP07='1'

DELETE
--Select COunt(*)
from [FactL2Monitor] 
Where ConfigID IN (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124) and ConfigValue='NULL' and IsINFA='1'

TRUNCATE TABLE dbo.FactL2Monitor_ACN

SET IDENTITY_INSERT dbo.FactL2Monitor_ACN ON;

INSERT INTO dbo.FactL2Monitor_ACN
([FactL2ID], [LoadRunDateTime], [BusinessPartner], [ConfigID], [ConfigValue], [IsINFA], [IsP40], [IsDIH], [IsP07], [MatchStatus], [CompareCode], [CodeDescription], [BPEtEMatch], [FactL1ID], [CriteriaValue], [BRStatus], [BRIMRelevancy], [BPStatus], [IsFilter], [FilterDetails], [CLASSIFICATION], [CONCLUSION_NEEDS_CC], [Filter1], [Filter2], [Filter3], [Filter4], [Filter5], [KUNNR_P07], [PARTNER_S4], [Filter6], [Filter7], [Filter8], [Filter9], [Rank])
Select   *, rank() OVER(Order BY FactL2ID) as [Rank] From [dbo].[FactL2Monitor] L2
Where L2.configid  in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124);

DELETE from dbo.FactL2Monitor_ACN
Where IsINFA = 1 and IsP07 = 1	and (ConfigValue is NULL or ConfigValue='NULL')

DELETE from dbo.[FactL2Monitor]
Where IsINFA = 1 and IsP07 = 1	and (ConfigValue is NULL or ConfigValue='NULL')
and configid  in (15,16,17,18,19,20,23,24,121,69,21,22,122,123,124);

SET IDENTITY_INSERT dbo.FactL2Monitor_ACN OFF;
