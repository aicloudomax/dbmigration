Create  PROCEDURE [divadim].[LoadDateDimension_Combined] 
as
--select * from divadim.DateDimension_Combined
DECLARE @StartDate DATE = '2025-01-01';
DECLARE @EndDate DATE = '2030-12-31';

IF OBJECT_ID('divadim.DateDimension_Combined', 'U') IS NOT NULL
    DROP TABLE divadim.DateDimension_Combined;

CREATE TABLE divadim.DateDimension_Combined (
    DateKey INT NOT NULL PRIMARY KEY,
    [Date] DATE NOT NULL,
    [Day] TINYINT NOT NULL,
    DaySuffix CHAR(2) NOT NULL,
    [Weekday] TINYINT NOT NULL,
    WeekDayName VARCHAR(10) NOT NULL,
    WeekdayAbbreviation CHAR(3) NOT NULL,
    WeekDayName_FirstLetter CHAR(1) NOT NULL,
    IsWeekend BIT NOT NULL,
    IsHoliday BIT NOT NULL DEFAULT 0,
    HolidayText VARCHAR(64) SPARSE NULL,
    SpecialDays VARCHAR(20) NULL,
    FiscalYear INT NOT NULL,
    FiscalQuarter TINYINT NOT NULL,
    FinancialMonth INT NULL,
    HalfYear TINYINT NOT NULL,
    Season VARCHAR(10) NOT NULL,
    WeekOfYear TINYINT NOT NULL,
    WeekOfMonth TINYINT NOT NULL,
    [Month] TINYINT NOT NULL,
    [MonthName] VARCHAR(10) NOT NULL,
    [MonthName_Short] CHAR(3) NOT NULL,
    [MonthName_FirstLetter] CHAR(1) NOT NULL,
    [Quarter] TINYINT NOT NULL,
    [QuarterName] VARCHAR(10) NOT NULL,
    [Year] INT NOT NULL,
    MMYYYY CHAR(6) NOT NULL,
    MonthYear CHAR(7) NOT NULL,
    FirstDayOfMonth DATE NOT NULL,
    LastDayOfMonth DATE NOT NULL,
    FirstDateofWeek DATE NOT NULL,
    LastDateofWeek DATE NOT NULL,
    FirstDateofQuater DATE NULL,
    LastDateofQuater DATE NULL,
    FirstDateofYear DATE NULL,
    LastDateofYear DATE NULL,
    DOWInMonth TINYINT NULL,
    DayOfYear SMALLINT NULL,
    CurrentYear SMALLINT NULL,
    CurrentQuater SMALLINT NULL,
    CurrentMonth SMALLINT NULL,
    CurrentWeek SMALLINT NULL,
    CurrentDay SMALLINT NULL
);

DECLARE @CurrentDate DATE = @StartDate;

WHILE @CurrentDate <= @EndDate
BEGIN
    INSERT INTO divadim.DateDimension_Combined
    SELECT
        DateKey = CONVERT(INT, CONVERT(CHAR(8), @CurrentDate, 112)),
        [Date] = @CurrentDate,
        [Day] = DAY(@CurrentDate),
        DaySuffix = CASE 
            WHEN DAY(@CurrentDate) IN (1, 21, 31) THEN 'st'
            WHEN DAY(@CurrentDate) IN (2, 22) THEN 'nd'
            WHEN DAY(@CurrentDate) IN (3, 23) THEN 'rd'
            ELSE 'th' END,
        [Weekday] = DATEPART(WEEKDAY, @CurrentDate),
        WeekDayName = DATENAME(WEEKDAY, @CurrentDate),
        WeekdayAbbreviation = LEFT(DATENAME(WEEKDAY, @CurrentDate), 3),
        WeekDayName_FirstLetter = LEFT(DATENAME(WEEKDAY, @CurrentDate), 1),
        IsWeekend = CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 1 ELSE 0 END,
        IsHoliday = 0,
        HolidayText = NULL,
        SpecialDays = NULL,
        FiscalYear = YEAR(@CurrentDate),
        FiscalQuarter = DATEPART(QUARTER, @CurrentDate),
        FinancialMonth = MONTH(@CurrentDate),
        HalfYear = CASE WHEN MONTH(@CurrentDate) <= 6 THEN 1 ELSE 2 END,
        Season = CASE 
            WHEN MONTH(@CurrentDate) IN (12, 1, 2) THEN 'Winter'
            WHEN MONTH(@CurrentDate) IN (3, 4, 5) THEN 'Spring'
            WHEN MONTH(@CurrentDate) IN (6, 7, 8) THEN 'Summer'
            ELSE 'Autumn' END,
        WeekOfYear = DATEPART(WEEK, @CurrentDate),
        WeekOfMonth = DATEPART(WEEK, @CurrentDate) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, @CurrentDate), 0)) + 1,
        [Month] = MONTH(@CurrentDate),
        [MonthName] = DATENAME(MONTH, @CurrentDate),
        [MonthName_Short] = UPPER(LEFT(DATENAME(MONTH, @CurrentDate), 3)),
        [MonthName_FirstLetter] = LEFT(DATENAME(MONTH, @CurrentDate), 1),
        [Quarter] = DATEPART(QUARTER, @CurrentDate),
        [QuarterName] = CASE DATEPART(QUARTER, @CurrentDate)
                            WHEN 1 THEN 'First'
                            WHEN 2 THEN 'Second'
                            WHEN 3 THEN 'Third'
                            ELSE 'Fourth' END,
        [Year] = YEAR(@CurrentDate),
        MMYYYY = RIGHT('0' + CAST(MONTH(@CurrentDate) AS VARCHAR(2)), 2) + CAST(YEAR(@CurrentDate) AS VARCHAR(4)),
        MonthYear = CAST(YEAR(@CurrentDate) AS VARCHAR(4)) + UPPER(LEFT(DATENAME(MONTH, @CurrentDate), 3)),
        FirstDayOfMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, @CurrentDate), 0),
        LastDayOfMonth = EOMONTH(@CurrentDate),
        FirstDateofWeek = DATEADD(DAY, 1 - DATEPART(WEEKDAY, @CurrentDate), @CurrentDate),
        LastDateofWeek = DATEADD(DAY, 7 - DATEPART(WEEKDAY, @CurrentDate), @CurrentDate),
        FirstDateofQuater = DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @CurrentDate), 0),
        LastDateofQuater = DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @CurrentDate) + 1, 0)),
        FirstDateofYear = CAST(CAST(YEAR(@CurrentDate) AS VARCHAR(4)) + '-01-01' AS DATE),
        LastDateofYear = CAST(CAST(YEAR(@CurrentDate) AS VARCHAR(4)) + '-12-31' AS DATE),
        DOWInMonth = DAY(@CurrentDate),
        DayOfYear = DATEPART(DAYOFYEAR, @CurrentDate),
        CurrentYear = DATEDIFF(YEAR, GETDATE(), @CurrentDate),
        CurrentQuater = DATEDIFF(QUARTER, GETDATE(), @CurrentDate),
        CurrentMonth = DATEDIFF(MONTH, GETDATE(), @CurrentDate),
        CurrentWeek = DATEDIFF(WEEK, GETDATE(), @CurrentDate),
        CurrentDay = DATEDIFF(DAY, GETDATE(), @CurrentDate);

    SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
END;

-- Optional: Populate fixed holidays
UPDATE divadim.DateDimension_Combined SET IsHoliday = 1, HolidayText = 'New Year''s Day'
WHERE MONTH([Date]) = 1 AND DAY([Date]) = 1;

UPDATE divadim.DateDimension_Combined SET IsHoliday = 1, HolidayText = 'Christmas'
WHERE MONTH([Date]) = 12 AND DAY([Date]) = 25;

UPDATE divadim.DateDimension_Combined SET SpecialDays = 'Valentine''s Day'
WHERE MONTH([Date]) = 2 AND DAY([Date]) = 14;
