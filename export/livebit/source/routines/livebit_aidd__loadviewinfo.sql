CREATE PROCEDURE [aidd].[LoadViewInfo]
    @ViewName NVARCHAR(512),
    @ViewSchemaName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- Resolve schema & name
    -------------------------------------------------------------------------
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @Name NVARCHAR(128);

    IF CHARINDEX('.', @ViewName) > 0
    BEGIN
        SET @SchemaName = PARSENAME(@ViewName, 2);
        SET @Name       = PARSENAME(@ViewName, 1);
    END
    ELSE
    BEGIN
        SET @SchemaName = ISNULL(@ViewSchemaName, 'dbo');
        SET @Name = @ViewName;
    END

    -------------------------------------------------------------------------
    -- Validate object exists
    -------------------------------------------------------------------------
    IF OBJECT_ID(QUOTENAME(@SchemaName) + '.' + QUOTENAME(@Name)) IS NULL
    BEGIN
        RAISERROR('Object %s.%s not found.', 16, 1, @SchemaName, @Name);
        RETURN;
    END

    -------------------------------------------------------------------------
    -- Get ObjectID and basic metadata
    -------------------------------------------------------------------------
    DECLARE @ObjectID INT = OBJECT_ID(QUOTENAME(@SchemaName) + '.' + QUOTENAME(@Name));
    DECLARE @TableDatabaseName NVARCHAR(255) = DB_NAME();
    DECLARE @TableDescription NVARCHAR(MAX) = CONCAT('Metadata for object ', @SchemaName, '.', @Name);
    DECLARE @TableRowCount BIGINT = NULL;
    DECLARE @TableColumnCount INT = NULL;
    DECLARE @TableColumnList NVARCHAR(MAX) = NULL;
    DECLARE @TableIdentityColumn NVARCHAR(255) = NULL;
    DECLARE @TablePrimaryColumnCSV NVARCHAR(MAX) = NULL;
    DECLARE @Now DATETIME = GETDATE();

    -------------------------------------------------------------------------
    -- Column list & count
    -------------------------------------------------------------------------
    SELECT @TableColumnCount = COUNT(*)
    FROM sys.columns
    WHERE object_id = @ObjectID;

    SELECT @TableColumnList =
        STUFF((
            SELECT ',' + QUOTENAME(c.name)
            FROM sys.columns c
            WHERE c.object_id = @ObjectID
            ORDER BY c.column_id
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, '');

    -------------------------------------------------------------------------
    -- Row count (table: fast, view: fallback to COUNT(*))
    -------------------------------------------------------------------------
    SELECT @TableRowCount = SUM(ps.row_count)
    FROM sys.dm_db_partition_stats ps
    WHERE ps.object_id = @ObjectID
      AND ps.index_id IN (0,1);

    -- If NULL (e.g., for views), calculate using COUNT(*)
    IF @TableRowCount IS NULL
    BEGIN
        DECLARE @SQL NVARCHAR(MAX) = N'SELECT @rc = COUNT(*) FROM ' 
                                   + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@Name) + ';';
        BEGIN TRY
            EXEC sp_executesql @SQL, N'@rc BIGINT OUTPUT', @rc = @TableRowCount OUTPUT;
        END TRY
        BEGIN CATCH
            PRINT 'Error counting rows for object ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@Name) + ': ' + ERROR_MESSAGE();
            SET @TableRowCount = 0;
        END CATCH
    END

    -------------------------------------------------------------------------
    -- Identity & Primary Key
    -------------------------------------------------------------------------
    IF OBJECTPROPERTY(@ObjectID, 'IsTable') = 1
    BEGIN
        SELECT TOP 1 @TableIdentityColumn = c.name
        FROM sys.columns c
        WHERE c.object_id = @ObjectID AND c.is_identity = 1;

        SELECT @TablePrimaryColumnCSV = STRING_AGG(QUOTENAME(c.name), ',')
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE i.object_id = @ObjectID AND i.is_primary_key = 1;
    END
    ELSE IF OBJECTPROPERTY(@ObjectID, 'IsView') = 1
    BEGIN
        -- Attempt to get first underlying table for Identity/PK
        DECLARE @BaseObjectID INT;
        SELECT TOP 1 @BaseObjectID = referenced_id
        FROM sys.sql_expression_dependencies
        WHERE referencing_id = @ObjectID
          AND referenced_class = 1;  -- OBJECT

        IF @BaseObjectID IS NOT NULL
        BEGIN
            SELECT TOP 1 @TableIdentityColumn = c.name
            FROM sys.columns c
            WHERE c.object_id = @BaseObjectID AND c.is_identity = 1;

            SELECT @TablePrimaryColumnCSV = STRING_AGG(QUOTENAME(c.name), ',')
            FROM sys.indexes i
            JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
            JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE i.object_id = @BaseObjectID AND i.is_primary_key = 1;
        END
    END

    -------------------------------------------------------------------------
    -- Upsert TableInfo
    -------------------------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 FROM [divaconfig].[TableInfo] ti
        WHERE ti.TableDatabaseName = @TableDatabaseName
          AND ti.TableSchemaName   = @SchemaName
          AND ti.TableName         = @Name
    )
    BEGIN
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
        VALUES (
            @TableDatabaseName,
            @SchemaName,
            @Name,
            @TableDescription,
            @TableRowCount,
            @TableColumnCount,
            @TableIdentityColumn,
            @TablePrimaryColumnCSV,
            @TableColumnList,
            CASE WHEN OBJECTPROPERTY(@ObjectID, 'IsView') = 1 THEN 0 ELSE 1 END,
            @Now,
            0
        );
    END
    ELSE
    BEGIN
        UPDATE ti
        SET ti.TableDescription          = @TableDescription,
            ti.TableRowCount             = @TableRowCount,
            ti.TableColumnCount          = @TableColumnCount,
            ti.TableIdentityColumnName   = @TableIdentityColumn,
            ti.TablePrimaryColumnCSV     = @TablePrimaryColumnCSV,
            ti.TableUniqueColumnCSV      = @TableColumnList,
            ti.IsTableEditable           = CASE WHEN OBJECTPROPERTY(@ObjectID, 'IsView') = 1 THEN 0 ELSE 1 END,
            ti.TableMetadataSyncDateTime = @Now,
            ti.IsDeleted                 = 0,
            ti.UpdatedAt                 = GETDATE()
        FROM [divaconfig].[TableInfo] ti
        WHERE ti.TableDatabaseName = @TableDatabaseName
          AND ti.TableSchemaName   = @SchemaName
          AND ti.TableName         = @Name;
    END

    SET NOCOUNT OFF;
END
