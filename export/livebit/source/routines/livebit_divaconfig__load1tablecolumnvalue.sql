CREATE PROCEDURE [divaconfig].[Load1TableColumnValue]
    @inputFullTableName NVARCHAR(256) -- Removed NOT NULL constraint
AS

    -- Ensure parameter is not NULL
    IF @inputFullTableName IS NULL
    BEGIN
        RAISERROR ('The input parameter @inputFullTableName cannot be NULL.', 16, 1);
        RETURN;
    END
DECLARE @DynamicSQL NVARCHAR(MAX);
DECLARE @FullTableName NVARCHAR(256) = NULL; -- Specify the schema.table (e.g., 'schema.table'), or leave NULL to process all tables
SET @FullTableName=@inputFullTableName
--SET @FullTableName  = 'divaconfig.SampleData'; -- Specify the schema and table in this format
  PRINT 'Processing table: ' + @FullTableName;
DECLARE @SchemaName NVARCHAR(128), @TableName NVARCHAR(128);
DECLARE @ColumnName NVARCHAR(128);
DECLARE @CurrentIndex INT = 1;
DECLARE @TotalTables INT;
DECLARE @TotalColumns INT;

-- Temporary table to store the list of tables
IF OBJECT_ID('livebit..DivaTempTableList', 'U') IS NOT NULL
    DROP TABLE livebit..DivaTempTableList;

CREATE TABLE livebit..DivaTempTableList (
    RowNum INT,
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(128)
);

-- Populate the table list based on the input
IF @FullTableName IS NULL
BEGIN
    -- No table specified: Process all tables
    INSERT INTO livebit..DivaTempTableList (RowNum, SchemaName, TableName)
    SELECT 
        ROW_NUMBER() OVER (ORDER BY s.name, t.name) AS RowNum,
        s.name AS SchemaName,
        t.name AS TableName
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.is_ms_shipped = 0; -- Exclude system tables
END
ELSE
BEGIN
    -- Specific table specified: Parse schema and table name
    SET @SchemaName = LEFT(@FullTableName, CHARINDEX('.', @FullTableName) - 1);
    SET @TableName = RIGHT(@FullTableName, LEN(@FullTableName) - CHARINDEX('.', @FullTableName));

    -- Validate inputs
    IF @SchemaName IS NULL OR @TableName IS NULL
    BEGIN
        PRINT 'Invalid schema.table format. Please provide input as schema.table';
        RETURN;
    END

    INSERT INTO livebit..DivaTempTableList (RowNum, SchemaName, TableName)
    VALUES (1, @SchemaName, @TableName);
END

-- Get the total number of tables to process
SELECT @TotalTables = COUNT(*) FROM livebit..DivaTempTableList;

PRINT 'Total Tables to Process: ' + CAST(@TotalTables AS NVARCHAR);

-- Check if there are tables to process
IF @TotalTables = 0
BEGIN
    PRINT 'No tables to process.';
    RETURN;
END

-- Temporary table to store the column list
IF OBJECT_ID('livebit..DivaTempColumnList', 'U') IS NOT NULL
    DROP TABLE livebit..DivaTempColumnList;

CREATE TABLE livebit..DivaTempColumnList (
    RowNum INT,
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(128),
    ColumnName NVARCHAR(128)
);

-- Process each table
WHILE @CurrentIndex <= @TotalTables
BEGIN
    -- Fetch details of the current table
    SELECT @SchemaName = SchemaName, @TableName = TableName
    FROM livebit..DivaTempTableList
    WHERE RowNum = @CurrentIndex;

    PRINT 'Processing Table: ' + @SchemaName + '.' + @TableName;

    -- Populate the column list for the current table
    DELETE FROM livebit..DivaTempColumnList;
    INSERT INTO livebit..DivaTempColumnList (RowNum, SchemaName, TableName, ColumnName)
    SELECT 
        ROW_NUMBER() OVER (ORDER BY c.name) AS RowNum,
        @SchemaName AS SchemaName,
        @TableName AS TableName,
        c.name AS ColumnName
    FROM sys.columns c
    INNER JOIN sys.tables t ON c.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = @SchemaName
      AND t.name = @TableName
      AND c.is_computed = 0; -- Exclude computed columns

    -- Get the total number of columns for the current table
    SELECT @TotalColumns = COUNT(*) FROM livebit..DivaTempColumnList;

    PRINT 'Total Columns to Process for ' + @SchemaName + '.' + @TableName + ': ' + CAST(@TotalColumns AS NVARCHAR);
			-- Drop and create the DivaTempColumnValues table
			IF OBJECT_ID('livebit..DivaTempColumnValues', 'U') IS NOT NULL
				DROP TABLE livebit..DivaTempColumnValues;

			CREATE TABLE livebit..DivaTempColumnValues (
				ColumnValueID INT IDENTITY(1,1),
				DatabaseName NVARCHAR(128),
				SchemaName NVARCHAR(128),
				TableName NVARCHAR(128),
				ColumnName NVARCHAR(128),
				Value NVARCHAR(MAX),
				DisplayText NVARCHAR(MAX),
				Description NVARCHAR(MAX),
				ValueCount NVARCHAR(MAX),
				IsActive BIT,
				SortOrder INT,
				CreatedAt DATETIME DEFAULT GETDATE(),
				UpdatedAt DATETIME DEFAULT GETDATE()
			);
    -- Process each column
    DECLARE @ColumnIndex INT = 1;
    WHILE @ColumnIndex <= @TotalColumns
    BEGIN

        -- Fetch details of the current column
        SELECT @ColumnName = ColumnName
        FROM livebit..DivaTempColumnList
        WHERE RowNum = @ColumnIndex;

        PRINT 'Processing Table: ' + @SchemaName + '.' + @TableName+' for Column: ' + @ColumnName;

        -- Dynamic SQL for processing the current column
        SET @DynamicSQL = '
            ;WITH DistinctValues AS (
                SELECT DISTINCT
                    COALESCE(CAST([' + @ColumnName + '] AS NVARCHAR(MAX)), ''NULL'') AS Value, -- Replace NULL with string NULL
                    CAST(COUNT(*) OVER (PARTITION BY [' + @ColumnName + ']) AS NVARCHAR(MAX)) AS ValueCount -- Count occurrences
                FROM [' + @SchemaName + '].[' + @TableName + ']
            )
            INSERT INTO livebit..DivaTempColumnValues (DatabaseName, SchemaName, TableName, ColumnName, Value, DisplayText, Description, ValueCount, IsActive, SortOrder)
            SELECT 
                DB_NAME() AS DatabaseName,
                ''' + @SchemaName + ''' AS SchemaName,
                ''' + @TableName + ''' AS TableName,
                ''' + @ColumnName + ''' AS ColumnName,
                Value,
                Value AS DisplayText,
                ''Distinct value from table [' + @SchemaName + '].[' + @TableName + '] column [' + @ColumnName + ']'' AS Description,
                ValueCount,
                1 AS IsActive,
                ROW_NUMBER() OVER (ORDER BY Value) AS SortOrder -- Incremental sort order for distinct rows
            FROM DistinctValues';

        PRINT 'Generated Dynamic SQL for Column: ' + @ColumnName;

        EXEC sp_executesql @DynamicSQL;

        -- Move to the next column
        SET @ColumnIndex = @ColumnIndex + 1;
    END

    -- Move to the next table
    SET @CurrentIndex = @CurrentIndex + 1;
END

-- Final MERGE and cleanup
PRINT 'Performing final MERGE and cleanup operations...';

MERGE INTO [divaconfig].[ColumnValue] AS Target
USING livebit..DivaTempColumnValues AS Source
ON Target.DatabaseName = Source.DatabaseName
   AND Target.SchemaName = Source.SchemaName
   AND Target.TableName = Source.TableName
   AND Target.ColumnName = Source.ColumnName
   AND Target.Value = Source.Value
WHEN MATCHED THEN
    UPDATE SET 
        Target.DisplayText = Source.DisplayText,
        Target.Description = Source.Description,
        Target.ValueCount = Source.ValueCount,
        Target.IsActive = Source.IsActive,
        Target.SortOrder = Source.SortOrder,
        Target.UpdatedAt = GETDATE(),
        Target.IsDeleted = 0
WHEN NOT MATCHED THEN
    INSERT (DatabaseName, SchemaName, TableName, ColumnName, Value, DisplayText, Description, ValueCount, IsActive, SortOrder, CreatedAt, UpdatedAt, IsDeleted)
    VALUES (Source.DatabaseName, Source.SchemaName, Source.TableName, Source.ColumnName, Source.Value, Source.DisplayText, Source.Description, Source.ValueCount, Source.IsActive, Source.SortOrder, GETDATE(), GETDATE(), 0);

-- Soft delete any records missing in the final source
UPDATE Target
SET Target.IsDeleted = 1,
    Target.UpdatedAt = GETDATE()
FROM [divaconfig].[ColumnValue] AS Target
LEFT JOIN livebit..DivaTempColumnValues AS Source
ON Target.DatabaseName = Source.DatabaseName
   AND Target.SchemaName = Source.SchemaName
   AND Target.TableName = Source.TableName
   AND Target.ColumnName = Source.ColumnName
   AND Target.Value = Source.Value
WHERE Source.ColumnValueID IS NULL;

-- Cleanup physical tables
DROP TABLE livebit..DivaTempTableList;
DROP TABLE livebit..DivaTempColumnList;
DROP TABLE livebit..DivaTempColumnValues;

PRINT 'Processing Completed.';
