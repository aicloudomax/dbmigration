create procedure sp_survey_assessment_rpt
as
begin
Select distinct
[QuestionShortText],[QuestionShortAbbrev]
---,r.ResponseText,[ResponceDescriptionToAchiveThisShort],r.ResponceDescriptionToAchiveThisLarge,[ResponseSort],[ResponseIsTopBoxChoice],[ResponseIsBottomBoxChoice],[ResponseIsAverageChoice],[ResponseWeightage]
from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =43  and QuestionSort=1
union all 
Select distinct 
q.QuestionText,[QuestionGroupText]
---,r.ResponseText,[ResponceDescriptionToAchiveThisShort],r.ResponceDescriptionToAchiveThisLarge,[ResponseSort],[ResponseIsTopBoxChoice],[ResponseIsBottomBoxChoice],[ResponseIsAverageChoice],[ResponseWeightage]
from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =43  and QuestionSort=1

declare @SurveyID as int
set @SurveyID=43


Select distinct 
'Response' as Response,Cast(ResponseSort as varchar(10)) as ResponseSort
,r.ResponseText
,Case when [ResponseIsTopBoxChoice]=1 then 'Yes' else 'No' End    [ResponseIsTopBoxChoice]
,Case when [ResponseIsBottomBoxChoice]=1 THEN 'Yes' else 'No' end [ResponseIsBottomBoxChoice]
,Case when [ResponseIsAverageChoice]  =1 THEN 'Yes' else 'No' end [ResponseIsAverageChoice]
,CAST( [ResponseWeightage] AS varchar(10)) AS [ResponseWeightage]
from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=1 and QuestionSort=1
union all 

select 
'','',
'Response Achiver'
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]
union all 
Select 
'','',[ResponceDescriptionToAchiveThisShort]
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,''AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=1 and QuestionSort=1
union all 
Select 
'','',ResponceDescriptionToAchiveThisLarge
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=1 and QuestionSort=1

union all 
Select distinct 
'Response' as Response,Cast(ResponseSort as varchar(10)) as ResponseSort
,r.ResponseText
,Case when [ResponseIsTopBoxChoice]=1 then 'Yes' else 'No' End    [ResponseIsTopBoxChoice]
,Case when [ResponseIsBottomBoxChoice]=1 THEN 'Yes' else 'No' end [ResponseIsBottomBoxChoice]
,Case when [ResponseIsAverageChoice]  =1 THEN 'Yes' else 'No' end [ResponseIsAverageChoice]
,CAST( [ResponseWeightage] AS varchar(10)) AS [ResponseWeightage]
from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=2 and QuestionSort=1
union all 

select 
'','',
'Response Achiver'
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]
union all 
Select 
'','',[ResponceDescriptionToAchiveThisShort]
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,''AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=2 and QuestionSort=1
union all 
Select 
'','',ResponceDescriptionToAchiveThisLarge
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=2 and QuestionSort=1
union all 

Select distinct 
'Response' as Response,Cast(ResponseSort as varchar(10)) as ResponseSort
,r.ResponseText
,Case when [ResponseIsTopBoxChoice]=1 then 'Yes' else 'No' End    [ResponseIsTopBoxChoice]
,Case when [ResponseIsBottomBoxChoice]=1 THEN 'Yes' else 'No' end [ResponseIsBottomBoxChoice]
,Case when [ResponseIsAverageChoice]  =1 THEN 'Yes' else 'No' end [ResponseIsAverageChoice]
,CAST( [ResponseWeightage] AS varchar(10)) AS [ResponseWeightage]
from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=3 and QuestionSort=1
union all 

select 
'','',
'Response Achiver'
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]
union all 
Select 
'','',[ResponceDescriptionToAchiveThisShort]
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,''AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=3 and QuestionSort=1
union all 
Select 
'','',ResponceDescriptionToAchiveThisLarge
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=3 and QuestionSort=1
union all 

Select distinct 
'Response' as Response,Cast(ResponseSort as varchar(10)) as ResponseSort
,r.ResponseText
,Case when [ResponseIsTopBoxChoice]=1 then 'Yes' else 'No' End    [ResponseIsTopBoxChoice]
,Case when [ResponseIsBottomBoxChoice]=1 THEN 'Yes' else 'No' end [ResponseIsBottomBoxChoice]
,Case when [ResponseIsAverageChoice]  =1 THEN 'Yes' else 'No' end [ResponseIsAverageChoice]
,CAST( [ResponseWeightage] AS varchar(10)) AS [ResponseWeightage]
from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=4 and QuestionSort=1
union all 

select 
'','',
'Response Achiver'
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]
union all 
Select 
'','',[ResponceDescriptionToAchiveThisShort]
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,''AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=4 and QuestionSort=1
union all 
Select 
'','',ResponceDescriptionToAchiveThisLarge
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=4 and QuestionSort=1
union all 

Select distinct 
'Response' as Response,Cast(ResponseSort as varchar(10)) as ResponseSort
,r.ResponseText
,Case when [ResponseIsTopBoxChoice]=1 then 'Yes' else 'No' End    [ResponseIsTopBoxChoice]
,Case when [ResponseIsBottomBoxChoice]=1 THEN 'Yes' else 'No' end [ResponseIsBottomBoxChoice]
,Case when [ResponseIsAverageChoice]  =1 THEN 'Yes' else 'No' end [ResponseIsAverageChoice]
,CAST( [ResponseWeightage] AS varchar(10)) AS [ResponseWeightage]
from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=5 and QuestionSort=1
union all 

select 
'','',
'Response Achiver'
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]
union all 
Select 
'','',[ResponceDescriptionToAchiveThisShort]
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,''AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=5 and QuestionSort=1
union all 
Select 
'','',ResponceDescriptionToAchiveThisLarge
,'' AS [ResponseIsTopBoxChoice]
,'' AS [ResponseIsBottomBoxChoice]
,'' AS [ResponseIsAverageChoice]
,'' AS [ResponseWeightage]from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
where SurveyID =@SurveyID  and r.responsesort=5 and QuestionSort=1
end