CREATE PROCEDURE [divaconfig].[sp_GetStoredProcedureLog]
    @ProcedureTabID INT,
    @ProcedureID INT
AS


    SELECT   
        [ProcedureExecutionStatus] AS 'Status',
        [ProcedureExecutionStart] AS 'StartedAt',
        [ProcedureExecutionEnd] AS 'EndedAt',
        [ProcedureErrorMessage] AS 'ErrorMessage'
    FROM [divaconfig].[StoredProcedureExecutionLog] l
    LEFT JOIN [divaconfig].[StoredProcedures] p
        ON l.[ProcedureID] = p.[ProcedureID]
    WHERE l.[ProcedureTabID] = @ProcedureTabID
      AND l.[ProcedureID] = @ProcedureID
    ORDER BY ProcedureExecutionEnd DESC;

--SELECT   
--	  [ProcedureExecutionStatus] As 'Status'
--      ,[ProcedureExecutionStart] As 'StartedAt'
--      ,[ProcedureExecutionEnd] As 'EndedAt'
--,[ProcedureErrorMessage] As 'ErrorMessage'
--  FROM [divaconfig].[StoredProcedureExecutionLog] l
--  left join [divaconfig].[StoredProcedures] p
--  on l.[ProcedureID]=p.[ProcedureID]
--  Where ProcedureTabID=1--Subtab ID
--  and l.[ProcedureID]=18--Procedure ID
--   order by ProcedureExecutionEnd desc

