
CREATE proc divaconfig.loadSpecialTableCardChart
AS
MERGE INTO [divaconfig].[CardDisplayPerSubtab] AS target
USING (
    SELECT 
        84 AS SubTabID,
        DimTableName AS ChartDisplayName,
        CAST(GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time' AS DATE) AS ChartDisplayValue,
        'Build on ' AS ChartDisplayValuePrefix,
       ' Time ' + CONVERT(VARCHAR(8), GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time', 108) AS ChartDisplayValueSuffix,
        'Value Generated for ' + DimTableName + ' ' + DimTableDescription AS ChartDisplayDescription
    FROM divadim.DimMaster
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

