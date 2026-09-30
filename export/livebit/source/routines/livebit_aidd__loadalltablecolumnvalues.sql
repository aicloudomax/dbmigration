
CREATE   PROCEDURE [aidd].[LoadAllTableColumnValues]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SchemaName NVARCHAR(255),
            @TableName NVARCHAR(255),
            @ColumnName NVARCHAR(255),
            @SQL NVARCHAR(MAX);

    -- Clean existing data (soft delete old values instead of hard delete)
    UPDATE [aidd].[ColumnValue]
    SET IsDeleted = 1, UpdatedAt = GETDATE();

    -- Cursor over active column metadata from ColumnInfo
    DECLARE cur CURSOR FAST_FORWARD FOR
    SELECT SchemaName, TableName, ColumnName
    FROM [aidd].[ColumnInfo]
    WHERE IsDeleted = 0
      AND IsEditable = 1;  -- optional filter

    OPEN cur;
    FETCH NEXT FROM cur INTO @SchemaName, @TableName, @ColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Dynamic SQL to insert distinct column values
        SET @SQL = '
            INSERT INTO [aidd].[ColumnValue] (
                DatabaseName, SchemaName, TableName, ColumnName,
                Value, ValueCount, DisplayText, Description, IsActive, SortOrder, CreatedAt, UpdatedAt, IsDeleted
            )
            SELECT 
                DB_NAME(),
                ''' + @SchemaName + ''',
                ''' + @TableName + ''',
                ''' + @ColumnName + ''',
                CAST([' + @ColumnName + '] AS NVARCHAR(MAX)) AS Value,
                COUNT(*) AS ValueCount,
                CAST([' + @ColumnName + '] AS NVARCHAR(MAX)) AS DisplayText,
                NULL AS Description,
                1 AS IsActive,
                ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS SortOrder,
                GETDATE() AS CreatedAt,
                GETDATE() AS UpdatedAt,
                0 AS IsDeleted
            FROM [' + @SchemaName + '].[' + @TableName + ']
            WHERE [' + @ColumnName + '] IS NOT NULL
            GROUP BY [' + @ColumnName + ']';

        EXEC sp_executesql @SQL;

        FETCH NEXT FROM cur INTO @SchemaName, @TableName, @ColumnName;
    END;

    CLOSE cur;
    DEALLOCATE cur;
END;
 