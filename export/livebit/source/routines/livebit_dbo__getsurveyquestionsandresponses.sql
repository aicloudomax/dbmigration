CREATE PROCEDURE GetSurveyQuestionsAndResponses
    @SurveyID INT
AS
BEGIN
    DECLARE @Result TABLE (
        Question NVARCHAR(MAX),
        GroupText NVARCHAR(MAX),
        Response NVARCHAR(MAX),
        Sort INT,
        ShortDescription NVARCHAR(MAX),
        LargeDescription NVARCHAR(MAX),
        IsTopBoxChoice BIT,
        IsBottomBoxChoice BIT,
        IsAverageChoice BIT,
        Weightage INT
    );

    DECLARE @QuestionID AS INT;
    DECLARE @QuestionText AS NVARCHAR(MAX);
    DECLARE @QuestionGroupText AS NVARCHAR(MAX);
    DECLARE @ResponseText AS NVARCHAR(MAX);
    DECLARE @ResponceDescriptionToAchiveThisShort AS NVARCHAR(MAX);
    DECLARE @ResponceDescriptionToAchiveThisLarge AS NVARCHAR(MAX);
    DECLARE @ResponseSort AS INT;
    DECLARE @ResponseIsTopBoxChoice AS BIT;
    DECLARE @ResponseIsBottomBoxChoice AS BIT;
    DECLARE @ResponseIsAverageChoice AS BIT;
    DECLARE @ResponseWeightage AS INT;

    DECLARE question_cursor CURSOR FOR
    SELECT q.QuestionID, q.QuestionText, q.QuestionGroupText
    FROM [dbo].[Survey] s
    INNER JOIN [dbo].[Question] q ON q.QuestionSurveyID = s.SurveyID
    WHERE s.SurveyID = @SurveyID
    ORDER BY q.QuestionSort;

    OPEN question_cursor;
    FETCH NEXT FROM question_cursor INTO @QuestionID, @QuestionText, @QuestionGroupText;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE response_cursor CURSOR FOR
        SELECT 
            r.ResponseText,
            r.ResponceDescriptionToAchiveThisShort,
            r.ResponceDescriptionToAchiveThisLarge,
            r.ResponseSort,
            r.ResponseIsTopBoxChoice,
            r.ResponseIsBottomBoxChoice,
            r.ResponseIsAverageChoice,
            r.ResponseWeightage
        FROM [dbo].[Response] r
        WHERE r.ResponseQuestionID = @QuestionID
        ORDER BY r.ResponseSort;

        OPEN response_cursor;
        FETCH NEXT FROM response_cursor INTO @ResponseText, @ResponceDescriptionToAchiveThisShort, @ResponceDescriptionToAchiveThisLarge,
                                             @ResponseSort, @ResponseIsTopBoxChoice, @ResponseIsBottomBoxChoice, @ResponseIsAverageChoice,
                                             @ResponseWeightage;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO @Result (Question, GroupText, Response, Sort, ShortDescription, LargeDescription,
                                 IsTopBoxChoice, IsBottomBoxChoice, IsAverageChoice, Weightage)
            VALUES (@QuestionText, @QuestionGroupText, @ResponseText, @ResponseSort, @ResponceDescriptionToAchiveThisShort,
                    @ResponceDescriptionToAchiveThisLarge, @ResponseIsTopBoxChoice, @ResponseIsBottomBoxChoice,
                    @ResponseIsAverageChoice, @ResponseWeightage);

            FETCH NEXT FROM response_cursor INTO @ResponseText, @ResponceDescriptionToAchiveThisShort, @ResponceDescriptionToAchiveThisLarge,
                                                 @ResponseSort, @ResponseIsTopBoxChoice, @ResponseIsBottomBoxChoice,
                                                 @ResponseIsAverageChoice, @ResponseWeightage;
        END

        CLOSE response_cursor;
        DEALLOCATE response_cursor;

        FETCH NEXT FROM question_cursor INTO @QuestionID, @QuestionText, @QuestionGroupText;
    END

    CLOSE question_cursor;
    DEALLOCATE question_cursor;

    SELECT * FROM @Result;
END
