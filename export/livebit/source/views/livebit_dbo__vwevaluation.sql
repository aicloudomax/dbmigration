CREATE view  [dbo].[vwEvaluation]
as
SELECT [EvalID]
,Cast([SurveyID] as varchar(99))+'-'+Cast([QuestionID] as varchar(99))+'-'+Cast([ResponseID] as varchar(99)) as 'AssessmentID'
      ,[SurveyID]
      ,[QuestionID]
      ,[ResponseID]
      ,[UserID]
      ,[QuestionStartDisplayDataTime]
      ,[QuestionResponceSubmitedDateTime]
      ,[RecordResponceType]
      ,[BackendRecordDataTime]
      ,[TrackerID]
  FROM [dbo].[FactEval]
  