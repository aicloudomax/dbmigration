CREATE view  [dbo].[vwAssessment]
as
Select distinct  
--ID to Match with Evaluation
Cast(s.[SurveyID] as varchar(99))+'-'+Cast(q.[QuestionID] as varchar(99))+'-'+Cast(r.[ResponseID] as varchar(99)) as 'AssessmentID'
--Assessment Group Details
,sg.[SurveyProductID], sg.[SurveyProductCategory], sg.[SurveyProductName], sg.[SurveyProductDesc], sg.[SurveyProductSort], sg.[SurveyProductIsOpen]
,sg.[SurveyProductCategory]+'-'+SurveyProductName as SurveyProductCategoryNName
,sg.[SurveyProductCategory]+'-'+SurveyProductName +'-'+[SurveyProductDesc] SurveyProductCategoryNDesc
--Assessment details 
,s.[SurveyID], s.[SurveyCategory], s.[SurveyName], s.[SurveyDesc], s.[SurveyLastUpdated], s.[SurveyStartDate], s.[SurveyEndDate],  s.[SurveyNextResetRunningWindowInDays], s.[SurveyIsLockedForSeason], s.[SurveyGroup1], s.[SurveyGroup2], s.[SurveyGroup3], s.[SurveyGenratedByAI], s.[SurveyAIVerifiedByHuman], s.[SurveyApprovedByUserID], s.[SurveyRequestByUserID]
,s.[SurveyCategory]+'-'+s.[SurveyName] as SurveyCategoryNName
,s.[SurveyCategory]+'-'+s.[SurveyName]+'-'+s.[SurveyDesc] as SurveyCategoryNNameNDesc
--Assessment Question
,q.[QuestionID], [QuestionText], [QuestionShortText], [QuestionGroupText], [QuestionShortAbbrev],
q.[QuestionSort], [QuestionIsMultiMark], [QuestionIsScale], [QuestionIsTopBox], [QuestionIsSkipQuestion],
[QuestionSkipToQuestionID], [QuestionGroup1Text], [QuestionGroup2Text], [QuestionGroup3Text], [QuestionGroup4Text],
[QuestionGroup5Text], [QuestionChoiceAIGenrated], [QuestionScale]
,[QuestionShortAbbrev]+ISNULL('('+[QuestionShortText]+')','') as [QuestionShortAbbrevText]
--Assessment Response
,r.[ResponseID], r.[ResponseText], r.[ResponseWeightage], r.[ResponseSort], r.[ResponseIsDefaultChoice], r.[ResponseIsCompulsoryChoice],
r.[ResponseIsTopBoxChoice], r.[ResponseIsBottomBoxChoice], r.[ResponseIsAverageChoice], r.[ResponseIsSkipChoice],
r.[ResponseGroup1], r.[ResponseGroup2], r.[ResponseGroup3], r.[ResponseGroup4], r.[ResponseGroup5], r.[ResponceDescriptionToAchiveThisLarge],
r.[ResponceDescriptionToAchiveThisShort], r.[ResponceAverageDaysToAchive]
,Cast([ResponseSort] as Varchar(20))+'-'+[ResponseText] As ResponseTextWithSort
,Cast([ResponseSort] as Varchar(20))+'-'+[ResponseText]
+ Case When ResponseIsTopBoxChoice= 1 then ' | Top' Else '' End 
+ Case When ResponseIsBottomBoxChoice= 1 then ' | Bottom' Else '' End 
+ Case When ResponseIsAverageChoice= 1 then ' | Avg' Else '' End 
As ResponseTextWithSortWithAllBox
from [dbo].[Survey] s 
left join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
left join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
left join [dbo].[SurveyGroup] sg on sg.SurveyProductID = s.[SurveyProductID]
Where q.[QuestionID] is not null or r.[ResponseID] is not null
--order by q.QuestionID,ResponseSort
