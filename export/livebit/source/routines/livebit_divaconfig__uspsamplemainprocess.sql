CREATE PROCEDURE [divaconfig].[uspSampleMainProcess]
AS
BEGIN
    -- Generate a new Execution ID for logging
    DECLARE @ExecutionID UNIQUEIDENTIFIER = NEWID();

    -- Start logging for the parent procedure
    EXEC [divaconfig].[uspLogCustomSP]
        @InputStoredProcedureExecutionID = @ExecutionID,
        @InputStoredProcedureName = 'uspMainProcess',
        @InputTransactionType = 'Start-PROCESS',
        @InputBatchId = 3003,
        @InputStoredProcedureParameterAll = 'ProcessID=3003',
        @ExecutionContext = 'Main process initiation',
        @ExecutionSqContext = 303,
        @ExecutionPipelineContext = 'Main Process',
        @AzureCorrelationId = @ExecutionID;

    -- Call the child procedure that internally logs its own process
    BEGIN TRY
        -- Call the child process (e.g., uspProcessData)
        EXEC [divaconfig].[uspSampleProcessData];

        -- Log success after the child procedure finishes successfully
        EXEC [divaconfig].[uspLogCustomSP]
            @InputStoredProcedureExecutionID = @ExecutionID,
            @InputStoredProcedureName = 'uspMainProcess',
            @InputTransactionType = 'End-SUCCESS',
            @InputBatchId = 3003,
            @InputStoredProcedureParameterAll = 'ProcessID=3003',
            @ExecutionContext = 'Main process completed successfully',
            @ExecutionSqContext = 303,
            @ExecutionPipelineContext = 'Main Process',
            @AzureCorrelationId = @ExecutionID;
    END TRY
    BEGIN CATCH
        -- Log error if something goes wrong
        EXEC [divaconfig].[uspLogCustomSP]
            @InputStoredProcedureExecutionID = @ExecutionID,
            @InputStoredProcedureName = 'uspMainProcess',
            @InputTransactionType = 'End-ERROR',
            @InputBatchId = 3003,
            @InputStoredProcedureParameterAll = 'ProcessID=3003',
            @ExecutionContext = 'Main process failed',
            @ExecutionSqContext = 303,
            @ExecutionPipelineContext = 'Main Process',
            @AzureCorrelationId = @ExecutionID;

        -- Optionally, re-throw the error to propagate it
        THROW;
    END CATCH;
END;
