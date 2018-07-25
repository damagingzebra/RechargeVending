-- CHeck Script To Verify ETL LOAD
USE RechargeDM;

SET NOCOUNT ON
SELECT 'FactSale' AS 'Table', COUNT(*) AS 'Rows'  FROM FactSale     UNION
SELECT 'DimDate',             COUNT(*)            FROM DimDate      UNION
SELECT 'DimTime',             COUNT(*)            FROM DimTime      UNION
SELECT 'DimLocation',         COUNT(*)            FROM DimLocation  UNION
SELECT 'DimMachine',          COUNT(*)            FROM DimMachine   UNION
SELECT 'DimProduct',          COUNT(*)            FROM DimProduct     
ORDER BY 1;
SET NOCOUNT OFF
--
GO

SELECT count(*) FROM Recharge.dbo.Sales;