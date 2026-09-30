
CREATE PROCEDURE Test( @SurveyID int) as 


begin

select dbo.ResponseIsTopBoxChoice(@SurveyID) as ResponseIsTopBoxChoice ,dbo.ResponseIsBottomBoxChoice(@SurveyID) as  ResponseIsBottomBoxChoice,dbo.ResponseIsAverageChoice(@SurveyID) as  ResponseIsAverageChoice,
dbo.ResponseWeightage(@SurveyID) as  ResponseWeightage
--,Case when [ResponseIsTopBoxChoice]=1 then 'Yes' else 'No' End    [ResponseIsTopBoxChoice]
--,Case when [ResponseIsBottomBoxChoice]=1 THEN 'Yes' else 'No' end [ResponseIsBottomBoxChoice]
--,Case when [ResponseIsAverageChoice]  =1 THEN 'Yes' else 'No' end [ResponseIsAverageChoice]
--,CAST( [ResponseWeightage] AS varchar(10)) AS [ResponseWeightage]
end 