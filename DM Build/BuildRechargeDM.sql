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
	(Time_SK INT NOT NULL CONSTRAINT pk_time_sk PRIMARY KEY,
 	 Time TIME NOT NULL,
 	 Hour24 INT NOT NULL,
 	 Hour INT NOT NULL,
 	 Minute INT NOT NULL,
 	 Second INT NOT NULL,
	 AM_PM	NVARCHAR(2) NOT NULL,
	 TimeOfDate	NVARCHAR(20) NOT NULL
	);
--
CREATE TABLE DimDate
	(Date_SK INT CONSTRAINT pk_date_sk PRIMARY KEY,
 	 Date DATE NOT NULL,
 	 Year INT NOT NULL,
 	 Quarter INT NOT NULL,
 	 YearQuarter NVARCHAR(7) NOT NULL,
 	 Month INT NOT NULL,
 	 MonthName NVARCHAR(10) NOT NULL,
 	 WeekOfYear INT NOT NULL,
 	 DayOfWeek INT NOT NULL,
 	 DayName INT NOT NULL,
 	 Weekend INT NOT NULL,
 	 Holiday INT NOT NULL,
 	 Season NVARCHAR(10) NOT NULL
	);
--
CREATE TABLE DimProduct
	(Product_SK  INT IDENTITY(1,1)  NOT NULL CONSTRAINT pk_product_sk PRIMARY KEY,
 	 Product_AK	 INT NOT NULL,
 	 ProductType NVARCHAR(30) NOT NULL,
 	 ProductName NVARCHAR(30) NOT NULL,
 	 Brand NVARCHAR(30) NOT NULL,
 	 Manufacturer NVARCHAR(30) NOT NULL,
 	 Size DECIMAL(5,2) NOT NULL
	);
--
CREATE TABLE DimLocation
	(Location_SK INT IDENTITY(1,1)  NOT NULL CONSTRAINT pk_location_sk PRIMARY KEY,
	 Location_AK INT NOT NULL,
	 CampusName NVARCHAR(75) NOT NULL,
	 DepartmentName NVARCHAR(75) NOT NULL,
	 BuildingName NVARCHAR(75) NOT NULL,
	 Floor INT NOT NULL
	);
--
CREATE TABLE DimMachine
	(Machine_SK INT IDENTITY(1,1)  NOT NULL CONSTRAINT pk_machine_sk PRIMARY KEY,
	 Machine_AK INT NOT NULL,
	 ModelNumber NVARCHAR(10) NOT NULL,
	 MachineType NVARCHAR(20) NOT NULL,
     CreditEnabled INT NOT NULL,	 
     MobilPayEnabled INT NOT NULL,	 
     CashEnabled INT NOT NULL
	);
--
CREATE TABLE FactSale
	(SaleDate INT CONSTRAINT fk_sale_date_sk FOREIGN KEY REFERENCES DimDate(Date_SK),
     SaleTime INT CONSTRAINT fk_sale_time_sk FOREIGN KEY REFERENCES DimTime(Time_SK),
     Machine_SK INT CONSTRAINT fk_machine_sk FOREIGN KEY REFERENCES DimMachine(Machine_SK),
     Location_SK INT CONSTRAINT fk_location_sk FOREIGN KEY REFERENCES DimLocation(Location_SK),
     Product_SK INT CONSTRAINT fk_product_sk FOREIGN KEY REFERENCES DimProduct(Product_SK),
     Shelf INT NOT NULL,	 
     Position INT NOT NULL,	 
	 Tender NVARCHAR(10) NOT NULL,
     Price DECIMAL(3,2) NOT NULL,
     Cost DECIMAL(3,2) NOT NULL,
     LastItem INT NOT NULL
	);

GO

--
-- List table names and row counts for confirmation
--
SET NOCOUNT ON
SELECT 'FactSale' AS "Table", COUNT(*) AS "Rows"	FROM FactSale	 UNION
SELECT 'DimDate',             COUNT(*)				FROM DimDate     UNION
SELECT 'DimTime',             COUNT(*)				FROM DimTime     UNION
SELECT 'DimProduct',          COUNT(*)				FROM DimProduct  UNION
SELECT 'DimLocation',         COUNT(*)				FROM DimLocation UNION
SELECT 'DimMachine',          COUNT(*)				FROM DimMachine           
ORDER BY 1;
SET NOCOUNT OFF
GO