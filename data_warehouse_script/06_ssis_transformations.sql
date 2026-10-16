/* =====================================================================
   Step 5: Make the Transform visible inside the SSIS data flows
   What moves into SSIS components:
     LoadCustomerDim   : Derived Column  -> CustomerType, StoreName ('N/A')
     LoadOrderLineFact : Derived Column  -> DateKey, DiscountAmount
                         Lookup          -> CustomerKey (from dw.CustomerDim)
                         Multicast + Conditional Split -> anomaly log
   What stays in T-SQL (and why):
     ProductDim as-of version logic (needs the replay window view) and the
     ProductKey date-range lookup with fallback (does not fit an equality Lookup).
   Run sections 1-3 in SSMS BEFORE editing the packages.
   ===================================================================== */

USE CompanyX_DW;
GO

/* ---------------------------------------------------------------------
   1. staging.OrderLine receives the values computed in the data flow
   --------------------------------------------------------------------- */
IF COL_LENGTH(N'staging.OrderLine', N'CustomerKey') IS NULL
    ALTER TABLE staging.OrderLine ADD CustomerKey int NULL;
IF COL_LENGTH(N'staging.OrderLine', N'DateKey') IS NULL
    ALTER TABLE staging.OrderLine ADD DateKey int NULL;
IF COL_LENGTH(N'staging.OrderLine', N'DiscountAmount') IS NULL
    ALTER TABLE staging.OrderLine ADD DiscountAmount decimal(38,6) NULL;
GO

/* ---------------------------------------------------------------------
   2. Data-quality log: lines with null, zero or negative quantity/price.
      They are KEPT in the fact table (revenue must reconcile); this table
      only records them, so the Conditional Split makes the rule visible.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'etl.OrderLineAnomaly', N'U') IS NULL
CREATE TABLE etl.OrderLineAnomaly
(
    SalesOrderID       int           NOT NULL,
    SalesOrderDetailID int           NOT NULL,
    ProductID          int           NOT NULL,
    OrderQty           smallint      NULL,
    UnitPrice          decimal(19,4) NULL,
    LoggedAt           datetime      NOT NULL CONSTRAINT DF_OrderLineAnomaly_LoggedAt DEFAULT (SYSDATETIME())
);
GO

/* ---------------------------------------------------------------------
   3. Reset procedure: same as before, plus clearing the anomaly log
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE etl.usp_ReplayReset
    @StartClock date = '2011-05-30'
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dw.OrderLineFact;
    DELETE FROM dw.ProductDim;
    DELETE FROM dw.CustomerDim;
    DBCC CHECKIDENT ('dw.ProductDim',  RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dw.CustomerDim', RESEED, 0) WITH NO_INFOMSGS;

    TRUNCATE TABLE staging.ProductVersion;
    TRUNCATE TABLE staging.Customer;
    TRUNCATE TABLE staging.OrderLine;
    TRUNCATE TABLE etl.OrderLineAnomaly;

    UPDATE etl.Watermark
    SET    LastWatermark = @StartClock, LastRunAt = NULL, RowsLoaded = NULL
    WHERE  TableName = N'dw.OrderLineFact';
END
GO

/* =====================================================================
   SSIS CHANGES
   ===================================================================== */

/* ---------------------------------------------------------------------
   A. LoadCustomerDim - new OLE DB Source query (raw values, no CASE/COALESCE).
      Then add a Derived Column Transformation between source and destination:
        CustomerType  <add as new column> (the cast makes it string [DT_STR], length 10, code page 1252)
            (DT_STR,10,1252)(ISNULL(StoreID) ? "Individual" : "Reseller")
        StoreName     <replace 'StoreName'> (the cast keeps it Unicode string [DT_WSTR], length 50)
            (DT_WSTR,50)(ISNULL(StoreName) ? "N/A" : StoreName)
   --------------------------------------------------------------------- */
/*
SELECT
    c.CustomerID,
    c.StoreID,
    st.[Name]            AS StoreName,
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
   B. LoadOrderLineFact - Derived Column (new columns):
        DateKey         data type four-byte signed integer [DT_I4]
            YEAR(OrderDate) * 10000 + MONTH(OrderDate) * 100 + DAY(OrderDate)
        DiscountAmount  data type numeric [DT_NUMERIC], precision 38, scale 6
            ISNULL(OrderQty) || ISNULL(UnitPrice) ? NULL(DT_NUMERIC,38,6) : (DT_NUMERIC,38,6)((DT_NUMERIC,19,4)OrderQty * UnitPrice * UnitPriceDiscount)

      Lookup Transformation (after the Derived Column):
        Connection CompanyX_DW, "Use results of an SQL query":
            SELECT CustomerID, CustomerKey FROM dw.CustomerDim
        Join CustomerID = CustomerID, add lookup column CustomerKey.
        No-match handling: leave "Fail component" (every customer exists).

      Multicast (after the Lookup), two outputs:
        1) OLE DB Destination staging.OrderLine (all rows; map CustomerKey, DateKey, DiscountAmount too)
        2) Conditional Split, output name Anomalous, condition:
            ISNULL(OrderQty) || OrderQty <= 0 || ISNULL(UnitPrice) || UnitPrice <= 0
           Anomalous -> OLE DB Destination etl.OrderLineAnomaly
           (map SalesOrderID, SalesOrderDetailID, ProductID, OrderQty, UnitPrice; leave LoggedAt unmapped)
           Default output: leave unconnected (a harmless warning).
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   C. LoadOrderLineFact - replace the SQLStatement of LoadOrderLineFactLookup.
      CustomerKey, DateKey and DiscountAmount now arrive from staging; the
      ProductKey date-range lookup with the last-version fallback stays in T-SQL.
      (No GO lines; paste only the INSERT.)
   --------------------------------------------------------------------- */
/*
INSERT INTO dw.OrderLineFact
    (SalesOrderID, SalesOrderDetailID, ProductKey, CustomerKey, DateKey,
     OrderQty, UnitPrice, UnitPriceDiscount, LineTotal, DiscountAmount,
     OnlineOrderFlag, ModifiedDate)
SELECT
    s.SalesOrderID,
    s.SalesOrderDetailID,
    pk.ProductKey,
    s.CustomerKey,
    s.DateKey,
    s.OrderQty,
    s.UnitPrice,
    s.UnitPriceDiscount,
    s.LineTotal,
    s.DiscountAmount,
    s.OnlineOrderFlag,
    s.ModifiedDate
FROM staging.OrderLine AS s
CROSS APPLY
(
    SELECT TOP (1) p.ProductKey
    FROM dw.ProductDim AS p
    WHERE p.ProductID = s.ProductID
    ORDER BY CASE WHEN s.OrderDate >= p.EffectiveFrom
                   AND (p.EffectiveTo IS NULL OR s.OrderDate <= p.EffectiveTo)
                  THEN 0 ELSE 1 END,
             p.EffectiveFrom DESC
) AS pk
WHERE NOT EXISTS (SELECT 1 FROM dw.OrderLineFact AS f
                  WHERE f.SalesOrderID = s.SalesOrderID
                    AND f.SalesOrderDetailID = s.SalesOrderDetailID);
*/

/* =====================================================================
   CHECKS (run after a full replay: reset, catch-up, weekly runs, final big window)
   ===================================================================== */
/*
-- 1. Results must equal the earlier full load: 353 / 19,119 / 120,147 / 108,734,796.040861 / 2014-06-30
SELECT (SELECT COUNT(*) FROM dw.ProductDim)    AS ProductVersions,
       (SELECT COUNT(*) FROM dw.CustomerDim)   AS Customers,
       (SELECT COUNT(*) FROM dw.OrderLineFact) AS FactLines,
       (SELECT SUM(LineTotal) FROM dw.OrderLineFact) AS Revenue,
       (SELECT LastWatermark FROM etl.Watermark WHERE TableName = N'dw.OrderLineFact') AS Clock;

-- 2. Customer split from the Derived Column: 18,484 Individual / 635 Reseller; 'N/A' only for individuals
SELECT CustomerType, COUNT(*) AS Customers,
       SUM(CASE WHEN StoreName = N'N/A' THEN 1 ELSE 0 END) AS NAStoreNames
FROM dw.CustomerDim GROUP BY CustomerType;

-- 3. Anomaly log equals the anomalous lines in the fact table (both numbers must match)
SELECT (SELECT COUNT(*) FROM etl.OrderLineAnomaly) AS LoggedAnomalies,
       (SELECT COUNT(*) FROM dw.OrderLineFact
        WHERE OrderQty IS NULL OR OrderQty <= 0 OR UnitPrice IS NULL OR UnitPrice <= 0) AS AnomaliesInFact;

-- 4. DateKey from the Derived Column agrees with the date table (expect 0 rows)
SELECT TOP (10) f.SalesOrderID FROM dw.OrderLineFact f
JOIN dw.DateDim d ON d.DateKey = f.DateKey
WHERE d.DateKey <> YEAR(d.FullDate) * 10000 + MONTH(d.FullDate) * 100 + DAY(d.FullDate);

-- 5. DiscountAmount is NULL exactly when quantity or price is NULL (expect 0)
SELECT COUNT(*) AS Mismatch
FROM dw.OrderLineFact
WHERE (DiscountAmount IS NULL AND OrderQty IS NOT NULL AND UnitPrice IS NOT NULL)
   OR (DiscountAmount IS NOT NULL AND (OrderQty IS NULL OR UnitPrice IS NULL));
*/
