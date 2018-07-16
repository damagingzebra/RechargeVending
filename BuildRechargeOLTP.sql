-- Recharge Vending database developed and written by Brian Corcoran
-- Originally Written: July 2018
-----------------------------------------------------------
-- Replace <data_path> with the full path to this file 
-- Ensure it ends with a backslash. 
-- E.g., C:\MyDatabases\ See line 17
-----------------------------------------------------------
IF NOT EXISTS(SELECT * FROM sys.databases
 WHERE name = N'Recharge')
 CREATE DATABASE Recharge
GO
USE Recharge
--
-- Alter the path so the script can find the CSV files 
--
DECLARE @data_path NVARCHAR(256);
SELECT @data_path = 'C:\Temp\RechargeVending\OLTP Build\';

--
-- Delete existing tables
--
DROP TABLE IF EXISTS BuildingMachine ;
DROP TABLE IF EXISTS Building ;

DROP TABLE IF EXISTS Sales ;
DROP TABLE IF EXISTS Stock ;
DROP TABLE IF EXISTS Product ;

DROP TABLE IF EXISTS Machine ;

DROP TABLE IF EXISTS ModelShelf ;
DROP TABLE IF EXISTS Model ;
DROP TABLE IF EXISTS Shelf ;

DROP TABLE IF EXISTS ModelType ;
DROP TABLE IF EXISTS ProductType ;
DROP TABLE IF EXISTS Tender ;
DROP TABLE IF EXISTS Department ;
DROP TABLE IF EXISTS Campus ;
DROP TABLE IF EXISTS Manufacturer ;
DROP TABLE IF EXISTS Brand ;


--
-- Create tables
--
CREATE TABLE Brand
 (BrandID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_brand_id PRIMARY KEY,
  Name   NVARCHAR(75) NOT NULL
 );
--
CREATE TABLE Manufacturer
 (ManufacturerID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_manufacturer_id PRIMARY KEY,
  Name   NVARCHAR(75) NOT NULL
 );
--
CREATE TABLE Campus
 (CampusID  INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_campus_id PRIMARY KEY,
  Name    NVARCHAR(75) NOT NULL
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
CREATE TABLE Shelf
 (ShelfID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_shelf_id PRIMARY KEY,
  ModelName  NVARCHAR(50) NOT NULL,
  Description   NVARCHAR(50) NOT NULL,
  Slots INT NOT NULL
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
  CONSTRAINT ck_mobilepay CHECK  (MobilePay = 0 OR MobilePay = 1),
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
  ManufactureDate DATE NOT NULL,
  PurchaseDate DATE NOT NULL
 );
--
CREATE TABLE Product
 (ProductID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_product_id PRIMARY KEY,
  ProductTypeID INT NOT NULL CONSTRAINT fk_product_type_id FOREIGN KEY REFERENCES ProductType(ProductTypeID),
  BrandID INT CONSTRAINT fk_brand_id FOREIGN KEY REFERENCES Brand(BrandID),
  ManufacturerID INT CONSTRAINT fk_manufacturer_id FOREIGN KEY REFERENCES Manufacturer(ManufacturerID),
  Name NVARCHAR(75) NOT NULL,
  Description NVARCHAR(75) NOT NULL,
  Size NUMERIC(5,2) NOT NULL,
  Price NUMERIC(5,2) NOT NULL,
  Cost  NUMERIC(5,2) NOT NULL
 );
--
CREATE TABLE Stock
 (StockID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_stock_id PRIMARY KEY,
  MachineID INT CONSTRAINT fk_s_machine_id FOREIGN KEY REFERENCES Machine(MachineID),
  ProductID INT CONSTRAINT fk_s_product_id FOREIGN KEY REFERENCES Product(ProductID),
  Year INT NOT NULL,
  Week INT NOT NULL,
  Shelf INT NOT NULL,
  Position INT NOT NULL,
  Quantity INT NOT NULL
 );
--
CREATE TABLE Sales
 (SaleID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_sales_id PRIMARY KEY,
  StockID INT CONSTRAINT fk_stock_id FOREIGN KEY REFERENCES Stock(StockID),
  TenderID INT CONSTRAINT fk_tender_id FOREIGN KEY REFERENCES Tender(TenderID),
  SaleDate DATETIME NOT NULL,
  LastItem INT NOT NULL,
  CONSTRAINT ck_last_item CHECK  (LastItem = 0 OR LastItem = 1),
 );
--
CREATE TABLE Building
 (BuildingID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_building_id PRIMARY KEY,
  CampusID INT CONSTRAINT fk_campus_id FOREIGN KEY REFERENCES Campus(CampusID),
  DepartmentID INT CONSTRAINT fk_department_id FOREIGN KEY REFERENCES Department(DepartmentID),
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
--
GO
--

--
-- Load table data
--

-- 
INSERT INTO Campus VALUES ('Technology University of James Denver');

--EXECUTE (N'BULK INSERT Brand FROM ''' + @data_path + N'SaleStatus.csv''
--WITH (
-- CHECK_CONSTRAINTS,
-- CODEPAGE=''ACP'',
-- DATAFILETYPE = ''char'',
-- FIELDTERMINATOR= '','',
-- ROWTERMINATOR = ''\n'',
-- KEEPIDENTITY,
-- TABLOCK
-- );
--');
--


--
-- List table names and row counts for confirmation
--
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
