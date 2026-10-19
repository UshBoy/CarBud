/* ============================================================
   CarBud - Rental portal database (customers, logins, bookings)
   Run this AFTER CarBud_Setup.sql and CarBud_Scoring.sql.
   Press F5 ONCE with nothing highlighted. It:
     1. adds two tables (only if they don't exist yet, so data is kept)
     2. creates or updates the stored procedures
     3. runs quick checks and a self-test, then removes the test data
   It is safe to run again.
   NOTE: If you ever re-run CarBud_Setup.sql, run CarBud_Scoring.sql
   and this file again too.
   ============================================================ */

USE CarBud;
GO

/* ============================================================
   1. TABLES
   ============================================================ */

-- Customers and admins. Passwords are NEVER stored as text:
-- the website turns each password into a hash (with a random salt) before saving it.
IF OBJECT_ID(N'dbo.tblUser', N'U') IS NULL
BEGIN
    CREATE TABLE tblUser (
        UserID       INT IDENTITY(1,1) PRIMARY KEY,
        FullName     NVARCHAR(100) NOT NULL,
        Email        NVARCHAR(150) NOT NULL CONSTRAINT UQ_tblUser_Email UNIQUE,
        PasswordHash VARBINARY(32) NOT NULL,
        PasswordSalt VARBINARY(16) NOT NULL,
        IsAdmin      BIT NOT NULL CONSTRAINT DF_tblUser_IsAdmin  DEFAULT 0,
        IsActive     BIT NOT NULL CONSTRAINT DF_tblUser_IsActive DEFAULT 1,
        CreatedAt    DATETIME2 NOT NULL CONSTRAINT DF_tblUser_CreatedAt DEFAULT SYSDATETIME()
    );
END
GO

-- Bookings. A booking is never deleted: cancelling sets BookingStatus to 'Cancelled'.
-- SessionID links a booking to the chatbot conversation that led to it (empty if booked without the chatbot).
IF OBJECT_ID(N'dbo.tblBooking', N'U') IS NULL
BEGIN
    CREATE TABLE tblBooking (
        BookingID     INT IDENTITY(1,1) PRIMARY KEY,
        UserID        INT NOT NULL REFERENCES tblUser(UserID),
        CarID         INT NOT NULL REFERENCES tblCar(CarID),
        StartDate     DATE NOT NULL,     -- pick-up day
        EndDate       DATE NOT NULL,     -- return day
        TotalPrice    INT NOT NULL,      -- in DKK
        BookingStatus NVARCHAR(20) NOT NULL CONSTRAINT DF_tblBooking_Status DEFAULT N'Confirmed',
        SessionID     INT NULL REFERENCES tblSession(SessionID),
        CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_tblBooking_CreatedAt DEFAULT SYSDATETIME(),
        CONSTRAINT CK_tblBooking_Dates CHECK (EndDate > StartDate)
    );
END
GO

/* ============================================================
   2. STORED PROCEDURES
   ============================================================ */

-- Register a new customer.
-- @NewUserID returns the new UserID, or -1 if the email is already registered.
CREATE OR ALTER PROCEDURE usp_RegisterUser
    @FullName     NVARCHAR(100),
    @Email        NVARCHAR(150),
    @PasswordHash VARBINARY(32),
    @PasswordSalt VARBINARY(16),
    @NewUserID    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Email = LOWER(LTRIM(RTRIM(@Email)));

    IF EXISTS (SELECT 1 FROM tblUser WHERE Email = @Email)
    BEGIN
        SET @NewUserID = -1;
        RETURN;
    END

    INSERT INTO tblUser (FullName, Email, PasswordHash, PasswordSalt)
    VALUES (LTRIM(RTRIM(@FullName)), @Email, @PasswordHash, @PasswordSalt);

    SET @NewUserID = CAST(SCOPE_IDENTITY() AS INT);
END
GO

-- Fetch a user by email so the website can check the password.
-- (The password check itself happens in C#, by comparing hashes.)
CREATE OR ALTER PROCEDURE usp_GetUserForLogin
    @Email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserID, FullName, Email, PasswordHash, PasswordSalt, IsAdmin
    FROM tblUser
    WHERE Email = LOWER(LTRIM(RTRIM(@Email))) AND IsActive = 1;
END
GO

-- The list of car types, for the filter drop-down on the Cars page.
CREATE OR ALTER PROCEDURE usp_GetCarTypes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT CarType FROM tblCar WHERE IsAvailable = 1 ORDER BY CarType;
END
GO

-- Browse and filter cars. Leave a filter empty (NULL) to ignore it.
CREATE OR ALTER PROCEDURE usp_SearchCars
    @CarType  NVARCHAR(30) = NULL,
    @MaxPrice INT = NULL,
    @MinSeats INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CarID, Make, Model, CarType, Seats, BootLitres, PricePerDay, FuelType, ComfortRating
    FROM tblCar
    WHERE IsAvailable = 1
      AND (@CarType  IS NULL OR CarType = @CarType)
      AND (@MaxPrice IS NULL OR PricePerDay <= @MaxPrice)
      AND (@MinSeats IS NULL OR Seats >= @MinSeats)
    ORDER BY PricePerDay, Make, Model;
END
GO

-- One car, for the Car Details page.
CREATE OR ALTER PROCEDURE usp_GetCarByID
    @CarID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CarID, Make, Model, CarType, Seats, BootLitres, PricePerDay, FuelType, ComfortRating
    FROM tblCar
    WHERE CarID = @CarID AND IsAvailable = 1;
END
GO

-- Book a car.
-- @Result returns: the new BookingID (a positive number) if it worked, or
--   -1 = the dates are wrong (return day must be after pick-up day, and pick-up can't be in the past)
--   -2 = the car does not exist or is hidden
--   -3 = the car is already booked for some of those days
-- @TotalPrice returns the price (number of days x price per day), or 0 if it failed.
CREATE OR ALTER PROCEDURE usp_CreateBooking
    @UserID     INT,
    @CarID      INT,
    @StartDate  DATE,
    @EndDate    DATE,
    @SessionID  INT = NULL,
    @Result     INT OUTPUT,
    @TotalPrice INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @TotalPrice = 0;

    IF @StartDate IS NULL OR @EndDate IS NULL OR @EndDate <= @StartDate
       OR @StartDate < CAST(GETDATE() AS DATE)
    BEGIN
        SET @Result = -1;
        RETURN;
    END

    DECLARE @Price INT = (SELECT PricePerDay FROM tblCar WHERE CarID = @CarID AND IsAvailable = 1);
    IF @Price IS NULL
    BEGIN
        SET @Result = -2;
        RETURN;
    END

    BEGIN TRANSACTION;

    -- The locks stop two customers from booking the same car for the same days at the same moment.
    -- A booking may start on the day another one ends (the car is returned, then picked up again).
    IF EXISTS (SELECT 1 FROM tblBooking WITH (UPDLOCK, HOLDLOCK)
               WHERE CarID = @CarID
                 AND BookingStatus = N'Confirmed'
                 AND StartDate < @EndDate
                 AND EndDate > @StartDate)
    BEGIN
        ROLLBACK TRANSACTION;
        SET @Result = -3;
        RETURN;
    END

    SET @TotalPrice = DATEDIFF(DAY, @StartDate, @EndDate) * @Price;

    INSERT INTO tblBooking (UserID, CarID, StartDate, EndDate, TotalPrice, SessionID)
    VALUES (@UserID, @CarID, @StartDate, @EndDate, @TotalPrice, @SessionID);

    SET @Result = CAST(SCOPE_IDENTITY() AS INT);

    COMMIT TRANSACTION;
END
GO

-- A customer's own bookings, for the My Bookings page.
CREATE OR ALTER PROCEDURE usp_GetBookingsByUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.BookingID, b.StartDate, b.EndDate,
           DATEDIFF(DAY, b.StartDate, b.EndDate) AS Days,
           b.TotalPrice, b.BookingStatus,
           c.CarID, c.Make, c.Model, c.CarType
    FROM tblBooking b
    INNER JOIN tblCar c ON c.CarID = b.CarID
    WHERE b.UserID = @UserID
    ORDER BY b.StartDate DESC, b.BookingID DESC;
END
GO

-- Cancel a booking (soft cancel: the row stays, the status changes).
-- Only the customer who made it can cancel it, and only before the pick-up day has passed.
-- @Result returns 1 if it was cancelled, 0 if not (not theirs, already cancelled, or already started).
CREATE OR ALTER PROCEDURE usp_CancelBooking
    @BookingID INT,
    @UserID    INT,
    @Result    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE tblBooking
    SET BookingStatus = N'Cancelled'
    WHERE BookingID = @BookingID
      AND UserID = @UserID
      AND BookingStatus = N'Confirmed'
      AND StartDate >= CAST(GETDATE() AS DATE);

    SET @Result = @@ROWCOUNT;
END
GO

/* ============================================================
   3. QUICK CHECKS (each one shows a small results table)
   ============================================================ */

EXEC usp_GetCarTypes;                                   -- expect 8 rows
EXEC usp_SearchCars @CarType = N'SUV';                  -- expect 3 rows: Duster, Qashqai, Tucson
EXEC usp_SearchCars @MaxPrice = 500, @MinSeats = 5;     -- expect 4 rows: 208, Polo, Yaris Hybrid, Duster
EXEC usp_GetCarByID @CarID = 8;                         -- expect 1 row: Toyota Corolla Touring Sports
GO

/* ============================================================
   4. SELF-TEST for customers and bookings
   It creates a test customer and test bookings, shows the results,
   then deletes the test data again (test data only).
   ============================================================ */

DECLARE @TestEmail NVARCHAR(150) = N'test.customer@carbud.test';

-- Remove leftovers from an earlier test run
DELETE FROM tblBooking WHERE UserID IN (SELECT UserID FROM tblUser WHERE Email = @TestEmail);
DELETE FROM tblUser WHERE Email = @TestEmail;

DECLARE @UserID INT, @r INT, @t INT, @FirstBooking INT;
DECLARE @Day1 DATE = DATEADD(DAY, 1, CAST(GETDATE() AS DATE));   -- tomorrow
DECLARE @Day2 DATE = DATEADD(DAY, 1, @Day1);
DECLARE @Day3 DATE = DATEADD(DAY, 2, @Day1);
DECLARE @Day4 DATE = DATEADD(DAY, 3, @Day1);
DECLARE @Day6 DATE = DATEADD(DAY, 5, @Day1);
DECLARE @Log TABLE (TestNo INT, Test NVARCHAR(80), Result INT, TotalPrice INT, Expected NVARCHAR(80));

EXEC usp_RegisterUser @FullName = N'Test Customer', @Email = @TestEmail,
     @PasswordHash = 0x01, @PasswordSalt = 0x01, @NewUserID = @UserID OUTPUT;
INSERT INTO @Log VALUES (1, N'Register a new customer', @UserID, NULL, N'a positive number (the new UserID)');

EXEC usp_RegisterUser @FullName = N'Test Again', @Email = @TestEmail,
     @PasswordHash = 0x01, @PasswordSalt = 0x01, @NewUserID = @r OUTPUT;
INSERT INTO @Log VALUES (2, N'Register the same email again', @r, NULL, N'-1 (email already used)');

EXEC usp_CreateBooking @UserID = @UserID, @CarID = 1, @StartDate = @Day1, @EndDate = @Day4,
     @Result = @r OUTPUT, @TotalPrice = @t OUTPUT;
SET @FirstBooking = @r;
INSERT INTO @Log VALUES (3, N'Book the Up! for 3 days', @r, @t, N'a positive BookingID, price 900');

EXEC usp_CreateBooking @UserID = @UserID, @CarID = 1, @StartDate = @Day2, @EndDate = @Day3,
     @Result = @r OUTPUT, @TotalPrice = @t OUTPUT;
INSERT INTO @Log VALUES (4, N'Book the same car on overlapping days', @r, @t, N'-3 (already booked), price 0');

EXEC usp_CreateBooking @UserID = @UserID, @CarID = 1, @StartDate = @Day4, @EndDate = @Day6,
     @Result = @r OUTPUT, @TotalPrice = @t OUTPUT;
INSERT INTO @Log VALUES (5, N'Book it again from the return day (back to back)', @r, @t, N'a positive BookingID, price 600');

EXEC usp_CreateBooking @UserID = @UserID, @CarID = 1, @StartDate = @Day1, @EndDate = @Day1,
     @Result = @r OUTPUT, @TotalPrice = @t OUTPUT;
INSERT INTO @Log VALUES (6, N'Return day same as pick-up day', @r, @t, N'-1 (wrong dates), price 0');

EXEC usp_CreateBooking @UserID = @UserID, @CarID = 999, @StartDate = @Day1, @EndDate = @Day2,
     @Result = @r OUTPUT, @TotalPrice = @t OUTPUT;
INSERT INTO @Log VALUES (7, N'Book a car that does not exist', @r, @t, N'-2 (no such car), price 0');

EXEC usp_CancelBooking @BookingID = @FirstBooking, @UserID = @UserID, @Result = @r OUTPUT;
INSERT INTO @Log VALUES (8, N'Cancel the first booking', @r, NULL, N'1 (cancelled)');

EXEC usp_CreateBooking @UserID = @UserID, @CarID = 1, @StartDate = @Day2, @EndDate = @Day3,
     @Result = @r OUTPUT, @TotalPrice = @t OUTPUT;
INSERT INTO @Log VALUES (9, N'Book the overlapping days again after cancelling', @r, @t, N'a positive BookingID, price 300');

-- Results: compare the Result and TotalPrice columns with the Expected column
SELECT TestNo, Test, Result, TotalPrice, Expected FROM @Log ORDER BY TestNo;

-- The test customer's bookings: expect 3 rows, 1 Cancelled and 2 Confirmed
EXEC usp_GetBookingsByUser @UserID = @UserID;

-- Clean up the test data so your demo starts empty
DELETE FROM tblBooking WHERE UserID = @UserID;
DELETE FROM tblUser WHERE UserID = @UserID;
GO
