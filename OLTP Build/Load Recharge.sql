-- Recharge Vending database developed and written by Brian Corcoran
-- Originally Written: July 2018

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- !!                      WARNING                       !! --
-- !!            DEPENDING ON PARAMETERS SET,            !! --
-- !!      MACHINE SPEED AND RESULT OUTOUT SETTINGS      !! --
-- !!	     THIS CAN RUN A LONG TIME OR CRASH ;-)       !! --
-- !!            READ THE DOCUMENTATION NOTES            !! --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 

-- -----------------------------------------------------------
-- Script Documentation 
-- ---------------------------------------------------------

-- Designed To Be Self Contained For Loading
-- Load Time is based on date ranges supplied : see below
-- Loading goes smoother when Results go to a text File (Tools -> Options -> SQL Results)

-- The Following Items are designed to be skewed vs fully random
-- * Sales & Tenders To More Modern Machines
-- * Prefer to use Bottle Machines vs Cans

-- Script Sections
-- * Documentation
-- * Set Parameters For Script
-- * Create Database As Needed
-- * Create DimDate (from Amy Phillips)
-- * Create DimTime (from Amy Phillips)
-- * Drop Tables
-- * Create Recharge Tables
-- * Load Basic Data Tables
-- * Dynamic Load of Machine / BuildingMachine
-- * Dynamic Load of Stock
-- * Dynamic Load of Sales
-- * Clean Up Helper Tables (Per Parameter)

-- Expected Counts
-- -- Due to Dynamic Loading of Machine & BuildingMachine Exact Models Selected Vary 
-- -- Due to Dynamic Loading of Stock, Machines, Sales Counts Very
-- * Brand: 67
-- * Building: 17
-- * BuildingMachine: 159
-- * Campus: 1
-- * Department: 10
-- * Machine: 159
-- * Manufacturer: 21
-- * Model: 7
-- * ModelShelf: 54
-- * ModelType: 4
-- * Product: 280
-- * ProductType: 10
-- * Sales: VARIABLE 
-- * Shelf: 6
-- * Stock: VARIABLE
-- * Tender: 7

-- Helper Tables Dropped After Load Compete (Per Parameter)
-- -- DimDate
-- -- DimTime
-- -- BuildingLoad
-- -- SalesLoad 
-- -- WeightTenders

-- ---------------------------------------------------------
-- Set Date Ranges For Data Generation
-- -----------------------------------------------------------
-- All start dates must be less than corresponding end date 
-- Dates Are Set Below : Only One GO at the End of load, so they are accessible throughout

-- -----------------------------------------------------------
-- Additional Tuning Options
-- ---------------------------------------------------------
-- Shelf Qty (Search for the shelf Insert)
-- Limit the number of can machines (Search for max_cans)
-- Adjust the values/counts in WeightTenders

-- -----------------------------------------------------------
-- Things To improve
-- ---------------------------------------------------------
-- * Campus ID Is not accounted For In the Dynamic Loads 
--         (Only one campus so not relevant at this time)
-- * Consider moving all declares to the very top and then initializing fetch vars where needed
-- * Add Ability to skew which slots/position is selected for a product OR
-- * Add Ability for a product to have an affinity for a slot or a machine
-- -----------------------------------------------------------

-- -----------------------------------------------------------
-- Create Database AS Need
-- -----------------------------------------------------------
IF NOT EXISTS(SELECT * FROM sys.databases
 WHERE name = N'Recharge')
 CREATE DATABASE Recharge
--
GO
--

USE Recharge;

-- -----------------------------------------------------------
-- Set Date Parameters
-- -----------------------------------------------------------

-- Specify start date and end date here for DimDate
DECLARE @StartDate DATE = '2017-05-01' 
DECLARE @EndDate DATE = '2018-07-31' 

-- In Service Dates For BulidingMachine (Dates do not matter much)
DECLARE @ServiceDateStart Date = '2010-01-01';
DECLARE @ServiceDateEnd Date = '2018-01-01';

-- Dates To Generate Stock For
DECLARE @StockDateStart	Date = '2017-05-01';
DECLARE @StockDateEnd	Date = '2018-07-13';

-- Set dates to make sales for (inclusive)
DECLARE @SaleDateStart Date = '2017-06-01';
DECLARE @SaleDateEnd Date = '2018-06-30';

-- Do you want to drop the helper tables
DECLARE @drop_helpers INT = 1;

-- -----------------------------------------------------------
-- Loading DimDate Table to Facilitate Dynamic Table Loading
-- -----------------------------------------------------------
-- Load Date Dimension (DimDate) adapted by Amy Phillips using various online resources
-- Originally adapted: June 2016 | Modified: July 2018
-- -----------------------------------------------------------

-- Drop Table as Needed
DROP TABLE IF EXISTS DimDate;

-- Create Table
CREATE TABLE [dbo].[DimDate](
	[Date_SK] [int] NOT NULL,
	[Date] [date] NULL,
	[FullDate] [nchar](10) NULL,
	[DayOfMonth] [int] NULL,
	[DayName] [nvarchar](9) NULL,
	[DayOfWeek] [int] NULL,
	[DayOfWeekInMonth] [int] NULL,
	[DayOfWeekInYear] [int] NULL,
	[DayOfQuarter] [int] NULL,
	[DayOfYear] [int] NULL,
	[WeekOfMonth] [int] NULL,
	[WeekOfQuarter] [int] NULL,
	[WeekOfYear] [int] NULL,
	[Month] [int] NULL,
	[MonthName] [nvarchar](9) NULL,
	[MonthOfQuarter] [int] NULL,
	[Quarter] [nchar](2) NULL,
	[QuarterName] [nvarchar](9) NULL,
	[Year] [int] NULL,
	[YearName] [char](7) NULL,
	[MonthYear] [char](10) NULL,
	[MMYYYY] [int] NULL,
	[FirstDayOfMonth] [date] NULL,
	[LastDayOfMonth] [date] NULL,
	[FirstDayOfQuarter] [date] NULL,
	[LastDayOfQuarter] [date] NULL,
	[FirstDayOfYear] [date] NULL,
	[LastDayOfYear] [date] NULL,
	[IsHoliday] [bit] NULL,
	[IsWeekday] [bit] NULL,
	[Holiday] [nvarchar](50) NULL,
	[Season] [nvarchar](10) NULL,
PRIMARY KEY CLUSTERED 
(
	[Date_SK] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]


-- Temporary variables to hold the values during processing of each date of year
DECLARE
	@DayOfWeekInMonth INT,
	@DayOfWeekInYear INT,
	@DayOfQuarter INT,
	@WeekOfMonth INT,
	@CurrentYear INT,
	@CurrentMonth INT,
	@CurrentQuarter INT

-- Table data type to store the day of week count for the month and year
DECLARE @DayOfWeek TABLE (DOW INT, MonthCount INT, QuarterCount INT, YearCount INT)

INSERT INTO @DayOfWeek VALUES (1, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (2, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (3, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (4, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (5, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (6, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (7, 0, 0, 0)

-- Extract and assign various parts of values from current date to variable

DECLARE @CurrentDate AS DATE = @StartDate
SET @CurrentMonth = DATEPART(MM, @CurrentDate)
SET @CurrentYear = DATEPART(YY, @CurrentDate)
SET @CurrentQuarter = DATEPART(QQ, @CurrentDate)

-- Proceed only if start date(current date ) is less than end date you specified above

WHILE @CurrentDate < @EndDate
BEGIN
 
-- Begin day of week logic

	/*Check for change in month of the current date if month changed then change variable value*/
	IF @CurrentMonth <> DATEPART(MM, @CurrentDate) 
	BEGIN
		UPDATE @DayOfWeek
		SET MonthCount = 0
		SET @CurrentMonth = DATEPART(MM, @CurrentDate)
	END

	/* Check for change in quarter of the current date if quarter changed then change variable value*/

	IF @CurrentQuarter <> DATEPART(QQ, @CurrentDate)
	BEGIN
		UPDATE @DayOfWeek
		SET QuarterCount = 0
		SET @CurrentQuarter = DATEPART(QQ, @CurrentDate)
	END
       
	/* Check for Change in Year of the Current date if Year changed then change variable value*/
	
	IF @CurrentYear <> DATEPART(YY, @CurrentDate)
	BEGIN
		UPDATE @DayOfWeek
		SET YearCount = 0
		SET @CurrentYear = DATEPART(YY, @CurrentDate)
	END
	
-- Set values in table data type created above from variables 

	UPDATE @DayOfWeek
	SET 
		MonthCount = MonthCount + 1,
		QuarterCount = QuarterCount + 1,
		YearCount = YearCount + 1
	WHERE DOW = DATEPART(DW, @CurrentDate)

	SELECT
		@DayOfWeekInMonth = MonthCount,
		@DayOfQuarter = QuarterCount,
		@DayOfWeekInYear = YearCount
	FROM @DayOfWeek
	WHERE DOW = DATEPART(DW, @CurrentDate)
	
-- End day of week logic

	/* Populate your dimension table with values*/
	
	INSERT INTO DimDate
	SELECT
		
		CONVERT (char(8),@CurrentDate,112) AS Date_SK,
		@CurrentDate AS Date,
		CONVERT (char(10),@CurrentDate,101) AS FullDate,
		DATEPART(DD, @CurrentDate) AS DayOfMonth,
		DATENAME(DW, @CurrentDate) AS DayName,
		DATEPART(DW, @CurrentDate) AS DayOfWeek,
		@DayOfWeekInMonth AS DayOfWeekInMonth,
		@DayOfWeekInYear AS DayOfWeekInYear,
		@DayOfQuarter AS DayOfQuarter,
		DATEPART(DY, @CurrentDate) AS DayOfYear,
		DATEPART(WW, @CurrentDate) + 1 - DATEPART(WW, CONVERT(VARCHAR, 
		DATEPART(MM, @CurrentDate)) + '/1/' + CONVERT(VARCHAR, 
		DATEPART(YY, @CurrentDate))) AS WeekOfMonth,
		(DATEDIFF(DD, DATEADD(QQ, DATEDIFF(QQ, 0, @CurrentDate), 0), 
		@CurrentDate) / 7) + 1 AS WeekOfQuarter,
		DATEPART(WW, @CurrentDate) AS WeekOfYear,
		DATEPART(MM, @CurrentDate) AS Month,
		DATENAME(MM, @CurrentDate) AS MonthName,
		CASE
			WHEN DATEPART(MM, @CurrentDate) IN (1, 4, 7, 10) THEN 1
			WHEN DATEPART(MM, @CurrentDate) IN (2, 5, 8, 11) THEN 2
			WHEN DATEPART(MM, @CurrentDate) IN (3, 6, 9, 12) THEN 3
			END AS MonthOfQuarter,
		'Q' + CONVERT(VARCHAR, DATEPART(QQ, @CurrentDate)) AS Quarter,
		CASE DATEPART(QQ, @CurrentDate)
			WHEN 1 THEN 'First'
			WHEN 2 THEN 'Second'
			WHEN 3 THEN 'Third'
			WHEN 4 THEN 'Fourth'
			END AS QuarterName,
		DATEPART(YEAR, @CurrentDate) AS Year,
		'CY ' + CONVERT(VARCHAR, DATEPART(YEAR, @CurrentDate)) AS YearName,
		LEFT(DATENAME(MM, @CurrentDate), 3) + '-' + CONVERT(VARCHAR, 
		DATEPART(YY, @CurrentDate)) AS MonthYear,
		RIGHT('0' + CONVERT(VARCHAR, DATEPART(MM, @CurrentDate)),2) + 
		CONVERT(VARCHAR, DATEPART(YY, @CurrentDate)) AS MMYYYY,
		CONVERT(DATETIME, CONVERT(DATE, DATEADD(DD, - (DATEPART(DD, 
		@CurrentDate) - 1), @CurrentDate))) AS FirstDayOfMonth,
		CONVERT(DATETIME, CONVERT(DATE, DATEADD(DD, - (DATEPART(DD, 
		(DATEADD(MM, 1, @CurrentDate)))), DATEADD(MM, 1, 
		@CurrentDate)))) AS LastDayOfMonth,
		DATEADD(QQ, DATEDIFF(QQ, 0, @CurrentDate), 0) AS FirstDayOfQuarter,
		DATEADD(QQ, DATEDIFF(QQ, -1, @CurrentDate), -1) AS LastDayOfQuarter,
		CONVERT(DATETIME, '01/01/' + CONVERT(VARCHAR, DATEPART(YY, 
		@CurrentDate))) AS FirstDayOfYear,
		CONVERT(DATETIME, '12/31/' + CONVERT(VARCHAR, DATEPART(YY, 
		@CurrentDate))) AS LastDayOfYear,
		NULL AS IsHoliday,
		CASE DATEPART(DW, @CurrentDate)
			WHEN 1 THEN 0
			WHEN 2 THEN 1
			WHEN 3 THEN 1
			WHEN 4 THEN 1
			WHEN 5 THEN 1
			WHEN 6 THEN 1
			WHEN 7 THEN 0
			END AS IsWeekday,
		NULL AS Holiday,
		 CASE
			WHEN DATEPART(MM, @CurrentDate) IN (12,1,2) THEN 'Winter'
			WHEN DATEPART(MM, @CurrentDate) IN (3,4,5) THEN 'Spring'
			WHEN DATEPART(MM, @CurrentDate) IN (6,7,8) THEN 'Summer'
			WHEN DATEPART(MM, @CurrentDate) IN (9,10,11) THEN 'Fall'
			END AS Season

	SET @CurrentDate = DATEADD(DD, 1, @CurrentDate)
END

--Update values of holiday as per USA Govt. Declaration for National Holiday

	-- THANKSGIVING - Fourth THURSDAY in November
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Thanksgiving Day'
	WHERE
		[Month] = 11 
		AND [DayName] = 'Thursday' 
		AND DayOfWeekInMonth = 4

	-- CHRISTMAS
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Christmas Day'
		
	WHERE [Month] = 12 AND [DayOfMonth]  = 25

	-- 4th of July
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Independance Day'
	WHERE [Month] = 7 AND [DayOfMonth] = 4

	-- New Years Day
	UPDATE [dbo].[DimDate]
		SET Holiday = 'New Year''s Day'
	WHERE [Month] = 1 AND [DayOfMonth] = 1

	-- Memorial Day - Last Monday in May
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Memorial Day'
	FROM [dbo].[DimDate]
	WHERE Date_SK IN 
		(
		SELECT
			MAX(Date_SK)
		FROM [dbo].[DimDate]
		WHERE
			[MonthName] = 'May'
			AND [DayName]  = 'Monday'
		GROUP BY
			[Year],
			[Month]
		)

	-- Labor Day - First Monday in September
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Labor Day'
	FROM [dbo].[DimDate]
	WHERE Date_SK IN 
		(
		SELECT
			MIN(Date_SK)
		FROM [dbo].[DimDate]
		WHERE
			[MonthName] = 'September'
			AND [DayName] = 'Monday'
		GROUP BY
			[Year],
			[Month]
		)

	-- Valentine's Day
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Valentine''s Day'
	WHERE
		[Month] = 2 
		AND [DayOfMonth] = 14

	-- Saint Patrick's Day
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Saint Patrick''s Day'
	WHERE
		[Month] = 3
		AND [DayOfMonth] = 17

	-- Martin Luthor King Day - Third Monday in January starting in 1983
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Martin Luthor King Jr Day'
	WHERE
		[Month] = 1
		AND [DayName]  = 'Monday'
		AND [Year] >= 1983
		AND DayOfWeekInMonth = 3

	-- President's Day - Third Monday in February
	UPDATE [dbo].[DimDate]
		SET Holiday = 'President''s Day'
	WHERE
		[Month] = 2
		AND [DayName] = 'Monday'
		AND DayOfWeekInMonth = 3

	-- Mother's Day - Second Sunday of May
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Mother''s Day'
	WHERE
		[Month] = 5
		AND [DayName] = 'Sunday'
		AND DayOfWeekInMonth = 2

	-- Father's Day - Third Sunday of June
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Father''s Day'
	WHERE
		[Month] = 6
		AND [DayName] = 'Sunday'
		AND DayOfWeekInMonth = 3

	-- Halloween 10/31*/
	UPDATE [dbo].[DimDate]
		SET Holiday = 'Halloween'
	WHERE
		[Month] = 10
		AND [DayOfMonth] = 31

	-- Election Day - The first Tuesday after the first Monday in November
	BEGIN
	DECLARE @Holidays TABLE (ID INT IDENTITY(1,1), 
	DateID int, Week TINYINT, YEAR CHAR(4), DAY CHAR(2))

		INSERT INTO @Holidays(DateID, [Year],[Day])
		SELECT
			Date_SK,
			[Year],
			[DayOfMonth] 
		FROM [dbo].[DimDate]
		WHERE
			[Month] = 11
			AND [DayName] = 'Monday'
		ORDER BY
			YEAR,
			DayOfMonth 

		DECLARE @CNTR INT, @POS INT, @STARTYEAR INT, @ENDYEAR INT, @MINDAY INT

		SELECT
			@CURRENTYEAR = MIN([Year]),
			@STARTYEAR = MIN([Year]),
			@ENDYEAR = MAX([Year])
		FROM @Holidays

		WHILE @CURRENTYEAR <= @ENDYEAR
		BEGIN
			SELECT @CNTR = COUNT([Year])
			FROM @Holidays
			WHERE [Year] = @CURRENTYEAR

			SET @POS = 1

			WHILE @POS <= @CNTR
			BEGIN
				SELECT @MINDAY = MIN(DAY)
				FROM @Holidays
				WHERE
					[Year] = @CURRENTYEAR
					AND [Week] IS NULL

				UPDATE @Holidays
					SET [Week] = @POS
				WHERE
					[Year] = @CURRENTYEAR
					AND [Day] = @MINDAY

				SELECT @POS = @POS + 1
			END

			SELECT @CURRENTYEAR = @CURRENTYEAR + 1
		END

		UPDATE [dbo].[DimDate]
			SET Holiday  = 'Election Day'				
		FROM [dbo].[DimDate] DT
			JOIN @Holidays HL ON (HL.DateID + 1) = DT.Date_SK
		WHERE
			[Week] = 1
	END
	-- Set flag for USA holidays in Dimension
	UPDATE [dbo].[DimDate]
	SET IsHoliday = 
		CASE	WHEN Holiday IS NULL THEN 0 
			WHEN Holiday IS NOT NULL THEN 1 
	END

-- --------------------------------------------------------------------------------------
-- End LoadDate
-- --------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------
-- Load DimTime
-- --------------------------------------------------------------------------------------

-- Drop Table DimTime if exists
DROP TABLE IF EXISTS DimTime;

-- Create Table DimTime
CREATE TABLE DimTime
	(
	TimeSK [int] IDENTITY(1,1) NOT NULL CONSTRAINT [PK_dim_Time] PRIMARY KEY,
	Time CHAR(8) NOT NULL,
	Hour CHAR(2) NOT NULL,
	MilitaryHour CHAR(2) NOT NULL,
	Minute CHAR(2) NOT NULL,
	Second CHAR(2) NOT NULL,
	AmPm CHAR(2) NOT NULL,
	StandardTime CHAR(11) NULL
	);

--------------------------------------------------------------------------------------------------------
PRINT CONVERT(VARCHAR,GETDATE(),113)--USED FOR CHECKING RUN TIME.

SET NOCOUNT ON
--Load time data for every second of a day
DECLARE @Time DATETIME

SET @TIME = CONVERT(VARCHAR,'12:00:00 AM',108)

TRUNCATE TABLE DimTime

WHILE @TIME <= '11:59:59 PM'
	BEGIN
	INSERT INTO dbo.DimTime([Time], [HOUR], [MilitaryHour], [MINUTE], [SECOND], [AmPm])
	SELECT CONVERT(VARCHAR,@TIME,108) [Time], 
		CASE 
			WHEN DATEPART(HOUR,@Time) > 12 
				THEN DATEPART(HOUR,@Time) - 12
			ELSE DATEPART(HOUR,@Time) 
		END AS [HOUR],
	CAST(SUBSTRING(CONVERT(VARCHAR,@TIME,108),1,2) AS INT) [MilitaryHour],
	DATEPART(MINUTE,@Time) [MINUTE],
	DATEPART(SECOND,@Time) [SECOND],
	CASE 
		WHEN DATEPART(HOUR,@Time) >= 12 THEN 'PM'
	ELSE 'AM'
	END AS [AmPm]

 SELECT @TIME = DATEADD(SECOND,1,@Time)
 END

UPDATE DimTime
SET [HOUR] = '0' + [HOUR]
WHERE LEN([HOUR]) = 1

UPDATE DimTime
SET [MINUTE] = '0' + [MINUTE]
WHERE LEN([MINUTE]) = 1

UPDATE DimTime
SET [SECOND] = '0' + [SECOND]
WHERE LEN([SECOND]) = 1

UPDATE DimTime
SET [MilitaryHour] = '0' + [MilitaryHour]
WHERE LEN([MilitaryHour]) = 1

UPDATE DimTime
SET StandardTime = [HOUR] + ':' + [MINUTE] + ':' + [SECOND] + ' ' + AmPm
WHERE StandardTime IS NULL
AND HOUR <> '00'

UPDATE DimTime
SET StandardTime = '12' + ':' + [MINUTE] + ':' + [SECOND] + ' ' + AmPm
WHERE [HOUR] = '00'

-- --------------------------------------------------------------------------------------
-- End Load DimTime
-- --------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------
-- Delete existing tables
-- --------------------------------------------------------------------------------------
DROP TABLE IF EXISTS BuildingMachine ;
DROP TABLE IF EXISTS BuildingLoad ;
DROP TABLE IF EXISTS Building ;

DROP TABLE IF EXISTS SalesLoad ;
DROP TABLE IF EXISTS WeightTenders;
DROP TABLE IF EXISTS SaleTimes;

DROP TABLE IF EXISTS Sales ;
DROP TABLE IF EXISTS Stock ;
DROP TABLE IF EXISTS Product ;

DROP TABLE IF EXISTS Machine ;

DROP TABLE IF EXISTS ModelShelf ;
DROP TABLE IF EXISTS Model ;
DROP TABLE IF EXISTS Shelf ;
DROP TABLE IF EXISTS SlotSize ;

DROP TABLE IF EXISTS ModelType ;
DROP TABLE IF EXISTS ProductType ;
DROP TABLE IF EXISTS Tender ;
DROP TABLE IF EXISTS Department ;
DROP TABLE IF EXISTS Brand ;
DROP TABLE IF EXISTS Manufacturer ;
DROP TABLE IF EXISTS Campus ;
DROP TABLE IF EXISTS DayName;

--
-- Create tables
--
--
CREATE TABLE DayName
 (DayNameID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_day_name_id PRIMARY KEY,
  Name  NVARCHAR(50) NOT NULL
 );
--
CREATE TABLE Campus
 (CampusID  INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_campus_id PRIMARY KEY,
  Name    NVARCHAR(75) NOT NULL
 );
--
CREATE TABLE Manufacturer
 (ManufacturerID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_manufacturer_id PRIMARY KEY,
  Name   NVARCHAR(75) NOT NULL
 );
--
CREATE TABLE Brand
 (BrandID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_brand_id PRIMARY KEY,
  Name   NVARCHAR(75) NOT NULL
 );
--
CREATE TABLE Department
 (DepartmentID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_department_id PRIMARY KEY,
  Name   NVARCHAR(75) NOT NULL
 );
--
CREATE TABLE Tender
 (TenderID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_tender_id PRIMARY KEY,
  Name   NVARCHAR(75) NOT NULL
 );
--
CREATE TABLE ProductType
 (ProductTypeID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_product_type_id PRIMARY KEY,
  Description  NVARCHAR(75) NOT NULL
 );
--
CREATE TABLE ModelType
 (ModelTypeID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_model_type_id PRIMARY KEY,
 Description   NVARCHAR(50) NOT NULL
 );
--
CREATE TABLE SlotSize
 (SlotSizeID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_slot_size_id PRIMARY KEY,
 Description   NVARCHAR(50) NOT NULL
 );
--
CREATE TABLE Shelf
 (ShelfID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_shelf_id PRIMARY KEY,
  ModelName  NVARCHAR(50) NOT NULL,
  Description   NVARCHAR(50) NOT NULL,
  Slots INT NOT NULL,
  SlotSizeID INT NOT NULL  CONSTRAINT fk_slot_size_id FOREIGN KEY REFERENCES SlotSize(SlotSizeID),
  Quantity INT NOT NULL,
  CONSTRAINT uq_model_name UNIQUE (ModelName)        

 );
--
CREATE TABLE Model
 (ModelID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_model_id PRIMARY KEY,
  Name NVARCHAR(50) NOT NULL,
  ModelTypeID INT CONSTRAINT fk_model_type_id FOREIGN KEY REFERENCES ModelType(ModelTypeID),
  Cash INT NOT NULL,
  CreditCard INT NOT NULL,
  MobilePay INT NOT NULL,
  CONSTRAINT ck_cash CHECK  (Cash = 0 OR Cash = 1),
  CONSTRAINT ck_creditcard CHECK  (CreditCard = 0 OR CreditCard = 1),
  CONSTRAINT ck_mobilepay CHECK  (MobilePay = 0 OR MobilePay = 1)
 );
 --
CREATE TABLE ModelShelf
(ModelID  INT CONSTRAINT fk_ms_model_id FOREIGN KEY REFERENCES Model(ModelID),
 ShelfID  INT CONSTRAINT fk_ms_shelf_id FOREIGN KEY REFERENCES Shelf(ShelfID),
 Position INT NOT NULL,
 CONSTRAINT uq_position UNIQUE (ModelID, ShelfID, Position)        
 );
--
CREATE TABLE Machine
 (MachineID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_machine_id PRIMARY KEY,
  ModelID INT CONSTRAINT fk_model_id FOREIGN KEY REFERENCES Model(ModelID),
  InService DATE NOT NULL
 );
--
CREATE TABLE Product
 (ProductID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_product_id PRIMARY KEY,
  ProductTypeID INT NOT NULL CONSTRAINT fk_product_type_id FOREIGN KEY REFERENCES ProductType(ProductTypeID),
  BrandID INT CONSTRAINT fk_brand_id FOREIGN KEY REFERENCES Brand(BrandID),
  ManufacturerID INT CONSTRAINT fk_manufacturer_id FOREIGN KEY REFERENCES Manufacturer(ManufacturerID),
  Name NVARCHAR(75) NOT NULL,
  SlotSizeID INT NOT NULL  CONSTRAINT fk_prod_slot_size_id FOREIGN KEY REFERENCES SlotSize(SlotSizeID),
  Price NUMERIC(5,2) NOT NULL,
  Cost  NUMERIC(5,2) NOT NULL
 );
--
CREATE TABLE Stock
 (StockID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_stock_id PRIMARY KEY,
  MachineID INT CONSTRAINT fk_s_machine_id FOREIGN KEY REFERENCES Machine(MachineID),
  ProductID INT CONSTRAINT fk_s_product_id FOREIGN KEY REFERENCES Product(ProductID),
  Loaded DATE NOT NULL,
  Position INT NOT NULL,
  Slot INT NOT NULL,
  Quantity INT NOT NULL,
  CONSTRAINT uq_stock UNIQUE (MachineID, ProductID, Loaded, Position, Slot)        
 );
--
CREATE TABLE Sales
 (SaleID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_sales_id PRIMARY KEY,
  StockID INT NOT NULL CONSTRAINT  fk_stock_id FOREIGN KEY REFERENCES Stock(StockID),
  TenderID INT NOT NULL CONSTRAINT fk_tender_id FOREIGN KEY REFERENCES Tender(TenderID),
  SaleDate DATE NOT NULL,
  SaleTime TIME NOT NULL,
  LastItem INT NOT NULL,
  CONSTRAINT ck_last_item CHECK  (LastItem = 0 OR LastItem = 1),
  CONSTRAINT uq_sale UNIQUE (StockID, SaleDate, SaleTime)        
 );
--
CREATE TABLE Building
 (BuildingID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_building_id PRIMARY KEY,
  CampusID INT CONSTRAINT fk_campus_id FOREIGN KEY REFERENCES Campus(CampusID),
  DepartmentID INT CONSTRAINT fk_department_id FOREIGN KEY REFERENCES Department(DepartmentID),
  DayNameID INT CONSTRAINT fk_day_name_id FOREIGN KEY REFERENCES DayName(DayNameID),
  Name  NVARCHAR(75) NOT NULL,
  Floors INT NOT NULL,
  CONSTRAINT ck_floors CHECK  (Floors < 15),
 );
--
CREATE TABLE BuildingMachine
 (BuildingMachineID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_building_machine_id PRIMARY KEY,
  BuildingID INT CONSTRAINT fk_building_id FOREIGN KEY REFERENCES Building(BuildingID),
  MachineID INT CONSTRAINT fk_machine_id FOREIGN KEY REFERENCES Machine(MachineID),
  Floor INT NOT NULL,
  CONSTRAINT ck_floor CHECK  (Floor < 15),
 ); 

-- Helper Tables Will Drop When Full Load Is Complete
CREATE TABLE BuildingLoad
 (BuildingID INT CONSTRAINT fk_load_building_id FOREIGN KEY REFERENCES Building(BuildingID),
  Floor INT NOT NULL,
  SnackCount INT NOT NULL,
  DrinkCount INT NOT NULL,
  EnergyCount INT NOT NULL,
 ); 

-- 
 CREATE TABLE SalesLoad
 (ModelID INT CONSTRAINT fk_sale_model_id FOREIGN KEY REFERENCES Model(ModelID),
  WeekdayPriLow INT NOT NULL,
  WeekdayPriHigh INT NOT NULL,
  WeekdaySecLow INT NOT NULL,
  WeekdaySecHigh INT NOT NULL,
  WeekendPriLow INT NOT NULL,
  WeekendPriHigh INT NOT NULL,
  WeekendSecLow INT NOT NULL,
  WeekendSecHigh INT NOT NULL
 ); 
 
-- 
 CREATE TABLE SaleTimes
 (SaleTime TIME NOT NULL,
 CONSTRAINT uq_sale_time UNIQUE (SaleTime)        
 );
 -- 
 CREATE TABLE WeightTenders
 (TenderID INT CONSTRAINT fk_stack_tender_id FOREIGN KEY REFERENCES Tender(TenderID),
 );

-- ------------------------------------------------------------------------------------
-- Load table data
-- ------------------------------------------------------------------------------------

-- 
INSERT INTO DayName (Name) VALUES 
('Sunday'),
('Monday'),
('Tuesday'),
('Wednesday'),
('Thursday'),
('Friday'),
('Saturday');

-- 
INSERT INTO Campus (Name) VALUES 
('Technology University of James Denver');

-- 
INSERT INTO Department (Name) VALUES 
('Engineering'),
('Business'),
('Mathematics'),
('Biology'),
('Chemistry'),
('Music'),
('Psychology'),
('Physics'),
('History'),
('Education');

--
INSERT INTO Building (CampusID, DepartmentID, DayNameID, Name, Floors) VALUES 
(1, 2, 2, 'Daniels', 3),
(1, 3, 2, 'Jefferson', 6),
(1, 8, 2, 'Hamilton', 5),
(1, 1, 2, 'Norris', 4),
(1, 9, 3, 'Cribbs Hall', 8),
(1, 4, 6, 'Dabny', 3),
(1, 8, 4, 'Prichard', 13),
(1, 10, 6, 'Cruthers', 4),
(1, 10, 5, 'Ambler Johnston', 12),
(1, 5, 3, 'Driscoll North', 3),
(1, 5, 3, 'Driscoll South', 3),
(1, 6, 6, 'Aspen Hall', 6),
(1, 6, 2, 'Vail Hall', 3),
(1, 7, 6, 'Harrison', 3),
(1, 1, 6, 'Wilson', 4),
(1, 7, 6, 'Madison', 3),
(1, 2, 6, 'Margery Reed', 4);

--
INSERT INTO Manufacturer (Name) VALUES 
-- Candy Manufacturers https://www.candystore.com/brands/
('American Licorice'),
('Ce De Candy Candy'),
('Claey''s Candy'),
('Farley''s & Sathers'),
('Ferrara Pan Candy'),
('Haribo Candy'),
('Hershey''s'),
('JustBorn Candy'),
('Mars Candy'),
('Necco Candy'),
('Nestle Candy'),
('Sour Patch Kids'),
('Swedish Fish'),
('Wrigley Candy'),
-- Chips & Cookies
('Utz'),
('Frito-Lay'),
('Nibisco'),
('Planters'),
-- Drinks
('Coke-Cola'),
('Redbull'),
('Gatorade');

-- 
INSERT INTO Brand (Name) VALUES 
('M&Ms'),
('Funyuns'),
('RedBull'),
('Coke'),
('Utz'),
('Snickers'),
('Oreo'),
('Reeses'),
('Twizzlers'),
('Hershey''s'),
('MilkyWay'),
('LifeSavers'),
('Grandma''s'),
('Twix'),
('Powerade'),
('Sprite'),
('Dr Pepper'),
('Zapps'),
('Red Vines'),
('Sour Punch'),
('Smarties'),
('Chuckles'),
('Jujubes'),
('Black Forest'),
('Fruit Stripe'),
('Gold Bears'),
('Kit-Kat'),
('Bubble Yum'),
('Whatchamacallit'),
('Skor'),
('Mounds'),
('Almond Joy'),
('Mr. Goodbar'),
('PayDay'),
('Whoppers'),
('Krackle'),
('Heath'),
('Rolo'),
('Take 5'),
('Hot Tamales'),
('Mike & Ike'),
('Starburst'),
('Skittles'),
('3 Musketeers'),
('100 Grand'),
('Baby Ruth'),
('Nestle Crunch '),
('Nerds'),
('Butterfinger'),
('Sour Patch Kids'),
('Swedish Fish'),
('Big Red'),
('Juciy Fruit'),
('Doublemint'),
('Wrigley''s 5'),
('Lays'),
('Cheetos'),
('Doritos'),
('Sun Chips'),
('Fritos'),
('Wheat Thins'),
('Chips Ahoy'),
('Planters'),
('Barq''s'),
('Dasani'),
('Mello Yellow'),
('Gatorade');

--
INSERT INTO ProductType (Description) VALUES 
('Candy'),
('Canned Soda'),
('Bottled Soda'),
('Chips'),
('Crackers & Peanuts'),
('Cookies'),
('Energy Drinks'),
('Gum'),
('Bottled Water'),
('Bottled Sports Drink');

--
INSERT INTO SlotSize (Description) VALUES 
('Small'),
('Medium'),
('Large'),
('<12oz'),
('<24oz'),
('<12oz Energy');

--
INSERT INTO Shelf (ModelName, Description, Slots, SlotSizeID, Quantity) VALUES
('CAC17','Large slots for oversized items.',4,3,12),
('S13','Standard Shelf.',8,2,15),
('GS42','Small slots for gum and other smal items.',12,1,17),
('CD7','Canned Drink holder',1,4,45),
('CD8','Bottled Drink holder',9,5,14),
('ED8','Energy Drink Holder',11,4,13);

--
INSERT INTO ModelType (Description) VALUES 
('Snacks'),
('Canned Drinks'),
('Bottled Drinks'),
('Energy Drinks');

--
INSERT INTO Model (Name, ModelTypeID, Cash, CreditCard, MobilePay) VALUES
('Snacks-n-More', 1, 1, 0, 0), 
('Snacks-n-More Gen 2', 1, 1, 1, 0), 
('Snacks-n-More Gen 3', 1, 1, 1, 1), 
('Caninator', 2, 1, 1, 0), 
('Caninator Xlr8ed', 2, 1, 1, 1),
('Bottleinator Xlr8ed', 3, 1, 1, 1),
('Energy Xlr8ed', 4, 1, 1, 1);

-- 
INSERT INTO ModelShelf (ModelID, ShelfID, Position) VALUES
(1, 1, 1),
(1, 1, 2),
(1, 2, 3),
(1, 2, 4),
(1, 2, 5),
(1, 2, 6),
(2, 1, 1),
(2, 1, 2),
(2, 2, 3),
(2, 2, 4),
(2, 2, 5),
(2, 1, 6),
(2, 3, 7),
(3, 1, 1),
(3, 1, 2),
(3, 2, 3),
(3, 2, 4),
(3, 2, 5),
(3, 2, 6),
(3, 3, 7),
(4, 4, 1),
(4, 4, 2),
(4, 4, 3),
(4, 4, 4),
(4, 4, 5),
(4, 4, 6),
(4, 4, 7),
(4, 4, 8),
(4, 4, 9),
(4, 4, 10),
(5, 4, 1),
(5, 4, 2),
(5, 4, 3),
(5, 4, 4),
(5, 4, 5),
(5, 4, 6),
(5, 4, 7),
(5, 4, 8),
(5, 4, 9),
(5, 4, 10),
(6, 5, 1),
(6, 5, 2),
(6, 5, 3),
(6, 5, 4),
(6, 5, 5),
(6, 5, 6),
(7, 4, 1),
(7, 4, 2),
(7, 4, 3),
(7, 4, 4),
(7, 4, 5),
(7, 4, 6),
(7, 4, 7),
(7, 4, 8);

--
INSERT INTO Tender (Name) VALUES 
('Cash'),
('Visa'),
('MasterCard'),
('Amex'),
('Discover'),
('Apple Pay'),
('Android Pay');

-- Helping Table To Allow Dynamic Loading
INSERT INTO BuildingLoad (BuildingID, Floor, SnackCount, DrinkCount, EnergyCount) VALUES 
(1, 1, 1, 2, 1),
(1, 2, 0, 0, 0),
(1, 3, 0, 0, 0),
(2, 1, 1, 2, 1),
(2, 2, 0, 0, 0),
(2, 3, 0, 0, 0),
(2, 4, 1, 2, 0),
(2, 5, 0, 0, 0),
(2, 6, 0, 0, 0),
(3, 1, 2, 2, 0),
(3, 2, 0, 0, 0),
(3, 3, 0, 0, 0),
(3, 4, 0, 0, 0),
(3, 5, 0, 0, 0),
(4, 1, 2, 4, 1),
(4, 2, 0, 0, 0),
(4, 3, 2, 4, 1),
(4, 4, 0, 0, 0),
(5, 1, 1, 1, 1),
(5, 2, 1, 1, 0),
(5, 3, 1, 1, 1),
(5, 4, 1, 1, 0),
(5, 5, 1, 1, 1),
(5, 6, 1, 1, 0),
(5, 7, 1, 1, 1),
(5, 8, 1, 1, 0),
(6, 1, 1, 1, 0),
(6, 2, 0, 0, 0),
(6, 3, 0, 0, 0),
(7, 1, 1, 1, 1),
(7, 2, 1, 1, 0),
(7, 3, 1, 1, 0),
(7, 4, 1, 1, 1),
(7, 5, 1, 1, 0),
(7, 6, 1, 1, 0),
(7, 7, 1, 1, 1),
(7, 8, 1, 1, 1),
(7, 9, 1, 1, 0),
(7, 10, 1, 1, 1),
(7, 11, 1, 1, 0),
(7, 12, 1, 1, 0),
(7, 13, 1, 1, 1),
(8, 1, 2, 2, 0),
(8, 2, 0, 0, 0),
(8, 3, 0, 0, 0),
(8, 4, 0, 0, 0),
(9, 1, 1, 1, 1),
(9, 2, 1, 1, 0),
(9, 3, 1, 1, 1),
(9, 4, 1, 1, 0),
(9, 5, 1, 1, 1),
(9, 6, 1, 1, 0),
(9, 7, 1, 1, 1),
(9, 8, 1, 1, 0),
(9, 9, 1, 1, 1),
(9, 10, 1, 1, 0),
(9, 11, 1, 1, 1),
(9, 12, 1, 1, 0),
(10, 1, 1, 1, 1),
(10, 2, 1, 1, 0),
(10, 3, 1, 1, 0),
(11, 1, 2, 2, 1),
(11, 2, 0, 0, 0),
(11, 3, 1, 1, 1),
(12, 1, 1, 1, 1),
(12, 2, 1, 1, 0),
(12, 3, 1, 1, 0),
(12, 4, 1, 1, 0),
(12, 5, 1, 1, 0),
(12, 6, 1, 1, 0),
(13, 1, 1, 1, 0),
(13, 2, 0, 0, 0),
(13, 3, 0, 0, 0),
(14, 1, 1, 1, 1),
(14, 2, 0, 0, 0),
(14, 3, 0, 0, 0),
(15, 1, 2, 1, 1),
(15, 2, 0, 0, 0),
(15, 3, 0, 0, 0),
(15, 4, 0, 0, 0),
(16, 1, 1, 1, 0),
(16, 2, 0, 0, 0),
(16, 3, 0, 0, 0),
(17, 1, 1, 1, 1),
(17, 2, 0, 0, 0),
(17, 3, 0, 0, 0),
(17, 4, 0, 0, 0);


-- Load Products
INSERT INTO Product (ProductTypeID, BrandID, ManufacturerID, Name, SlotSizeID, Price, Cost) VALUES
('1','19','1','Red Vines','2','1.75','1.24'),
('1','19','1','Red Vines King Size','3','2.5','1.96'),
('1','20','1','Sour Punch Bites - Blue Raspberry','3','2.5','1.33'),
('1','20','1','Sour Punch Bites - Raging Reds','3','2.5','1.33'),
('1','20','1','Sour Punch Bites - Tropical Blend','3','2.5','1.33'),
('1','20','1','Sour Punch Bites ','3','2.5','1.33'),
('1','20','1','Sour Punch Staws Strawberry King Size','3','2.5','1.83'),
('1','20','1','Sour Punch Staws Rainbow King Size','3','2.5','1.83'),
('1','21','2','Mega Smarties','2','1.75','1.21'),
('1',NULL,'3','Claey''s Wild Cherry Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Horehound Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Licorice Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Anise Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Assorted Fruit Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Peppermint Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Green Apple Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Watermelon Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Root Beer Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Sassafras Drop Bags','3','2.5','1.46'),
('1',NULL,'3','Claey''s Cinnamon Drop Bags','3','2.5','1.46'),
('1','22','4','Chuckles','2','1.5','1.17'),
('1','23','4','Jujubes Theatre Boxes','3','2.5','1.92'),
('1','24','5','Black Forest Gummy Bears','3','2.5','1.67'),
('1','24','5','Black Forest Gummy Sharks Filled','3','2.5','1.67'),
('1','24','5','Black Forest Organic Gummy Bears','3','2.5','2.17'),
('1','25','5','Fruit Stripe Gum','1','2.00','1.67'),
('1','26','6','Gold Bears Theater Box','3','2.5','2'),
('1','26','6','Gummi Gold Bears','3','2.5','1.75'),
('1','26','6','Haribo Gold Bears','2','1.5','0.92'),
('1',NULL,'6','Haribo Roulette Candy','1','1','0.44'),
('1',NULL,'6','Gummi Peaches Bag','3','2.25','1.75'),
('1',NULL,'6','Gummi Alphabet Letters Bag','3','2.25','1.75'),
('1',NULL,'6','Gummi Twin Cherries Bag ','3','2.25','1.75'),
('1',NULL,'6','Fizzy Cola Bags','3','2.25','1.75'),
('1',NULL,'6','Smurfs','3','2.25','1.75'),
('1',NULL,'6','Gummi Happy Cola Bottle','3','2.25','1.75'),
('1',NULL,'6','Gummi Fruit Salad','3','2.25','1.75'),
('1',NULL,'6','German Raspberries','3','2.25','1.75'),
('1',NULL,'6','Gummi Frogs','3','2.25','1.75'),
('1','10','7','Hershey''s Standard Bar','2','1.5','0.86'),
('1','10','7','Hershey;s Almond Bar','2','1.5','0.86'),
('1','10','7','Hershey''s Special Dark Bar','2','1.5','0.86'),
('1','10','7','Hershey''s Cookies N Cream Bar','2','1.5','0.86'),
('1','28','7','Hershey''s Gold Bar','1','1.5','0.86'),
('1','8','7','Reeses Peanut Butter Cup','2','1.5','0.86'),
('1','8','7','Reeses Peanut Butter Cup - Crunchy','2','1.5','0.86'),
('1','8','7','Reeses Big Cup','1','1.25','0.77'),
('1','8','7','Kit-Kat','2','1.5','0.86'),
('1','8','7','Kit-Kat - White Chocolate','2','1.5','0.86'),
('1','8','7','Kit-Kat - Dark','2','1.5','0.86'),
('1',NULL,'7','Milk Duds Packs','2','1.5','1.04'),
('8','28','7','Original Bubble Yum','1','1.25','0.83'),
('8','28','7','Original Bubble Yum - Sugarless','1','2.00','1.58'),
('8','28','7','Cotton Candy Bubble Yum','1','1.25','0.83'),
('8','28','7','Stawberry Bubble Yum','1','1.25','0.83'),
('8','28','7','Grape Bubble Yum','1','1.25','0.83'),
('8','28','7','Wild Cherry Bubble Yum','1','1.25','0.83'),
('8','28','7','Wild Cherry Bubble Yum - Sugar Free','1','1.25','0.83'),
('1','29','7','Whatchamacallit','2','1.5','0.97'),
('1','30','7','Skor','2','1.5','1.11'),
('1','31','7','Mounds','2','1.5','0.97'),
('1','32','7','Almond Joy','2','1.5','0.97'),
('1','33','7','Mr. Goodbar','2','1.5','0.97'),
('1','34','7','PayDay','2','1.5','0.97'),
('1','35','7','Whoppers Bag','2','1.75','1.13'),
('1','36','7','Krackle Bar','2','1.5','0.97'),
('1','37','7','Heath Bar','2','1.5','1.02'),
('1','38','7','Rolo','2','1.5','0.95'),
('1','8','7','Reeses Pieces Theater Box','3','2.5','1.67'),
('1','8','7','Reeses Pieces Bag','2','1.5','0.96'),
('1','39','7','Take 5','2','1.5','1.02'),
('1','9','7','Twizzlers','2','1.5','1.02'),
('1','9','7','Twizzlers Nibs','2','1.5','0.98'),
('1','9','7','Twizzlers Nibs Theater Bag','2','2.5','1.96'),
('1','9','7','Twizzlers Nibs Theater Bag - Licorice','2','2.5','1.96'),
('1','9','7','Twizzlers - Pull & Peal','2','1.5','1.06'),
('1','9','7','Twizzlers Theater Bag','3','2.5','1.72'),
('1','40','8','Hot Tamales','2','1.5','1.1'),
('1','41','8','Mike & Ike','2','1.5','1.1'),
('1','41','8','Mike & Ike Theater Boxes','3','2.5','1.94'),
('1','6','9','Snckers Bar','2','1.5','0.98'),
('1','6','9','Snckers Midnight Bar','2','1.5','0.98'),
('1','6','9','Snckers Peanut Butter Bar','2','1.5','0.98'),
('1','6','9','Snckers Crispers','2','1.5','0.98'),
('1','11','9','MIlkyWay','2','1.5','0.98'),
('1','11','9','MIlkyWay Simply Carmel','2','1.5','0.98'),
('1','44','9','3 Musketeers','2','1.5','0.98'),
('1','14','9','Twix','2','1.5','0.98'),
('1','14','9','Twix Peanut Butter','2','1.5','0.98'),
('1','14','9','Twix Dark','2','1.5','0.98'),
('1','1','9','M&Ms Milk Chocolate','2','1.5','0.98'),
('1','1','9','M&Ms Milk Chocolate Tear & Share','3','2.25','1.42'),
('1','1','9','M&Ms Peanut','2','1.5','0.98'),
('1','1','9','M&Ms Peanut Tear & Share','3','2.25','1.42'),
('1','1','9','M&Ms Peanut Butter','2','1.5','0.98'),
('1','1','9','M&Ms Almond','2','1.5','0.98'),
('1','1','9','M&Ms Mint','2','1.5','0.98'),
('1','1','9','M&Ms Carmel','2','1.5','0.98'),
('1','1','9','M&Ms Crispy','2','1.5','0.98'),
('1','1','9','M&Ms Dark','2','1.5','0.98'),
('1','1','9','M&Ms Pretzel','2','1.5','0.98'),
('1','1','9','M&Ms Pretzel Theater Box','3','2.5','1.47'),
('1','42','9','Starburst Fruit Chews','2','1.5','1.03'),
('1','42','9','Starburst Fruit Chews Tropical','2','1.5','1.03'),
('1','42','9','Starburst FaveReds','3','1.5','1.03'),
('1','42','9','Starburst Minis Theater Box','3','2.5','1.94'),
('1','43','9','Skittles','2','1.5','0.99'),
('1','43','9','Skittles Sour','2','1.5','0.99'),
('1','43','9','Skittles Tropical','2','1.5','0.99'),
('1','43','9','Skittles Sweet & Sour Theater Box','3','2.5','1.67'),
('1','43','9','Skittles Wild Berry','2','1.5','0.99'),
('1',NULL,'10','Necco Wafers','2','1.5','1.05'),
('1','45','11','100 Grand','2','1.5','0.97'),
('1','46','11','Baby Ruth','2','1.5','0.98'),
('1','47','11','Nestle Crunch Bar','2','1.5','0.98'),
('1','47','11','Nestle Crunch Carmel Bar','2','1.5','0.99'),
('1','48','11','Nerds - Cherry N Grape','2','1.5','1.04'),
('1','49','11','Butterfinger','2','1.5','0.95'),
('1','50','12','Sour Patch Kids ','2','1.5','0.93'),
('1','50','12','Sour Patch Kids Watermellon','2','1.5','0.96'),
('1','50','12','Sour Patch Kids Fire','2','1.5','0.96'),
('1','50','12','Sour Patch Kids Tropical','2','1.5','0.96'),
('1','50','12','Sour Patch Kids Strawberry','2','1.5','0.96'),
('1','50','12','Sour Patch Kids MixUp','2','1.5','0.96'),
('1','50','12','Sour Patch Kids Big Kids','3','2.5','1.63'),
('1','51','13','The Original Swedish Fish Red','3','2.5','1.87'),
('1','51','13','Mini Swedish Fish Red','2','1.5','1.13'),
('8','52','14','Big Red','1','1','0.65'),
('8','52','14','Big Red Big Pack','1','1.5','0.88'),
('8','53','14','Juciy Fruit','1','1','0.65'),
('8','53','14','Juciy Fruit Big Pack','1','1.5','0.88'),
('8','54','14','Doublemint','1','1','0.65'),
('8','54','14','Doublemint Big Pack','1','1.5','0.88'),
('8',NULL,'14','Spearmint','1','1','0.65'),
('8',NULL,'14','Spearmint Big Pack','1','1.5','0.88'),
('8',NULL,'14','Winterfresh','1','1','0.65'),
('8',NULL,'14','Winterfresh Big Pack','1','1.5','0.88'),
('8','55','14','Cobolt','1','1.5','0.92'),
('8','55','14','Prism','1','1.5','0.92'),
('8','55','14','Rain','1','1.5','0.92'),
('8','55','14','React','1','1.5','0.92'),
('8','55','14','RPM Sugarfree','1','1.5','0.92'),
('1','12','14','LifeSavers 5 Flavors','1','1.25','0.87'),
('1','12','14','LifeSavers Wild Chery','1','1.25','0.87'),
('1','12','14','LifeSavers Butter Run','1','1.25','0.87'),
('1','12','14','LifeSavers Wint O Green','1','1.25','0.87'),
('4','18','15','Salt & Vinegar','3','1.25','0.59'),
('4','18','15','Sweet Pimento Cream Cheese','3','1.25','0.59'),
('4','18','15','Mesquite Bar-B-Que','3','1.25','0.59'),
('4','18','15','Bar-B-Que Ranch','3','1.25','0.59'),
('4','18','15','Sour Cream & Creole Onion','3','1.25','0.59'),
('4','18','15','Spicy Cajun Crawtators Limited Edition','3','1.25','0.59'),
('4','18','15','VooDoo','3','1.25','0.59'),
('4','18','15','No Salt Added','3','1.25','0.59'),
('4','18','15','Sweet Creole Onion','3','1.25','0.59'),
('4','18','15','Hotter''n Hot Jalapeno','3','1.25','0.59'),
('4','18','15','Spicy Cajun Crawtators','3','1.25','0.59'),
('4','18','15','VooDoo Heat','3','1.25','0.59'),
('4','18','15','Regular Flavor','3','1.25','0.59'),
('4','18','15','Cajun Dill Gator-Tators','3','1.25','0.59'),
('4','5','15','Original ','3','1.25','0.42'),
('4','5','15','Sour Cream & Onion','3','1.25','0.42'),
('4','5','15','Salt & Viniger','3','1.25','0.42'),
('4','5','15','Barbecue','3','1.25','0.42'),
('4','5','15','Grandma','3','1.25','0.42'),
('4','5','15','Ripple Cut','3','1.25','0.42'),
('4','5','15','Pretzel Sourdough Hards','3','1.5','0.88'),
('4','5','15','Pretzel Thins','3','1.5','0.88'),
('6','13','16','Chocolate Chip','2','1.00','0.46'),
('6','13','16','Chocolate Brownie','2','1.00','0.46'),
('6','13','16','Oatmeal Rasin','2','1.00','0.46'),
('6','13','16','Peanut Butter','2','1.00','0.46'),
('6','13','16','Mini Chocolate Chip','3','1.75','0.88'),
('6','13','16','Mini Sandwich Creams','3','1.75','0.88'),
('4','56','16','Classic','3','1.75','0.76'),
('4','56','16','Cheddar & Sour Cream','3','1.75','0.76'),
('4','56','16','Barbecue','3','1.75','0.76'),
('4','56','16','Chile Limon','3','1.75','0.76'),
('4','56','16','Deli Style','3','1.75','0.76'),
('4','56','16','Dill Pickle','3','1.75','0.76'),
('4','56','16','Flaming Hot','3','1.75','0.76'),
('4','56','16','Honey Barbecue','3','1.75','0.76'),
('4','56','16','Lightly Salted','3','1.75','0.76'),
('4','56','16','Baked Original','3','1.75','0.76'),
('4','56','16','Salt & Viniger','3','1.75','0.76'),
('4','56','16','White Cheddar','3','1.75','0.76'),
('4','56','16','Sour Cream & Onion','3','1.75','0.76'),
('4','56','16','Kettle Cooked Original','3','1.75','0.82'),
('4','56','16','Kettle Cooked Jalapeno','3','1.75','0.82'),
('4','56','16','Kettle Cooked Olive & Herb','3','1.75','0.82'),
('4','57','16','Cheetos','3','1.75','0.76'),
('4','57','16','Cheetos Flamin Hot','3','1.75','0.76'),
('4','57','16','Cheetos Puffs','3','1.75','0.76'),
('4','57','16','Cheetos Jalapeno','3','1.75','0.76'),
('4','57','16','Cheetos','2','1.25','0.46'),
('4','57','16','Cheetos Flamin Hot','2','1.25','0.46'),
('4','57','16','Cheetos Puffs','2','1.25','0.46'),
('4','57','16','Cheetos Jalapeno','2','1.25','0.46'),
('4','58','16','Nacho Cheese','3','1.75','0.77'),
('4','58','16','Cool Ranch','3','1.75','0.77'),
('4','58','16','Blaze','3','1.75','0.77'),
('4','58','16','Spice Nacho','3','1.75','0.77'),
('4','58','16','Salsa Verda','3','1.75','0.77'),
('4','58','16','Spicy Sweet Chili','3','1.75','0.77'),
('4','58','16','Nacho Cheese','2','1.25','0.48'),
('4','58','16','Cool Ranch','2','1.25','0.48'),
('4','58','16','Blaze','2','1.25','0.48'),
('4','58','16','Spice Nacho','2','1.25','0.48'),
('4','58','16','Salsa Verda','2','1.25','0.48'),
('4','58','16','Spicy Sweet Chili','2','1.25','0.48'),
('4','59','16','Original','3','1.25','0.83'),
('4','59','16','French Onion','3','1.25','0.83'),
('4','59','16','Garden Salsa','3','1.25','0.83'),
('4','59','16','Harvest Cheddar','3','1.25','0.83'),
('4','59','16','Sweet Potato & Brown Sugar','3','1.25','0.83'),
('4','60','16','Original','3','1.25','0.69'),
('4','60','16','Chili Cheese','3','1.25','0.69'),
('4','60','16','Classic Ranch','3','1.25','0.69'),
('4','60','16','Flamin Hot','3','1.25','0.69'),
('4','60','16','Honey BBQ','3','1.25','0.69'),
('4','60','16','Lightly Salted','3','1.25','0.69'),
('4','60','16','Scoops','3','1.25','0.69'),
('4','2','16','Funyuns','3','1.25','0.73'),
('4','2','16','Funyuns Flamin Hot','3','1.25','0.73'),
('6','7','17','Oreo','2','1.25','0.67'),
('6','7','17','Oreo Double Stuffed','2','1.25','0.67'),
('6','7','17','Oreo Golden','2','1.25','0.67'),
('6','7','17','Oreo Golden Double Stuff','2','1.25','0.67'),
('6','7','17','Mini Oreo Sandwiches','3','2.00','1.13'),
('6','7','17','Oreo Thins','2','1.25','0.63'),
('5','61','17','Wheat Thins','2','1.25','0.65'),
('5','61','17','Wheat Thins Reduced Fat','2','1.25','0.65'),
('5','61','17','Wheat Thins Ranch','2','1.25','0.65'),
('6','62','17','Chips Ahoy','2','1.25','0.60'),
('6','62','17','Chips Ahoy Chewy','2','1.25','0.60'),
('6','62','17','Chips Ahoy Chunks','2','1.25','0.60'),
('5','63','18','Peanuts Salted','1','1.25','0.57'),
('5','63','18','Peanuts Lighly Salted','1','1.25','0.57'),
('5','63','18','Peanuts Honey Roasted','1','1.25','0.57'),
('5','63','18','Peanuts Unsalted','1','1.25','0.57'),
('5','63','18','Peanuts Salted','2','1.50','0.73'),
('5','63','18','Peanuts Lighly Salted','2','1.50','0.73'),
('5','63','18','Peanuts Honey Roasted','2','1.50','0.73'),
('5','63','18','Peanuts Unsalted','2','1.50','0.73'),
('2','4','19','Coke 12oz Can','4','1.00','0.49'),
('2','4','19','Diet Coke 12oz Can','4','1.00','0.49'),
('2','4','19','Coke Zero 12oz Can','4','1.00','0.49'),
('2','4','19','Cherry Coke 12oz Can','4','1.00','0.49'),
('2','16','19','Sprite 12oz Can','4','1.00','0.49'),
('2','17','19','Dr Pepper 12oz Can','4','1.00','0.49'),
('2','64','19','Barq''s 12oz Can','4','1.00','0.49'),
('2','66','19','Mellow Yellow 12oz Can','4','1.00','0.49'),
('3','4','19','Coke 20oz Bottle','5','1.75','0.92'),
('3','4','19','Diet Coke 20oz Bottle','5','1.75','0.92'),
('3','4','19','Coke Zero 20oz Bottle','5','1.75','0.92'),
('3','4','19','Cherry Coke 20oz Bottle','5','1.75','0.92'),
('3','16','19','Sprite 20oz Bottle','5','1.75','0.92'),
('3','17','19','Dr Pepper 20oz Bottle','5','1.75','0.92'),
('2','64','19','Barq''s 20oz Bottle','5','1.75','0.92'),
('2','66','19','Mellow Yellow 20oz Bottle','5','1.75','0.92'),
('9','65','19','Dasani 20oz Bottle','5','1.75','0.57'),
('10','15','19','Fruit Punch 24oz','5','2.00','1.03'),
('10','15','19','Orange 24oz','5','2.00','1.03'),
('10','15','19','Grape 24oz','5','2.00','1.03'),
('7','3','20','RedBull 8.4oz','6','2.50','1.26'),
('7','3','20','RedBull Sugar Free 8.4oz ','6','2.50','1.26'),
('7','3','20','RedBull 12oz','6','3.25','1.72'),
('7','3','20','Sugar Free RedBull 12oz','6','3.25','1.72'),
('7','3','20','RedBull Purple Edition 12oz','6','3.25','1.72'),
('7','3','20','RedBull Red Edition 12oz','6','3.25','1.72'),
('7','3','20','RedBull Blue Edition 12oz','6','3.25','1.72'),
('7','3','20','RedBull Yellow Edition 12oz','6','3.25','1.72'),
('7','3','20','RedBull Orange Edition 12oz','6','3.25','1.72'),
('7','3','20','RedBull Green Edition 12oz','6','3.25','1.72'),
('7','3','20','RedBull Total 12oz','6','3.25','1.72'),
('10','67','21','Fruit Punch 20oz','5','2.00','1.01'),
('10','67','21','Orange 20oz','5','2.00','1.01'),
('10','67','21','Grape 20oz','5','2.00','1.01'),
('10','67','21','Stawberry 20oz','5','2.00','1.01'),
('10','67','21','Lemon Lime 20oz','5','2.00','1.01');


-- ------------------------------------------------------------------------------------
-- Dynamic Load Of Machine AND BuildingMachine
-- ------------------------------------------------------------------------------------
DECLARE @building_id INT, @snack_count INT, @drink_count INT, @energy_count INT,
        @model_id INT, @in_service DATE, @building_floors INT, @floor INT, 
        @max_cans INT, @cans INT;

-- Create Cursor For Building Load Data
DECLARE building_load_cursor CURSOR FOR   
SELECT BuildingID, Floor, SnackCount, DrinkCount, EnergyCount
FROM BuildingLoad  
WHERE (SnackCount > 0 
      OR DrinkCount > 0
	  OR EnergyCount > 0 ) 
ORDER BY BuildingID;  

SELECT @max_cans = CEILING((SUM(DrinkCount) * .2)) FROM BuildingLoad;
SET @cans = 0;

OPEN building_load_cursor;

FETCH NEXT FROM building_load_cursor   
INTO @building_id, @floor, @snack_count, @drink_count, @energy_count;

WHILE @@FETCH_STATUS = 0  
BEGIN   
   
   DECLARE @cnt INT = 0;

   -- Make Snack Machines
   WHILE @cnt < @snack_count
   BEGIN
     SELECT Top 1 @model_id  =  ModelID FROM Model WHERE ModelTypeID=1 ORDER BY NEWID();
     SELECT @in_service   = DateAdd(Day, Rand() * DateDiff(Day, @ServiceDateStart, @ServiceDateEnd), @ServiceDateStart);
     INSERT INTO Machine VALUES (@model_id, @in_service);
     INSERT INTO BuildingMachine VALUES (@building_id, @@IDENTITY, @floor);
     SET @cnt = @cnt + 1;
   END;
  
   -- Make Drink Machines
   SET @cnt = 0;
   WHILE @cnt < @drink_count
   BEGIN
     SELECT Top 1 @model_id  =  ModelID FROM Model WHERE ModelTypeID IN (2,3) ORDER BY NEWID();     

     -- Stack Towards Bottles
     IF (@model_id IN (4,5) )
        SET @cans = @cans + 1;

     IF (@cans >= @max_cans) 
         SELECT Top 1 @model_id  =  ModelID FROM Model WHERE ModelTypeID = 3 ORDER BY NEWID();     

     SELECT @in_service   = DateAdd(Day, Rand() * DateDiff(Day, @ServiceDateStart, @ServiceDateEnd), @ServiceDateStart);
     INSERT INTO Machine VALUES (@model_id, @in_service);
     INSERT INTO BuildingMachine VALUES (@building_id, @@IDENTITY, @floor);
     SET @cnt = @cnt + 1;
   END;

   -- Make Enery Machines
   SET @cnt = 0;
   WHILE @cnt < @energy_count
   BEGIN
     SELECT Top 1 @model_id  =  ModelID FROM Model WHERE ModelTypeID=4 ORDER BY NEWID();
     SELECT @in_service   = DateAdd(Day, Rand() * DateDiff(Day, @ServiceDateStart, @ServiceDateEnd), @ServiceDateStart);

     INSERT INTO Machine  (ModelID, InService) VALUES 
     (@model_id, @in_service);

     INSERT INTO BuildingMachine (BuildingID, MachineID, Floor) VALUES 
     (@building_id, @@IDENTITY, @floor);
     
     SET @cnt = @cnt + 1;
   END;

   SET NOCOUNT ON

   FETCH NEXT FROM building_load_cursor 
   INTO @building_id, @floor, @snack_count, @drink_count, @energy_count; 
END

CLOSE  building_load_cursor;
DEALLOCATE building_load_cursor;

-- Clean Up
DROP TABLE BuildingLoad;

-- ------------------------------------------------------------------------------------
-- End Load Machine & BuildingMachine
-- ------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------
-- Dynamic Load Of Stock Information
-- ------------------------------------------------------------------------------------

-- Load Stock
DECLARE @loaded DATE, @day_of_week INT, @machine_id INT,
        @position INT, @slot_size_id INT, @slots INT, @quantity INT, @slot_id INT,
        @slot_loop INT, @product_id INT;

-- Cursors
DECLARE @fetch_load_cursor int
DECLARE @fetch_machine_cursor int
DECLARE @fetch_shelf_cursor int
DECLARE @fetch_slots_cursor int

-- Set The Slot Loop Before We Forget
SET @slot_loop = 0;

-- Get All The Days We Are Doing Loading For   
DECLARE stock_cursor CURSOR FOR   
SELECT Date, DayOfWeek
FROM DimDate
WHERE Date>=@StockDateStart
      AND Date<=@StockDateEnd
      AND IsWeekday = 1
      AND IsHoliday=0
ORDER BY Date;

OPEN stock_cursor;

FETCH NEXT FROM stock_cursor   
INTO @loaded, @day_of_week;
SET @fetch_load_cursor = @@FETCH_STATUS
   
WHILE @fetch_load_cursor = 0  
BEGIN   
   
      -- Debug Loading For 
      -- SELECT @loaded, @day_of_week;

      -- Get All the Machines THat Need Loading
      DECLARE machines_cursor CURSOR FOR   
      SELECT m.MachineID
      FROM Machine AS m 
      INNER JOIN BuildingMachine AS bm ON bm.MachineID=m.MachineID
      INNER JOIN Building AS b ON b.BuildingID=bm.BuildingID
      WHERE DayNameID=@day_of_week;

      OPEN machines_cursor;

      FETCH NEXT FROM machines_cursor   
      INTO @machine_id;

      SET @fetch_machine_cursor = @@FETCH_STATUS
      
      WHILE @fetch_machine_cursor = 0  
      BEGIN
           -- Debug  
           -- SELECT @machine_id;

           -- Get The Shelfs The Machine Has
           DECLARE shelf_cursor CURSOR FOR   
           SELECT Position, SlotSizeID, Slots, Quantity 
           FROM Shelf AS s
           INNER JOIN ModelShelf AS ms ON ms.ShelfID = s.ShelfID
           INNER JOIN Model AS md ON md.ModelID = ms.ModelID
           INNER JOIN Machine AS m ON m.ModelID = md.ModelID
           WHERE m.MachineID=@machine_id
           
           OPEN shelf_cursor;
           
           FETCH NEXT FROM shelf_cursor   
           INTO @position, @slot_size_id, @slots, @quantity;

           SET @fetch_shelf_cursor = @@FETCH_STATUS
      
           WHILE @fetch_shelf_cursor = 0  
           BEGIN
                -- Loop Through Slots
                WHILE (@slot_loop < @slots)
                BEGIN
                   -- Increment The Slot Counter Loop
                   SET @slot_loop = @slot_loop + 1;
                   
                   -- Debug
                   -- SELECT 'Loading Slot',@slot_loop
                   
                   -- Select A Product For The Slot
                   SELECT TOP 1 @product_id = ProductID
                   FROM Product 
                   WHERE SlotSizeID=@slot_size_id 
                   ORDER BY NEWID();
                   
                   -- Stock The Slot
                   INSERT INTO Stock (MachineId, ProductID, Loaded, Position, Slot, Quantity)
                   VALUES (@machine_id, @product_id, @loaded, @position, @slot_loop, @quantity);

                END
                SET @slot_loop = 0;
                
                -- Get Next Shelf Record 
                FETCH NEXT FROM shelf_cursor INTO @position, @slot_size_id, @slots, @quantity; 
                SET @fetch_shelf_cursor = @@FETCH_STATUS
           END
           
           CLOSE  shelf_cursor;
           DEALLOCATE shelf_cursor;
      
           FETCH NEXT FROM machines_cursor INTO @machine_id; 
           SET @fetch_machine_cursor = @@FETCH_STATUS
      END

      CLOSE  machines_cursor;
      DEALLOCATE machines_cursor;

   FETCH NEXT FROM stock_cursor INTO @loaded, @day_of_week; 
   SET @fetch_load_cursor = @@FETCH_STATUS
END

CLOSE  stock_cursor;
DEALLOCATE stock_cursor;

-- ------------------------------------------------------------------------------------
-- End Load Stock
-- ------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------
-- Dynamic Load Of Sales Transactions
-- ------------------------------------------------------------------------------------

-- Set Sale Boundaries Based on Model ... Skew to newer models getting more sales
INSERT INTO SalesLoad (ModelID, WeekdayPriLow, WeekdayPriHigh, WeekdaySecLow, WeekdaySecHigh, 
                       WeekendPriLow, WeekendPriHigh, WeekendSecLow, WeekendSecHigh) VALUES
(1, 6, 60, 2, 30, 3, 20, 1, 15),
(2, 16, 70, 4, 30, 5, 30, 3, 25),
(3, 26, 80, 6, 40, 7, 40, 5, 20),
(4, 6, 40, 6, 20, 2, 20, 1, 8),
(5, 10, 60, 8, 30, 4, 25, 2, 10),
(6, 20, 100, 13, 80, 6, 30, 3, 13),
(7, 2, 40, 2, 20, 1, 13, 0, 6);

-- Create Table to Weight tender types in favor of mobile pay
INSERT INTO WeightTenders (TenderID) VALUES 
(1),
(1),
(1),
(2),
(2),
(2),
(3),
(3),
(3),
(4),
(5),
(6),
(6),
(6),
(6),
(6),
(7),
(7),
(7),
(7);


-- Do the real work To Load Sales Here
-- Declare Vars We Will Need: Doing By Line for Clarity
DECLARE @sale_day DATE, @is_weekday INT, @is_holiday INT;
DECLARE @accept_credit INT, @accept_mobile INT;
DECLARE @primarySales INT, @secondarySales INT;
DECLARE @holiday_multiplier FLOAT;
DECLARE @start_stock_window DATE, @end_stock_window DATE;
DECLARE @sale_time TIME, @stock_id INT, @remainder INT, @last_item INT;
DECLARE @tender_id INT;

-- Debug
--DECLARE @machine_count INT, @sale_count INT;

-- Cursors
DECLARE @fetch_sale_day_cursor INT
DECLARE @fetch_machine2_cursor INT
DECLARE @fetch_sale_time_cursor INT

-- Get All The Days We Are Doing Loading For   
DECLARE sale_day_cursor CURSOR FOR   
SELECT Date, IsWeekday, IsHoliday
FROM DimDate
WHERE Date>=@SaleDateStart
      AND Date<=@SaleDateEnd
ORDER BY Date;

OPEN sale_day_cursor;

FETCH NEXT FROM sale_day_cursor   
INTO @sale_day, @is_weekday, @is_holiday;

SET @fetch_sale_day_cursor = @@FETCH_STATUS
   
WHILE @fetch_sale_day_cursor = 0  
BEGIN   

   -- Debug 
   -- SELECT @sale_day AS SaleDate ,  @is_weekday AS IsWeekday, @is_holiday AS IsHoliday;
   -- SET @machine_count=0;
   
   --
   -- Get All The Days We Are Doing Loading For   
   --
   DECLARE machine_cursor CURSOR FOR   
   SELECT MachineID, m.ModelID, CreditCard, MobilePay
   FROM Machine AS m 
   INNER JOIN Model AS md ON md.ModelID=m.ModelID;
   
   OPEN machine_cursor;

   FETCH NEXT FROM machine_cursor   
   INTO @machine_id, @model_id, @accept_credit, @accept_mobile;

   SET @fetch_machine2_cursor = @@FETCH_STATUS
   
   WHILE @fetch_machine2_cursor = 0  
   BEGIN   
       -- Debug
       -- SELECT @machine_id AS MachineID, @model_id AS ModelID;

       -- Calculate Sale Qty

        IF (@is_weekday = 1)
           BEGIN
               -- Get A Weekday Primary Sales Count #
               SELECT @primarySales = CAST(((WeekdayPriHigh +1) - WeekdayPriLow) * RAND(CHECKSUM(NEWID()) + WeekdayPriLow) AS INT)
               FROM SalesLoad
               WHERE ModelID = @model_id;

               -- Get A Weekend Secondary Sales Count #
               SELECT @secondarySales = CAST(((WeekdaySecHigh +1) - WeekdaySecLow) * RAND(CHECKSUM(NEWID()) + WeekdaySecLow) AS INT)
               FROM SalesLoad
               WHERE ModelID = @model_id;
            END
        ELSE
           BEGIN
               -- Get A Weekend Primary Sales Count #
               SELECT @primarySales = CAST(((WeekendPriHigh +1) - WeekendPriLow) * RAND(CHECKSUM(NEWID()) + WeekendPriLow) AS INT)
               FROM SalesLoad
               WHERE ModelID = @model_id;

               -- Get A Weekend Secondary Sales Count #
               SELECT @secondarySales = CAST(((WeekendSecHigh +1) - WeekendSecLow) * RAND(CHECKSUM(NEWID()) + WeekendSecLow) AS INT)
               FROM SalesLoad
               WHERE ModelID = @model_id;
            END

        -- Reduce Sales If Holiday
        IF (@is_holiday = 1)
            SET @holiday_multiplier = CAST(50 AS FLOAT) / CAST(100 AS FLOAT);
        ELSE
            SET @holiday_multiplier=1
            
        -- Run Through Sales Adjuster
        SET @primarySales = FLOOR(@primarySales * @holiday_multiplier);
        SET @secondarySales = FLOOR(@secondarySales * @holiday_multiplier);

        -- Calculate THe Stocking Window
        SELECT Top 1 @start_stock_window = Loaded FROM Stock WHERE MachineID=@machine_id AND Loaded <= @sale_day;
        SELECT Top 1 @end_stock_window = Loaded FROM Stock WHERE MachineID=@machine_id AND Loaded > @sale_day;
        
        -- Debug
        -- SELECT @machine_id AS MachineID, @model_id AS ModelID, @primarySales PrimarySales, @secondarySales SecondarySales;
 
        -- Create Sale Times
        TRUNCATE TABLE SaleTimes;
        INSERT INTO SaleTimes SELECT TOP (@primarySales) Time FROM DimTime WHERE MilitaryHour>=9 AND MilitaryHour<17 ORDER BY NEWID();
        INSERT INTO SaleTimes SELECT TOP (@secondarySales) Time FROM DimTime WHERE MilitaryHour<9 OR MilitaryHour>=17 ORDER BY NEWID();

        -- Create A Cursor For All Our Sale Times
        DECLARE sale_time_cursor CURSOR FOR   
        SELECT DISTINCT SaleTime
        FROM SaleTimes
        ORDER BY SaleTime;
        
        -- DEBUG
        -- SET @sale_count=0;
        
        OPEN sale_time_cursor;
        
        FETCH NEXT FROM sale_time_cursor   
        INTO @sale_time;

        SET @fetch_sale_time_cursor = @@FETCH_STATUS
   
        WHILE @fetch_sale_time_cursor = 0  
        BEGIN   
           -- Debug
           -- SELECT @machine_id AS MachineID, @sale_time AS SaleTime;

           -- Select A StockID To Sell with Remainder
           SELECT TOP 1  
                   @stock_id  = s.StockID,
                   @remainder = (Quantity - (SELECT count(*) FROM Sales AS sl WHERE sl.StockID = s.StockID)) 
           FROM Stock AS s
           WHERE MachineID=@machine_id
                AND Loaded >= @start_stock_window
                AND Loaded < @end_stock_window 
           	    AND (Quantity - (SELECT count(*) FROM Sales AS sl WHERE sl.StockID = s.StockID)) > 0
           ORDER BY NEWID();

           -- Check that We actually Found An Item TO SELL
           IF ( ISNULL(@stock_id,1) = 1)
           BEGIN
             -- Debug
             -- SELECT 'No Item Found To Sell';
             FETCH NEXT FROM sale_time_cursor INTO @sale_time; 
             SET @fetch_sale_time_cursor = @@FETCH_STATUS
             BREAK;
           END
          
           -- Determine If This Is the Last Item
           IF (@remainder =1)
             SET @last_item=1;
           ELSE
             SET @last_item=0;
                      
           -- Debug
           -- SELECT 'SELL', @stock_id, @remainder;
           
           -- Pick A Tender: Weighted Towards Mobile & Credit
           IF (@accept_credit=1 AND @accept_mobile=1) 
          	  SELECT TOP 1 @tender_id = TenderID FROM WeightTenders ORDER BY NEWID();

           IF (@accept_credit=1 AND @accept_mobile=0)  
          	  SELECT TOP 1 @tender_id = TenderID FROM WeightTenders WHERE TenderID NOT IN (6,7) ORDER BY NEWID();

           IF (@accept_credit=0 AND @accept_mobile=0)  
          	  SELECT TOP 1 @tender_id = TenderID  FROM WeightTenders WHERE TenderID =1 ORDER BY NEWID();
           
           -- Debug
           -- SELECT 'Tender', @tender_id;
           -- SELECT @stock_id AS StockID, @tender_id AS TenderID, @sale_day AS SaleDate, @sale_time AS SaleTime, @last_item AS LastItem;

           -- Now that we know everything INSERT A Sale Record
           INSERT INTO Sales (StockID, TenderID, SaleDate, SaleTime, LastItem)
           VALUES (@stock_id, @tender_id, @sale_day, @sale_time, @last_item);

           -- DEBUG
           -- SET @sale_count = @sale_count +1;
           
           FETCH NEXT FROM sale_time_cursor INTO @sale_time; 
           SET @fetch_sale_time_cursor = @@FETCH_STATUS
        END
                 
        CLOSE  sale_time_cursor;
        DEALLOCATE sale_time_cursor;
        

       -- DEBUG
       -- SELECT @machine_id AS MachineID, @sale_day AS SaleDate, @sale_count AS SalesCount
       -- SET @machine_count = @machine_count +1;
       
       FETCH NEXT FROM machine_cursor INTO @machine_id, @model_id, @accept_credit, @accept_mobile; 
       SET @fetch_machine2_cursor = @@FETCH_STATUS
   END

   CLOSE  machine_cursor;
   DEALLOCATE machine_cursor;
  
   -- DEBUG
   -- SELECT @sale_day AS SaleDay, @machine_count AS MachineCount;
  
   FETCH NEXT FROM sale_day_cursor INTO @sale_day , @is_weekday, @is_holiday; 
   SET @fetch_sale_day_cursor = @@FETCH_STATUS
END

CLOSE  sale_day_cursor;
DEALLOCATE sale_day_cursor;
-- ------------------------------------------------------------------------------------
-- End Load Sales
-- ------------------------------------------------------------------------------------


-- ------------------------------------------------------------------------------------
-- Drop Load Helper Tables
-- ------------------------------------------------------------------------------------
IF (@drop_helpers = 1) 
BEGIN
    DROP TABLE IF EXISTS DimDate;
    DROP TABLE IF EXISTS DimTime;
    DROP TABLE IF EXISTS SalesLoad;
    DROP TABLE IF EXISTS SaleTimes;
    DROP TABLE IF EXISTS WeightTenders;
END

--
GO
--


-- ------------------------------------------------------------------------------------
-- List table names and row counts for confirmation
-- ------------------------------------------------------------------------------------
SET NOCOUNT ON
SELECT 'Brand' AS 'Table', COUNT(*) AS 'Rows'  FROM Brand           UNION
SELECT 'Manufacturer',     COUNT(*)            FROM Manufacturer    UNION
SELECT 'Campus',           COUNT(*)            FROM Campus          UNION
SELECT 'Department',       COUNT(*)            FROM Department      UNION
SELECT 'Tender',           COUNT(*)            FROM Tender          UNION
SELECT 'ProductType',      COUNT(*)            FROM ProductType     UNION
SELECT 'ModelType',        COUNT(*)            FROM ModelType       UNION
SELECT 'Shelf',            COUNT(*)            FROM Shelf           UNION
SELECT 'Model',            COUNT(*)            FROM Model           UNION
SELECT 'ModelShelf',       COUNT(*)            FROM ModelShelf      UNION
SELECT 'Machine',          COUNT(*)            FROM Machine         UNION
SELECT 'Building',         COUNT(*)            FROM Building        UNION
SELECT 'BuildingMachine',  COUNT(*)            FROM BuildingMachine UNION
SELECT 'Product',          COUNT(*)            FROM Product         UNION
SELECT 'Stock',            COUNT(*)            FROM Stock           UNION
SELECT 'Sales',            COUNT(*)            FROM Sales           
ORDER BY 1;
SET NOCOUNT OFF
GO
