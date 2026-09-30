CREATE PROCEDURE [divaconfig].[uspLogCustomSP] (
    @InputStoredProcedureExecutionID   VARCHAR(100),
    @InputStoredProcedureName          VARCHAR(100),
    @InputTransactionType              CHAR(10),
    @InputBatchId                      BIGINT,
    @InputStoredProcedureParameterAll  VARCHAR(4000),
    @ExecutionContext                  NVARCHAR(MAX) = NULL,  
    @ExecutionSqContext                INT = NULL,
    @ExecutionPipelineContext          NVARCHAR(200) = NULL,
    @AzureCorrelationId                NVARCHAR(100) = NULL, 
	@ErrorMessage                      NVARCHAR(MAX) = NULL, 
    @ErrorSeverity                     INT = NULL,           
    @ErrorLine                         INT = NULL            
) AS
BEGIN
    DECLARE @startTime          DATETIME2 = GETUTCDATE();
    DECLARE @executionTime      INT;
    DECLARE @cpuTime            BIGINT;
    DECLARE @elapsedTime        BIGINT;
    DECLARE @logicalReads       BIGINT;
    DECLARE @physicalReads      BIGINT;
    DECLARE @logicalWrites      BIGINT;
    DECLARE @executionCount     INT;
    DECLARE @maxGrantKb         BIGINT;
    DECLARE @maxUsedGrantKb     BIGINT;
    DECLARE @sessionId          NVARCHAR(50);
    DECLARE @loginNameSession   NVARCHAR(128);
    DECLARE @programName        NVARCHAR(128);
    DECLARE @client_net_address NVARCHAR(128);

    -- Use TRY-CATCH to log execution and errors
    BEGIN TRY
        -- Capture resource usage (CPU time, reads, writes, physical reads, execution count, memory grants, elapsed time)
        SELECT TOP 1 
            @cpuTime        = total_worker_time,
            @elapsedTime    = total_elapsed_time,
            @logicalReads   = total_logical_reads,
            @physicalReads  = total_physical_reads,
            @logicalWrites  = total_logical_writes,
            @executionCount = execution_count,
            @maxGrantKb     = max_grant_kb,
            @maxUsedGrantKb = max_used_grant_kb
        FROM sys.dm_exec_query_stats AS qs
        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle)
        WHERE qs.sql_handle IS NOT NULL;

        -- Capture session details
        SELECT TOP 1
            @sessionId         = CAST(s.session_id AS NVARCHAR(50)), 
            @loginNameSession  = s.login_name,
            @programName       = s.program_name,
            @client_net_address = c.client_net_address
        FROM sys.dm_exec_sessions s
        JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
        WHERE s.session_id = @@SPID;

        -- Calculate execution time in milliseconds
        SET @executionTime = DATEDIFF(MILLISECOND, @startTime, GETUTCDATE());

    END TRY
    BEGIN CATCH
        -- Capture error details in case of failure
        SET @errorMessage  = ERROR_MESSAGE();
        SET @errorSeverity = ERROR_SEVERITY();
        SET @errorLine     = ERROR_LINE();
    END CATCH;

    -- Insert log into the [LogCustomeSp] table, logging every execution and error details
    INSERT INTO [divaconfig].[LogCustomeSp] (
        [ID],
        [StoredProcedureExecutionID],
        [BatchId],
        [StoredProcedureName],
        [StoredProcedureParameterAll],
        [LoginName],
        [ClientId],
        [AppName],
        [TransactionStartDateTime],
        [TransactionEndDateTime],
        [TransactionType],
        [Spid],
        [ErrorMessage],
        [ErrorSeverity],        -- Log error severity
        [ErrorLine],            -- Log the line number where the error occurred
        [ExecutionTime],
        [CpuTime],               
        [ElapsedTime],            
        [LogicalReads],          
        [PhysicalReads],        
        [LogicalWrites],         
        [ExecutionCount],        
        [MaxGrantKb],            
        [MaxUsedGrantKb],       
        [AzureCorrelationId],    
        [sessionId],             
        [loginNameSession],      
        [programName],           
        [client_net_address],    
        [ExecutionContext],      
        [ExecutionSqContext],    
        [ExecutionPipelineContext]
    )
    VALUES (
        NEWID(),
        @InputStoredProcedureExecutionID,
        @InputBatchId,
        @InputStoredProcedureName,
        @InputStoredProcedureParameterAll,
        @loginNameSession,
        @client_net_address,
        @programName,
        @startTime,
        GETUTCDATE(),
        @InputTransactionType,
        @@SPID,
        @errorMessage,           -- Logging actual error message
        @errorSeverity,          -- Logging error severity
        @errorLine,              -- Logging error line number
        @executionTime,   
        @cpuTime,         
        @elapsedTime,     
        @logicalReads,    
        @physicalReads,   
        @logicalWrites,   
        @executionCount,  
        @maxGrantKb,      
        @maxUsedGrantKb,  
        @AzureCorrelationId,
        @sessionId,
        @loginNameSession,
        @programName,
        @client_net_address,
        @ExecutionContext,
        @ExecutionSqContext,
        @ExecutionPipelineContext
    );
END;
