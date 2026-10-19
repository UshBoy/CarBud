/* ============================================================
   CarBud Prototype 1 - Scoring (the recommendation brain)
   Run this AFTER CarBud_Setup.sql, in the CarBud database.
   It is safe to run again: it refreshes the purpose data and
   replaces the stored procedure.
   NOTE: If you ever re-run CarBud_Setup.sql, run this file again too,
   because that script rebuilds the whole database.
   ============================================================ */

USE CarBud;
GO

/* ---------- 1. HOW WELL EACH CAR TYPE SUITS EACH TRIP PURPOSE ----------
   Points are 0 to 100. These are starting values for you to tune.
   Purpose values come from question 5:
   1 Business, 2 Family trip, 3 Holiday, 4 Moving or carrying things, 5 Just a drive for fun */

DELETE FROM tblPurposeFit;

INSERT INTO tblPurposeFit (OptionID, CarType, Points)
SELECT o.OptionID, v.CarType, v.Points
FROM tblQuestionOption o
INNER JOIN tblQuestion q ON q.QuestionID = o.QuestionID AND q.DisplayOrder = 5
INNER JOIN (VALUES
    (1, N'Premium', 100), (1, N'SUV', 70),  (1, N'Estate', 70),  (1, N'Hatchback', 50),
    (1, N'City', 30),     (1, N'Family', 30), (1, N'Minibus', 20), (1, N'Van', 10),

    (2, N'Family', 100),  (2, N'SUV', 90),  (2, N'Estate', 90),  (2, N'Minibus', 70),
    (2, N'Hatchback', 60), (2, N'Premium', 50), (2, N'City', 30), (2, N'Van', 10),

    (3, N'Estate', 100),  (3, N'SUV', 90),  (3, N'Family', 90),  (3, N'Premium', 70),
    (3, N'Hatchback', 60), (3, N'Minibus', 60), (3, N'City', 40), (3, N'Van', 10),

    (4, N'Van', 100),     (4, N'Minibus', 60), (4, N'Estate', 50), (4, N'Family', 40),
    (4, N'SUV', 30),      (4, N'Hatchback', 20), (4, N'Premium', 10), (4, N'City', 0),

    (5, N'Premium', 100), (5, N'City', 80), (5, N'SUV', 70),     (5, N'Hatchback', 70),
    (5, N'Estate', 50),   (5, N'Family', 30), (5, N'Minibus', 20), (5, N'Van', 0)
) AS v (PurposeValue, CarType, Points) ON v.PurposeValue = o.OptionValue;
GO

/* ---------- 2. THE SCORING PROCEDURE ----------
   You give it the number from each answer (the OptionValue the user clicked):
     @Passengers : 2, 4, 5 or 6        (question 1)
     @Distance   : 1, 2 or 3           (question 2)
     @Luggage    : 1, 2, 3 or 4        (question 3)
     @MaxBudget  : 400, 700, 1000 or 9999 (question 4)
     @Purpose    : 1 to 5              (question 5)
     @TopN       : how many cars to return (default 3)

   How it works, in plain English:
   - A car must have enough seats, and it must be available. Otherwise it is left out.
   - Every remaining car gets a "fit" from 0 to 100 for five things:
     seats, luggage space, budget, comfort for the trip distance, and trip purpose.
   - The five fits are combined using the weights in tblScoringWeight.
     Change a weight in that table and the recommendations change, with no code changes.
   - Cars within budget always come first. Then the highest score wins.
     If scores tie, the cheaper car wins. */

CREATE OR ALTER PROCEDURE usp_RecommendCars
    @Passengers INT,
    @Distance   INT,
    @Luggage    INT,
    @MaxBudget  INT,
    @Purpose    INT,
    @TopN       INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    IF @TopN IS NULL OR @TopN < 1 SET @TopN = 3;

    -- The weights (how much each factor counts)
    DECLARE @wSeats    INT = ISNULL((SELECT Weight FROM tblScoringWeight WHERE Factor = N'Seats'),    0);
    DECLARE @wLuggage  INT = ISNULL((SELECT Weight FROM tblScoringWeight WHERE Factor = N'Luggage'),  0);
    DECLARE @wBudget   INT = ISNULL((SELECT Weight FROM tblScoringWeight WHERE Factor = N'Budget'),   0);
    DECLARE @wDistance INT = ISNULL((SELECT Weight FROM tblScoringWeight WHERE Factor = N'Distance'), 0);
    DECLARE @wPurpose  INT = ISNULL((SELECT Weight FROM tblScoringWeight WHERE Factor = N'Purpose'),  0);
    DECLARE @wTotal    INT = @wSeats + @wLuggage + @wBudget + @wDistance + @wPurpose;
    IF @wTotal = 0 SET @wTotal = 1;

    -- Turn the luggage answer into the boot space (in litres) the trip needs
    DECLARE @NeededBoot INT = CASE @Luggage WHEN 1 THEN 100 WHEN 2 THEN 250 WHEN 3 THEN 400 WHEN 4 THEN 1000 ELSE 250 END;

    -- Turn the distance answer into the comfort level (1 to 5) the trip needs
    DECLARE @NeededComfort INT = CASE @Distance WHEN 1 THEN 1 WHEN 2 THEN 3 WHEN 3 THEN 4 ELSE 3 END;

    -- Find which answer option the user picked for the purpose question (question 5)
    DECLARE @PurposeOptionID INT =
        (SELECT TOP 1 o.OptionID
         FROM tblQuestionOption o
         INNER JOIN tblQuestion q ON q.QuestionID = o.QuestionID
         WHERE q.DisplayOrder = 5 AND o.OptionValue = @Purpose AND o.IsActive = 1);

    ;WITH Fit AS (
        SELECT
            c.CarID, c.Make, c.Model, c.CarType, c.Seats, c.BootLitres,
            c.PricePerDay, c.FuelType, c.ComfortRating,

            -- Seats: an exact fit (or one spare seat) is best. Each extra spare seat costs 20 points.
            CASE WHEN c.Seats - @Passengers <= 1 THEN 100.0
                 WHEN 100 - 20 * (c.Seats - @Passengers - 1) < 0 THEN 0.0
                 ELSE 100 - 20 * (c.Seats - @Passengers - 1) END AS SeatFit,

            -- Luggage: enough boot space = 100. Too small loses points quickly.
            CASE WHEN c.BootLitres >= @NeededBoot THEN 100.0
                 WHEN 100 - 200.0 * (@NeededBoot - c.BootLitres) / @NeededBoot < 0 THEN 0.0
                 ELSE 100 - 200.0 * (@NeededBoot - c.BootLitres) / @NeededBoot END AS LuggageFit,

            -- Budget: within budget = 100, over budget = 0
            CASE WHEN c.PricePerDay <= @MaxBudget THEN 100.0 ELSE 0.0 END AS BudgetFit,

            -- Distance: comfortable enough for the trip = 100. Each missing comfort step costs 40 points.
            CASE WHEN c.ComfortRating >= @NeededComfort THEN 100.0
                 WHEN 100 - 40 * (@NeededComfort - c.ComfortRating) < 0 THEN 0.0
                 ELSE 100 - 40 * (@NeededComfort - c.ComfortRating) END AS DistanceFit,

            -- Purpose: taken from the table above (0 if the car type is not listed)
            CAST(ISNULL(pf.Points, 0) AS DECIMAL(5,1)) AS PurposeFit,

            CASE WHEN c.PricePerDay <= @MaxBudget THEN 1 ELSE 0 END AS WithinBudget
        FROM tblCar c
        LEFT JOIN tblPurposeFit pf
               ON pf.CarType = c.CarType AND pf.OptionID = @PurposeOptionID
        WHERE c.IsAvailable = 1
          AND c.Seats >= @Passengers
    ),
    Scored AS (
        SELECT Fit.*,
               CAST(ROUND((SeatFit * @wSeats + LuggageFit * @wLuggage + BudgetFit * @wBudget
                         + DistanceFit * @wDistance + PurposeFit * @wPurpose) / (@wTotal * 1.0), 0) AS INT) AS Score
        FROM Fit
    ),
    Ranked AS (
        SELECT Scored.*,
               ROW_NUMBER() OVER (ORDER BY WithinBudget DESC, Score DESC, PricePerDay ASC, CarID ASC) AS RankPosition
        FROM Scored
    )
    SELECT TOP (@TopN)
        RankPosition, CarID, Make, Model, CarType, Seats, BootLitres, PricePerDay, FuelType, ComfortRating,
        WithinBudget, Score,
        CAST(ROUND(SeatFit, 0)     AS INT) AS SeatFit,
        CAST(ROUND(LuggageFit, 0)  AS INT) AS LuggageFit,
        CAST(ROUND(BudgetFit, 0)   AS INT) AS BudgetFit,
        CAST(ROUND(DistanceFit, 0) AS INT) AS DistanceFit,
        CAST(ROUND(PurposeFit, 0)  AS INT) AS PurposeFit
    FROM Ranked
    ORDER BY RankPosition;
END
GO

/* ---------- 3. TEST IT: select ONE line at a time and press F5 ---------- */

-- Quick check: you should see 40 rows
SELECT COUNT(*) AS PurposeFitRows FROM tblPurposeFit;

-- Test A: family of 5, long trip, lots of luggage, budget up to 1000 kr, holiday
-- Expect three 5-seat estate cars near the top (Corolla Touring Sports, Octavia Combi, Passat Variant)
EXEC usp_RecommendCars @Passengers = 5, @Distance = 3, @Luggage = 3, @MaxBudget = 1000, @Purpose = 3;

-- Test B: 2 people, around town, almost no luggage, budget up to 400 kr, just a drive for fun
-- Expect small city cars (Up!, Aygo X, 500e)
EXEC usp_RecommendCars @Passengers = 2, @Distance = 1, @Luggage = 1, @MaxBudget = 400, @Purpose = 5;

-- Test C: 6 or more people, day trip, large items, budget up to 1000 kr, moving things
-- No car has the boot space, so you should see the best available 7-9 seaters, with low luggage scores
EXEC usp_RecommendCars @Passengers = 6, @Distance = 2, @Luggage = 4, @MaxBudget = 1000, @Purpose = 4;

-- Test D: business, 2 people, long trip, one or two bags, no budget limit
-- Expect Tesla Model 3 and BMW 3 Series first (score 88), then Corolla Touring Sports (score 85)
EXEC usp_RecommendCars @Passengers = 2, @Distance = 3, @Luggage = 2, @MaxBudget = 9999, @Purpose = 1;
GO
