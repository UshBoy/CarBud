/* ============================================================
   CarBud - Chatbot database procedures
   Run this AFTER CarBud_Setup.sql, CarBud_Scoring.sql and CarBud_Portal.sql.
   Press F5 once with nothing highlighted. It is safe to run again.
   NOTE: If you ever re-run CarBud_Setup.sql, run the other three files again too.
   ============================================================ */

USE CarBud;
GO

-- All active questions with their clickable choices, in order (for the chat page)
CREATE OR ALTER PROCEDURE usp_GetChatQuestions
AS
BEGIN
    SET NOCOUNT ON;
    SELECT q.QuestionID, q.QuestionText, q.DisplayOrder AS QuestionOrder,
           o.OptionID, o.OptionText, o.OptionValue, o.DisplayOrder AS OptionOrder
    FROM tblQuestion q
    INNER JOIN tblQuestionOption o ON o.QuestionID = q.QuestionID
    WHERE q.IsActive = 1 AND o.IsActive = 1
    ORDER BY q.DisplayOrder, o.DisplayOrder;
END
GO

-- Starts a new chat and returns its SessionID
CREATE OR ALTER PROCEDURE usp_CreateChatSession
    @UserNotes NVARCHAR(500) = NULL,
    @SessionID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO tblSession (UserNotes) VALUES (NULLIF(LTRIM(RTRIM(@UserNotes)), N''));
    SET @SessionID = CAST(SCOPE_IDENTITY() AS INT);
END
GO

-- Saves one answer the customer clicked
CREATE OR ALTER PROCEDURE usp_SaveSessionAnswer
    @SessionID INT,
    @QuestionID INT,
    @OptionID INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO tblSessionAnswer (SessionID, QuestionID, OptionID)
    VALUES (@SessionID, @QuestionID, @OptionID);
END
GO

-- Saves one recommended car with its score and explanation
CREATE OR ALTER PROCEDURE usp_SaveRecommendation
    @SessionID INT,
    @CarID INT,
    @RankPosition INT,
    @Score INT,
    @Explanation NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO tblRecommendation (SessionID, CarID, RankPosition, Score, Explanation)
    VALUES (@SessionID, @CarID, @RankPosition, @Score, @Explanation);
END
GO

-- Records which model answered ('fallback' if the AI was not used) and how long it took
CREATE OR ALTER PROCEDURE usp_FinishChatSession
    @SessionID INT,
    @ModelUsed NVARCHAR(50),
    @ResponseMs INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE tblSession
    SET ModelUsed = @ModelUsed, ResponseMs = @ResponseMs
    WHERE SessionID = @SessionID;
END
GO

-- Numbers for your thesis: how the chatbot is being used
CREATE OR ALTER PROCEDURE usp_GetChatStats
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM tblSession) AS ChatSessions,
        (SELECT COUNT(*) FROM tblSession WHERE ModelUsed IS NOT NULL AND ModelUsed <> N'fallback') AS AnsweredByAI,
        (SELECT COUNT(*) FROM tblSession WHERE ModelUsed = N'fallback') AS AnsweredByFallback,
        (SELECT CAST(ROUND(AVG(CAST(ResponseMs AS FLOAT)) / 1000.0, 1) AS DECIMAL(6,1))
           FROM tblSession WHERE ModelUsed IS NOT NULL AND ModelUsed <> N'fallback') AS AvgAISeconds,
        (SELECT COUNT(*) FROM tblBooking WHERE SessionID IS NOT NULL AND BookingStatus = N'Confirmed') AS BookingsFromChat,
        (SELECT COUNT(*) FROM tblBooking WHERE BookingStatus = N'Confirmed') AS AllConfirmedBookings;
END
GO

/* ---------- Quick checks ---------- */
EXEC usp_GetChatQuestions;   -- expect 20 rows (5 questions x their choices)
EXEC usp_GetChatStats;       -- expect 1 row
GO
