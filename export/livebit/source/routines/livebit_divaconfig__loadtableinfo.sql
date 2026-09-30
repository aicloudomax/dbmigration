CREATE PROCEDURE [divaconfig].[LoadTableInfo]
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare a table variable to hold the latest metadata
    DECLARE @LatestMetadata TABLE (
        ID INT IDENTITY(1,1),
        TableDatabaseName NVARCHAR(255),
        TableSchemaName NVARCHAR(255),
        TableName NVARCHAR(255),
        TableDescription NVARCHAR(MAX),
        TableRowCount BIGINT NULL,
        TableColumnCount INT,
        TableIdentityColumnName NVARCHAR(255),
        TablePrimaryColumnCSV NVARCHAR(MAX),
        TableUniqueColumnCSV NVARCHAR(MAX),
        IsTableEditable BIT,
        TableMetadataSyncDateTime DATETIME
    );

    -- Insert latest metadata into the table variable
    INSERT INTO @LatestMetadata
    SELECT 
        DB_NAME() AS TableDatabaseName,              -- Current database name
        t.TABLE_SCHEMA AS TableSchemaName,          -- Schema of the table
        t.TABLE_NAME AS TableName,                  -- Name of the table
        'Table name is ' + t.TABLE_NAME AS TableDescription, -- Table description
        NULL AS TableRowCount,                      -- Placeholder for row count
        COUNT(c.COLUMN_NAME) AS TableColumnCount,   -- Total column count
        NULL AS TableIdentityColumnName,            -- Identity column (not available in INFORMATION_SCHEMA)
        STRING_AGG(pk.COLUMN_NAME, ',') AS TablePrimaryColumnCSV, -- Primary key columns (comma-separated)
        STRING_AGG(u.COLUMN_NAME, ',') AS TableUniqueColumnCSV,   -- Unique key columns (comma-separated)
        CASE 
            WHEN t.TABLE_TYPE = 'BASE TABLE' THEN 1 -- Editable for base tables
            ELSE 0
        END AS IsTableEditable, 
        GETDATE() AS TableMetadataSyncDateTime      -- Current date for metadata sync
    FROM 
        INFORMATION_SCHEMA.TABLES t
    LEFT JOIN 
        INFORMATION_SCHEMA.COLUMNS c 
        ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
    LEFT JOIN 
        (SELECT 
             ku.TABLE_SCHEMA, 
             ku.TABLE_NAME, 
             ku.COLUMN_NAME
         FROM 
             INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
         JOIN 
             INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
             ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
         WHERE 
             tc.CONSTRAINT_TYPE = 'PRIMARY KEY') pk
        ON t.TABLE_SCHEMA = pk.TABLE_SCHEMA AND t.TABLE_NAME = pk.TABLE_NAME
    LEFT JOIN 
        (SELECT 
             ku.TABLE_SCHEMA, 
             ku.TABLE_NAME, 
             ku.COLUMN_NAME
         FROM 
             INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
         JOIN 
             INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
             ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
         WHERE 
             tc.CONSTRAINT_TYPE = 'UNIQUE') u
        ON t.TABLE_SCHEMA = u.TABLE_SCHEMA AND t.TABLE_NAME = u.TABLE_NAME
    WHERE 
        t.TABLE_TYPE IN ('BASE TABLE') -- Include only base tables
    GROUP BY 
        t.TABLE_SCHEMA, t.TABLE_NAME, t.TABLE_TYPE;

    -- Variables for row count updates
    DECLARE @ID INT, @MaxID INT, @SchemaName NVARCHAR(255), @TableName NVARCHAR(255), @SQL NVARCHAR(MAX), @RowCount BIGINT;

    -- Get the range of IDs in the table
    SELECT @ID = MIN(ID), @MaxID = MAX(ID) FROM @LatestMetadata;

    -- WHILE loop to process each table
    WHILE @ID IS NOT NULL AND @ID <= @MaxID
    BEGIN
        -- Get the schema and table name for the current record
        SELECT @SchemaName = TableSchemaName, @TableName = TableName
        FROM @LatestMetadata WHERE ID = @ID;

        -- Build dynamic SQL to get the row count
        SET @SQL = N'SELECT @RowCount = COUNT(*) FROM [' + @SchemaName + '].[' + @TableName + ']';

        BEGIN TRY
            -- Execute the SQL and get the row count
            EXEC sp_executesql @SQL, N'@RowCount BIGINT OUTPUT', @RowCount OUTPUT;

            -- Update the row count in @LatestMetadata
            UPDATE @LatestMetadata
            SET TableRowCount = @RowCount
            WHERE ID = @ID;
        END TRY
        BEGIN CATCH
            -- Log errors if any during row count execution
            PRINT 'Error calculating row count for [' + @SchemaName + '].[' + @TableName + ']: ' 
                + ERROR_MESSAGE();
        END CATCH;

        -- Increment to the next record
        SET @ID = @ID + 1;
    END;

    -- Insert new records
    INSERT INTO [divaconfig].[TableInfo] (
        TableDatabaseName,
        TableSchemaName,
        TableName,
        TableDescription,
        TableRowCount,
        TableColumnCount,
        TableIdentityColumnName,
        TablePrimaryColumnCSV,
        TableUniqueColumnCSV,
        IsTableEditable,
        TableMetadataSyncDateTime,
        IsDeleted
    )
    SELECT 
        lm.TableDatabaseName,
        lm.TableSchemaName,
        lm.TableName,
        lm.TableDescription,
        lm.TableRowCount,
        lm.TableColumnCount,
        lm.TableIdentityColumnName,
        lm.TablePrimaryColumnCSV,
        lm.TableUniqueColumnCSV,
        lm.IsTableEditable,
        lm.TableMetadataSyncDateTime,
        0 -- IsDeleted = 0 for new records
    FROM 
        @LatestMetadata lm
    WHERE 
        NOT EXISTS (
            SELECT 1 
            FROM [divaconfig].[TableInfo] ti
            WHERE ti.TableDatabaseName = lm.TableDatabaseName
              AND ti.TableSchemaName = lm.TableSchemaName
              AND ti.TableName = lm.TableName
        );

    -- Update existing records
    UPDATE ti
    SET 
        ti.TableDescription = lm.TableDescription,
        ti.TableRowCount = lm.TableRowCount,
        ti.TableColumnCount = lm.TableColumnCount,
        ti.TableIdentityColumnName = lm.TableIdentityColumnName,
        ti.TablePrimaryColumnCSV = lm.TablePrimaryColumnCSV,
        ti.TableUniqueColumnCSV = lm.TableUniqueColumnCSV,
        ti.IsTableEditable = lm.IsTableEditable,
        ti.TableMetadataSyncDateTime = lm.TableMetadataSyncDateTime,
        ti.IsDeleted = 0, -- Reset IsDeleted flag if it was previously set
        ti.UpdatedAt = GETDATE()
    FROM 
        [divaconfig].[TableInfo] ti
    INNER JOIN 
        @LatestMetadata lm
    ON 
        ti.TableDatabaseName = lm.TableDatabaseName
        AND ti.TableSchemaName = lm.TableSchemaName
        AND ti.TableName = lm.TableName;

    -- Soft delete records not in the latest metadata
    UPDATE ti
    SET 
        ti.IsDeleted = 1,
        ti.UpdatedAt = GETDATE()
    FROM 
        [divaconfig].[TableInfo] ti
    WHERE 
        NOT EXISTS (
            SELECT 1 
            FROM @LatestMetadata lm
            WHERE ti.TableDatabaseName = lm.TableDatabaseName
              AND ti.TableSchemaName = lm.TableSchemaName
              AND ti.TableName = lm.TableName
        );

    SET NOCOUNT OFF;
END;
