/* =====================================================================
   Step 3b: CustomerDim - staging table, extraction query, checks, SCD1 upsert
   Run in SSMS against the same instance as CompanyX / CompanyX_DW.
   Expected: 19,119 customers (18,484 Individual + 635 Reseller).
   ===================================================================== */

USE CompanyX_DW;
GO

/* ---------------------------------------------------------------------
   1. Staging table (heap; truncated and reloaded on every run)
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'staging.Customer', N'U') IS NULL
CREATE TABLE staging.Customer
(
    CustomerID        int          NOT NULL,
    CustomerType      varchar(10)  NOT NULL,
    StoreID           int          NULL,
    StoreName         nvarchar(50) NOT NULL,
    TerritoryID       int          NOT NULL,
    TerritoryName     nvarchar(50) NOT NULL,
    CountryRegionCode nvarchar(3)  NOT NULL,
    TerritoryGroup    nvarchar(50) NOT NULL,
    LoadedAt          datetime     NOT NULL CONSTRAINT DF_stgCustomer_LoadedAt DEFAULT (SYSDATETIME())
);
GO

/* ---------------------------------------------------------------------
   2. The extraction query (this is the SSIS source query)
      - load rule: PersonID IS NOT NULL (drops the 701 store-only placeholders)
      - StoreID IS NOT NULL => Reseller, otherwise Individual
      - store join key is Store.BusinessEntityID
      - [Group] is a reserved word in SalesTerritory
   --------------------------------------------------------------------- */
/*
SELECT
    c.CustomerID,
    CASE WHEN c.StoreID IS NOT NULL THEN 'Reseller' ELSE 'Individual' END AS CustomerType,
    c.StoreID,
    COALESCE(st.[Name], N'N/A') AS StoreName,
    c.TerritoryID,
    t.[Name]             AS TerritoryName,
    t.CountryRegionCode  AS CountryRegionCode,
    t.[Group]            AS TerritoryGroup
FROM CompanyX.Sales.Customer       AS c
LEFT JOIN CompanyX.Sales.Store     AS st ON st.BusinessEntityID = c.StoreID
JOIN CompanyX.Sales.SalesTerritory AS t  ON t.TerritoryID = c.TerritoryID
WHERE c.PersonID IS NOT NULL;
*/

/* ---------------------------------------------------------------------
   3. Optional: load staging with T-SQL to test the query in SSMS
      (the SSIS data flow does the same job)
   --------------------------------------------------------------------- */
TRUNCATE TABLE staging.Customer;

INSERT INTO staging.Customer
    (CustomerID, CustomerType, StoreID, StoreName, TerritoryID, TerritoryName, CountryRegionCode, TerritoryGroup)
SELECT
    c.CustomerID,
    CASE WHEN c.StoreID IS NOT NULL THEN 'Reseller' ELSE 'Individual' END,
    c.StoreID,
    COALESCE(st.[Name], N'N/A'),
    c.TerritoryID,
    t.[Name],
    t.CountryRegionCode,
    t.[Group]
FROM CompanyX.Sales.Customer       AS c
LEFT JOIN CompanyX.Sales.Store     AS st ON st.BusinessEntityID = c.StoreID
JOIN CompanyX.Sales.SalesTerritory AS t  ON t.TerritoryID = c.TerritoryID
WHERE c.PersonID IS NOT NULL;
GO

/* ---------------------------------------------------------------------
   4. Checks (expected values in the comments)
   --------------------------------------------------------------------- */

-- 4a. Row count and split: expect 19,119 total, 18,484 Individual, 635 Reseller
SELECT COUNT(*) AS Customers,
       SUM(CASE WHEN CustomerType = 'Individual' THEN 1 ELSE 0 END) AS Individuals,
       SUM(CASE WHEN CustomerType = 'Reseller'   THEN 1 ELSE 0 END) AS Resellers
FROM staging.Customer;

-- 4b. Source rows lost by the joins (territory join is inner): expect 0
SELECT (SELECT COUNT(*) FROM CompanyX.Sales.Customer WHERE PersonID IS NOT NULL)
       - (SELECT COUNT(*) FROM staging.Customer) AS RowsLost;

-- 4c. Resellers map to distinct stores: expect 635 distinct stores
SELECT COUNT(DISTINCT StoreID) AS DistinctStores
FROM staging.Customer WHERE CustomerType = 'Reseller';

-- 4d. Individuals carry no store: expect 0 rows with a StoreID, and 18,484 'N/A' names
SELECT SUM(CASE WHEN StoreID IS NOT NULL THEN 1 ELSE 0 END) AS IndividualsWithStore,
       SUM(CASE WHEN StoreName = N'N/A'  THEN 1 ELSE 0 END) AS NAStoreNames
FROM staging.Customer WHERE CustomerType = 'Individual';

-- 4e. Customers on orders that are missing from staging: expect 0
SELECT COUNT(DISTINCT h.CustomerID) AS OrderCustomersMissing
FROM CompanyX.Sales.SalesOrderHeader AS h
WHERE NOT EXISTS (SELECT 1 FROM staging.Customer s WHERE s.CustomerID = h.CustomerID);

-- 4f. Duplicate business keys in staging: expect 0 rows
SELECT CustomerID, COUNT(*) AS Dupes
FROM staging.Customer GROUP BY CustomerID HAVING COUNT(*) > 1;
GO

/* ---------------------------------------------------------------------
   5. SCD Type 1 upsert from staging into dw.CustomerDim
      This is the statement for the second Execute SQL Task in the package.
      Changed rows are overwritten (no history) and UpdatedDate is refreshed;
      new rows are inserted (InsertedDate/UpdatedDate come from the defaults).
   --------------------------------------------------------------------- */
UPDATE d
SET    d.CustomerType      = s.CustomerType,
       d.StoreID           = s.StoreID,
       d.StoreName         = s.StoreName,
       d.TerritoryID       = s.TerritoryID,
       d.TerritoryName     = s.TerritoryName,
       d.CountryRegionCode = s.CountryRegionCode,
       d.TerritoryGroup    = s.TerritoryGroup,
       d.UpdatedDate       = SYSDATETIME()
FROM   dw.CustomerDim AS d
JOIN   staging.Customer AS s ON s.CustomerID = d.CustomerID
WHERE  EXISTS (SELECT s.CustomerType, s.StoreID, s.StoreName, s.TerritoryID,
                      s.TerritoryName, s.CountryRegionCode, s.TerritoryGroup
               EXCEPT
               SELECT d.CustomerType, d.StoreID, d.StoreName, d.TerritoryID,
                      d.TerritoryName, d.CountryRegionCode, d.TerritoryGroup);

INSERT INTO dw.CustomerDim
    (CustomerID, CustomerType, StoreID, StoreName, TerritoryID, TerritoryName, CountryRegionCode, TerritoryGroup)
SELECT s.CustomerID, s.CustomerType, s.StoreID, s.StoreName, s.TerritoryID,
       s.TerritoryName, s.CountryRegionCode, s.TerritoryGroup
FROM   staging.Customer AS s
WHERE  NOT EXISTS (SELECT 1 FROM dw.CustomerDim AS d WHERE d.CustomerID = s.CustomerID)
ORDER BY s.CustomerID;
GO

-- Expect 19,119 rows: 18,484 Individual, 635 Reseller
SELECT COUNT(*) AS DimRows,
       SUM(CASE WHEN CustomerType = 'Individual' THEN 1 ELSE 0 END) AS Individuals,
       SUM(CASE WHEN CustomerType = 'Reseller'   THEN 1 ELSE 0 END) AS Resellers
FROM dw.CustomerDim;
GO
