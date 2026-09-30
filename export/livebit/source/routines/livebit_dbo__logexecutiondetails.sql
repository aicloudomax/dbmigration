CREATE PROCEDURE LogExecutionDetails
    @ProcedureName NVARCHAR(255) = NULL,  -- Only required for 'Started' status
    @ParameterDetails NVARCHAR(MAX) = NULL,  -- Only required for 'Started' status
    @OpenAIStepName NVARCHAR(255) = NULL,  -- Only required for 'Started' status
    @OpenAIParameterDetails NVARCHAR(MAX) = NULL,  -- Only required for 'Started' status
    @OpenAIPrompt NVARCHAR(MAX) = NULL,  -- Only required for 'Started' status
    @AdditionalLoggingDetails NVARCHAR(MAX) = NULL,
    @Status NVARCHAR(50),  -- 'Started', 'Completed', or Error status
    @ErrorMessage NVARCHAR(MAX) = NULL,  -- Optional error message for error statuses
    @LogID INT = NULL OUTPUT,  -- Input/Output parameter for LogID
    @ExecutionGUID NVARCHAR(MAX) = NULL  -- Optional input for Execution GUID, can be blank
AS
BEGIN
    -- If no LogID is provided and status is 'Started', insert a new log entry
    IF @LogID IS NULL AND @Status = 'Started'
    BEGIN
        -- If ExecutionGUID is not provided or blank, generate a new GUID and convert to NVARCHAR
        IF @ExecutionGUID IS NULL OR @ExecutionGUID = ''
        BEGIN
            SET @ExecutionGUID = CAST(NEWID() AS NVARCHAR(MAX));
        END

        -- Insert log with start time and ExecutionGUID
        INSERT INTO ExecutionLog 
        (ProcedureName, StartTime, ParameterDetails, Status, OpenAIStepName, OpenAIParameterDetails, OpenAIPrompt, AdditionalLoggingDetails, ExecutionGUID)
        VALUES 
        (@ProcedureName, GETDATE(), @ParameterDetails, 'Started', @OpenAIStepName, @OpenAIParameterDetails, @OpenAIPrompt, @AdditionalLoggingDetails, @ExecutionGUID);

        -- Capture the identity value of the inserted row (LogID)
        SET @LogID = SCOPE_IDENTITY();
    END

    -- If LogID is provided and status is 'Completed', update the existing log with end time
    ELSE IF @LogID IS NOT NULL AND @Status = 'Completed'
    BEGIN
        UPDATE ExecutionLog
        SET EndTime = GETDATE(),
            Status = 'Completed',
            AdditionalLoggingDetails = @AdditionalLoggingDetails
        WHERE LogID = @LogID;
    END

    -- If LogID is provided and the status is not 'Completed' or 'Started', treat it as an error
    ELSE IF @LogID IS NOT NULL AND @Status != 'Started' AND @Status != 'Completed'
    BEGIN
        UPDATE ExecutionLog
        SET EndTime = GETDATE(),
            Status = 'Error',
            ErrorMessage = @ErrorMessage,
            AdditionalLoggingDetails = @AdditionalLoggingDetails
        WHERE LogID = @LogID;
    END
    ELSE
    BEGIN
        -- Handle invalid cases where neither a valid @LogID nor a valid @Status is provided
        RAISERROR('Invalid input: LogID or Status is missing.', 16, 1);
    END
END;
