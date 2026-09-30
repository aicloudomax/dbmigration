CREATE PROCEDURE [divaconfig].LoadAllTableColumnValue
AS

    -- Step 1: Create a physical table to store schema.table names
    IF OBJECT_ID('[divaconfig].[TableList]', 'U') IS NOT NULL
        DROP TABLE [divaconfig].[TableList]; -- Drop the table if it exists
    
    CREATE TABLE [divaconfig].[TableList] (
        ID INT IDENTITY(1, 1) PRIMARY KEY, -- Unique identifier for iteration
        FullTableName NVARCHAR(256) NOT NULL -- Schema and table name
    );

    -- Step 2: Dynamically populate the table with schema.table names
    INSERT INTO [divaconfig].[TableList] (FullTableName)
    SELECT TABLE_SCHEMA + '.' + TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE'; -- Adjust this filter if needed (e.g., to exclude system tables)

	Select * from [divaconfig].[TableList]

    -- Step 3: Declare variables for the loop
    DECLARE @CurrentID INT = 1; -- Start with the first ID
    DECLARE @MaxID INT; -- Store the maximum ID for the loop
    DECLARE @TableName NVARCHAR(256); -- Store the current table name

    -- Get the maximum ID from the TableList
    SELECT @MaxID = MAX(ID) FROM [divaconfig].[TableList];

    -- Step 4: Process each table in a WHILE loop
    WHILE @CurrentID <= @MaxID
    BEGIN
        -- Get the table name for the current ID
        SELECT @TableName = FullTableName
        FROM [divaconfig].[TableList]
        WHERE ID = @CurrentID;

        -- Check if a valid table name was found (to handle gaps in IDs)
        IF @TableName IS NOT NULL
        BEGIN
            -- Call the procedure for processing one table
            EXEC [divaconfig].[Load1TableColumnValue] @TableName;
        END

        -- Increment the ID
        SET @CurrentID = @CurrentID + 1;
    END;

