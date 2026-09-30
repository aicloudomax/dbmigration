
---exec [aidd].[LoadColumnInfo]

CREATE PROCEDURE [aidd].[LoadColumnInfo]
   @Schema SYSNAME,
    @Table SYSNAME

AS

--    SET NOCOUNT ON;

    -- Declare a table variable to hold the latest metadata

-- Drop the table if it exists
IF OBJECT_ID('dbo.DivaTempLatestMetadata', 'U') IS NOT NULL
    DROP TABLE dbo.DivaTempLatestMetadata;

-- Use SELECT INTO to dynamically create the table with all data types
SELECT TOP 0 *
INTO dbo.DivaTempLatestMetadata
FROM aidd.ColumnInfo;

    -- Populate metadata for columns
    INSERT INTO DivaTempLatestMetadata
	(DatabaseName, SchemaName, TableName, ColumnName, ColumnSort, ColumnDescription, DataType, MaxLengthOrValue, MinLengthOrValue, 
    DefaultValue, ValidationRules, CustomCastForSearch, CustomCastForCRUD, DistinctValueCount, IsNullable, IsPrimaryKey, 
    IsForeignKey, IsLookupValue, IsEditable, IsFixedSetValue, IsDate, IsTime, IsDateTime, IsIdentity, IsInt, IsFloat, 
    IsAssociatedToDelete, IsDeleted, IsVoid, IsSensitive, IsUpdateAllow, DataClassification, ComplianceTag, QualityScore, 
    QualityRemarks, ParentColumnID, RestrictionsType, ColumnMetadataSyncDateTime, CreatedAt, UpdatedAt, UpdatedBy,IsDelta,IsLockFromBackend,IsLockFromFrontEnd
)
    SELECT 
        DB_NAME() AS DatabaseName,
        c.TABLE_SCHEMA AS SchemaName,
        c.TABLE_NAME AS TableName,
        c.COLUMN_NAME AS ColumnName,
        c.ORDINAL_POSITION AS ColumnSort, -- Placeholder
        NULL AS ColumnDescription,
        c.DATA_TYPE AS DataType,
        CASE WHEN c.CHARACTER_MAXIMUM_LENGTH = -1 THEN NULL ELSE c.CHARACTER_MAXIMUM_LENGTH END AS MaxLengthOrValue,
        NULL AS MinLengthOrValue, 
        c.COLUMN_DEFAULT AS DefaultValue,
        NULL AS ValidationRules,
        'CAST([' + c.COLUMN_NAME + '] AS NVARCHAR(MAX))' AS CustomCastForSearch,
            CASE 
        WHEN  c.DATA_TYPE = 'INT' THEN 'CAST(' + c.COLUMN_NAME + ' AS INT)'
        WHEN  c.DATA_TYPE = 'DECIMAL' THEN 'CAST(' + c.COLUMN_NAME + ' AS DECIMAL(18, 2))'
        WHEN  c.DATA_TYPE = 'DATETIME' THEN 'CAST(' + c.COLUMN_NAME + ' AS DATETIME)'
        WHEN  c.DATA_TYPE = 'BIT' THEN 'CAST(' + c.COLUMN_NAME + ' AS BIT)'
        WHEN  c.DATA_TYPE = 'VARCHAR' THEN 'CAST(' + c.COLUMN_NAME + ' AS VARCHAR(MAX))'
        WHEN  c.DATA_TYPE = 'FLOAT' THEN 'CAST(' + c.COLUMN_NAME + ' AS FLOAT)'
        WHEN  c.DATA_TYPE = 'TIME' THEN 'CAST(' + c.COLUMN_NAME + ' AS TIME)'
        WHEN  c.DATA_TYPE = 'DATE' THEN 'CAST(' + c.COLUMN_NAME + ' AS DATE)'
		WHEN  c.DATA_TYPE = 'nvarchar' THEN 'CAST(' + c.COLUMN_NAME + ' AS nvarchar(MAX))'
        ELSE null 
		 END AS  CustomCastForCRUD,
        NULL AS DistinctValueCount,
        CASE WHEN c.IS_NULLABLE = 'YES' THEN 1 ELSE 0 END AS IsNullable,
        CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END AS IsPrimaryKey,
        0 AS IsForeignKey,
        0 AS IsLookupValue,
        1 AS IsEditable,
        0 AS IsFixedSetValue,
        CASE WHEN c.DATA_TYPE IN ('date') THEN 1 ELSE 0 END AS IsDate,
        CASE WHEN c.DATA_TYPE IN ('time') THEN 1 ELSE 0 END AS IsTime,
        CASE WHEN c.DATA_TYPE IN ('datetime', 'smalldatetime') THEN 1 ELSE 0 END AS IsDateTime,
        Case WHEN id.IsIdentity is null then 0 else id.IsIdentity end AS IsIdentity, -- Placeholder
        CASE WHEN c.DATA_TYPE IN ('int', 'bigint', 'smallint', 'tinyint') THEN 1 ELSE 0 END AS IsInt,
        CASE WHEN c.DATA_TYPE IN ('float', 'real', 'decimal', 'numeric') THEN 1 ELSE 0 END AS IsFloat,
        CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 0 ELSE 1 END AS IsAssociatedToDelete,
        0 AS IsDeleted,
        0 AS IsVoid,
        0 AS IsSensitive,
        0 AS IsUpdateAllow,
        NULL AS DataClassification,
        NULL AS ComplianceTag,
        NULL AS QualityScore,
        NULL AS QualityRemarks,
        NULL AS ParentColumnID,
        NULL AS RestrictionsType,
        GETDATE() AS ColumnMetadataSyncDateTime,
        GETDATE() AS CreatedAt,
        GETDATE() AS UpdatedAt,
        NULL AS UpdatedBy,
		0 AS IsDelta,
		0 AS IsLockFromBackend,
		0 AS IsLockFromFrontEnd
    FROM INFORMATION_SCHEMA.COLUMNS c
    LEFT JOIN (
        SELECT 
            ku.TABLE_SCHEMA, 
            ku.TABLE_NAME, 
            ku.COLUMN_NAME
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
            ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
        WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    ) pk
        ON c.TABLE_SCHEMA = pk.TABLE_SCHEMA 
        AND c.TABLE_NAME = pk.TABLE_NAME 
        AND c.COLUMN_NAME = pk.COLUMN_NAME
    LEFT JOIN (SELECT 
		c.TABLE_SCHEMA,
		c.TABLE_NAME,
		c.COLUMN_NAME,
		c.ORDINAL_POSITION,
		CASE 
			WHEN COLUMNPROPERTY(OBJECT_ID(c.TABLE_SCHEMA + '.' + c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') = 1 THEN 1 
			ELSE 0 
		END AS IsIdentity
	FROM INFORMATION_SCHEMA.COLUMNS c
	) id 
		 ON id.TABLE_SCHEMA = pk.TABLE_SCHEMA 
        AND id.TABLE_NAME = pk.TABLE_NAME 
        AND id.COLUMN_NAME = pk.COLUMN_NAME
		where         c.TABLE_SCHEMA = @Schema and 
        c.TABLE_NAME = @Table


-----------------C1
DECLARE @SQL NVARCHAR(MAX), @DistinctCount BIGINT;
DECLARE @DynamicSQL NVARCHAR(MAX);
DECLARE @CurrentIndex INT = 1;
DECLARE @TotalColumns INT;

-- Get the total number of columns to process
SELECT @TotalColumns = COUNT(*) FROM DivaTempLatestMetadata;

-- Temporary table to store intermediate results
IF OBJECT_ID('dbo.DivaTempDistinctCounts', 'U') IS NOT NULL
    DROP TABLE dbo.DivaTempDistinctCounts;
CREATE TABLE dbo.DivaTempDistinctCounts (
    DistinctValueCount BIGINT,
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(128),
    ColumnName NVARCHAR(128),
    MaxLengthOrValue NVARCHAR(MAX),
    MinLengthOrValue NVARCHAR(MAX),
    QualityCheckAllNullVoidOneMany NVARCHAR(50),
    QualityCheckAllNullVoidOneValue NVARCHAR(MAX)
);

-- Process each column one at a time using a WHILE loop
WHILE @CurrentIndex <= @TotalColumns
BEGIN
    -- Get the current column details
    DECLARE @SchemaName NVARCHAR(128), @TableName NVARCHAR(128), @ColumnName NVARCHAR(128), @DataType NVARCHAR(50);
    SELECT @SchemaName = SchemaName, @TableName = TableName, @ColumnName = ColumnName, @DataType = DataType
    FROM (
        SELECT *, ROW_NUMBER() OVER (ORDER BY SchemaName, TableName, ColumnName) AS RowNum
        FROM DivaTempLatestMetadata
    ) AS OrderedColumns
    WHERE RowNum = @CurrentIndex;

    -- Build dynamic SQL for the current column
    IF @DataType LIKE '%bit%'
    BEGIN
        SET @DynamicSQL = '
            INSERT INTO dbo.DivaTempDistinctCounts (
                DistinctValueCount, SchemaName, TableName, ColumnName, MaxLengthOrValue, MinLengthOrValue, QualityCheckAllNullVoidOneMany, QualityCheckAllNullVoidOneValue)
            SELECT 
                COUNT(DISTINCT [' + @ColumnName + ']) AS DistinctValueCount, 
                ''' + @SchemaName + ''',
                ''' + @TableName + ''',
                ''' + @ColumnName + ''',
                NULL AS MaxLengthOrValue, -- Not applicable for bit
                NULL AS MinLengthOrValue, -- Not applicable for bit
                CASE 
                    WHEN COUNT(*) = SUM(CASE WHEN [' + @ColumnName + '] IS NULL THEN 1 ELSE 0 END) THEN ''All NULL''
                    WHEN COUNT(DISTINCT [' + @ColumnName + ']) = 1 THEN ''All ONE''
                    ELSE ''Many''
                END AS QualityCheckAllNullVoidOneMany,
                CASE 
                    WHEN COUNT(*) = SUM(CASE WHEN [' + @ColumnName + '] IS NULL THEN 1 ELSE 0 END) THEN NULL
                    WHEN COUNT(DISTINCT [' + @ColumnName + ']) = 1 THEN CAST(COUNT([' + @ColumnName + ']) AS NVARCHAR)
                    ELSE NULL
                END AS QualityCheckAllNullVoidOneValue
            FROM [' + @SchemaName + '].[' + @TableName + ']';
    END
    ELSE
    BEGIN
        SET @DynamicSQL = '
            INSERT INTO dbo.DivaTempDistinctCounts (
                DistinctValueCount, SchemaName, TableName, ColumnName, MaxLengthOrValue, MinLengthOrValue, QualityCheckAllNullVoidOneMany, QualityCheckAllNullVoidOneValue)
            SELECT 
                COUNT(DISTINCT [' + @ColumnName + ']) AS DistinctValueCount, 
                ''' + @SchemaName + ''',
                ''' + @TableName + ''',
                ''' + @ColumnName + ''',
                ' + CASE 
                    WHEN @DataType LIKE '%char%' OR @DataType LIKE '%text%' THEN 
                        'MAX(LEN([' + @ColumnName + '])) AS MaxLengthOrValue, MIN(LEN([' + @ColumnName + '])) AS MinLengthOrValue'
                    WHEN @DataType LIKE '%int%' OR @DataType LIKE '%numeric%' OR @DataType LIKE '%decimal%' THEN 
                        'MAX([' + @ColumnName + ']) AS MaxLengthOrValue, MIN([' + @ColumnName + ']) AS MinLengthOrValue'
                    WHEN @DataType LIKE '%date%' OR @DataType LIKE '%time%' THEN 
                        'MAX([' + @ColumnName + ']) AS MaxLengthOrValue, MIN([' + @ColumnName + ']) AS MinLengthOrValue'
                    ELSE 
                        'NULL AS MaxLengthOrValue, NULL AS MinLengthOrValue'
                  END + ',
                CASE 
                    WHEN COUNT(*) = SUM(CASE WHEN [' + @ColumnName + '] IS NULL THEN 1 ELSE 0 END) THEN ''All NULL''
                    WHEN COUNT(*) = SUM(CASE WHEN LTRIM(RTRIM([' + @ColumnName + '])) = '''' THEN 1 ELSE 0 END) THEN ''All Void''
                    WHEN COUNT(DISTINCT [' + @ColumnName + ']) = 1 THEN ''All ONE''
                    ELSE ''Many''
                END AS QualityCheckAllNullVoidOneMany,
                CASE 
                    WHEN COUNT(*) = SUM(CASE WHEN [' + @ColumnName + '] IS NULL THEN 1 ELSE 0 END) THEN NULL
                    WHEN COUNT(*) = SUM(CASE WHEN LTRIM(RTRIM([' + @ColumnName + '])) = '''' THEN 1 ELSE 0 END) THEN ''''
                    WHEN COUNT(DISTINCT [' + @ColumnName + ']) = 1 THEN MAX([' + @ColumnName + '])
                    ELSE NULL
                END AS QualityCheckAllNullVoidOneValue
            FROM [' + @SchemaName + '].[' + @TableName + ']';
    END

    -- Execute the dynamic SQL
    EXEC sp_executesql @DynamicSQL;

    SET @CurrentIndex = @CurrentIndex + 1;
END

-- Update the main table with the results
UPDATE lm
SET lm.DistinctValueCount = t.DistinctValueCount,
    lm.MaxLengthOrValue = t.MaxLengthOrValue,
    lm.MinLengthOrValue = t.MinLengthOrValue,
    lm.QualityCheckAllNullVoidOneMany = t.QualityCheckAllNullVoidOneMany,
    lm.QualityCheckAllNullVoidOneValue = t.QualityCheckAllNullVoidOneValue
FROM DivaTempLatestMetadata lm
JOIN dbo.DivaTempDistinctCounts t
ON lm.SchemaName = t.SchemaName
   AND lm.TableName = t.TableName
   AND lm.ColumnName = t.ColumnName;






-----------------C1 end
Delete From [aidd].[ColumnInfo]

    -- Insert or update [aidd].[ColumnInfo]
MERGE [aidd].[ColumnInfo] AS ci
USING DivaTempLatestMetadata AS lm
ON ci.DatabaseName = lm.DatabaseName
    AND ci.SchemaName = lm.SchemaName
    AND ci.TableName = lm.TableName
    AND ci.ColumnName = lm.ColumnName
WHEN MATCHED AND ci.IsLockFromBackend = 0 THEN
    UPDATE SET
        ci.ColumnSort = lm.ColumnSort,
        ci.ColumnDescription = lm.ColumnDescription,
        ci.DataType = lm.DataType,
        ci.MaxLengthOrValue = lm.MaxLengthOrValue,
        ci.MinLengthOrValue = lm.MinLengthOrValue,
        ci.DefaultValue = lm.DefaultValue,
        ci.ValidationRules = lm.ValidationRules,
        ci.CustomCastForSearch = lm.CustomCastForSearch,
        ci.CustomCastForCRUD = lm.CustomCastForCRUD,
        ci.DistinctValueCount = lm.DistinctValueCount,
        ci.IsNullable = lm.IsNullable,
        ci.IsPrimaryKey = lm.IsPrimaryKey,
        ci.IsForeignKey = lm.IsForeignKey,
        ci.IsLookupValue = lm.IsLookupValue,
        ci.IsEditable = lm.IsEditable,
        ci.IsFixedSetValue = lm.IsFixedSetValue,
        ci.IsDate = lm.IsDate,
        ci.IsTime = lm.IsTime,
        ci.IsDateTime = lm.IsDateTime,
        ci.IsIdentity = lm.IsIdentity,
        ci.IsInt = lm.IsInt,
        ci.IsFloat = lm.IsFloat,
        ci.IsAssociatedToDelete = lm.IsAssociatedToDelete,
        ci.IsDeleted = lm.IsDeleted,
        ci.IsVoid = lm.IsVoid,
        ci.IsSensitive = lm.IsSensitive,
        ci.IsUpdateAllow = lm.IsUpdateAllow,
        ci.DataClassification = lm.DataClassification,
        ci.ComplianceTag = lm.ComplianceTag,
        ci.QualityScore = lm.QualityScore,
        ci.QualityRemarks = lm.QualityRemarks,
        ci.ParentColumnID = lm.ParentColumnID,
        ci.RestrictionsType = lm.RestrictionsType,
        ci.ColumnMetadataSyncDateTime = lm.ColumnMetadataSyncDateTime,
        ci.UpdatedAt = GETDATE(),
        ci.UpdatedBy = lm.UpdatedBy,
        ci.IsDelta = lm.IsDelta,
		ci.QualityCheckAllNullVoidOneMany = lm.QualityCheckAllNullVoidOneMany,
      ci.QualityCheckAllNullVoidOneValue = lm.QualityCheckAllNullVoidOneValue
WHEN NOT MATCHED THEN
    INSERT (
        DatabaseName, SchemaName, TableName, ColumnName, ColumnSort, ColumnDescription, 
        DataType, MaxLengthOrValue, MinLengthOrValue, DefaultValue, ValidationRules, CustomCastForSearch, CustomCastForCRUD,
        DistinctValueCount, IsNullable, IsPrimaryKey, IsForeignKey, IsLookupValue, IsEditable, IsFixedSetValue,
        IsDate, IsTime, IsDateTime, IsIdentity, IsInt, IsFloat, IsAssociatedToDelete, IsDeleted, IsVoid,
        IsSensitive, IsUpdateAllow, DataClassification, ComplianceTag, QualityScore, QualityRemarks,
        ParentColumnID, RestrictionsType, ColumnMetadataSyncDateTime, CreatedAt, UpdatedAt, UpdatedBy, IsDelta,QualityCheckAllNullVoidOneMany,QualityCheckAllNullVoidOneValue
    )
    VALUES (
        lm.DatabaseName, lm.SchemaName, lm.TableName, lm.ColumnName, lm.ColumnSort, lm.ColumnDescription, 
        lm.DataType, lm.MaxLengthOrValue, lm.MinLengthOrValue, lm.DefaultValue, lm.ValidationRules, lm.CustomCastForSearch, lm.CustomCastForCRUD,
        lm.DistinctValueCount, lm.IsNullable, lm.IsPrimaryKey, lm.IsForeignKey, lm.IsLookupValue, lm.IsEditable, lm.IsFixedSetValue,
        lm.IsDate, lm.IsTime, lm.IsDateTime, lm.IsIdentity, lm.IsInt, lm.IsFloat, lm.IsAssociatedToDelete, lm.IsDeleted, lm.IsVoid,
        lm.IsSensitive, lm.IsUpdateAllow, lm.DataClassification, lm.ComplianceTag, lm.QualityScore, lm.QualityRemarks,
        lm.ParentColumnID, lm.RestrictionsType, lm.ColumnMetadataSyncDateTime, GETDATE(), GETDATE(), lm.UpdatedBy, lm.IsDelta, lm.QualityCheckAllNullVoidOneMany, lm.QualityCheckAllNullVoidOneValue
    );


    -- Soft delete columns not in the latest metadata
    UPDATE ci
    SET ci.IsDeleted = 1, ci.UpdatedAt = GETDATE()
    FROM [aidd].[ColumnInfo] ci
    WHERE NOT EXISTS (
        SELECT 1
        FROM DivaTempLatestMetadata lm
        WHERE ci.DatabaseName = lm.DatabaseName
            AND ci.SchemaName = lm.SchemaName
            AND ci.TableName = lm.TableName
            AND ci.ColumnName = lm.ColumnName
    );

	;WITH IdentityColumns AS (
    SELECT 
        t.name AS TableName,
        c.name AS ColumnName
    FROM sys.tables t
    INNER JOIN sys.columns c ON t.object_id = c.object_id
    INNER JOIN sys.identity_columns ic ON c.object_id = ic.object_id AND c.column_id = ic.column_id
)

-- Update IsPrimaryKey to 1 for identified identity columns
UPDATE ci
SET IsPrimaryKey = 1
--Select ic.*,ci.*
FROM [aidd].[ColumnInfo] ci
INNER JOIN IdentityColumns ic ON ci.TableName = ic.TableName AND ci.ColumnName = ic.ColumnName
WHERE ci.IsPrimaryKey = 0;


---exec [aidd].[LoadColumnInfo]