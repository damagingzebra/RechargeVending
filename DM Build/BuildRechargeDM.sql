-- Recharge Vending database developed and written by Brian Corcoran
-- Originally Written: July 2018
-----------------------------------------------------------
IF NOT EXISTS(SELECT * FROM sys.databases
	WHERE name = N'RechargeDM')
	CREATE DATABASE RechargeDM
GO

USE RechargeDM

--
-- Delete existing tables
--
IF EXISTS(
	SELECT *
	FROM sys.tables
	WHERE name = N'FactSale'
       )
	DROP TABLE FactSale;
--
IF EXISTS(
	SELECT *
	FROM sys.tables
	WHERE name = N'DimMachine'
       )
	DROP TABLE DimMachine;
--
IF EXISTS(
	SELECT *
	FROM sys.tables
	WHERE name = N'DimLocation'
       )
	DROP TABLE DimLocation;
--
IF EXISTS(
	SELECT *
	FROM sys.tables
	WHERE name = N'DimProduct'
       )
	DROP TABLE DimProduct;
--
IF EXISTS(
	SELECT *
	FROM sys.tables
	WHERE name = N'DimDate'
       )
	DROP TABLE DimDate;
--
IF EXISTS(
	SELECT *
	FROM sys.tables
	WHERE name = N'DimTime'
       )
	DROP TABLE DimTime;

--
-- Create tables
--
CREATE TABLE DimTime
	(
	Time_SK INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_Time PRIMARY KEY,
	Time NCHAR(8) NOT NULL,
	Hour NCHAR(2) NOT NULL,
	MilitaryHour NCHAR(2) NOT NULL,
	Minute NCHAR(2) NOT NULL,
	Second NCHAR(2) NOT NULL,
	AmPm NCHAR(2) NOT NULL,
	StandardTime NCHAR(11) NULL
	);


-- 
CREATE TABLE DimDate (
	Date_SK           INT NOT NULL,
	DATE              DATE NULL,
	FullDate          NCHAR(10) NULL,
	DayOfMonth        INT NULL,
	DayName           NVARCHAR(9) NULL,
	DayOfWeek         INT NULL,
	DayOfWeekInMonth  INT NULL,
	DayOfWeekInYear   INT NULL,
	DayOfQuarter      INT NULL,
	DayOfYear         INT NULL,
	WeekOfMonth       INT NULL,
	WeekOfQuarter     INT NULL,
	WeekOfYear        INT NULL,
	Month             INT NULL,
	MonthName         NVARCHAR(9) NULL,
	MonthOfQuarter    INT NULL,
	Quarter           NCHAR(2) NULL,
	QuarterName       NVARCHAR(9) NULL,
	Year              INT NULL,
	YearName          CHAR(7) NULL,
	MonthYear         CHAR(10) NULL,
	MMYYYY            INT NULL,
	FirstDayOfMonth   DATE NULL,
	LastDayOfMonth    DATE NULL,
	FirstDayOfQuarter DATE NULL,
	LastDayOfQuarter  DATE NULL,
	FirstDayOfYear    DATE NULL,
	LastDayOfYear     DATE NULL,
	IsHoliday         BIT NULL,
	IsWeekday         BIT NULL,
	Holiday           NVARCHAR(50) NULL,
	Season            NVARCHAR(10) NULL,
PRIMARY KEY CLUSTERED 
(
	[Date_SK] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

--
CREATE TABLE DimProduct
	(Product_SK  INT IDENTITY(1,1)  NOT NULL CONSTRAINT pk_product_sk PRIMARY KEY,
 	 Product_AK	 INT NOT NULL,
 	 ProductType NVARCHAR(75) NOT NULL,
 	 ProductName NVARCHAR(75) NOT NULL,
 	 Brand NVARCHAR(75) NOT NULL,
 	 Manufacturer NVARCHAR(75) NOT NULL,
 	 Size NVARCHAR(50) NOT NULL
);
--
CREATE TABLE DimLocation
	(Location_SK INT IDENTITY(1,1)  NOT NULL CONSTRAINT pk_location_sk PRIMARY KEY,
	 Location_AK INT NOT NULL,
	 CampusName NVARCHAR(75) NOT NULL,
	 DepartmentName NVARCHAR(75) NOT NULL,
	 BuildingName NVARCHAR(75) NOT NULL,
	 Floor INT NOT NULL,
	 StartDate Datetime ,
	 EndDate Datetime ,
);
--
CREATE TABLE DimMachine
	(Machine_SK INT IDENTITY(1,1)  NOT NULL CONSTRAINT pk_machine_sk PRIMARY KEY,
	 Machine_AK INT NOT NULL,
	 ModelName NVARCHAR(50) NOT NULL,
	 MachineType NVARCHAR(50) NOT NULL,
     CashEnabled INT NOT NULL,
     CreditEnabled INT NOT NULL,	 
     MobilePayEnabled INT NOT NULL,	 
);
--
CREATE TABLE FactSale
	(SaleDate INT CONSTRAINT fk_sale_date_sk FOREIGN KEY REFERENCES DimDate(Date_SK),
     SaleTime INT CONSTRAINT fk_sale_time_sk FOREIGN KEY REFERENCES DimTime(Time_SK),
     Machine_SK INT CONSTRAINT fk_machine_sk FOREIGN KEY REFERENCES DimMachine(Machine_SK),
     Location_SK INT CONSTRAINT fk_location_sk FOREIGN KEY REFERENCES DimLocation(Location_SK),
     Product_SK INT CONSTRAINT fk_product_sk FOREIGN KEY REFERENCES DimProduct(Product_SK),
     Position_DD INT NOT NULL,	 
     Slot_DD INT NOT NULL,	 
     Tender NVARCHAR(75) NOT NULL,
     Price DECIMAL(3,2) NOT NULL,
     Cost DECIMAL(3,2) NOT NULL,
     LastItem INT NOT NULL,
     CONSTRAINT pk_sale PRIMARY KEY  (SaleDate, SaleTime, Machine_SK)        
);
--
GO
