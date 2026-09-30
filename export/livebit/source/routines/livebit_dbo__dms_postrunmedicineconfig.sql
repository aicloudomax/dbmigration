



CREATE PROC [dbo].[DMS_PostRunMedicineConfig] AS

Begin 


IF OBJECT_ID('dbo.DMS_SAP_Medicine_Base', 'U')				IS NOT NULL BEGIN	DROP TABLE dbo.DMS_SAP_Medicine_Base		END 
IF OBJECT_ID('dbo.DMS_SQL_Medicine_Base', 'U')				IS NOT NULL BEGIN	DROP TABLE dbo.DMS_SQL_Medicine_Base	END
IF OBJECT_ID('dbo.DMS_SharePoint_Medicine_Base', 'U')		IS NOT NULL BEGIN	DROP TABLE dbo.DMS_SharePoint_Medicine_Base	END
IF OBJECT_ID('dbo.DMS_FTP_Medicine_Base', 'U')				IS NOT NULL BEGIN	DROP TABLE dbo.DMS_FTP_Medicine_Base	END


Select * INTO	 DMS_SAP_Medicine_Base				From DMS_SAP_Medicine
Select * INTO	 DMS_SQL_Medicine_Base				From DMS_SQL_Medicine
Select * INTO	 DMS_SharePoint_Medicine_Base		From DMS_SharePoint_Medicine
Select * INTO	 DMS_FTP_Medicine_Base				From DMS_FTP_Medicine


Select 'PRE Row Base Count INFA Sales Area' as 'RowType', Count(1) 'RowCount',Count(Distinct MedicineID ) 'DistinctBP'  From DMS_SAP_Medicine_Base UNION
Select 'PRE Row Base Count P04 Sales Area' as 'RowType', Count(1) 'RowCount',Count(Distinct MedicineID ) 'DistinctBP'	  From DMS_SQL_Medicine_Base UNION
Select 'PRE Row Base Count P04 Sales Area' as 'RowType', Count(1) 'RowCount',Count(Distinct MedicineID ) 'DistinctBP'	  From DMS_SharePoint_Medicine_Base UNION
Select 'PRE Row Base Count P04 Sales Area' as 'RowType', Count(1) 'RowCount',Count(Distinct MedicineID ) 'DistinctBP'	  From DMS_FTP_Medicine_Base



--Updating NULL Values of SAP

Update DMS_SAP_Medicine	SET MedicineID = 'NULL'			Where MedicineID = ''				OR MedicineID			IS NULL
Update DMS_SAP_Medicine	SET MedicineName = 'NULL'		Where MedicineName = ''				OR MedicineName			IS NULL
Update DMS_SAP_Medicine	SET MedicineCategory = 'NULL'	Where MedicineCategory = ''			OR MedicineCategory		IS NULL


--Updating NULL Values of SQL

Update DMS_SQL_Medicine	SET MedicineID = 'NULL'			Where MedicineID = ''				OR MedicineID			IS NULL
Update DMS_SQL_Medicine	SET MedicineName = 'NULL'		Where MedicineName = ''				OR MedicineName			IS NULL
Update DMS_SQL_Medicine	SET MedicineCategory = 'NULL'	Where MedicineCategory = ''			OR MedicineCategory		IS NULL


--Updating NULL Values of SharePoint

Update DMS_SharePoint_Medicine	SET MedicineID = 'NULL'			Where MedicineID = ''				OR MedicineID			IS NULL
Update DMS_SharePoint_Medicine	SET MedicineName = 'NULL'		Where MedicineName = ''				OR MedicineName			IS NULL
Update DMS_SharePoint_Medicine	SET MedicineCategory = 'NULL'	Where MedicineCategory = ''			OR MedicineCategory		IS NULL


--Updating NULL Values of FTP

Update DMS_FTP_Medicine	SET MedicineID = 'NULL'			Where MedicineID = ''				OR MedicineID			IS NULL
Update DMS_FTP_Medicine	SET MedicineName = 'NULL'		Where MedicineName = ''				OR MedicineName			IS NULL
Update DMS_FTP_Medicine	SET MedicineCategory = 'NULL'	Where MedicineCategory = ''			OR MedicineCategory		IS NULL





Exec DMS_FactL2PerConfig 1
Exec DMS_FactL2PerConfig 2
Exec DMS_FactL2PerConfig 3




--Update l2
--SET l2.KUNNR_P07			=rl.KUNNR_P07
--,	l2.PARTNER_S4			=rl.PARTNER_S4
--,	l2.CLASSIFICATION		=rl.CLASSIFICATION
--,	l2.CONCLUSION_NEEDS_CC	=rl.CONCLUSION_NEEDS_CC
--,l2.Filter9 = 'BP Exist in ZDCV_BRIM_RELEVANCY DIH'
----Select Count(*) 
--from [DMS_FactL2Monitor] l2
--Inner join [dbo].[ZDCV_BRIM_RELEVANCY] rl  on l2.BusinessPartner= rl.PARTNER_S4
--Where l2.ConfigID IN (1,2,3)

Update [DMS_FactL2Monitor]
SET CONCLUSION_NEEDS_CC = 'Y'
--[DMS_FactL2Monitor]
Where FactL2ID NOT IN (Select Top 50 FactL2ID from [DMS_FactL2Monitor]) and ConfigID IN (1,2,3)

Update [DMS_FactL2Monitor]
SET CONCLUSION_NEEDS_CC = 'Y'
--[DMS_FactL2Monitor]
Where FactL2ID IN (Select Top 20 FactL2ID from [DMS_FactL2Monitor] where configid not in (2,3)) and ConfigID IN (1,2,3)

Update [DMS_FactL2Monitor]
SET CONCLUSION_NEEDS_CC = 'N'
Where CONCLUSION_NEEDS_CC is null


Update [DMS_FactL2Monitor]  
SET IsFilter = 'N'
Where ConfigID IN (1,2,3)
/*
Update l2
SET l2.Filter1 =  POSITION_END_DATE
from [DMS_FactL2Monitor] l2 
Inner join DMS_SAP_Medicine N on l2.BusinessPartner = n.MedicineID
Where ConfigID = 30

Update l2
SET l2.Filter2 = ZZ_POSITION_END_DATE 
from [DMS_FactL2Monitor] l2 
Inner join DMS_SQL_Medicine N on l2.BusinessPartner = n.MedicineID
Where ConfigID = 30

Update l2
SET l2.Filter3 = POSITION_START_DATE
from [DMS_FactL2Monitor] l2 
Inner join DMS_SharePoint_Medicine N on l2.BusinessPartner = n.MedicineID
Where ConfigID = 31
*/

/*
Update l2
SET l2.Filter6 = 
from [DMS_FactL2Monitor] l2 
Inner join SAPX40_R_KNA1_SALES_PSTN N on l2.BusinessPartner = n.KUNNR
Where ConfigID = 34
*/

--Update  [DMS_FactL2Monitor]
--SET IsFilter = 'Y', FilterDetails ='SS_CUST_TYPE=55' 
--Where 1=1 
-- and  ConfigID IN (25,39)
-- and Filter5 <> 'NULL'
-- and Filter5 = 55
 

--  DELETE
----Select COunt(*)
--from [DMS_FactL2Monitor] 
--Where ConfigValue='NULL' and IsINFA='1' and IsP40='1' and IsDIH='1' and IsP07='1'

 
TRUNCATE TABLE dbo.DMS_FactL2Monitor_MedicineConfig

SET IDENTITY_INSERT dbo.DMS_FactL2Monitor_MedicineConfig ON;

INSERT INTO dbo.DMS_FactL2Monitor_MedicineConfig
([FactL2ID], [LoadRunDateTime], [BusinessPartner], [ConfigID], [ConfigValue], [IsSAP], [IsSQL], [IsFTP], [IsSharePoint], [MatchStatus], [CompareCode], [CodeDescription], [BPEtEMatch], [FactL1ID], [CriteriaValue], [BRStatus], [BRIMRelevancy], [BPStatus], [IsFilter], [FilterDetails], [CLASSIFICATION], [CONCLUSION_NEEDS_CC], [Filter1], [Filter2], [Filter3], [Filter4], [Filter5], [KUNNR_P07], [PARTNER_S4], [Filter6], [Filter7], [Filter8], [Filter9], [Rank])
Select   *, rank() OVER(Order BY FactL2ID) as [Rank] from [dbo].[DMS_FactL2Monitor] L2
Where L2.configid  IN (1,2,3)

SET IDENTITY_INSERT dbo.DMS_FactL2Monitor_MedicineConfig OFF;


END;

