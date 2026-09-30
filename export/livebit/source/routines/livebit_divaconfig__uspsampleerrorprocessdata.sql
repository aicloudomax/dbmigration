CREATE PROCEDURE [divaconfig].[uspSampleErrorProcessData]
AS
BEGIN
    -- Generate a new Execution ID for logging
    DECLARE @ExecutionID UNIQUEIDENTIFIER = NEWID();
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorLine INT;

    -- Start logging the execution details (before the process starts)
    EXEC [divaconfig].[uspLogCustomSP]
        @InputStoredProcedureExecutionID = @ExecutionID,
        @InputStoredProcedureName = 'uspSampleProcessData',
        @InputTransactionType = 'Start-INSERT',
        @InputBatchId = 2002,
        @InputStoredProcedureParameterAll = 'ProcessType=DataLoad;RecordID=2024',
        @ExecutionContext = 'Starting data load operation for records',
        @ExecutionSqContext = 101,
        @ExecutionPipelineContext = 'ETL Pipeline Execution',
        @AzureCorrelationId = @ExecutionID;

    -- Actual processing logic of the stored procedure (for example, data load)
    BEGIN TRY
        -- Simulate a data processing step (e.g., data load or manipulation)
        -- In reality, replace this with your business logic
        WAITFOR DELAY '00:00:05'; -- Simulates 5 seconds of processing
        
        -- FORCED ERROR: This will simulate a critical error during the process
        RAISERROR('Simulated critical error during data load operation.', 16, 1);

        -- If no error, log success at the end of the operation (this will be skipped due to the error)
        EXEC [divaconfig].[uspLogCustomSP]
            @InputStoredProcedureExecutionID = @ExecutionID,
            @InputStoredProcedureName = 'uspSampleProcessData',
            @InputTransactionType = 'End-SUCCESS',
            @InputBatchId = 2002,
            @InputStoredProcedureParameterAll = 'ProcessType=DataLoad;RecordID=2024',
            @ExecutionContext = 'Data load operation for records completed successfully',
            @ExecutionSqContext = 101,
            @ExecutionPipelineContext = 'ETL Pipeline Execution',
            @AzureCorrelationId = @ExecutionID;
    END TRY
    BEGIN CATCH
        -- Capture the error details
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorSeverity = ERROR_SEVERITY();
        SET @ErrorLine = ERROR_LINE();
        
        -- Log the error details
        EXEC [divaconfig].[uspLogCustomSP]
            @InputStoredProcedureExecutionID = @ExecutionID,
            @InputStoredProcedureName = 'uspSampleProcessData',
            @InputTransactionType = 'End-ERROR',
            @InputBatchId = 2002,
            @InputStoredProcedureParameterAll = 'ProcessType=DataLoad;RecordID=2024',
            @ExecutionContext = 'Data load operation failed due to error',
            @ExecutionSqContext = 101,
            @ExecutionPipelineContext = 'ETL Pipeline Execution',
            @AzureCorrelationId = @ExecutionID,
            @ErrorMessage = @ErrorMessage, -- Log captured error message
            @ErrorSeverity =@ErrorSeverity,             -- Log error severity (0 as default)
            @ErrorLine = @ErrorLine;                    -- Log error line number (-1 as default)

        -- Optionally, re-throw the error to propagate it
        THROW;
    END CATCH;
END;
