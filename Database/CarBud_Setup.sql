/* ============================================================
   CarBud Prototype 1 - Database setup script
   It creates the database, the tables, the sample data and
   the first stored procedure. It rebuilds CarBud from scratch
   each time it runs (see the warning below).
   NOTE: The car figures are rounded SAMPLE values for the demo.
   They are not official specifications.
   ============================================================ */

USE master;
GO

-- WARNING: this script DELETES any existing CarBud database and builds it again from scratch.
-- That makes it safe to re-run while setting up, but it wipes saved data.
-- Do not run it again once you have real sessions you want to keep.
IF DB_ID('CarBud') IS NOT NULL
BEGIN
    ALTER DATABASE CarBud SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CarBud;
END
GO

CREATE DATABASE CarBud;
GO

USE CarBud;
GO

/* ---------- TABLES ---------- */

-- The cars the bot can recommend. IsAvailable = 0 means "hidden" (soft delete, like DriveNow).
CREATE TABLE tblCar (
    CarID         INT IDENTITY(1,1) PRIMARY KEY,
    Make          NVARCHAR(50) NOT NULL,
    Model         NVARCHAR(50) NOT NULL,
    CarType       NVARCHAR(30) NOT NULL,
    Seats         INT NOT NULL,
    BootLitres    INT NOT NULL,
    PricePerDay   INT NOT NULL,          -- in DKK
    FuelType      NVARCHAR(20) NOT NULL,
    ComfortRating INT NOT NULL,          -- 1 (basic) to 5 (very comfortable)
    IsAvailable   BIT NOT NULL DEFAULT 1
);

-- The questions the bot asks. Stored in the database so you can add more later.
CREATE TABLE tblQuestion (
    QuestionID   INT IDENTITY(1,1) PRIMARY KEY,
    QuestionText NVARCHAR(200) NOT NULL,
    DisplayOrder INT NOT NULL,
    IsActive     BIT NOT NULL DEFAULT 1
);

-- The clickable choices for each question.
CREATE TABLE tblQuestionOption (
    OptionID     INT IDENTITY(1,1) PRIMARY KEY,
    QuestionID   INT NOT NULL REFERENCES tblQuestion(QuestionID),
    OptionText   NVARCHAR(100) NOT NULL,
    OptionValue  INT NOT NULL,           -- the number the scoring uses
    DisplayOrder INT NOT NULL,
    IsActive     BIT NOT NULL DEFAULT 1
);

-- How much each factor counts in the scoring. Change these to tune the bot.
CREATE TABLE tblScoringWeight (
    WeightID INT IDENTITY(1,1) PRIMARY KEY,
    Factor   NVARCHAR(30) NOT NULL UNIQUE,
    Weight   INT NOT NULL
);

-- Which car types suit which trip purpose (filled in later, when we write the scoring).
CREATE TABLE tblPurposeFit (
    PurposeFitID INT IDENTITY(1,1) PRIMARY KEY,
    OptionID     INT NOT NULL REFERENCES tblQuestionOption(OptionID),
    CarType      NVARCHAR(30) NOT NULL,
    Points       INT NOT NULL
);

-- One row per chat. This is your evidence for the thesis.
CREATE TABLE tblSession (
    SessionID  INT IDENTITY(1,1) PRIMARY KEY,
    StartedAt  DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    UserNotes  NVARCHAR(500) NULL,
    ModelUsed  NVARCHAR(50) NULL,
    ResponseMs INT NULL
);

-- The answer the user picked for each question in a chat.
CREATE TABLE tblSessionAnswer (
    AnswerID   INT IDENTITY(1,1) PRIMARY KEY,
    SessionID  INT NOT NULL REFERENCES tblSession(SessionID),
    QuestionID INT NOT NULL REFERENCES tblQuestion(QuestionID),
    OptionID   INT NOT NULL REFERENCES tblQuestionOption(OptionID)
);

-- The 3 cars recommended in a chat, with the explanation.
CREATE TABLE tblRecommendation (
    RecommendationID INT IDENTITY(1,1) PRIMARY KEY,
    SessionID        INT NOT NULL REFERENCES tblSession(SessionID),
    CarID            INT NOT NULL REFERENCES tblCar(CarID),
    RankPosition     INT NOT NULL,
    Score            INT NOT NULL,
    Explanation      NVARCHAR(MAX) NULL
);
GO

/* ---------- SAMPLE CARS (20) ---------- */

INSERT INTO tblCar (Make, Model, CarType, Seats, BootLitres, PricePerDay, FuelType, ComfortRating) VALUES
(N'Volkswagen', N'Up!',                 N'City',      4,  251,  300, N'Petrol',   2),
(N'Toyota',     N'Aygo X',              N'City',      4,  231,  320, N'Petrol',   2),
(N'Fiat',       N'500e',                N'City',      4,  185,  350, N'Electric', 2),
(N'Peugeot',    N'208',                 N'Hatchback', 5,  311,  400, N'Petrol',   3),
(N'Volkswagen', N'Polo',                N'Hatchback', 5,  351,  420, N'Petrol',   3),
(N'Toyota',     N'Yaris Hybrid',        N'Hatchback', 5,  286,  450, N'Hybrid',   3),
(N'Volkswagen', N'Golf',                N'Hatchback', 5,  380,  520, N'Petrol',   4),
(N'Toyota',     N'Corolla Touring Sports', N'Estate', 5,  598,  600, N'Hybrid',   4),
(N'Skoda',      N'Octavia Combi',       N'Estate',    5,  640,  620, N'Diesel',   4),
(N'Volvo',      N'V60',                 N'Estate',    5,  529,  800, N'Hybrid',   5),
(N'Volkswagen', N'Passat Variant',      N'Estate',    5,  690,  780, N'Diesel',   5),
(N'Dacia',      N'Duster',              N'SUV',       5,  445,  500, N'Petrol',   3),
(N'Nissan',     N'Qashqai',             N'SUV',       5,  504,  650, N'Hybrid',   4),
(N'Hyundai',    N'Tucson',              N'SUV',       5,  539,  700, N'Hybrid',   4),
(N'Tesla',      N'Model 3',             N'Premium',   5,  561,  900, N'Electric', 5),
(N'BMW',        N'3 Series',            N'Premium',   5,  480, 1100, N'Petrol',   5),
(N'Skoda',      N'Kodiaq 7-seater',     N'Family',    7,  270,  850, N'Diesel',   4),
(N'Citroen',    N'Berlingo 7-seater',   N'Family',    7,  300,  650, N'Diesel',   3),
(N'Renault',    N'Trafic Minibus',      N'Minibus',   9,  400, 1000, N'Diesel',   3),
(N'Ford',       N'Transit Custom Van',  N'Van',       3, 6000,  750, N'Diesel',   2);
GO

/* ---------- THE 5 QUESTIONS AND THEIR CHOICES ---------- */

DECLARE @q INT;

-- Question 1: passengers (value = number of seats needed)
INSERT INTO tblQuestion (QuestionText, DisplayOrder) VALUES (N'How many people will be travelling?', 1);
SET @q = SCOPE_IDENTITY();
INSERT INTO tblQuestionOption (QuestionID, OptionText, OptionValue, DisplayOrder) VALUES
(@q, N'1 to 2 people',  2, 1),
(@q, N'3 to 4 people',  4, 2),
(@q, N'5 people',       5, 3),
(@q, N'6 or more',      6, 4);

-- Question 2: trip distance (1 = short, 2 = medium, 3 = long)
INSERT INTO tblQuestion (QuestionText, DisplayOrder) VALUES (N'How far is your trip in total?', 2);
SET @q = SCOPE_IDENTITY();
INSERT INTO tblQuestionOption (QuestionID, OptionText, OptionValue, DisplayOrder) VALUES
(@q, N'Around town (under 50 km)',      1, 1),
(@q, N'A day trip (50 to 200 km)',      2, 2),
(@q, N'A long trip (over 200 km)',      3, 3);

-- Question 3: luggage (1 = almost none ... 4 = large items)
INSERT INTO tblQuestion (QuestionText, DisplayOrder) VALUES (N'How much luggage will you bring?', 3);
SET @q = SCOPE_IDENTITY();
INSERT INTO tblQuestionOption (QuestionID, OptionText, OptionValue, DisplayOrder) VALUES
(@q, N'Almost nothing',                     1, 1),
(@q, N'One or two bags',                    2, 2),
(@q, N'A lot of luggage',                   3, 3),
(@q, N'Large items (moving or equipment)',  4, 4);

-- Question 4: budget per day (value = highest price per day in DKK)
INSERT INTO tblQuestion (QuestionText, DisplayOrder) VALUES (N'What is your budget per day?', 4);
SET @q = SCOPE_IDENTITY();
INSERT INTO tblQuestionOption (QuestionID, OptionText, OptionValue, DisplayOrder) VALUES
(@q, N'Up to 400 kr',   400, 1),
(@q, N'Up to 700 kr',   700, 2),
(@q, N'Up to 1000 kr', 1000, 3),
(@q, N'No limit',      9999, 4);

-- Question 5: purpose (1 = business, 2 = family, 3 = holiday, 4 = moving things, 5 = just for fun)
INSERT INTO tblQuestion (QuestionText, DisplayOrder) VALUES (N'What is the main purpose of the trip?', 5);
SET @q = SCOPE_IDENTITY();
INSERT INTO tblQuestionOption (QuestionID, OptionText, OptionValue, DisplayOrder) VALUES
(@q, N'Business',                  1, 1),
(@q, N'Family trip',               2, 2),
(@q, N'Holiday',                   3, 3),
(@q, N'Moving or carrying things', 4, 4),
(@q, N'Just a drive for fun',      5, 5);
GO

/* ---------- SCORING WEIGHTS (starting values, you will tune these) ---------- */

INSERT INTO tblScoringWeight (Factor, Weight) VALUES
(N'Seats',    30),
(N'Luggage',  25),
(N'Budget',   25),
(N'Distance', 10),
(N'Purpose',  10);
GO

/* ---------- FIRST STORED PROCEDURE ---------- */

CREATE PROCEDURE usp_GetAllCars
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CarID, Make, Model, CarType, Seats, BootLitres, PricePerDay, FuelType, ComfortRating
    FROM tblCar
    WHERE IsAvailable = 1
    ORDER BY Make, Model;
END
GO

/* ---------- QUICK CHECK: you should see 20 cars, 5 questions, 20 options, 5 weights ---------- */
SELECT COUNT(*) AS Cars        FROM tblCar;
SELECT COUNT(*) AS Questions   FROM tblQuestion;
SELECT COUNT(*) AS Options     FROM tblQuestionOption;
SELECT COUNT(*) AS Weights     FROM tblScoringWeight;
GO
