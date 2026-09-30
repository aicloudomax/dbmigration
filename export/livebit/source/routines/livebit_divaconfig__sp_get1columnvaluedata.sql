
Create PROCEDURE [divaconfig].[sp_Get1ColumnValueData]
    @SchemaTable NVARCHAR(512) -- Schema and table name in the format: schema.table
	,@ColumnName NVARCHAR(512)
AS
BEGIN
    /*
    Description:
    - Fetches metadata for a specific table's columns.
    - Ensures the table exists, is editable, and is not deleted.
    - Returns distinct error messages for non-existing, non-editable, or deleted tables.

    Example Usage:
    EXEC [divaconfig].[sp_GetColumnMetadata] @SchemaTable = 'dbo.MyTable';
	 EXEC [divaconfig].[sp_GetColumnMetadata] @SchemaTable = 'divaconfig.SampleData';
    */

    -- Variables to store schema and table name
    DECLARE @SchemaName NVARCHAR(255);
    DECLARE @TableName NVARCHAR(255);

    -- Parse Schema and Table from @SchemaTable
    SET @SchemaName = LEFT(@SchemaTable, CHARINDEX('.', @SchemaTable) - 1);
    SET @TableName = SUBSTRING(@SchemaTable, CHARINDEX('.', @SchemaTable) + 1, LEN(@SchemaTable));

    -- Check if the table exists
    IF NOT EXISTS (
        SELECT 1
        FROM [divaconfig].[TableInfo]
        WHERE [TableSchemaName] = @SchemaName
          AND [TableName] = @TableName
    )
    BEGIN
        SELECT 'The specified table [' + @SchemaTable + '] does not exist.' AS ErrorMessage;
        RETURN;
    END



    -- Check if the table is deleted
    IF EXISTS (
        SELECT 1
        FROM [divaconfig].[TableInfo]
        WHERE [TableSchemaName] = @SchemaName
          AND [TableName] = @TableName
          AND [IsDeleted] = 1
    )
    BEGIN
        SELECT 'The specified table [' + @SchemaTable + '] is marked as deleted.' AS ErrorMessage;
        RETURN;
    END

    -- Fetch column metadata for the specified table
    SELECT *
    FROM [divaconfig].[ColumnValue]
    WHERE [SchemaName] = @SchemaName
      AND [TableName] = @TableName
	  and ColumnName = @ColumnName

END
