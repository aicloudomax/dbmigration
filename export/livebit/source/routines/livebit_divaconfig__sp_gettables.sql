CREATE PROCEDURE [divaconfig].[sp_GetTables]
    @SchemaName NVARCHAR(MAX) = NULL,      -- Optional: Comma-separated schema names
    @TableName NVARCHAR(MAX) = NULL,       -- Optional: Comma-separated table names
    @SchemaTableCSV NVARCHAR(MAX) = NULL  -- Optional: Comma-separated schema.table combinations
AS
BEGIN
    /*
    Usage Examples:
    1. Fetch all editable tables:
       EXEC [divaconfig].[sp_GetTables];

    2. Fetch editable tables for specific schemas:
       EXEC [divaconfig].[sp_GetTables] @SchemaName = 'dbo,divaconfig';
	   	   EXEC [divaconfig].[sp_GetTables] @SchemaName = 'dbo';
	   EXEC [divaconfig].[sp_GetTables] @SchemaName = 'divaconfig';

    3. Fetch specific tables:
       EXEC [divaconfig].[sp_GetTables] @TableName = 'DMS_ConfigIDBusinessPartnerPercetage,YourTable';

    4. Fetch specific schema.table combinations:
       EXEC [divaconfig].[sp_GetTables] @SchemaTableCSV = 'dbo.MyTable,divaconfig.YourTable';
	    EXEC [divaconfig].[sp_GetTables] @SchemaTableCSV = 'dbo.DMS_ConfigIDBusinessPartnerPercetage,divaconfig.SampleData'

		   EXEC [divaconfig].[sp_GetTables] @SchemaTableCSV = 'dbo.DMS_ConfigIDBusinessPartnerPercetage,'

    5. Fetch specific tables within specific schemas:
       EXEC [divaconfig].[sp_GetTables] @SchemaName = 'dbo', @TableName = 'MyTable';
    */

    -- Temporary table for splitting SchemaTableCSV into schema.table pairs
    DECLARE @SchemaTableCombo TABLE (FullName NVARCHAR(512));

    -- Split @SchemaTableCSV into schema.table pairs
    IF @SchemaTableCSV IS NOT NULL
    BEGIN
        INSERT INTO @SchemaTableCombo (FullName)
        SELECT TRIM(value)
        FROM STRING_SPLIT(@SchemaTableCSV, ',')
        WHERE CHARINDEX('.', value) > 0; -- Ensure valid schema.table format
    END

    -- Query with strict filters
    SELECT * 
    FROM [divaconfig].[TableInfo]
    WHERE [IsDeleted] = 0
      AND [IsTableEditable] = 1
      AND (
          -- Apply SchemaTableCSV filter strictly when provided
          (@SchemaTableCSV IS NOT NULL AND EXISTS (
              SELECT 1 
              FROM @SchemaTableCombo 
              WHERE FullName = [TableSchemaName] + '.' + [TableName]
          ))
          OR
          -- Apply SchemaName or TableName filters when SchemaTableCSV is NULL
          (@SchemaTableCSV IS NULL AND (
              (@SchemaName IS NULL OR [TableSchemaName] IN (SELECT TRIM(value) FROM STRING_SPLIT(@SchemaName, ',')))
              AND (@TableName IS NULL OR [TableName] IN (SELECT TRIM(value) FROM STRING_SPLIT(@TableName, ',')))
          ))
      );
END
