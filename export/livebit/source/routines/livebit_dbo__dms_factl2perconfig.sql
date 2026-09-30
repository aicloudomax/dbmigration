




CREATE PROC [dbo].[DMS_FactL2PerConfig] @InputConfigID [int] AS


DECLARE @WhileConfigCount INT
DECLARE @SQL NVARCHAR(400)
DECLARE @LoadRunDateTime DATETIME = GETDATE()
Declare @ConfigID int 
SET @ConfigID = @InputConfigID 

Declare @ConfigCategory varchar(50)


SET  @ConfigCategory = (Select ConfigCategory  From [dbo].[DMS_CustMonitorConfig] Where ConfigID = @ConfigID)

IF @ConfigCategory is not null
BEGIN 

Select @ConfigID '@ConfigID',@ConfigCategory '@ConfigCategory'


IF Object_ID(N'tempdb..#TempCustMonitorConfigL2')	IS NOT NULL BEGIN	DROP Table #TempCustMonitorConfigL2		END 
IF Object_ID(N'tempdb..#TempConfigValueL2')			IS NOT NULL BEGIN	DROP Table #TempConfigValueL2			END 
IF Object_ID(N'tempdb..#L2Config')					IS NOT NULL BEGIN	DROP Table #L2Config					END 
IF Object_ID(N'tempdb..#DMS_FactL2Monitor')			IS NOT NULL BEGIN	DROP Table #DMS_FactL2Monitor				END 


CREATE TABLE #TempCustMonitorConfigL2 (
	[ConfigID] [int] NOT NULL,
	[GeneralColumnName] [varchar](300) NULL,
	[SAPSourceTableName] [varchar](100) NULL,
	[SAPSourceColumnName] [varchar](100) NULL,
	[SAPStageTableName] [varchar](100) NULL,
	[SAPStagColumnName] [varchar](100) NULL,
	[SAPPostUpdate] [varchar](600) NULL,
	[SAPIsPart] [bit] NULL,
	[SQLSourceTableName] [varchar](100) NULL,
	[SQLSourceColumnName] [varchar](100) NULL,
	[SQLStageTableName] [varchar](100) NULL,
	[SQLStagColumnName] [varchar](100) NULL,
	[SQLPostUpdate] [varchar](600) NULL,
	[SQLIsPart] [bit] NULL,
	[SharePointSourceTableName] [varchar](100) NULL,
	[SharePointSourceColumnName] [varchar](100) NULL,
	[SharePointStageTableName] [varchar](100) NULL,
	[SharePointStagColumnName] [varchar](100) NULL,
	[SharePointPostUpdate] [varchar](100) NULL,
	[SharePointIsPart] [bit] NULL,
	[FTPSourceTableName] [varchar](100) NULL,
	[FTPSourceColumnName] [varchar](100) NULL,
	[FTPStageTableName] [varchar](100) NULL,
	[FTPStagColumnName] [varchar](100) NULL,
	[FTPIsPart] [varchar](100) NULL,
	[ExecutionSequence] [int] NULL,
	[IsDateType] [bit] NULL,
	[IsNumericType] [bit] NULL,
	[IsFloatType] [bit] NULL,
	[IsPK] [bit] NULL,
	[OverAllStatus] [varchar](100) NULL,
	[StatusDesc] [varchar](100) NULL,
	[IsReady] [bit] NULL,
	[HashColumnName] [varchar](100) NULL,
	[Isl1Only] [bit] NULL,
	[Isl2Only] [bit] NULL,
	[SAPStageTableNamePK] [varchar](100) NULL,
	[SQLStageTableNamePK] [varchar](100) NULL,
	[FTPStageTableNamePK] [varchar](100) NULL,
	[SharePointStageTableNamePK] [varchar](100) NULL,
	[CriteriaColumn] [varchar](100) NULL,
	[CriteriaValue] [varchar](100) NULL,
	[IsSharePointRequired] [bit] NULL,
	[GroupID] [int] NULL,
	[SubGroupID] [int] NULL,
	[SyncDataType] [varchar](100) NULL,
	[Fields] [varchar](600) NULL,
	[DQRule] [varchar](800) NULL,
	[SAPSourceQuery] [varchar](2000) NULL,
	[SQLSourceQuery] [varchar](2000) NULL,
	[SharePointSourceQuery] [varchar](2000) NULL,
	[FTPSourceQuery] [varchar](2000) NULL,
	[ConfigCategory] [varchar](400) NULL,
	[BusinssPriority] [smallint] NULL,
	[DMSStatus] [varchar](50) NULL,
	[DMSADOLink] [varchar](200) NULL,
	[DMSStatusComment] [varchar](200) NULL,
	[SP0SourceTableName] [varchar](100) NULL,
	[SP0SourceColumnName] [varchar](100) NULL,
	[SP0StageTableName] [varchar](100) NULL,
	[SP0StagColumnName] [varchar](100) NULL,
	[SP0PostUpdate] [varchar](600) NULL,
	[SP0IsPart] [bit] NULL,
	[SP0StageTableNamePK] [varchar](100) NULL,
	[SP0SourceQuery] [varchar](2000) NULL,
	[DistinctSQLSAPStagColumnName] [varchar](222) NULL,
	[DistinctSQLSQLStagColumnName] [varchar](222) NULL,
	[DistinctSQLSharePointStagColumnName] [varchar](222) NULL,
	[DistinctSQLFTPStagColumnName] [varchar](222) NULL,
	[NULLSQLSAPColumnName] [varchar](445) NULL,
	[NULLSQLSQLColumnName] [varchar](445) NULL,
	[NULLSQLSharePointColumnName] [varchar](222) NULL,
	[NULLSQLFTPColumnName] [varchar](445) NULL,
	[UnionSQLAll] [varchar](680) NULL,
	[UnionSQLAllExecute] [varchar](1220) NULL,
	[LoadSQLFactL1Monitor] [varchar](2002) NULL
) ON [PRIMARY]

CREATE TABLE #TempConfigValueL2 (
BusinessPartner	 [varchar](200) NULL,
ConfigValue	 [varchar](200) NULL
)


IF (@ConfigCategory= 'FTP+SAP+SQL')
BEGIN

Insert into #TempCustMonitorConfigL2
([ConfigID], [GeneralColumnName], [SAPSourceTableName], [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart], [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName], [SharePointPostUpdate], [SharePointIsPart], [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart], [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName], [Isl1Only], [Isl2Only], [SAPStageTableNamePK], [SQLStageTableNamePK], [FTPStageTableNamePK], [SharePointStageTableNamePK], [CriteriaColumn], [CriteriaValue], [IsSharePointRequired], [GroupID], [SubGroupID], [SyncDataType], [Fields], [DQRule], [SAPSourceQuery], [SQLSourceQuery], [SharePointSourceQuery], [FTPSourceQuery], [ConfigCategory], [BusinssPriority], [DMSStatus], [DMSADOLink], [DMSStatusComment], [SP0SourceTableName], [SP0SourceColumnName], [SP0StageTableName], [SP0StagColumnName], [SP0PostUpdate], [SP0IsPart], [SP0StageTableNamePK], [SP0SourceQuery], [DistinctSQLSAPStagColumnName], [DistinctSQLSQLStagColumnName], [DistinctSQLFTPStagColumnName], [NULLSQLSAPColumnName], [NULLSQLSQLColumnName], [NULLSQLFTPColumnName], [UnionSQLAll], [UnionSQLAllExecute], [LoadSQLFactL1Monitor])

SELECT 
--TOP 3 
*
, 'SELECT Distinct '+ISNULL(SAPStagColumnName,'')+ ' From ' +ISNULL(SAPStageTableName,'') AS 'DistinctSQLSAPStagColumnName'
, 'SELECT Distinct '+ISNULL(SQLStagColumnName,'')	 + ' From '+ISNULL(SQLStageTableName ,'') AS 'DistinctSQLSQLStagColumnName'
, 'SELECT Distinct '+ISNULL(FTPStagColumnName,'')	 + ' From '+ISNULL(FTPStageTableName ,'') AS 'DistinctSQLFTPStagColumnName'

,'UPDATE ' + ISNULL(SAPStageTableName,'')+ ' SET ' +ISNULL(SAPStagColumnName,'') +' = null Where ' +ISNULL(SAPStagColumnName,'') +' is null or '+ISNULL(SAPStagColumnName ,'')+'='+''''+'NULL'+'''' AS 'NULLSQLSAPColumnName'
,'UPDATE ' + ISNULL(SQLStageTableName ,'')+ ' SET '  +ISNULL(SQLStagColumnName   ,'') +' = null Where ' +ISNULL(SQLStagColumnName   ,'') +' is null or '+ISNULL(SQLStagColumnName    ,'')+'='+''''+'NULL'+''''  AS 'NULLSQLSQLColumnName'
,'UPDATE ' + ISNULL(FTPStageTableName ,'')+ ' SET '  +ISNULL(FTPStagColumnName   ,'') +' = null Where ' +ISNULL(FTPStagColumnName   ,'') +' is null or '+ISNULL(FTPStagColumnName    ,'')+'='+''''+'NULL'+''''  AS 'NULLSQLFTPColumnName'

,'SELECT Distinct '+ISNULL(SAPStagColumnName,'NULL')+ ' From '+SAPStageTableName
+' UNION '
+'SELECT Distinct '+ISNULL(SQLStagColumnName,'NULL')	 + ' From '+SQLStageTableName 
+' UNION '
+'SELECT Distinct '+ISNULL(FTPStagColumnName,'NULL')	 + ' From '+FTPStageTableName 
AS UnionSQLAll

,'INSERT INTO #TempConfigValueL2
(BusinessPartner, ConfigValue)
SELECT Distinct Cast('+SAPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SAPStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SAPStageTableName
+' UNION '
+'SELECT Distinct Cast('+SQLStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SQLStagColumnName	 + ' As Varchar(200)) From '+SQLStageTableName 
+' UNION '
+'SELECT Distinct Cast('+FTPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+FTPStagColumnName	 + ' As Varchar(200)) From '+FTPStageTableName 
AS UnionSQLAllExecute

,'INSERT INTO #DMS_FactL2Monitor
( [BusinessPartner],[ConfigValue], [IsSAP], [IsSQL],[IsFTP])
SELECT Distinct 
MAIN.[BusinessPartner]
,MAIN.ConfigValue
, CASE WHEN  SAP.ConfigValue IS NULL THEN 0 ELSE 1 END AS IsSAP
, CASE WHEN  SQL.ConfigValue  IS NULL THEN 0 ELSE 1 END AS IsSQL
, CASE WHEN  FTP.ConfigValue  IS NULL THEN 0 ELSE 1 END AS IsFTP
FROM #TempConfigValueL2 main
LEFT JOIN (SELECT Cast('+SAPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SAPStagColumnName+ ' As Varchar(200)) AS ConfigValue FROM '+SAPStageTableName+' ) SAP  
ON MAIN.ConfigValue = SAP.ConfigValue AND main.[BusinessPartner]=SAP.[BusinessPartner] 
LEFT JOIN (SELECT Cast('+SQLStageTableNamePK+' As Varchar(200))  AS [BusinessPartner], Cast('+SQLStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SQLStageTableName+'  ) SQL  
ON MAIN.ConfigValue = SQL.ConfigValue AND main.[BusinessPartner]=SQL.[BusinessPartner] 
LEFT JOIN (SELECT Cast('+FTPStageTableNamePK+' As Varchar(200))  AS [BusinessPartner], Cast('+FTPStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+FTPStageTableName+' ) FTP  
ON MAIN.ConfigValue = FTP.ConfigValue AND main.[BusinessPartner]=FTP.[BusinessPartner] 
Where  MAIN.ConfigValue is not null and len(MAIN.ConfigValue)>0 and MAIN.[BusinessPartner] is not null' --VP 02/27 NO PK IsNumeric(MAIN.[BusinessPartner])=1
AS LoadSQLFactL1Monitor

--INTO #TempCustMonitorConfigL2
FROM [dbo].[DMS_CustMonitorConfig]
WHERE 1=1
and IsReady='true'
--and ConfigID NOT IN (5)
and ispk = 'false' 
and Isl2Only = 1
--and ConfigID not in (Select Distinct ConfigID From DMS_FactL2Monitor (NOLOCK))
AND ConfigCategory='FTP+SAP+SQL'
and ConfigID = @ConfigID
--and ConfigID not in (Select ConfigID from DMS_ConfigIDBusinessPartnerPercetage where PercetageMatchedBP > 80)
--and ConfigID=28
--and ConfigID=12
--and ConfigID in (1,2,3)

--Select * from #TempCustMonitorConfigL2
END

IF (@ConfigCategory= 'SAP+SQL')
BEGIN 
Insert into #TempCustMonitorConfigL2
([ConfigID], [GeneralColumnName], [SAPSourceTableName], [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart], [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName], [SharePointPostUpdate], [SharePointIsPart], [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart], [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName], [Isl1Only], [Isl2Only], [SAPStageTableNamePK], [SQLStageTableNamePK], [FTPStageTableNamePK], [SharePointStageTableNamePK], [CriteriaColumn], [CriteriaValue], [IsSharePointRequired], [GroupID], [SubGroupID], [SyncDataType], [Fields], [DQRule], [SAPSourceQuery], [SQLSourceQuery], [SharePointSourceQuery], [FTPSourceQuery], [ConfigCategory], [BusinssPriority], [DMSStatus], [DMSADOLink], [DMSStatusComment], [SP0SourceTableName], [SP0SourceColumnName], [SP0StageTableName], [SP0StagColumnName], [SP0PostUpdate], [SP0IsPart], [SP0StageTableNamePK], [SP0SourceQuery], [DistinctSQLSAPStagColumnName], [DistinctSQLSQLStagColumnName], [NULLSQLSAPColumnName], [NULLSQLSQLColumnName], [UnionSQLAll], [UnionSQLAllExecute], [LoadSQLFactL1Monitor])

SELECT 
--TOP 3 
*
, 'SELECT Distinct '+ISNULL(SAPStagColumnName,'')+ ' From ' +ISNULL(SAPStageTableName,'') AS 'DistinctSQLSAPStagColumnName'
, 'SELECT Distinct '+ISNULL(SQLStagColumnName,'')	 + ' From '+ISNULL(SQLStageTableName ,'') AS 'DistinctSQLSQLStagColumnName'

,'UPDATE ' + ISNULL(SAPStageTableName,'')+ ' SET ' +ISNULL(SAPStagColumnName,'') +' = null Where ' +ISNULL(SAPStagColumnName,'') +' is null or '+ISNULL(SAPStagColumnName ,'')+'='+''''+'NULL'+'''' AS 'NULLSQLSAPColumnName'
,'UPDATE ' + ISNULL(SQLStageTableName ,'')+ ' SET '  +ISNULL(SQLStagColumnName   ,'') +' = null Where ' +ISNULL(SQLStagColumnName   ,'') +' is null or '+ISNULL(SQLStagColumnName    ,'')+'='+''''+'NULL'+''''  AS 'NULLSQLSQLColumnName'

,'SELECT Distinct '+ISNULL(SAPStagColumnName,'NULL')+ ' From '+SAPStageTableName
+' UNION '
+'SELECT Distinct '+ISNULL(SQLStagColumnName,'NULL')	 + ' From '+SQLStageTableName 
AS UnionSQLAll

,'INSERT INTO #TempConfigValueL2
(BusinessPartner, ConfigValue)
SELECT Distinct Cast('+SAPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SAPStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SAPStageTableName
+' UNION '
+'SELECT Distinct Cast('+SQLStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SQLStagColumnName	 + ' As Varchar(200)) From '+SQLStageTableName 
AS UnionSQLAllExecute

,'INSERT INTO #DMS_FactL2Monitor
( [BusinessPartner],[ConfigValue], [IsSAP], [IsSQL])
SELECT Distinct 
MAIN.[BusinessPartner]
,MAIN.ConfigValue
, CASE WHEN  SAP.ConfigValue IS NULL THEN 0 ELSE 1 END AS IsSAP
, CASE WHEN  SQL.ConfigValue  IS NULL THEN 0 ELSE 1 END AS IsSQL

FROM #TempConfigValueL2 main
LEFT JOIN (SELECT Cast('+SAPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SAPStagColumnName+ ' As Varchar(200)) AS ConfigValue FROM '+SAPStageTableName+' ) SAP  
ON MAIN.ConfigValue = SAP.ConfigValue AND main.[BusinessPartner]=SAP.[BusinessPartner] 
LEFT JOIN (SELECT Cast('+SQLStageTableNamePK+' As Varchar(200))  AS [BusinessPartner], Cast('+SQLStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SQLStageTableName+'  ) SQL  
ON MAIN.ConfigValue = SQL.ConfigValue AND main.[BusinessPartner]=SQL.[BusinessPartner] 
Where  MAIN.ConfigValue is not null and len(MAIN.ConfigValue)>0 and MAIN.[BusinessPartner] is not null' --VP 02/27 NO PK IsNumeric(MAIN.[BusinessPartner])=1
AS LoadSQLFactL1Monitor

--INTO #TempCustMonitorConfigL2
FROM [dbo].[DMS_CustMonitorConfig]
WHERE 1=1
and IsReady='true'
and ConfigID = @ConfigID
--and ConfigID NOT IN (5)
and ispk = 'false' 
and Isl2Only = 1
--and ConfigID not in (Select Distinct ConfigID From DMS_FactL2Monitor (NOLOCK))
AND ConfigCategory='SAP+SQL'
--and ConfigID=5

END

IF (@ConfigCategory= 'ShP+SAP')
BEGIN 
Insert into #TempCustMonitorConfigL2
([ConfigID], [GeneralColumnName], [SAPSourceTableName], [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart], [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName], [SharePointPostUpdate], [SharePointIsPart], [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart], [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName], [Isl1Only], [Isl2Only], [SAPStageTableNamePK], [SQLStageTableNamePK], [FTPStageTableNamePK], [SharePointStageTableNamePK], [CriteriaColumn], [CriteriaValue], [IsSharePointRequired], [GroupID], [SubGroupID], [SyncDataType], [Fields], [DQRule], [SAPSourceQuery], [SQLSourceQuery], [SharePointSourceQuery], [FTPSourceQuery], [ConfigCategory], [BusinssPriority], [DMSStatus], [DMSADOLink], [DMSStatusComment], [SP0SourceTableName], [SP0SourceColumnName], [SP0StageTableName], [SP0StagColumnName], [SP0PostUpdate], [SP0IsPart], [SP0StageTableNamePK], [SP0SourceQuery], [DistinctSQLSAPStagColumnName], [DistinctSQLSharePointStagColumnName], [NULLSQLSAPColumnName], [NULLSQLSharePointColumnName], [UnionSQLAll], [UnionSQLAllExecute], [LoadSQLFactL1Monitor])

SELECT 
--TOP 3 
*
, 'SELECT Distinct '+ISNULL(SharePointStagColumnName,'')+ ' From ' +ISNULL(SharePointStageTableName,'') AS 'DistinctSQLSharePointStagColumnName'
, 'SELECT Distinct '+ISNULL(SAPStagColumnName,'')	 + ' From '+ISNULL(SAPStageTableName ,'') AS 'DistinctSQLSAPStagColumnName'

,'UPDATE ' + ISNULL(SharePointStageTableName,'')+ ' SET ' +ISNULL(SharePointStagColumnName,'') +' = null Where ' +ISNULL(SharePointStagColumnName,'') +' is null or '+ISNULL(SharePointStagColumnName ,'')+'='+''''+'NULL'+'''' AS 'NULLSQLSharePointColumnName'
,'UPDATE ' + ISNULL(SAPStageTableName ,'')+ ' SET '  +ISNULL(SAPStagColumnName   ,'') +' = null Where ' +ISNULL(SAPStagColumnName   ,'') +' is null or '+ISNULL(SAPStagColumnName    ,'')+'='+''''+'NULL'+''''  AS 'NULLSQLSAPColumnName'

,'SELECT Distinct '+ISNULL(SAPStagColumnName,'NULL')+ ' From '+SAPStageTableName
+' UNION '
+'SELECT Distinct '+ISNULL(SharePointStagColumnName,'NULL')	 + ' From '+SharePointStageTableName 

AS UnionSQLAll

,'INSERT INTO #TempConfigValueL2
(BusinessPartner, ConfigValue)
SELECT Distinct Cast('+SAPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SAPStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SAPStageTableName
+' UNION '
+'SELECT Distinct Cast('+SharePointStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SharePointStagColumnName	 + ' As Varchar(200)) From '+SharePointStageTableName 
AS UnionSQLAllExecute

,'INSERT INTO #DMS_FactL2Monitor
( [BusinessPartner],[ConfigValue], [IsSAP], [IsSharePoint])
SELECT Distinct 
MAIN.[BusinessPartner]
,MAIN.ConfigValue
, CASE WHEN  SAP.ConfigValue IS NULL THEN 0 ELSE 1 END AS IsSAP
, CASE WHEN  ShP.ConfigValue  IS NULL THEN 0 ELSE 1 END AS IsSharePoint
FROM #TempConfigValueL2 main
LEFT JOIN (SELECT Cast('+SAPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SAPStagColumnName+ ' As Varchar(200)) AS ConfigValue FROM '+SAPStageTableName+' ) SAP  
ON MAIN.ConfigValue = SAP.ConfigValue AND main.[BusinessPartner]=SAP.[BusinessPartner] 
LEFT JOIN (SELECT Cast('+SharePointStageTableNamePK+' As Varchar(200))  AS [BusinessPartner], Cast('+SharePointStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SharePointStageTableName+'  ) ShP  
ON MAIN.ConfigValue = ShP.ConfigValue AND main.[BusinessPartner]=ShP.[BusinessPartner] 
Where  MAIN.ConfigValue is not null and len(MAIN.ConfigValue)>0' --VP 02/27 NO PK IsNumeric(MAIN.[BusinessPartner])=1
AS LoadSQLFactL1Monitor

--INTO #TempCustMonitorConfigL2
FROM [dbo].[DMS_CustMonitorConfig]
WHERE 1=1
and IsReady='true'
--and ConfigID NOT IN (5)
and ispk = 'false' 
and Isl2Only = 1
AND ConfigCategory='ShP+SAP'
AND ConfigID =@ConfigID
--and ConfigID not in (Select ConfigID from DMS_ConfigIDBusinessPartnerPercetage where PercetageMatchedBP > 80)
--and ConfigID not in (Select Distinct ConfigID From DMS_FactL2Monitor (NOLOCK))
--and ConfigID=24

END

IF (@ConfigCategory= 'ShP+FTP+SAP+SQL')
BEGIN 
Insert into #TempCustMonitorConfigL2
([ConfigID], [GeneralColumnName], [SAPSourceTableName], [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart], [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart], [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName], [SharePointPostUpdate], [SharePointIsPart], [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart], [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc], [IsReady], [HashColumnName], [Isl1Only], [Isl2Only], [SAPStageTableNamePK], [SQLStageTableNamePK], [FTPStageTableNamePK], [SharePointStageTableNamePK], [CriteriaColumn], [CriteriaValue], [IsSharePointRequired], [GroupID], [SubGroupID], [SyncDataType], [Fields], [DQRule], [SAPSourceQuery], [SQLSourceQuery], [SharePointSourceQuery], [FTPSourceQuery], [ConfigCategory], [BusinssPriority], [DMSStatus], [DMSADOLink], [DMSStatusComment], [SP0SourceTableName], [SP0SourceColumnName], [SP0StageTableName], [SP0StagColumnName], [SP0PostUpdate], [SP0IsPart], [SP0StageTableNamePK], [SP0SourceQuery], [DistinctSQLSAPStagColumnName], [DistinctSQLSQLStagColumnName], [DistinctSQLSharePointStagColumnName], [DistinctSQLFTPStagColumnName], [NULLSQLSAPColumnName], [NULLSQLSQLColumnName], [NULLSQLSharePointColumnName], [NULLSQLFTPColumnName], [UnionSQLAll], [UnionSQLAllExecute], [LoadSQLFactL1Monitor])

SELECT 
--TOP 3 
*
, 'SELECT Distinct '+ISNULL(SAPStagColumnName,'')+ ' From ' +ISNULL(SAPStageTableName,'') AS 'DistinctSQLSAPStagColumnName'
, 'SELECT Distinct '+ISNULL(SQLStagColumnName,'')	 + ' From '+ISNULL(SQLStageTableName ,'') AS 'DistinctSQLSQLStagColumnName'
, 'SELECT Distinct '+ISNULL(SharePointStagColumnName,'')+ ' From ' +ISNULL(SharePointStageTableName,'') AS 'DistinctSQLSharePointStagColumnName'
, 'SELECT Distinct '+ISNULL(FTPStagColumnName,'')	 + ' From '+ISNULL(FTPStageTableName ,'') AS 'DistinctSQLFTPStagColumnName'

,'UPDATE ' + ISNULL(SAPStageTableName,'')+ ' SET ' +ISNULL(SAPStagColumnName,'') +' = null Where ' +ISNULL(SAPStagColumnName,'') +' is null or '+ISNULL(SAPStagColumnName ,'')+'='+''''+'NULL'+'''' AS 'NULLSQLSAPColumnName'
,'UPDATE ' + ISNULL(SQLStageTableName ,'')+ ' SET '  +ISNULL(SQLStagColumnName   ,'') +' = null Where ' +ISNULL(SQLStagColumnName   ,'') +' is null or '+ISNULL(SQLStagColumnName    ,'')+'='+''''+'NULL'+''''  AS 'NULLSQLSQLColumnName'
,'UPDATE ' + ISNULL(SharePointStageTableName,'')+ ' SET ' +ISNULL(SharePointStagColumnName,'') +' = null Where ' +ISNULL(SharePointStagColumnName,'') +' is null or '+ISNULL(SharePointStagColumnName ,'')+'='+''''+'NULL'+'''' AS 'NULLSQLSharePointColumnName'
,'UPDATE ' + ISNULL(FTPStageTableName ,'')+ ' SET '  +ISNULL(FTPStagColumnName   ,'') +' = null Where ' +ISNULL(FTPStagColumnName   ,'') +' is null or '+ISNULL(FTPStagColumnName    ,'')+'='+''''+'NULL'+''''  AS 'NULLSQLFTPColumnName'

,'SELECT Distinct '+ISNULL(SAPStagColumnName,'NULL')+ ' From '+SAPStageTableName
+' UNION '
+'SELECT Distinct '+ISNULL(SQLStagColumnName,'NULL')	 + ' From '+SQLStageTableName 
+' UNION '
+'SELECT Distinct '+ISNULL(SharePointStagColumnName,'NULL')	 + ' From '+SharePointStageTableName 
+' UNION '
+'SELECT Distinct '+ISNULL(FTPStagColumnName,'NULL')	 + ' From '+FTPStageTableName 
AS UnionSQLAll

,'INSERT INTO #TempConfigValueL2
(BusinessPartner, ConfigValue)
SELECT Distinct Cast('+SAPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SAPStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SAPStageTableName
+' UNION '
+'SELECT Distinct Cast('+SQLStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SQLStagColumnName	 + ' As Varchar(200)) From '+SQLStageTableName 
+' UNION '
+'SELECT Distinct Cast('+FTPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+FTPStagColumnName	 + ' As Varchar(200)) From '+FTPStageTableName 
+' UNION '
+'SELECT Distinct Cast('+SharePointStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SharePointStagColumnName	 + ' As Varchar(200)) From '+SharePointStageTableName 
AS UnionSQLAllExecute

,'INSERT INTO #DMS_FactL2Monitor
( [BusinessPartner],[ConfigValue], [IsSAP], [IsSQL],[IsFTP],[IsSharePoint])
SELECT Distinct 
MAIN.[BusinessPartner]
,MAIN.ConfigValue
, CASE WHEN  SAP.ConfigValue IS NULL THEN 0 ELSE 1 END AS IsSAP
, CASE WHEN  SQL.ConfigValue  IS NULL THEN 0 ELSE 1 END AS IsSQL
, CASE WHEN  FTP.ConfigValue  IS NULL THEN 0 ELSE 1 END AS IsFTP
, CASE WHEN  ShP.ConfigValue  IS NULL THEN 0 ELSE 1 END AS IsSharePoint
FROM #TempConfigValueL2 main
LEFT JOIN (SELECT Cast('+SAPStageTableNamePK+' As Varchar(200)) AS [BusinessPartner], Cast('+SAPStagColumnName+ ' As Varchar(200)) AS ConfigValue FROM '+SAPStageTableName+' ) SAP  
ON MAIN.ConfigValue = SAP.ConfigValue AND main.[BusinessPartner]=SAP.[BusinessPartner] 
LEFT JOIN (SELECT Cast('+SQLStageTableNamePK+' As Varchar(200))  AS [BusinessPartner], Cast('+SQLStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SQLStageTableName+'  ) SQL  
ON MAIN.ConfigValue = SQL.ConfigValue AND main.[BusinessPartner]=SQL.[BusinessPartner] 
LEFT JOIN (SELECT Cast('+FTPStageTableNamePK+' As Varchar(200))  AS [BusinessPartner], Cast('+FTPStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+FTPStageTableName+' ) FTP  
ON MAIN.ConfigValue = FTP.ConfigValue AND main.[BusinessPartner]=FTP.[BusinessPartner] 
LEFT JOIN (SELECT Cast('+SharePointStageTableNamePK+' As Varchar(200))  AS [BusinessPartner], Cast('+SharePointStagColumnName+ ' As Varchar(200)) AS ConfigValue From '+SharePointStageTableName+' ) ShP  
ON MAIN.ConfigValue = ShP.ConfigValue AND main.[BusinessPartner]=ShP.[BusinessPartner] 
Where  MAIN.ConfigValue is not null and len(MAIN.ConfigValue)>0 and MAIN.[BusinessPartner] is not null' --VP 02/27 NO PK IsNumeric(MAIN.[BusinessPartner])=1
AS LoadSQLFactL1Monitor

--INTO #TempCustMonitorConfigL2
FROM [dbo].[DMS_CustMonitorConfig]
WHERE 1=1
and IsReady='true'
--and ConfigID NOT IN (5)
and ConfigID =@ConfigID
and ispk = 'false' 
and Isl2Only = 1
--and ConfigID not in (Select Distinct ConfigID From DMS_FactL2Monitor (NOLOCK))
AND ConfigCategory='ShP+FTP+SAP+SQL'
--and ConfigID not in (Select ConfigID from DMS_ConfigIDBusinessPartnerPercetage where PercetageMatchedBP > 80)

END



--IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'L2Config' )
--BEGIN
--	SET @SQL = 'DROP TABLE ' + 'L2Config' 
--	EXECUTE sp_executesql @SQL
--END

Select * into #L2Config from #TempCustMonitorConfigL2

Select * from #L2Config

Delete from DMS_CustDynamicConfig Where ConfigID in (Select ConfigID from #L2Config)
Insert into DMS_CustDynamicConfig
([ConfigID], [GeneralColumnName]
, [SAPSourceTableName], [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart]
, [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName], [SharePointPostUpdate], [SharePointIsPart]
, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc]
, [IsReady], [HashColumnName], [Isl1Only], [Isl2Only]
, [SAPStageTableNamePK], [SQLStageTableNamePK], [FTPStageTableNamePK], [SharePointStageTableNamePK]
, [CriteriaColumn], [CriteriaValue], [IsSharePointRequired], [GroupID], [SubGroupID], [SyncDataType], [Fields], [DQRule]
, [SAPSourceQuery], [SQLSourceQuery], [SharePointSourceQuery], [FTPSourceQuery], [ConfigCategory], [BusinssPriority]
, [DistinctSQLSAPStagColumnName], [DistinctSQLSQLStagColumnName], [DistinctSQLSharePointStagColumnName], [DistinctSQLFTPStagColumnName]
, [NULLSQLSAPColumnName], [NULLSQLSQLColumnName], [NULLSQLSharePointColumnName], [NULLSQLFTPColumnName], [UnionSQLAll]
, [UnionSQLAllExecute], [LoadSQLFactL1Monitor], [DMSStatus], [DMSStatusComment], [DMSADOLink])
Select [ConfigID], [GeneralColumnName]
, [SAPSourceTableName], [SAPSourceColumnName], [SAPStageTableName], [SAPStagColumnName], [SAPPostUpdate], [SAPIsPart]
, [SQLSourceTableName], [SQLSourceColumnName], [SQLStageTableName], [SQLStagColumnName], [SQLPostUpdate], [SQLIsPart]
, [SharePointSourceTableName], [SharePointSourceColumnName], [SharePointStageTableName], [SharePointStagColumnName], [SharePointPostUpdate], [SharePointIsPart]
, [FTPSourceTableName], [FTPSourceColumnName], [FTPStageTableName], [FTPStagColumnName], [FTPIsPart]
, [ExecutionSequence], [IsDateType], [IsNumericType], [IsFloatType], [IsPK], [OverAllStatus], [StatusDesc]
, [IsReady], [HashColumnName], [Isl1Only], [Isl2Only]
, [SAPStageTableNamePK], [SQLStageTableNamePK], [FTPStageTableNamePK], [SharePointStageTableNamePK]
, [CriteriaColumn], [CriteriaValue], [IsSharePointRequired], [GroupID], [SubGroupID], [SyncDataType], [Fields], [DQRule]
, [SAPSourceQuery], [SQLSourceQuery], [SharePointSourceQuery], [FTPSourceQuery], [ConfigCategory], [BusinssPriority]
, [DistinctSQLSAPStagColumnName], [DistinctSQLSQLStagColumnName], [DistinctSQLSharePointStagColumnName], [DistinctSQLFTPStagColumnName]
, [NULLSQLSAPColumnName], [NULLSQLSQLColumnName], [NULLSQLSharePointColumnName], [NULLSQLFTPColumnName], [UnionSQLAll]
, [UnionSQLAllExecute], [LoadSQLFactL1Monitor], [DMSStatus], [DMSStatusComment], [DMSADOLink]
from #L2Config



SET @WhileConfigCount = (SELECT COUNT(1) FROM #TempCustMonitorConfigL2)
--SELECT @WhileConfigCount AS '@WhileConfigCount'

--IF @WhileConfigCount>0 
--BEGIN 

DECLARE 
 @NULLSQLSAPColumnName				Nvarchar(200)
,@NULLSQLSQLColumnName				Nvarchar(200)
,@NULLSQLSharePointColumnName				Nvarchar(200)
,@NULLSQLFTPColumnName				Nvarchar(200)
,@UnionSQLAll						Nvarchar(Max)
,@UnionSQLAllExecute				Nvarchar(Max)
,@DistinctSQLSAPStagColumnName	Nvarchar(200)
,@DistinctSQLSQLStagColumnName		Nvarchar(200)
,@DistinctSQLSharePointStagColumnName		Nvarchar(200)
,@DistinctSQLFTPStagColumnName		Nvarchar(200)
--,@ConfigID							INT
,@LoadSQLFactL1Monitor				Nvarchar(max)
,@IsDateType						BIT
,@IsSAP bit
,@IsSQL bit
,@IsSharePoint bit
,@IsFTP bit

--Select * from TempCustMonitorConfigL2
--Test Specific ConfigID	 
--Delete from TempCustMonitorConfigL2 where ConfigID	<>2

SELECT TOP 1 
 @NULLSQLSAPColumnName		=NULLSQLSAPColumnName	
,@NULLSQLSQLColumnName		=NULLSQLSQLColumnName	
,@NULLSQLFTPColumnName		=NULLSQLFTPColumnName
,@UnionSQLAll				=UnionSQLAll
,@UnionSQLAllExecute		=UnionSQLAllExecute
,@DistinctSQLSAPStagColumnName	=DistinctSQLSAPStagColumnName	
,@DistinctSQLSQLStagColumnName		=DistinctSQLSQLStagColumnName
,@DistinctSQLSharePointStagColumnName = DistinctSQLSharePointStagColumnName
,@DistinctSQLFTPStagColumnName = DistinctSQLFTPStagColumnName
,@LoadSQLFactL1Monitor				=LoadSQLFactL1Monitor
,@IsDateType						=IsDateType
,@IsSAP =SAPIsPart
,@IsSQL =SQLIsPart
,@IsSharePoint =SharePointIsPart
,@IsFTP =FTPIsPart
--,* 
FROM #TempCustMonitorConfigL2 ORDER BY ExecutionSequence


Print 'Configid'
PRINT @ConfigID
PRINT '@UnionSQLAllExecute'
PRINT @UnionSQLAllExecute



EXECUTE sp_executesql @UnionSQLAllExecute

--PRINT '@LoadSQLFactL1MonitorPRE'
--PRINT @LoadSQLFactL1Monitor

SET @LoadSQLFactL1Monitor = Replace (@LoadSQLFactL1Monitor,'1 AS ConfigValue','NULL AS ConfigValue')


CREATE TABLE #DMS_FactL2Monitor
(
	[FactL2ID] [bigint] IDENTITY(1,1) NOT NULL,
	[LoadRunDateTime] [datetime] NULL,
	[BusinessPartner] [varchar](200) NULL,
	[ConfigID] [int] NULL,
	[ConfigValue] [varchar](200) NULL,
	[IsSAP] [bit] NULL,
	[IsSQL] [bit] NULL,
	[IsFTP] [bit] NULL,
	[IsSharePoint] [bit] NULL,
	[MatchStatus] [varchar](200) NULL,
	[CompareCode] [varchar](200) NULL,
	[CodeDescription] [varchar](200) NULL,
	[BPEtEMatch] [bit] NULL,
	[FactL1ID] [bigint] NULL,
	[CriteriaValue] [varchar](50) NULL,
	[BRStatus] [varchar](20) NULL,
	[BRIMRelevancy] [char](1) NULL,
	BPStatus [varchar](200) NULL
)


PRINT '@LoadSQLFactL1MonitorPost'
PRINT @LoadSQLFactL1Monitor
EXECUTE sp_executesql @LoadSQLFactL1Monitor

UPDATE #DMS_FactL2Monitor
SET ConfigID = @ConfigID,LoadRunDateTime = @LoadRunDateTime
WHERE ConfigID IS NULL 

 -- DELETE FROM [dbo].[DMS_FactL2Monitor] WHERE ConfigValue IS NULL 

--SELECT Count (1) AS 'TableTempConfigValueL2Count' FROM TempConfigValue



SELECT 
 @NULLSQLSAPColumnName		AS '@NULLSQLSAPColumnName'
,@NULLSQLSQLColumnName		AS '@NULLSQLSQLColumnName'	
,@NULLSQLSharePointColumnName		AS '@NULLSQLSharePointColumnName'
,@UnionSQLAll				AS '@UnionSQLAll'
,@LoadRunDateTime			AS '@LoadRunDateTime'
,@DistinctSQLSAPStagColumnName	AS '@@DistinctSQLSAPStagColumnName'	
,@DistinctSQLSQLStagColumnName		AS '@DistinctSQLSQLStagColumnName'	
,@DistinctSQLSharePointStagColumnName		AS '@DistinctSQLSharePointStagColumnName'		
,@ConfigID							AS '@ConfigID'
,@LoadSQLFactL1Monitor				AS '@LoadSQLFactL1Monitor'
,@IsDateType						AS '@IsDateType'


	   
Update a 
SET CompareCode
=	  'X'
	 +Case when [IsFTP]=1 then '1' Else '0' END 
	 +Case when [IsSAP]=1 then '1' Else '0' END 
	 +Case when [IsSQL]=1 then '1' Else '0' END 
From #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b 
on a.ConfigID = b.ConfigID
AND ConfigCategory='FTP+SAP+SQL'

Update a 
SET CompareCode
=	  'X'
	 +'X'
	 +Case when [IsSAP]=1 then '1' Else '0' END 
	 +Case when [IsSQL]=1 then '1' Else '0' END 
From #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b 
on a.ConfigID = b.ConfigID
Where b.ConfigCategory='SAP+SQL'

Update a 
SET CompareCode
=	  Case when [IsSharePoint]=1 then '1' Else '0' END  
	 + 'X'
	 +Case when [IsSAP]=1 then '1' Else '0' END 
	 + 'X'
From #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b 
on a.ConfigID = b.ConfigID
Where b.ConfigCategory='ShP+SAP'

Update a 
SET CompareCode
=	  Case when [IsSharePoint]=1 then '1' Else '0' END 
	 +Case when [IsFTP]=1 then '1' Else '0' END 
	 +Case when [IsSAP]=1 then '1' Else '0' END 
	 +Case when [IsSQL]=1 then '1' Else '0' END 
From #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b 
on a.ConfigID = b.ConfigID
AND ConfigCategory='ShP+FTP+SAP+SQL'

Update l1
SET l1.CodeDescription = c.CodeDescription
From #DMS_FactL2Monitor l1
left join [dbo].[DMS_CompareCode] c on l1.CompareCode=c.CompareCode
inner join [dbo].[DMS_CustMonitorConfig] b 
on l1.ConfigID = b.ConfigID
--Where ConfigCategory='FTP+SAP+SQL'

Update a 
SET [MatchStatus] = 'Matched'
From #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b 
on a.ConfigID = b.ConfigID
Where 1=1
--and ConfigCategory='FTP+SAP+SQL'
and CompareCode in ('1111','X111','XX11','1X1X')


Update a 
SET [MatchStatus] = 'Not Matched'
From #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b 
on a.ConfigID = b.ConfigID
Where 1=1
--and ConfigCategory='FTP+SAP+SQL'
and CompareCode not in ('1111','X111','XX11','1X1X')


/*
Update a 
SET [MatchStatus] = 'Matched'
From #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b 
on a.ConfigID = b.ConfigID
Where 1=1
--and ConfigCategory='FTP+SAP+SQL'
and CompareCode in ('1111','X111','XX11','1X1X','X011') --
and  a.ConfigID in (2,4,12,1,3,112,111,113,114)


--VP 0514 Special case tax area 
Update #DMS_FactL2Monitor
SET MatchStatus = 'Matched'
Where CompareCode = '0111' and ConfigID in (137,35,36,43,135)

--SP 0906 Specila case for CALocks as Per Sam
Update #DMS_FactL2Monitor
SET MatchStatus = 'Matched'
Where ConfigID in (27,29,56,127) and IsSAP=1 and IsSQL=1

UPDATE #DMS_FactL2Monitor
SET MatchStatus='Matched'
Where ConfigID in (4,5,44,45,51,52,115,144,145,151,152) and IsSAP=1 and IsSQL=1 and IsFTP=1
*/


Select 'Post BRIM' as 'StatusAT',a.ConfigID, a.CompareCode,[MatchStatus], Count(1)  
from #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b on a.ConfigID = b.ConfigID
Where 1=1 
--and b.ConfigCategory='FTP+SAP+SQL'
Group by  a.ConfigID, a.CompareCode ,[MatchStatus]
ORDER BY a.ConfigID



Update #DMS_FactL2Monitor
Set BPStatus = MatchStatus


Update a 
SET a.BPStatus = 'Not Matched'
--Select * 
from #DMS_FactL2Monitor a
Where 1=1
-- and a.configID not in (
-- /*BP t0 BP*/		  2,112,111,113,114,
-- /*Tax Area*/		  137,
-- /*ACN*/				  15,16,17,18,19,20,21,22,23,24,69,121,122,123,124,
-- /*Sales Area*/		  35,36,43,135,
-- /*CA Correspondence*/ 10,11,13,117,118,
-- /*CA Lock*/			  27,29,56,127,156,
-- /*Contract Account*/  7,8,9,28,41,42,46,47,53,54,55,59,60,61,62,63,64,65,66,67,68,
-- 					  108,109,128,141,142,146,147,153,154,155,159,160,161,162,163,164,165,166,167,168,
-- /*Business Partner*/  14,25,26,39,40,48,49,50,70,71,72,
-- /*Company Code*/	  4,5,44,45,51,52,115,
-- /*Sales Position*/	  30,31,32,33,34,57,58) 
and BusinessPartner
in
(
Select BusinessPartner--, Count(Distinct MatchStatus) 
from #DMS_FactL2Monitor
--Where BusinessPartner in (
--Select BusinessPartner--,Count(1) 
--from #DMS_FactL2Monitor
--Group by BusinessPartner
--Having Count(1)>1)
Group by BusinessPartner
Having Count(Distinct MatchStatus)>1
)
--Order by BusinessPartner

Select 'Final' as 'StatusAT',a.ConfigID, a.CompareCode,[MatchStatus],BPStatus, Count(1)  
from #DMS_FactL2Monitor a
inner join [dbo].[DMS_CustMonitorConfig] b on a.ConfigID = b.ConfigID
Where 1=1 
--and b.ConfigCategory='FTP+SAP+SQL'
Group by  a.ConfigID, a.CompareCode ,[MatchStatus],BPStatus
ORDER BY a.ConfigID


--Select * from #DMS_FactL2Monitor
DELETE FROM #DMS_FactL2Monitor WHERE ConfigValue IS NULL 
DELETE FROM [dbo].[DMS_FactL2Monitor]  where  ConfigID in (Select Top 1 ConfigID From #DMS_FactL2Monitor)
INSERT INTO  [dbo].[DMS_FactL2Monitor]
( [LoadRunDateTime], [BusinessPartner], [ConfigID], [ConfigValue], [IsSAP], [IsSQL], [IsFTP], [IsSharePoint]
, [MatchStatus], [CompareCode], [CodeDescription], [BPEtEMatch], [FactL1ID], [CriteriaValue], [BRStatus], [BRIMRelevancy],BPStatus)
SELECT [LoadRunDateTime], [BusinessPartner], [ConfigID], [ConfigValue], [IsSAP], [IsSQL], [IsFTP], [IsSharePoint]
, [MatchStatus], [CompareCode], [CodeDescription], [BPEtEMatch], [FactL1ID], [CriteriaValue], [BRStatus], [BRIMRelevancy],BPStatus
FROM #DMS_FactL2Monitor

IF Object_ID(N'tempdb..#ConfigIDBusinessPartner')						IS NOT NULL BEGIN	DROP Table #ConfigIDBusinessPartner						END 
IF Object_ID(N'tempdb..#ConfigIDBusinessPartnerMatched')				IS NOT NULL BEGIN	DROP Table #ConfigIDBusinessPartnerMatched				END 
IF Object_ID(N'tempdb..#ConfigIDBusinessPartnerNotMatched')				IS NOT NULL BEGIN	DROP Table #ConfigIDBusinessPartnerNotMatched			END 
IF Object_ID(N'tempdb..#ConfigIDConfigIDBusinessPartnerPercetage')		IS NOT NULL BEGIN	DROP Table #ConfigIDConfigIDBusinessPartnerPercetage	END 
IF Object_ID(N'tempdb..#TempConfigVariationCount')						IS NOT NULL BEGIN	DROP Table #TempConfigVariationCount						END 


Select ConfigID, Count(Distinct BusinessPartner) BusinessPartner 
into #ConfigIDBusinessPartner
from #DMS_FactL2Monitor
Where ConfigID=@ConfigID
Group by ConfigID




Select ConfigID, Count(Distinct BusinessPartner) BusinessPartner 
into #ConfigIDBusinessPartnerMatched
from #DMS_FactL2Monitor 
Where BPStatus = 'Matched'
and ConfigID=@ConfigID
Group by ConfigID




Select ConfigID, Count(Distinct BusinessPartner) BusinessPartner 
into #ConfigIDBusinessPartnerNotMatched
from #DMS_FactL2Monitor
Where BPStatus = 'Not Matched'
and ConfigID=@ConfigID
Group by ConfigID

Select 'All BP' as RowType,'#ConfigIDBusinessPartner' AS TempTable,* from #ConfigIDBusinessPartner
UNION
Select 'Matched BP' as RowType,'#ConfigIDBusinessPartnerMatched' AS TempTable,* from #ConfigIDBusinessPartnerMatched
UNION 
Select 'Not Mateched BP' as RowType,'#ConfigIDBusinessPartnerNotMatched' AS TempTable,* from #ConfigIDBusinessPartnerNotMatched




Select b.ConfigID,b.BusinessPartner as 'TotalBP'
, ISNULL(m.BusinessPartner,0) as 'MatchedBP'	
,ISNULL(ROUND(CAST((m.BusinessPartner * 100.0 / b.BusinessPartner) AS FLOAT), 2),0) as 'PercetageMatchedBP' 
--,Cast(ISNULL(((Cast(m.BusinessPartner*1.0/b.BusinessPartner*1.0 as float))*(100*1.0)),0.0) as decimal(4,2)) as 'PercetageMatchedBP' 
,ISNULL(n.BusinessPartner,0) as 'NotMatchedBP'
--,Cast(ISNULL(((Cast(n.BusinessPartner*1.0/b.BusinessPartner*1.0 as float))*(100*1.0)),0.0) as decimal(4,2)) as 'PercetageNotMatchedBP'
,ISNULL(ROUND(CAST((n.BusinessPartner * 100.0 / b.BusinessPartner) AS FLOAT), 2),0) as 'PercetageNotMatchedBP' 
Into #ConfigIDConfigIDBusinessPartnerPercetage
From #ConfigIDBusinessPartner b
Left join #ConfigIDBusinessPartnerMatched m on b.ConfigID = m.ConfigID
Left join #ConfigIDBusinessPartnerNotMatched n on b.ConfigID = n.ConfigID
Where b.ConfigID=@ConfigID
--Order by b.ConfigID

Select * from #ConfigIDConfigIDBusinessPartnerPercetage

Delete From DMS_ConfigIDBusinessPartnerPercetage Where ConfigID=@ConfigID
Insert into DMS_ConfigIDBusinessPartnerPercetage
Select * From #ConfigIDConfigIDBusinessPartnerPercetage


Update c
SET DMSStatus = 'DMS Passed', DMSStatusComment = 'Percentage Matched > 80, Rules applied as per Sync rule and spot checked from 1 matched and not matched with source system'
from [dbo].[DMS_CustMonitorConfig] c
left join DMS_ConfigIDBusinessPartnerPercetage p on c.ConfigID = p.ConfigID
Where PercetageMatchedBP >= 80 and c.ConfigID=@ConfigID

Update c
SET DMSStatus = 'DMS Not Passed', DMSStatusComment = 'Percentage Matched < 80 & >20, Still validating with IT SMEs'
from [dbo].[DMS_CustMonitorConfig] c
left join DMS_ConfigIDBusinessPartnerPercetage p on c.ConfigID = p.ConfigID
Where PercetageMatchedBP <= 80 and PercetageMatchedBP >=20 and c.ConfigID=@ConfigID

Update c
SET DMSStatus = 'DMS Not Passed', DMSStatusComment = 'Percentage Matched > 1 & < 5 ,DMS Team Still validating with Rule'
from [dbo].[DMS_CustMonitorConfig] c
left join DMS_ConfigIDBusinessPartnerPercetage p on c.ConfigID = p.ConfigID
Where PercetageMatchedBP >= 1 and PercetageMatchedBP <=20 and c.ConfigID=@ConfigID

Update c
SET DMSStatus = 'DMS Not Passed', DMSStatusComment = 'Percentage Matched < 1 , DMS Team + IT SMEs Identfying Gap between Sync Rule and Data Output'
from [dbo].[DMS_CustMonitorConfig] c
left join DMS_ConfigIDBusinessPartnerPercetage p on c.ConfigID = p.ConfigID
Where PercetageMatchedBP <= 1 and c.ConfigID=@ConfigID

Update c
SET DMSStatus = 'DMS Not Passed', DMSStatusComment = 'DMS Team started analyzing attribute '
from [dbo].[DMS_CustMonitorConfig] c
left join DMS_ConfigIDBusinessPartnerPercetage p on c.ConfigID = p.ConfigID
Where PercetageMatchedBP is null and c.ConfigID=@ConfigID

Update c
SET DMSStatus = 'DMS Not Passed', DMSStatusComment = 'DMS Team looking into Processing Issue'
from [dbo].[DMS_CustMonitorConfig] c
Where ConfigID not in (select Distinct ConfigID From  [DMS_FactL2Monitor])
/*
Update c
SET DMSStatus = 'DMS Passed', DMSStatusComment = 'Percentage Matched < 80, Rules applied as per Sync rule and spot checked from matched and not matched with source system'
from [dbo].[DMS_CustMonitorConfig] c
left join DMS_ConfigIDBusinessPartnerPercetage p on c.ConfigID = p.ConfigID
Where c.ConfigID in (46,59,8,9,13,10,11,6,40,35,36,37,38,43,135,137) and c.ConfigID=@ConfigID

Update c
SET DMSStatus = 'DMS Passed', DMSStatusComment = 'Percentage Matched < 80, FTP has no data yet, Passed as compare two data soures'
from [dbo].[DMS_CustMonitorConfig] c
left join DMS_ConfigIDBusinessPartnerPercetage p on c.ConfigID = p.ConfigID
Where c.ConfigID in (2,112) and c.ConfigID=@ConfigID

Select DMSStatus,DMSStatusComment,ConfigID,* from [dbo].[DMS_CustMonitorConfig] Where ConfigID=@ConfigID

Update c
SET DMSStatus = 'DMS Not Passed', DMSStatusComment = 'DMS Team looking into Processing Issue'
from [dbo].[DMS_CustMonitorConfig] c
Where DMSStatus is null 
OR ConfigID = 28 --As this is only few BP andd 100% Miss Match */
--/*
IF Object_ID(N'tempdb..#TempCustMonitorConfigL2')	IS NOT NULL BEGIN	DROP Table #TempCustMonitorConfigL2		END 
IF Object_ID(N'tempdb..#TempConfigValueL2')			IS NOT NULL BEGIN	DROP Table #TempConfigValueL2			END 
IF Object_ID(N'tempdb..#L2Config')					IS NOT NULL BEGIN	DROP Table #L2Config					END 
IF Object_ID(N'tempdb..#DMS_FactL2Monitor')				IS NOT NULL BEGIN	DROP Table #DMS_FactL2Monitor				END 
IF Object_ID(N'tempdb..#ConfigIDBusinessPartner')						IS NOT NULL BEGIN	DROP Table #ConfigIDBusinessPartner						END 
IF Object_ID(N'tempdb..#ConfigIDBusinessPartnerMatched')				IS NOT NULL BEGIN	DROP Table #ConfigIDBusinessPartnerMatched				END 
IF Object_ID(N'tempdb..#ConfigIDBusinessPartnerNotMatched')				IS NOT NULL BEGIN	DROP Table #ConfigIDBusinessPartnerNotMatched			END 
IF Object_ID(N'tempdb..#ConfigIDConfigIDBusinessPartnerPercetage')		IS NOT NULL BEGIN	DROP Table #ConfigIDConfigIDBusinessPartnerPercetage	END 
IF Object_ID(N'tempdb..#TempConfigVariationCount')						IS NOT NULL BEGIN	DROP Table #TempConfigVariationCount						END 
--
---*/


Select BusinessPartner,a.ConfigID,Count(Distinct a.ConfigValue) as 'VariationCount'--,Count(1)
Into #TempConfigVariationCount
from [dbo].[DMS_FactL2Monitor] a
inner join [dbo].[DMS_CustMonitorConfig] b on a.ConfigID = b.ConfigID
Where 1=1  
and a.ConfigID=@ConfigID
Group by BusinessPartner,a.ConfigID



Update s
Set S.CriteriaValue = V.VariationCount
From [dbo].[DMS_FactL2Monitor] S
inner join [dbo].[DMS_CustMonitorConfig] b 
on s.ConfigID = b.ConfigID
inner join #TempConfigVariationCount V   
on s.BusinessPartner = v.BusinessPartner 
and s.ConfigID = v.ConfigID
and s.ConfigID = @ConfigID


END
