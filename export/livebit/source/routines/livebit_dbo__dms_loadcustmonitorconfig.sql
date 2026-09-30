
CREATE   PROC [dbo].[DMS_LoadCustMonitorConfig] AS
begin
Truncate Table [dbo].[DMS_CustMonitorConfig];

SET IDENTITY_INSERT [dbo].[DMS_CustMonitorConfig] ON;

--ConfigID =1, BP2 in ALL for L1 for BP1 & BP2 for Excel ID =1
Print 1 INSERT [dbo].[DMS_CustMonitorConfig] ([ConfigID], [GeneralColumnName], [SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart], [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart], [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart], [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired],[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) VALUES (--[ConfigID], [GeneralColumnName]	1		, N'Medicine ID should Match in SharePoint, FTP, SAP, SQL'--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]	, 'SAP_Medicine'		, N'MedicineID'				, N'DMS_SAP_Medicine'	, N'MedicineID'			, NULL				, 1--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]	, 'SQL_Medicine'	, 'MedicineID'				, N'DMS_SQL_Medicine'	, N'MedicineID'				, NULL				, 1--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]	, 'SharePoint_Medicine'		, 'MedicineID'				, 'DMS_SharePoint_Medicine'			, 'MedicineID'				, NULL				, 1--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]	, 'FTP_Medicine'	, N'MedicineID'				, N'DMS_FTP_Medicine'	, N'MedicineID'					, 1--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]	, 1						, NULL			, 1					, NULL			, 0--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired	, N'Present in All Sources'	, NULL			, 1			, N'[MedicineConfig]'	,N'TRUE',0--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		  ,1			,'MedicineID'				,'MedicineID'				,'MedicineID'	 ,'MedicineID'--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 	,2,19,'MedicineConfig','MedicineID','Medicine ID Should Match in SharePoint, FTP, SAP, SQL','ShP+FTP+SAP+SQL',2)
Print 2 INSERT [dbo].[DMS_CustMonitorConfig] ([ConfigID], [GeneralColumnName], [SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart], [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart], [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart], [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired],[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) VALUES (--[ConfigID], [GeneralColumnName]	2		, N'Medicine Name should Match in SharePoint, FTP, SAP, SQL'--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]	, 'SAP_Medicine'		, N'MedicineName'				, N'DMS_SAP_Medicine'	, N'MedicineName'			, NULL				, 1--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]	, 'SQL_Medicine'	, 'MedicineName'				, N'DMS_SQL_Medicine'	, N'MedicineName'				, NULL				, 1--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]	, 'SharePoint_Medicine'		, 'MedicineName'				, 'DMS_SharePoint_Medicine'			, 'MedicineName'				, NULL				, 1--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]	, 'FTP_Medicine'	, N'MedicineName'				, N'DMS_FTP_Medicine'	, N'MedicineName'					, 1--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]	, 1						, NULL			, 1					, NULL			, 0--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired	, N'Present in All Sources'	, NULL			, 1			, N'[MedicineConfig]'	,N'TRUE',0--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		  ,1			,'MedicineID'				,'MedicineID'				,'MedicineID'	 ,'MedicineID'--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 	,2,19,'MedicineConfig','MedicineName','Medicine Name Should Match in SharePoint, FTP, SAP, SQL','ShP+FTP+SAP+SQL',2)
Print 3INSERT [dbo].[DMS_CustMonitorConfig] ([ConfigID], [GeneralColumnName], [SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart], [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart], [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart], [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired],[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) VALUES (--[ConfigID], [GeneralColumnName]	3		, N'Medicine Category should Match in SharePoint, FTP, SAP, SQL'--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]	, 'SAP_Medicine'		, N'MedicineCategory'				, N'DMS_SAP_Medicine'	, N'MedicineCategory'			, NULL				, 1--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]	, 'SQL_Medicine'	, 'MedicineCategory'				, N'DMS_SQL_Medicine'	, N'MedicineCategory'				, NULL				, 1--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]	, 'SharePoint_Medicine'		, 'MedicineCategory'				, 'DMS_SharePoint_Medicine'			, 'MedicineCategory'				, NULL				, 1--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]	, 'FTP_Medicine'	, N'MedicineCategory'				, N'DMS_FTP_Medicine'	, N'MedicineCategory'					, 1--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]	, 1						, NULL			, 1					, NULL			, 0--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired	, N'Present in All Sources'	, NULL			, 1			, N'[MedicineConfig]'	,N'TRUE',0--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		  ,1			,'MedicineID'				,'MedicineID'				,'MedicineID'	 ,'MedicineID'--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 	,2,19,'MedicineConfig','MedicineCategory','Medicine Category Should Match in SharePoint, FTP, SAP, SQL','ShP+FTP+SAP+SQL',2)

Print 4
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], 
[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (

--[ConfigID], [GeneralColumnName]
	4		, N'Patient Id should Match in FTP, SAP, SharePoint,SQL'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_Patient'		, N'PatientID'				, N'DMS_SAP_Patient'	, N'PatientID'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
	, 'SQL_Patient'	, 'PatientID'				, N'DMS_SQL_Patient'	, N'PatientID'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
	, 'SharePoint_Patient'		, 'PatientID'				, 'DMS_SharePoint_Patient'			, 'PatientID'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
	, 'FTP_Patient'	, N'PatientID'				, N'DMS_FTP_Patient'	, N'PatientID'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in All Sources'	, NULL			, 1			, N'[PatientConfig]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PatientID'				,'PatientID'				,'PatientID'	 ,'PatientID'
--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,20,'PatientConfig','PatientID','Patient ID Should Match in FTP, SAP, SharePoint,SQL','ShP+FTP+SAP+SQL',2)

Print 5
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], 
[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
--, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (

--[ConfigID], [GeneralColumnName]
	5		, N'Patient Name should Match in FTP, SAP, SQL'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_Patient'		, N'FirstName+LastName'				, N'DMS_SAP_Patient'	, N'PatientName'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
	, 'SQL_Patient'	, 'FirstName+LastName'				, N'DMS_SQL_Patient'	, N'PatientName'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
--	, 'SharePoint_Patient'		, 'FirstName+LastName'				, 'DMS_SharePoint_Patient'			, 'PatientName'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
	, 'FTP_Patient'	, N'FirstName+LastName'				, N'DMS_FTP_Patient'	, N'PatientName'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in FTP, SAP, SQL Sources'	, NULL			, 1			, N'[PatientConfig]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PatientID'				,'PatientID'				,'PatientID'	 ,'PatientID'
--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,20,'PatientConfig','PatientName','Patient Name Should Match in FTP, SAP, SQL','FTP+SAP+SQL',2)

Print 6
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], 
[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
--, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (

--[ConfigID], [GeneralColumnName]
	6		, N'Insurance Provider should Match in FTP, SAP, SQL'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_Patient'		, N'InsuranceProvider'				, N'DMS_SAP_Patient'	, N'InsuranceProvider'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
	, 'SQL_Patient'	, 'InsuranceProvider'				, N'DMS_SQL_Patient'	, N'InsuranceProvider'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
--	, 'SharePoint_Patient'		, 'InsuranceProvider'				, 'DMS_SharePoint_Patient'			, 'InsuranceProvider'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
	, 'FTP_Patient'	, N'InsuranceProvider'				, N'DMS_FTP_Patient'	, N'InsuranceProvider'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in FTP, SAP, SQL Sources'	, NULL			, 1			, N'[PatientConfig]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PatientID'				,'PatientID'				,'PatientID'	 ,'PatientID'
--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,20,'PatientConfig','InsuranceProvider','Insurance Provider Should Match in FTP, SAP, SQL','FTP+SAP+SQL',2)

Print 7
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], 
[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
--, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
--, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (

--[ConfigID], [GeneralColumnName]
	7		, N'Allergies should Match in SAP, SQL'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_Patient'		, N'Allergies'				, N'DMS_SAP_Patient'	, N'Allergies'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
	, 'SQL_Patient'	, 'Allergies'				, N'DMS_SQL_Patient'	, N'Allergies'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
--	, 'SharePoint_Patient'		, 'Allergies'				, 'DMS_SharePoint_Patient'			, 'Allergies'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
--	, 'FTP_Patient'	, N'Allergies'				, N'DMS_FTP_Patient'	, N'Allergies'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in SAP and SQL Sources'	, NULL			, 1			, N'[PatientConfig]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PatientID'				,'PatientID'				,'PatientID'	 ,'PatientID'
--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,20,'PatientConfig','Allergies','Allergies Should Match in SAP, SQL','SAP+SQL',2)

Print 8
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart]
--,[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
--, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (

--[ConfigID], [GeneralColumnName]
	8		, N'Medical History should Match in ShP, SAP'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_Patient'		, N'MedicalHistory'				, N'DMS_SAP_Patient'	, N'MedicalHistory'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
--	, 'SQL_Patient'	, 'MedicalHistory'				, N'DMS_SQL_Patient'	, N'MedicalHistory'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
	, 'SharePoint_Patient'		, 'MedicalHistory'				, 'DMS_SharePoint_Patient'			, 'MedicalHistory'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
--	, 'FTP_Patient'	, N'MedicalHistory'				, N'DMS_FTP_Patient'	, N'MedicalHistory'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in  ShP and SAP Sources'	, NULL			, 1			, N'[PatientConfig]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PatientID'				,'PatientID'				,'PatientID'	 ,'PatientID'
	--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,20,'PatientConfig','MedicalHistory','Medical History Should Match in ShP, SAP','ShP+SAP',2)

Print 9
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart]
,[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
--, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (

--[ConfigID], [GeneralColumnName]
	9		, N'Insurance Number should Match in FTP, SAP, SQL'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_Patient'		, N'InsuranceNumber'				, N'DMS_SAP_Patient'	, N'InsuranceNumber'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
	, 'SQL_Patient'	, 'InsuranceNumber'				, N'DMS_SQL_Patient'	, N'InsuranceNumber'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
--	, 'SharePoint_Patient'		, 'InsuranceNumber'				, 'DMS_SharePoint_Patient'			, 'InsuranceNumber'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
	, 'FTP_Patient'	, N'InsuranceNumber'				, N'DMS_FTP_Patient'	, N'InsuranceNumber'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in FTP, SAP, SQL Sources'	, NULL			, 1			, N'[PatientConfig]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PatientID'				,'PatientID'				,'PatientID'	 ,'PatientID'
--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,20,'PatientConfig','InsuranceNumber','Insurance Number Should Match in FTP, SAP, SQL','FTP+SAP+SQL',2)


Print 10
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart]
,[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
--, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
--, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (
--[ConfigID], [GeneralColumnName]
	10		, N'Purchase Type should Match in SAP, SQL'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_MedicinePurchaseType'		, N'PurchaseType'				, N'DMS_SAP_MedicinePurchaseType'	, N'PurchaseType'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
	, 'SQL_MedicinePurchaseType'	, 'PurchaseType'				, N'DMS_SQL_MedicinePurchaseType'	, N'PurchaseType'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
--	, 'SharePoint_MedicinePurchaseType'		, 'PurchaseType'				, 'DMS_SharePoint_MedicinePurchaseType'			, 'PurchaseType'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
--	, 'FTP_MedicinePurchaseType'	, N'PurchaseType'				, N'DMS_FTP_MedicinePurchaseType'	, N'PurchaseType'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in SAP, SQL Sources'	, NULL			, 1			, N'[MedicinePurchaseType]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PurchaseID'				,'PurchaseID'				,NULL	 ,'PurchaseID'
--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,21,'MedicinePurchaseType','PurchaseType','Purchase Type Should Match in SAP, SQL','SAP+SQL',2)

Print 11
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart]
,[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
--, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
--, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (
--[ConfigID], [GeneralColumnName]
	11		, N'Payment Method should Match in SAP, SQL'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_MedicinePurchaseType'		, N'PaymentMethod'				, N'DMS_SAP_MedicinePurchaseType'	, N'PaymentMethod'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
	, 'SQL_MedicinePurchaseType'	, 'PaymentMethod'				, N'DMS_SQL_MedicinePurchaseType'	, N'PaymentMethod'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
--	, 'SharePoint_MedicinePurchaseType'		, 'PaymentMethod'				, 'DMS_SharePoint_MedicinePurchaseType'			, 'PaymentMethod'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
--	, 'FTP_MedicinePurchaseType'	, N'PaymentMethod'				, N'DMS_FTP_MedicinePurchaseType'	, N'PaymentMethod'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in SAP, SQL Sources'	, NULL			, 1			, N'[MedicinePurchaseType]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PurchaseID'				,'PurchaseID'				,NULL	 ,'PurchaseID'
--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,21,'MedicinePurchaseType','PaymentMethod','Payment Method Should Match in SAP, SQL','SAP+SQL',2)

Print 12
INSERT [dbo].[DMS_CustMonitorConfig] 
([ConfigID], [GeneralColumnName], 
[SAPSourceTableName] , [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart]
--,[SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName],[SharePointPostUpdate], [SharePointIsPart]
--, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK]
, [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName],Isl1Only,[IsSharePointRequired]
,[Isl2Only],[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]	
,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
VALUES (
--[ConfigID], [GeneralColumnName]
	12		, N'Insurance Covered should Match in Shp, SAP'
--	, [SAPSourceTableName]	, [SAPSourceColumnName]		, [SAPStageTableName]	, [SAPStagColumnName]	, [SAPPostUpdate]	, [SAPIsPart]
	, 'SAP_MedicinePurchaseType'		, N'InsuranceCovered'				, N'DMS_SAP_MedicinePurchaseType'	, N'InsuranceCovered'			, NULL				, 1
--	, [SQLSourceTableName]	, [SQLSourceColumnName]		, [SQLStageTableName]  , [SQLStagColumnName]	, [SQLPostUpdate]   , [SQLIsPart]
--	, 'SQL_MedicinePurchaseType'	, 'InsuranceCovered'				, N'DMS_SQL_MedicinePurchaseType'	, N'InsuranceCovered'				, NULL				, 1
--	, [SharePointSourceTableName]	, [SharePointSourceColumnName]	, [SharePointStageTableName]		, [SharePointStagColumnName]	, [SharePointPostUpdate]	, [SharePointIsPart]
	, 'SharePoint_MedicinePurchaseType'		, 'InsuranceCovered'	, 'DMS_SharePoint_MedicinePurchaseType'	, 'InsuranceCovered'				, NULL				, 1
--	, [FTPSourceTableName]		, [FTPSourceColumnName]	, [FTPStageTableName]		, [FTPStagColumnName]	, [FTPIsPart]
--	, 'FTP_MedicinePurchaseType'	, N'InsuranceCovered'				, N'DMS_FTP_MedicinePurchaseType'	, N'InsuranceCovered'					, 1
--	, [ExecutionSequence]	, [IsDateType]	, [IsNumericType]	, [IsFloatType]	, [IsPK]
	, 1						, NULL			, 1					, NULL			, 0
--	, [OverAllStatus]			, [StatusDesc]	, [IsReady]	, [HashColumnName]		,Isl1Only,IsSharePointRequired
	, N'Present in ShP, SAP Sources'	, NULL			, 1			, N'[MedicinePurchaseType]'	,N'TRUE',0
--, [Isl2Only]	,[SAPStageTableNamePK]	,[SQLStageTableNamePK]	,[FTPStageTableNamePK]	,[SharePointStageTableNamePK]		
  ,1			,'PurchaseID'				,'PurchaseID'				,NULL	 ,'PurchaseID'
--,GroupID,SubGroupID,SyncDataType,Fields,DQRule,ConfigCategory,BusinssPriority) 
	,2,21,'MedicinePurchaseType','PaymentMethod','Payment Method Should Match in ShP, SAP','ShP+SAP',2)



SET IDENTITY_INSERT [dbo].[CustMonitorConfig] OFF;

Print 'End of insert'

End






