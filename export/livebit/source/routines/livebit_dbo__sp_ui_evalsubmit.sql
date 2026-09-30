CREATE PROCEDURE [dbo].[sp_ui_evalsubmit]
    @SurveyID INT,
    @QuestionID INT,
    @ResponseID INT,
    @UserID INT,
    @QuestionStartDisplayDataTime DATETIME,
    @QuestionResponceSubmitedDateTime DATETIME
AS
BEGIN
    SET NOCOUNT ON;

	-- Check if record exists and FirstTimeRespoceOpenFor30DayResponceWindow is more than 30 days old
    IF EXISTS (SELECT top 1 1 FROM [LiveBit].[dbo].[FactEval]
               WHERE SurveyID = @SurveyID 
               AND QuestionID = @QuestionID 
               AND UserID = @UserID)
    BEGIN
        -- Update existing record
        UPDATE [LiveBit].[dbo].[FactEval]
        SET ResponseID = @ResponseID,
            QuestionStartDisplayDataTime = @QuestionStartDisplayDataTime,
            QuestionResponceSubmitedDateTime = @QuestionResponceSubmitedDateTime,
			RecordResponceType = 'Update',
			BackendRecordDataTime=getdate()
        WHERE SurveyID = @SurveyID 
        AND QuestionID = @QuestionID 
        AND UserID = @UserID;
    END
    ELSE
    BEGIN
        -- Insert new record
        INSERT INTO [LiveBit].[dbo].[FactEval] 
            (SurveyID, QuestionID, ResponseID, UserID, 
             QuestionStartDisplayDataTime, QuestionResponceSubmitedDateTime,
             RecordResponceType,BackendRecordDataTime)
        VALUES 
            (@SurveyID, @QuestionID, @ResponseID, @UserID, 
             @QuestionStartDisplayDataTime, @QuestionResponceSubmitedDateTime, 
             'Insert', GETDATE());
    END
END


