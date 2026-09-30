Create proc divaconfig.LoadDIVAMetadata
AS

exec [divaconfig].[LoadTableInfo]
--Select * from [divaconfig].[TableInfo]Where TableName like '%SampleEmployees%'
exec [divaconfig].[LoadColumnInfo]
--Select * from [divaconfig].[ColumnInfo] Where TableName like '%SampleEmployees%'

--Update [divaconfig].[ColumnInfo]
--SET IsLookupValue = 1
--Where ColumnID=5280

exec [divaconfig].[Load1TableColumnValue] 'dbo.SampleEmployees'
--Select * from [divaconfig].[ColumnValue]Where TableName like '%SampleEmployees%'