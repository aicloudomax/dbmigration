
CREATE PROCEDURE divadim.LoadDateDimension
    @StartDate DATE = '20250101',
    @NumberOfYears INT = 1
AS
--exec divadim.LoadDateDimension '20200101',10
 --Declare   @StartDate DATE = '20250101',
 --   @NumberOfYears INT = 1
    -- Set consistent settings
    SET DATEFIRST 7;
    SET DATEFORMAT mdy;
    SET LANGUAGE us_english;

	DELETE FROM divadim.DateDimension
	WHERE  [Year] = YEAR(@StartDate);


    -- Calculate the cutoff date
    DECLARE @CutoffDate DATE = DATEADD(YEAR, @NumberOfYears, @StartDate);

    -- Drop and recreate the DateDimension table
    IF OBJECT_ID('divadim.DateDimension', 'U') IS NOT NULL
        DROP TABLE divadim.DateDimension;

    CREATE TABLE divadim.DateDimension
    (
        DateKey             INT         NOT NULL PRIMARY KEY,
        [Date]              DATE        NOT NULL,
        [Day]               TINYINT     NOT NULL,
        DaySuffix           CHAR(2)     NOT NULL,
        [Weekday]           TINYINT     NOT NULL,
        WeekDayName         VARCHAR(10) NOT NULL,
        WeekdayAbbreviation CHAR(3)     NOT NULL,
        IsWeekend           BIT         NOT NULL,
        IsHoliday           BIT         DEFAULT 0 NOT NULL,
        HolidayText         VARCHAR(64) SPARSE,
        FiscalYear          INT         NOT NULL,
        FiscalQuarter       TINYINT     NOT NULL,
        HalfYear            TINYINT     NOT NULL,
        Season              VARCHAR(10) NOT NULL,
        WeekOfYear          TINYINT     NOT NULL,
        [Month]             TINYINT     NOT NULL,
        [MonthName]         VARCHAR(10) NOT NULL,
        [Quarter]           TINYINT     NOT NULL,
        [Year]              INT         NOT NULL,
        FirstDayOfMonth     DATE        NOT NULL,
        LastDayOfMonth      DATE        NOT NULL
    );

    -- Populate the DateDimension table using a WHILE loop
    DECLARE @CurrentDate DATE = @StartDate;

    WHILE @CurrentDate < @CutoffDate
    BEGIN
        INSERT INTO divadim.DateDimension
        (
            DateKey,
            [Date],
            [Day],
            DaySuffix,
            [Weekday],
            WeekDayName,
            WeekdayAbbreviation,
            IsWeekend,
            FiscalYear,
            FiscalQuarter,
            HalfYear,
            Season,
            WeekOfYear,
            [Month],
            [MonthName],
            [Quarter],
            [Year],
            FirstDayOfMonth,
            LastDayOfMonth
        )
        SELECT
            DateKey       = CONVERT(INT, CONVERT(CHAR(8), @CurrentDate, 112)),
            [Date]        = @CurrentDate,
            [Day]         = DAY(@CurrentDate),
            DaySuffix     = CASE 
                              WHEN DAY(@CurrentDate) IN (1, 21, 31) THEN 'st'
                              WHEN DAY(@CurrentDate) IN (2, 22) THEN 'nd'
                              WHEN DAY(@CurrentDate) IN (3, 23) THEN 'rd'
                              ELSE 'th' END,
            [Weekday]     = DATEPART(WEEKDAY, @CurrentDate),
            WeekDayName   = DATENAME(WEEKDAY, @CurrentDate),
            WeekdayAbbreviation = LEFT(DATENAME(WEEKDAY, @CurrentDate), 3),
            IsWeekend     = CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 1 ELSE 0 END,
            FiscalYear    = YEAR(@CurrentDate), -- Adjust if fiscal year differs
            FiscalQuarter = DATEPART(QUARTER, @CurrentDate),
            HalfYear      = CASE WHEN MONTH(@CurrentDate) <= 6 THEN 1 ELSE 2 END,
            Season        = CASE 
                              WHEN MONTH(@CurrentDate) IN (12, 1, 2) THEN 'Winter'
                              WHEN MONTH(@CurrentDate) IN (3, 4, 5) THEN 'Spring'
                              WHEN MONTH(@CurrentDate) IN (6, 7, 8) THEN 'Summer'
                              WHEN MONTH(@CurrentDate) IN (9, 10, 11) THEN 'Autumn' END,
            WeekOfYear    = DATEPART(WEEK, @CurrentDate),
            [Month]       = MONTH(@CurrentDate),
            [MonthName]   = DATENAME(MONTH, @CurrentDate),
            [Quarter]     = DATEPART(QUARTER, @CurrentDate),
            [Year]        = YEAR(@CurrentDate),
            FirstDayOfMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, @CurrentDate), 0),
            LastDayOfMonth  = EOMONTH(@CurrentDate);

        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END;

    -- Populate IsHoliday and HolidayText
    UPDATE divadim.DateDimension
    SET IsHoliday = 1, HolidayText = 'New Year''s Day'
    WHERE MONTH([Date]) = 1 AND DAY([Date]) = 1;



	--Select * from divadim.DateDimension 