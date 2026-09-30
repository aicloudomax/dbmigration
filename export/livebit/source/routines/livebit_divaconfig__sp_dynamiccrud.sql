CREATE PROCEDURE [divaconfig].[sp_DynamicCRUD]
    @InputSchemaTable NVARCHAR(256), -- Fully qualified table name, e.g., 'schema.table'
    @InputOperationType NVARCHAR(10), -- Operation type: 'Read' or 'Create'
    @InputCSVValues NVARCHAR(MAX) NULL, -- Input values in CSV format with delimiter '$|@'
    @Debug BIT = 0 -- Debug flag (1 = show details, 0 = execute normally)
AS
BEGIN
    -- Declare variables
--Debug
--DECLARE @InputCSVValues NVARCHAR(MAX) = 
--'SampleName$|@SampleValue$|@Display Text$|@Description Text$|@1$|@2024-12-29$|@15:00:00$|@2024-12-29 15:00:00$|@123$|@456.789$|@10$|@2024-12-29 15:00:00$|@2024-12-29 15:00:00';
--DECLARE @InputSchemaTable NVARCHAR(256) = 'divaconfig.sampleData';
--DECLARE @InputOperationType NVARCHAR(10) = 'Create';
-- DECLARE   @Debug BIT = 1 -- Debug flag (1 = show details, 0 = execute normally)

--Log DynamicCRUDExecutionLog
insert into [divaconfig].[DynamicCRUDExecutionLog]
(CRUDSchemaTable,CRUDOperationType,CRUDParametersUsed,CRUDDebug,CRUDProcedureExecutionStart,CRUDExecutionStatus)
Values
(@InputSchemaTable,@InputOperationType,@InputCSVValues,@Debug,getdate(),'Started')

    DECLARE @Schema NVARCHAR(128), 
            @Table NVARCHAR(128), 
            @Query NVARCHAR(MAX),
            @CSVValues NVARCHAR(MAX),
            @InsertColumns NVARCHAR(MAX),
            @InsertValues NVARCHAR(MAX);

    DECLARE @ColumnMetadata TABLE (
        SourceTable NVARCHAR(256),
        ColumnName NVARCHAR(128),
        SortOrder INT,
        CustomCastForCRUD NVARCHAR(MAX),
        IsNullable BIT,
        IsIdentity BIT,
        DataType NVARCHAR(50)
    );

    -- Replace the input delimiter to simplify parsing
    SET @CSVValues = REPLACE(@InputCSVValues, '$|@', '|');
    IF @Debug = 1 
	BEGIN
	PRINT 'Step: Input delimiter. CSVValues: ' + @InputCSVValues;
	PRINT 'Step: Replaced input delimiter. CSVValues: ' + @CSVValues;
	END
    -- Split the schema and table from the input
    SET @Schema = LEFT(@InputSchemaTable, CHARINDEX('.', @InputSchemaTable) - 1);
    SET @Table = RIGHT(@InputSchemaTable, LEN(@InputSchemaTable) - CHARINDEX('.', @InputSchemaTable));
    IF @Debug = 1 PRINT 'Step: Extracted schema and table. Schema: ' + @Schema + ', Table: ' + @Table;

	    -- Check if the table exists in the database
    IF NOT EXISTS (
        SELECT 1 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = @Schema AND TABLE_NAME = @Table
    )
    BEGIN
        SELECT 'Error occurred as Table does not exist : '+@InputSchemaTable AS OutputMessage
        RETURN;
    END;

    IF @Debug = 1
    BEGIN
        PRINT 'Step: Verified table existence. Table: ' + @InputSchemaTable + ' exists.';
    END;

	--Comman Block
	-- Drop temporary metadata table if exists
        IF OBJECT_ID('dbo.DivaTempInsert', 'U') IS NOT NULL
            DROP TABLE dbo.DivaTempInsert;

        -- Create a temporary table to hold metadata
        SELECT @InputSchemaTable AS SourceTable,
               ColumnName,
               ColumnSort,
               CustomCastForCRUD,
               IsNullable,
               IsIdentity,
               DataType
        INTO dbo.DivaTempInsert
        FROM [divaconfig].[ColumnInfo]
        WHERE SchemaName = @Schema
          AND TableName = @Table;

        -- Insert column metadata into @ColumnMetadata table
        INSERT INTO @ColumnMetadata (SourceTable, ColumnName, SortOrder, CustomCastForCRUD, IsNullable, IsIdentity, DataType)
        SELECT 
            @InputSchemaTable AS SourceTable,
            ColumnName,
            ColumnSort,
            CustomCastForCRUD,
            IsNullable,
            IsIdentity,
            DataType
        FROM dbo.DivaTempInsert
        ORDER BY ColumnSort;

    -- Handle 'Read' operation
    IF @InputOperationType = 'Read'
    BEGIN
        SET @Query = 'SELECT * FROM ' + QUOTENAME(@Schema) + '.' + QUOTENAME(@Table);
        IF @Debug = 1 PRINT 'Generated Query (Read): ' + @Query; -- Debugging output
        IF @Debug = 0 EXEC sp_executesql @Query;
        RETURN;
    END

    -- Handle 'Create' operation
    IF @InputOperationType = 'Create'
    BEGIN
        

        IF @Debug = 1
        BEGIN
            PRINT 'Step: Populated Column Metadata:';
            SELECT '@ColumnMetadata' as TableName,* FROM @ColumnMetadata ORDER BY SortOrder;
        END

        -- Drop temporary table for parsed CSV values if exists
        IF OBJECT_ID('dbo.DivaTempInsertValues', 'U') IS NOT NULL
            DROP TABLE dbo.DivaTempInsertValues;

        -- Create the DivaTempInsertValues table explicitly with required columns
        CREATE TABLE dbo.DivaTempInsertValues (
            SourceTable NVARCHAR(256),
            ColumnName NVARCHAR(128),
            ParsedValue NVARCHAR(MAX),
            DataType NVARCHAR(50),
            SortOrder INT
        );

        -- Drop the #ParsedCSV table if it already exists
        IF OBJECT_ID('tempdb..#ParsedCSV') IS NOT NULL
            DROP TABLE #ParsedCSV;

        -- Parse the CSV values into a temporary table
        CREATE TABLE #ParsedCSV (
            ParsedValue NVARCHAR(MAX),
            SortOrder INT
        );

        -- Check if the table has an identity column
        DECLARE @SortOrderOffset INT = 0;
        SELECT @SortOrderOffset = 1
        FROM @ColumnMetadata
        WHERE IsIdentity = 1;

        INSERT INTO #ParsedCSV (ParsedValue, SortOrder)
        SELECT 
            value AS ParsedValue,
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + @SortOrderOffset AS SortOrder
        FROM STRING_SPLIT(@CSVValues, '|'); -- Use '|' as the delimiter

        IF @Debug = 1
        BEGIN
            PRINT 'Step: Populated Column Metadata:';
            SELECT '#ParsedCSV' as TableName, * FROM #ParsedCSV ORDER BY SortOrder;
        END


		-- Map CSV values to column metadata and insert into the temp table
			INSERT INTO dbo.DivaTempInsertValues (SourceTable, ColumnName, ParsedValue, DataType, SortOrder)
			SELECT 
				@InputSchemaTable AS SourceTable,
				cm.ColumnName,
				CASE 
					WHEN cm.IsNullable = 0 AND (pc.ParsedValue IS NULL OR LTRIM(RTRIM(pc.ParsedValue)) = '') THEN NULL
					ELSE pc.ParsedValue
				END AS ParsedValue,
				cm.DataType,
				cm.SortOrder
			FROM @ColumnMetadata cm
			LEFT JOIN #ParsedCSV pc ON cm.SortOrder = pc.SortOrder;

			-- Drop the #ParsedCSV table
			DROP TABLE #ParsedCSV;

			IF @Debug = 1
			BEGIN
				PRINT 'Step: Parsed CSV Values:';
				SELECT 'dbo.DivaTempInsertValues' AS TableName, * FROM dbo.DivaTempInsertValues ORDER BY SortOrder;
			END;

			-- Validate required columns
			DECLARE @MissingColumns NVARCHAR(MAX) = NULL;

			-- Identify missing non-nullable columns
			SELECT @MissingColumns = STRING_AGG(ColumnName, ', ')
			FROM @ColumnMetadata
			WHERE IsIdentity <> 1 and IsNullable = 0
			  AND ColumnName NOT IN (
				  SELECT ColumnName 
				  FROM dbo.DivaTempInsertValues 
				  WHERE ParsedValue IS NOT NULL AND LTRIM(RTRIM(ParsedValue)) <> ''
			  );

			IF @Debug = 1
			BEGIN
				PRINT 'Step: Missing Columns: ' + ISNULL(@MissingColumns, 'None');
			END;

			-- If missing columns exist, report and stop execution
			IF @MissingColumns IS NOT NULL
			BEGIN
				SELECT 'Error occurred as missing required columns:'+ @MissingColumns As OutputMessage;
				RETURN;
			END;


        -- Generate dynamic column names and values
        SELECT @InsertColumns = STRING_AGG(QUOTENAME(ColumnName), ', ')
        FROM dbo.DivaTempInsertValues
        WHERE ParsedValue <> 'NULL'
          AND ColumnName NOT IN (SELECT ColumnName FROM @ColumnMetadata WHERE IsIdentity = 1);

        SELECT @InsertValues = STRING_AGG(
            CASE 
                WHEN DataType IN ('bit') THEN ParsedValue
                WHEN DataType IN ('date', 'datetime', 'time') THEN '''' + ParsedValue + ''''
                ELSE '''' + ParsedValue + ''''
            END, ', ')
        FROM dbo.DivaTempInsertValues
        WHERE ParsedValue <> 'NULL'
          AND ColumnName NOT IN (SELECT ColumnName FROM @ColumnMetadata WHERE IsIdentity = 1);

        IF @Debug = 1
        BEGIN
            PRINT 'Step: Generated Insert Columns: ' + @InsertColumns;
            PRINT 'Step: Generated Insert Values: ' + @InsertValues;
        END

        -- Construct and execute final query
		DECLARE @NewID INT;

        SET @Query = 'INSERT INTO ' + QUOTENAME(@Schema) + '.' + QUOTENAME(@Table) + 
             ' (' + @InsertColumns + ') VALUES (' + @InsertValues + '); 
             SELECT @NewID = SCOPE_IDENTITY();';

        IF @Debug = 1
        BEGIN
            PRINT 'Generated Query (Create): ' + @Query;
            RETURN;
        END

        BEGIN TRY
		    EXEC sp_executesql @Query, N'@NewID INT OUTPUT', @NewID OUTPUT;

			Select 'Insert executed successfully.' As OutputMessage, @NewID AS NewID;
		END TRY
		BEGIN CATCH
			Select 'Error occurred during insert:'+ERROR_MESSAGE() As OutputMessage;
			--PRINT ERROR_MESSAGE();
			--THROW; -- Rethrow the error for further debugging if needed
		END CATCH;
    END

	-- Handle 'Delete' operation
	IF @InputOperationType = 'Delete'
	BEGIN
		-- Check if the table has an identity column
		DECLARE @IdentityColumn NVARCHAR(128) = NULL;

		SELECT TOP 1 @IdentityColumn = ColumnName
		FROM @ColumnMetadata
		WHERE IsIdentity = 1;

		IF @IdentityColumn IS NULL
		BEGIN
			SELECT 'Error occurred as no identity column found in the table: ' + @InputSchemaTable AS OutputMessage;
			RETURN;
		END;

		IF @Debug = 1
		BEGIN
			PRINT 'Step: Verified identity column. IdentityColumn: ' + @IdentityColumn;
		END;

		-- Validate the passed ID
		DECLARE @DeleteID NVARCHAR(MAX) = @InputCSVValues;

		IF @DeleteID IS NULL OR LTRIM(RTRIM(@DeleteID)) = ''
		BEGIN
			SELECT 'Error occurred as no valid ID provided for deletion in table: ' + @InputSchemaTable AS OutputMessage;
			RETURN;
		END;

		IF @Debug = 1
		BEGIN
			PRINT 'Step: Verified DeleteID. DeleteID: ' + @DeleteID;
		END;

		-- Check if the record exists for the given ID
		DECLARE @RecordExists INT;
		DECLARE @CheckExistenceQuery NVARCHAR(MAX);

		SET @CheckExistenceQuery = '
		SELECT @RecordExists = COUNT(1)
		FROM ' + QUOTENAME(@Schema) + '.' + QUOTENAME(@Table) + '
		WHERE ' + QUOTENAME(@IdentityColumn) + ' = @DeleteID';

		IF @Debug = 1
		BEGIN
			PRINT 'Generated Check Existence Query: ' + @CheckExistenceQuery;
		END;

		-- Execute the query to validate existence
		EXEC sp_executesql @CheckExistenceQuery, 
						   N'@DeleteID NVARCHAR(MAX), @RecordExists INT OUTPUT', 
						   @DeleteID, @RecordExists OUTPUT;

		-- If record does not exist, return error message
		IF @RecordExists = 0
		BEGIN
			SELECT 'Error occurred as no record found for ID: ' + @DeleteID + ' in table: ' + @InputSchemaTable AS OutputMessage;
			RETURN;
		END;

		-- Construct the DELETE query
		SET @Query = '
		DELETE FROM ' + QUOTENAME(@Schema) + '.' + QUOTENAME(@Table) + '
		WHERE ' + QUOTENAME(@IdentityColumn) + ' = @DeleteID';

		IF @Debug = 1
		BEGIN
			PRINT 'Generated Query (Delete): ' + @Query;
			RETURN; -- Stop here if in debug mode
		END;

		-- Execute the DELETE query
		BEGIN TRY
			EXEC sp_executesql @Query, N'@DeleteID NVARCHAR(MAX)', @DeleteID;
			SELECT 'Deletion executed successfully for ID: ' + @DeleteID AS OutputMessage;
		END TRY
		BEGIN CATCH
			SELECT 'Error occurred during deletion in table: ' + @InputSchemaTable + '. Message: ' + ERROR_MESSAGE() AS OutputMessage;
			RETURN;
		END CATCH;

	END;


	IF @InputOperationType = 'Update'
	BEGIN
		-- Use a unique variable for identity column in the update block
		DECLARE @IdentityColumnUpdate NVARCHAR(128) = NULL;
		DECLARE @IdentityColumnDataType NVARCHAR(50) = NULL;

		-- Get the identity column and its datatype
		SELECT TOP 1 
			@IdentityColumnUpdate = ColumnName,
			@IdentityColumnDataType = DataType
		FROM @ColumnMetadata
		WHERE IsIdentity = 1;

		IF @IdentityColumnUpdate IS NULL
		BEGIN
			SELECT 'Error occurred as no identity column found in the table: ' + @InputSchemaTable AS OutputMessage;
			RETURN;
		END;

		IF @Debug = 1
		BEGIN
			PRINT 'Step: Verified identity column. IdentityColumn: ' + @IdentityColumnUpdate + ', DataType: ' + @IdentityColumnDataType;
		END;

		-- Validate and extract the passed ID
		DECLARE @UpdateIdentityValue NVARCHAR(MAX);
		DECLARE @UpdateCSV NVARCHAR(MAX) = @InputCSVValues;

		SET @UpdateIdentityValue = LEFT(@UpdateCSV, CHARINDEX('|', @UpdateCSV) - 1);
		SET @UpdateIdentityValue = REPLACE(@UpdateIdentityValue, '$', ''); -- Sanitize ID value
		--SET @UpdateCSV = SUBSTRING(@UpdateCSV, CHARINDEX('|', @UpdateCSV) + 1, LEN(@UpdateCSV));

		IF @UpdateIdentityValue IS NULL OR LTRIM(RTRIM(@UpdateIdentityValue)) = ''
		BEGIN
			SELECT 'Error occurred as no valid ID provided for update in table: ' + @InputSchemaTable AS OutputMessage;
			RETURN;
		END;

		IF @Debug = 1
		BEGIN
			PRINT 'Step: Extracted IdentityValue: ' + @UpdateIdentityValue;
			PRINT 'Step: Remaining Update CSV: ' + @UpdateCSV;
		END;

		-- Map CSV values to column metadata using a new temporary table
		DECLARE @ParsedUpdateValues TABLE (
			ColumnName NVARCHAR(128),
			ParsedValue NVARCHAR(MAX),
			DataType NVARCHAR(50),
			SortOrder INT
		);

		CREATE TABLE #ParsedUpdateCSV (
			ParsedValue NVARCHAR(MAX),
			SortOrder INT
		);

		INSERT INTO #ParsedUpdateCSV (ParsedValue, SortOrder)
		SELECT 
		    CASE 
                -- If the value contains more than one '@', remove the first '@'
                WHEN LEN(value) - LEN(REPLACE(value, '@', '')) > 1 
                THEN 
                    STUFF(REPLACE(LTRIM(RTRIM(value)), '$', ''), CHARINDEX('@', value), 1, '')
                ELSE 
                    REPLACE(REPLACE(LTRIM(RTRIM(value)), '$', ''), '@', '') -- Remove both '@' and '$' if only one '@'
            END AS ParsedValue,
			ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS SortOrder
		FROM STRING_SPLIT(@UpdateCSV, '|'); -- Use '|' as the delimiter

		IF @Debug = 1
		BEGIN
			SELECT '#ParsedUpdateCSV' tablename, * FROM #ParsedUpdateCSV;
		END;

		INSERT INTO @ParsedUpdateValues (ColumnName, ParsedValue, DataType, SortOrder)
		SELECT 
			cm.ColumnName,
			CASE
				-- Handle critical columns like UpdatedAt explicitly
				WHEN pc.ParsedValue IS NULL OR pc.ParsedValue = '' THEN NULL
				WHEN cm.ColumnName = 'UpdatedAt' AND pc.ParsedValue IS NULL THEN CONVERT(NVARCHAR(MAX), GETDATE())
				WHEN cm.DataType IN ('bit') AND pc.ParsedValue NOT IN ('0', '1') THEN 'NULL'
				WHEN cm.DataType IN ('date', 'datetime', 'time') AND ISDATE(pc.ParsedValue) = 0 THEN 'NULL'
                ELSE pc.ParsedValue
			END AS ParsedValue,
			cm.DataType,
			cm.SortOrder
		FROM @ColumnMetadata cm
		LEFT JOIN #ParsedUpdateCSV pc ON cm.SortOrder = pc.SortOrder -- Ensure correct SortOrder mapping
		WHERE cm.ColumnName <> @IdentityColumnUpdate; -- Exclude identity column from updates

		-- Validate alignment
		DECLARE @MisalignedColumns NVARCHAR(MAX) = NULL;
		SELECT @MisalignedColumns = STRING_AGG(cm.ColumnName, ', ')
		FROM @ColumnMetadata cm
		LEFT JOIN #ParsedUpdateCSV pc ON cm.SortOrder = pc.SortOrder
		WHERE pc.SortOrder IS NULL;

		IF @MisalignedColumns IS NOT NULL
		BEGIN
			SELECT 'Misalignment detected for columns: ' + @MisalignedColumns AS OutputMessage;
			RETURN;
		END;

		IF @Debug = 1
		BEGIN
			SELECT '@ParsedUpdateValues' tablename, * FROM @ParsedUpdateValues;
		END;

		DROP TABLE #ParsedUpdateCSV;

		IF @Debug = 1
		BEGIN
			PRINT 'Step: Parsed Update Values:';
			SELECT * FROM @ParsedUpdateValues ORDER BY SortOrder;
		END;

		-- Validate non-nullable columns using unique variable name
		DECLARE @MissingColumnsUpdate NVARCHAR(MAX) = NULL;

		SELECT @MissingColumnsUpdate = STRING_AGG(ColumnName, ', ')
		FROM @ColumnMetadata
		WHERE IsNullable = 0
		  AND ColumnName NOT IN (
			  SELECT ColumnName 
			  FROM @ParsedUpdateValues 
			  WHERE ParsedValue IS NOT NULL
		  )
		  AND ColumnName <> @IdentityColumnUpdate; -- Exclude identity column from validation

		IF @MissingColumnsUpdate IS NOT NULL
		BEGIN
			SELECT 'Missing required columns for update: ' + @MissingColumnsUpdate AS OutputMessage;
			RETURN;
		END;

		-- Construct the UPDATE query with forced casting and proper quoting for date/time
		DECLARE @UpdateSet NVARCHAR(MAX) = NULL;

		SELECT @UpdateSet = STRING_AGG(
			QUOTENAME(ColumnName) + ' = ' + 
			CASE 
				WHEN DataType = 'bit' THEN 'CAST(' + ParsedValue + ' AS BIT)'
				WHEN DataType = 'date' THEN 'CAST(''' + ParsedValue + ''' AS DATE)'
				WHEN DataType = 'datetime' THEN 'CAST(''' + ParsedValue + ''' AS DATETIME)'
				WHEN DataType = 'time' THEN 'CAST(''' + ParsedValue + ''' AS TIME)'
				WHEN DataType = 'int' THEN 'CAST(' + ParsedValue + ' AS INT)'
				WHEN DataType = 'float' THEN 'CAST(' + ParsedValue + ' AS FLOAT)'
				ELSE '''' + ParsedValue + ''''
			END, ', '
		) WITHIN GROUP (ORDER BY SortOrder)
		FROM @ParsedUpdateValues
		WHERE ParsedValue <> 'NULL';

		IF @Debug = 1
		BEGIN
			PRINT 'Update set : ' + @UpdateSet;
			RETURN; -- Stop here if in debug mode
		END;

		-- Format the WHERE clause based on the identity column datatype
		DECLARE @WhereClause NVARCHAR(MAX);

		IF @IdentityColumnDataType IN ('int', 'float', 'bit')
			SET @WhereClause = QUOTENAME(@IdentityColumnUpdate) + ' = ' + @UpdateIdentityValue;
		ELSE
			SET @WhereClause = QUOTENAME(@IdentityColumnUpdate) + ' = ''' + @UpdateIdentityValue + '''';

		SET @Query = '
		UPDATE ' + QUOTENAME(@Schema) + '.' + QUOTENAME(@Table) + '
		SET ' + @UpdateSet + '
		WHERE ' + @WhereClause;

		IF @Debug = 1
		BEGIN
			PRINT 'Generated Query (Update): ' + @Query;
			RETURN; -- Stop here if in debug mode
		END;

		-- Execute the UPDATE query
		BEGIN TRY
			EXEC sp_executesql @Query;
			SELECT 'Update executed successfully for ID: ' + @UpdateIdentityValue AS OutputMessage;
		END TRY
		BEGIN CATCH
			SELECT 'Error occurred during update in table: ' + @InputSchemaTable + '. Message: ' + ERROR_MESSAGE() AS OutputMessage;
			RETURN;
		END CATCH;
	END;


END
