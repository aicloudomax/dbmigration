CREATE PROCEDURE [divaconfig].[uspSampleProcessData]
AS
BEGIN
    -- Generate a new Execution ID
    DECLARE @ExecutionID UNIQUEIDENTIFIER = NEWID();

    -- Start logging the execution details
    EXEC [divaconfig].[uspLogCustomSP]
        @InputStoredProcedureExecutionID = @ExecutionID,
        @InputStoredProcedureName = 'uspProcessData',
        @InputTransactionType = 'Start-INSERT',
        @InputBatchId = 2002,
        @InputStoredProcedureParameterAll = 'ProcessType=DataLoad;RecordID=2024',
        @ExecutionContext = 'Data load operation for records',
        @ExecutionSqContext = 101,
        @ExecutionPipelineContext = 'ETL Pipeline Execution',
        @AzureCorrelationId = @ExecutionID;

    -- Actual processing logic of the stored procedure (for example, a data load or some operation)
    BEGIN TRY
        -- Processing logic here
        -- Simulate a delay (can be replaced by real logic)
        WAITFOR DELAY '00:00:10'; -- Simulates 10 seconds of processing
        
        -- Log success at the end of the operation
        EXEC [divaconfig].[uspLogCustomSP]
            @InputStoredProcedureExecutionID = @ExecutionID,
            @InputStoredProcedureName = 'uspProcessData',
            @InputTransactionType = 'End-SUCCESS',
            @InputBatchId = 2002,
            @InputStoredProcedureParameterAll = 'ProcessType=DataLoad;RecordID=2024',
            @ExecutionContext = 'Data load operation for records completed',
            @ExecutionSqContext = 101,
            @ExecutionPipelineContext = 'ETL Pipeline Execution',
            @AzureCorrelationId = @ExecutionID;
    END TRY
    BEGIN CATCH
        -- Log the error if something goes wrong
        EXEC [divaconfig].[uspLogCustomSP]
            @InputStoredProcedureExecutionID = @ExecutionID,
            @InputStoredProcedureName = 'uspProcessData',
            @InputTransactionType = 'End-ERROR',
            @InputBatchId = 2002,
            @InputStoredProcedureParameterAll = 'ProcessType=DataLoad;RecordID=2024',
            @ExecutionContext = 'Data load operation failed',
            @ExecutionSqContext = 101,
            @ExecutionPipelineContext = 'ETL Pipeline Execution',
            @AzureCorrelationId = @ExecutionID;
        
        -- Optionally, re-throw the error to propagate it
        THROW;
    END CATCH;
END;
