Create proc divaconfig.loadCompanyInfoCardChart
AS
MERGE INTO [divaconfig].[CardDisplayPerSubtab] AS target
USING (
   SELECT 
        110 AS SubTabID,
        'CompanyInfo' AS ChartDisplayName,
       Cast((Select count (1) from divaconfig.CompanyInfo) as varchar(max)) AS ChartDisplayValue,
        'Total Company ' AS ChartDisplayValuePrefix,
       '' AS ChartDisplayValueSuffix,
        'Number of Company ' ChartDisplayDescription
  Union 
    SELECT 
        110 AS SubTabID,
        'CountGenerated' AS ChartDisplayName,
		Cast(CAST(GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time' AS DATE) as varchar(max)) AS ChartDisplayValue,
        'Build on ' AS ChartDisplayValuePrefix,
       ' Time ' + CONVERT(VARCHAR(8), GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time', 108) AS ChartDisplayValueSuffix,
        'Stats generated on' ChartDisplayDescription
 
) AS source
ON target.ChartDisplayName = source.ChartDisplayName  -- Matching based on ChartDisplayName

WHEN MATCHED THEN
    UPDATE SET 
        ChartDisplayValue = source.ChartDisplayValue,
        ChartDisplayValuePrefix = source.ChartDisplayValuePrefix,
        ChartDisplayValueSuffix = source.ChartDisplayValueSuffix,
        ChartDisplayDescription = source.ChartDisplayDescription

WHEN NOT MATCHED THEN
    INSERT (SubTabID, ChartDisplayName, ChartDisplayValue, ChartDisplayValuePrefix, ChartDisplayValueSuffix, ChartDisplayDescription)
    VALUES (source.SubTabID, source.ChartDisplayName, source.ChartDisplayValue, source.ChartDisplayValuePrefix, source.ChartDisplayValueSuffix, source.ChartDisplayDescription);
