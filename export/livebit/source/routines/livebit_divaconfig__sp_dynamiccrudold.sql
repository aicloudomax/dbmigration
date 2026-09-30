
CREATE PROCEDURE [divaconfig].[sp_DynamicCRUD]
    @InputSchemaTable NVARCHAR(256), -- Format: 'schema.table'
    @InputOperationType NVARCHAR(10), -- Expected: 'Create'
    @InputCSVValues NVARCHAR(MAX) NULL -- CSV value list
AS

--Declare @InputSchemaTable NVARCHAR(256), -- Format: 'schema.table'
--    @InputOperationType NVARCHAR(10), -- Expected: 'Create'
--    @InputCSVValues NVARCHAR(MAX) -- CSV value list

	Declare @SchemaTable NVARCHAR(256), -- Format: 'schema.table'
    @OperationType NVARCHAR(10), -- Expected: 'Create'
    @CSVValues NVARCHAR(MAX), -- CSV value list
	@SQLRead NVARCHAR(MAX)
	--SET @SchemaTable ='divaconfig.SampleData'
	--SET @OperationType='Read'
	--SET @CSVValues='99$|@MasterNameSampleColumn1$|@MasterValue1$|@MasterDisplayTextDescription1$|@MasterDescriptionnvarchar$|@1$|@NULL$|@14:45:301$|@NULL$|@98$|@1.0$|@99$|@NULL$|@null$|@10$|@15.5$|@1$|@NULL$|@NULL'
    SET @CSVValues = REPLACE(@CSVValues, '$|@', '|');
	SET @SchemaTable =@InputSchemaTable
	SET @OperationType=@InputOperationType
	SET @CSVValues= @InputCSVValues
    SET @CSVValues = REPLACE(@CSVValues, '$|@', '|');
    DECLARE @Schema NVARCHAR(128), @Table NVARCHAR(128), @Query NVARCHAR(MAX);
    DECLARE @ColumnMetadata TABLE (
        ColumnName NVARCHAR(128),
        SortOrder INT,
        CustomCastForCRUD NVARCHAR(MAX),
        IsNullable BIT,
		IsIdentity bit
    );
    -- Split Schema and Table
    SET @Schema = LEFT(@SchemaTable, CHARINDEX('.', @SchemaTable) - 1);
    SET @Table = RIGHT(@SchemaTable, LEN(@SchemaTable) - CHARINDEX('.', @SchemaTable));

	--Select @Schema,@Table

	IF(@OperationType='Read')
	BEGIN 

	SET @SQLRead = N'SELECT * FROM ' + QUOTENAME(@Schema) + '.' + QUOTENAME(@Table)
	-- Print the SQL to verify
	PRINT @SQLRead

	EXEC sp_executesql @SQLRead

	END
	IF(@OperationType='Create')
	BEGIN

	IF OBJECT_ID('dbo.DivaTempInsert', 'U') IS NOT NULL
    DROP TABLE dbo.DivaTempInsert;



	-- Use SELECT INTO to dynamically create the table with all data types
	SELECT TOP 0 *
	INTO dbo.DivaTempInsert
	FROM [divaconfig].[ColumnInfo];

	-- Enable IDENTITY_INSERT for the table
	SET IDENTITY_INSERT dbo.DivaTempInsert ON;

    -- Get column metadata ordered by SortOrder
    INSERT Into dbo.DivaTempInsert 
	(ColumnID,DatabaseName,SchemaName,TableName,ColumnName,ColumnSort,ColumnDescription,DataType,MaxLengthOrValue,MinLengthOrValue,DefaultValue
	,ValidationRules,CustomCastForSearch,CustomCastForCRUD,DistinctValueCount,IsNullable,IsPrimaryKey,IsForeignKey,IsLookupValue,IsEditable
	,IsFixedSetValue,IsDate,IsTime,IsDateTime,IsIdentity,IsInt,IsFloat,IsAssociatedToDelete,IsDeleted,IsVoid,IsSensitive,IsUpdateAllow,IsDelta
	,IsLockFromBackend,IsLockFromFrontEnd,TextualDataType,DataClassification,ComplianceTag,QualityCheckAllNullVoidOneMany
	,QualityCheckAllNullVoidOneValue,QualityScore,QualityRemarks,ParentColumnID,RestrictionsType,ColumnMetadataSyncDateTime,CreatedAt,UpdatedAt,UpdatedBy)
	Exec [divaconfig].[sp_GetColumnMetadata] @SchemaTable;

	--Select * from dbo.DivaTempInsert 

		-- Retrieve Metadata Ordered by SortOrder
		-- Insert column metadata into @ColumnMetadata table
		INSERT INTO @ColumnMetadata (ColumnName, SortOrder, CustomCastForCRUD, IsNullable,IsIdentity)
		SELECT 
			ColumnName,
			ColumnSort,
			CustomCastForCRUD,
			IsNullable,
			IsIdentity
		FROM dbo.DivaTempInsert
		WHERE CustomCastForCRUD IS NOT NULL
		ORDER BY ColumnSort;

		-- Drop temporary table if it exists
		IF OBJECT_ID('dbo.DivaTempInsertValues', 'U') IS NOT NULL
			DROP TABLE dbo.DivaTempInsertValues;

		-- Parse the CSV values and map to metadata
		;WITH ParsedCSV AS (
			SELECT 
				value,
				ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS SortOrder
			FROM STRING_SPLIT(@CSVValues, '|') -- Use '|' as the delimiter
		)
		-- Map CSV values to column metadata and generate casted values
		SELECT 
			cm.ColumnName,
			REPLACE(cm.CustomCastForCRUD, cm.ColumnName, ''''+p.value+'''')
			AS CastedValue
		INTO dbo.DivaTempInsertValues 
		FROM ParsedCSV p
		JOIN @ColumnMetadata cm ON p.SortOrder = cm.SortOrder
		Where cm.IsIdentity <>1
		
				
				update DivaTempInsertValues
				SET CastedValue = NULL
				Where CastedValue like '%null%'
				Select * from DivaTempInsertValues

-- Generate the final INSERT INTO query dynamically
DECLARE @InsertColumns NVARCHAR(MAX), @InsertValues NVARCHAR(MAX);

-- Construct column names for the INSERT statement
SELECT @InsertColumns = STRING_AGG(ColumnName, ', ')
FROM dbo.DivaTempInsertValues;

-- Construct values for the INSERT statement
SELECT @InsertValues = STRING_AGG(CastedValue, ', ')
FROM dbo.DivaTempInsertValues;

-- Final INSERT query
SET @Query = '
INSERT INTO ' + @Schema + '.' + @Table + '
(' + @InsertColumns + ')
VALUES
(' + @InsertValues + ');';

-- Output the query for debugging
PRINT @Query;

-- Uncomment below to execute the query
--EXEC sp_executesql @Query;

END


