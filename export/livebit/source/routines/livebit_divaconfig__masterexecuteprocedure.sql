

CREATE PROCEDURE divaconfig.MasterExecuteProcedure
    @UserID INT, -- User ID executing the stored procedure
    @SubTabID INT, -- SubTab ID for tracking execution source
    @ProcedureName NVARCHAR(255), -- Name of the stored procedure to execute
    @Parameters NVARCHAR(MAX) = NULL, -- Delimited parameters string (e.g., param1!@#param2)
	  @Debug BIT = 0 -- Set this to 1 for debugging, 0 to suppress debugging
AS
--exec divaconfig.MasterExecuteProcedure 1,1,'divaconfig.sp_DynamicCRUD','null!@#Read!@#divaconfig.SampleData',0
--TBD parameter dot 
-- --Debugging Block: Uncomment to test the procedure
--DECLARE
--    @UserID INT = 1,
--    @SubTabID INT = 1, -- SubTab ID for tracking execution source
--    @ProcedureName NVARCHAR(255) = 'divaconfig.sp_DynamicCRUD', -- Stored procedure to execute
--    @Parameters NVARCHAR(MAX) = 'null!@#Read!@#divaconfig.SampleData', -- Delimited parameters for testing
--	@Debug BIT = 0 -- Set this to 1 for debugging, 0 to suppress debugging

DECLARE @SQL NVARCHAR(MAX);
DECLARE @ParamList NVARCHAR(MAX) = '';
DECLARE @Delimiter NVARCHAR(10) = '!@#'; -- Delimiter for splitting parameters
DECLARE @ProcedureID INT;
DECLARE @ExecutionStart DATETIME = GETDATE();

-- Step 1: Validate ProcedureID
SELECT @ProcedureID = ProcedureID
FROM divaconfig.StoredProcedures
WHERE ProcedureName = @ProcedureName;

IF @Debug = 1
    PRINT 'ProcedureID: ' + ISNULL(CAST(@ProcedureID AS NVARCHAR), 'NULL');

IF @ProcedureID IS NULL
BEGIN
    PRINT 'Procedure ID not found.';
    RETURN;
END

-- Step 2: Validate User Permissions
IF NOT EXISTS (
    SELECT 1
    FROM divaconfig.StoredProcedureAccess
    WHERE UserID = @UserID AND ProcedureID = @ProcedureID AND HasExecuteAccess = 1 AND Type2Active = 1
)
BEGIN
    PRINT 'Permission Denied: User does not have access.';
    RETURN;
END

IF @Debug = 1
    PRINT 'User permissions validated.';

-- Step 3: Fetch Stored Procedure Parameters
DECLARE @ProcedureParameters TABLE (
    ParameterName NVARCHAR(255),
    ParameterDataType NVARCHAR(50),
    ParameterIsOptional BIT,
    ParameterDefaultValue NVARCHAR(MAX)
);

INSERT INTO @ProcedureParameters
SELECT ParameterName, ParameterDataType, ParameterIsOptional, ParameterDefaultValue
FROM divaconfig.StoredProcedureParameters
WHERE ProcedureID = @ProcedureID;

IF @Debug = 1
BEGIN
    PRINT 'Fetched Procedure Parameters:';
    SELECT * FROM @ProcedureParameters;
END

-- Parse Input Parameters
DECLARE @InputParameters TABLE (
    ParameterIndex INT,
    ParameterValue NVARCHAR(MAX)
);

DECLARE @Index INT = 1;

-- Ensure @Parameters is not NULL or empty before parsing
IF @Parameters IS NOT NULL AND LEN(@Parameters) > 0
BEGIN
    WHILE CHARINDEX(@Delimiter, @Parameters) > 0
    BEGIN
        -- Safeguard LEFT and SUBSTRING functions with valid indices
        IF CHARINDEX(@Delimiter, @Parameters) - 1 > 0
        BEGIN
            INSERT INTO @InputParameters
            VALUES (@Index, LEFT(@Parameters, CHARINDEX(@Delimiter, @Parameters) - 1));
        END

        SET @Parameters = SUBSTRING(@Parameters, CHARINDEX(@Delimiter, @Parameters) + LEN(@Delimiter), LEN(@Parameters));
        SET @Index = @Index + 1;
    END

    -- Add the last parameter if it exists
    IF LEN(@Parameters) > 0
        INSERT INTO @InputParameters
        VALUES (@Index, @Parameters);
END

IF @Debug = 1
BEGIN
    PRINT 'Parsed Input Parameters:';
    SELECT * FROM @InputParameters;
END

-- Step 4: Build Parameter List Dynamically
DECLARE @CurrentParam NVARCHAR(255);
DECLARE @CurrentValue NVARCHAR(MAX);
DECLARE @CurrentIsOptional BIT;
DECLARE @CurrentDefaultValue NVARCHAR(MAX);

DECLARE @ParamIndex INT = 1;

WHILE EXISTS (
    SELECT 1
    FROM @ProcedureParameters
    WHERE ParameterName = (SELECT ParameterName FROM (
        SELECT ROW_NUMBER() OVER (ORDER BY ParameterName) AS RowNum, ParameterName
        FROM @ProcedureParameters
    ) Ranked WHERE RowNum = @ParamIndex)
)
BEGIN
    SELECT 
        @CurrentParam = ParameterName,
        @CurrentIsOptional = ParameterIsOptional,
        @CurrentDefaultValue = ParameterDefaultValue
    FROM @ProcedureParameters
    WHERE ParameterName = (SELECT ParameterName FROM (
        SELECT ROW_NUMBER() OVER (ORDER BY ParameterName) AS RowNum, ParameterName
        FROM @ProcedureParameters
    ) Ranked WHERE RowNum = @ParamIndex);

    SELECT @CurrentValue = ParameterValue
    FROM @InputParameters
    WHERE ParameterIndex = @ParamIndex;

    IF @Debug = 1
        PRINT 'Processing Parameter: ' + @CurrentParam + ', Value: ' + ISNULL(@CurrentValue, 'NULL');

    IF @CurrentValue IS NULL AND @CurrentIsOptional = 1
    BEGIN
        SET @CurrentValue = @CurrentDefaultValue;
    END

    IF @CurrentValue IS NULL AND @CurrentIsOptional = 0
    BEGIN
        PRINT 'Missing required parameter: ' + @CurrentParam;
        RETURN;
    END

    IF @CurrentValue IS NOT NULL
BEGIN
    IF LOWER(@CurrentValue) = 'null'
		BEGIN
			SET @ParamList = @ParamList + @CurrentParam + ' = NULL, '
			Print 'IF @ParamList='+@ParamList
		END
    ELSE
	BEGIN
		SET @ParamList = @ParamList + @CurrentParam + ' = ''' + REPLACE(@CurrentValue, '''', '''''') + ''', ';
		Print 'ELSE @ParamList='+@ParamList
	End
END

    SET @ParamIndex = @ParamIndex + 1;
END

-- Remove trailing comma
IF RIGHT(@ParamList, 2) = ', '
    SET @ParamList = LEFT(@ParamList, LEN(@ParamList) - 1);

IF @Debug = 1
    PRINT 'Generated Parameter List: ' + @ParamList;

-- Step 5: Build and Execute SQL
SET @SQL = 'EXEC ' + @ProcedureName;
IF LEN(@ParamList) > 0
    SET @SQL = @SQL + ' ' + @ParamList;

IF @Debug = 1
    PRINT 'Generated SQL: ' + @SQL;

BEGIN TRY
    EXEC sp_executesql @SQL;
    PRINT 'SQL Execution Successful.';

    INSERT INTO divaconfig.StoredProcedureExecutionLog (
        ProcedureID,
        ProcedureTabID,
        ProcedureExecutedBy,
        ProcedureExecutionStart,
        ProcedureExecutionEnd,
        ProcedureParametersUsed,
        ProcedureExecutionStatus,
        ProcedureErrorMessage
    )
    VALUES (
        @ProcedureID,
        @SubTabID,
        @UserID,
        @ExecutionStart,
        GETDATE(),
        @Parameters,
        'Success',
        NULL
    );
END TRY
BEGIN CATCH
    IF @Debug = 1 
        PRINT 'Error Occurred: ' + ERROR_MESSAGE();
    ELSE
        SELECT 'Error Occurred: ' + ERROR_MESSAGE() AS ErrorMessage;

    INSERT INTO divaconfig.StoredProcedureExecutionLog (
        ProcedureID,
        ProcedureTabID,
        ProcedureExecutedBy,
        ProcedureExecutionStart,
        ProcedureExecutionEnd,
        ProcedureParametersUsed,
        ProcedureExecutionStatus,
        ProcedureErrorMessage
    )
    VALUES (
        @ProcedureID,
        @SubTabID,
        @UserID,
        @ExecutionStart,
        GETDATE(),
        @Parameters,
        'Failed',
        ERROR_MESSAGE()
    );
END CATCH;
