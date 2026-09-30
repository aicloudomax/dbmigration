
Create FUNCTION ResponseIsAverageChoice
(
    @SurveyID int
)
RETURNS varchar(1000) -- or whatever length you need
AS
BEGIN
    Declare @ResponseIsTopBoxChoice varchar(50), @ResponseIsBottomBoxChoice varchar(50), @ResponseIsAverageChoice varchar(50), @ResponseWeightage varchar(50)

    SELECT @ResponseIsTopBoxChoice = Case when [ResponseIsTopBoxChoice]=1 then 'Yes' else 'No' End 
	,@ResponseIsBottomBoxChoice=Case when [ResponseIsBottomBoxChoice]=1 THEN 'Yes' else 'No' end 
    ,@ResponseIsAverageChoice=Case when [ResponseIsAverageChoice]  =1 THEN 'Yes' else 'No' end 
    ,@ResponseWeightage=CAST( [ResponseWeightage] AS varchar(10)) 
	
	from [dbo].[Survey] s 
Inner join [dbo].[Question] q on q.QuestionSurveyID = s.SurveyID
inner join [dbo].[Response] r on r.[ResponseQuestionID]=q.QuestionID
    where SurveyID = @SurveyID

    RETURN   @ResponseIsAverageChoice --,@ResponseIsBottomBoxChoice , @ResponseIsAverageChoice , @ResponseWeightage 

END
