/* =====================================================================
   Step 3c: OrderLineFact - staging, extraction query, SCD2 lookup load, checks
   Prerequisite: dw.DateDim, dw.ProductDim and dw.CustomerDim are loaded.
   Scope: shipped orders only (Status = 5, provisional option A).
   Expected: about 120,147 lines on 31,150 orders.
   ===================================================================== */

USE CompanyX_DW;
GO

/* ---------------------------------------------------------------------
   1. Staging table: order header + detail flattened, one row per line.
      No Status column: the extraction already keeps shipped orders only.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'staging.OrderLine', N'U') IS NULL
CREATE TABLE staging.OrderLine
(
    SalesOrderID       int            NOT NULL,
    SalesOrderDetailID int            NOT NULL,
    ProductID          int            NOT NULL,
    CustomerID         int            NOT NULL,
    OrderDate          date           NOT NULL,
    OrderQty           smallint       NULL,
    UnitPrice          decimal(19,4)  NULL,
    UnitPriceDiscount  decimal(19,4)  NOT NULL,
    LineTotal          decimal(38,6)  NOT NULL,
    OnlineOrderFlag    bit            NOT NULL,
    ModifiedDate       datetime       NOT NULL,   -- later of header and detail ModifiedDate
    LoadedAt           datetime       NOT NULL CONSTRAINT DF_stgOrderLine_LoadedAt DEFAULT (SYSDATETIME())
);
GO

/* ---------------------------------------------------------------------
   2. The extraction query (this is the SSIS source query)
      To run the "all orders" sensitivity test later, remove the Status filter.
   --------------------------------------------------------------------- */
/*
SELECT
    d.SalesOrderID,
    d.SalesOrderDetailID,
    d.ProductID,
    h.CustomerID,
    CAST(h.OrderDate AS date)                     AS OrderDate,
    d.OrderQty,
    CAST(d.UnitPrice          AS decimal(19,4))   AS UnitPrice,
    CAST(d.UnitPriceDiscount  AS decimal(19,4))   AS UnitPriceDiscount,
    CAST(d.LineTotal          AS decimal(38,6))   AS LineTotal,
    h.OnlineOrderFlag,
    CASE WHEN d.ModifiedDate > h.ModifiedDate THEN d.ModifiedDate ELSE h.ModifiedDate END AS ModifiedDate
FROM CompanyX.Sales.SalesOrderDetail AS d
JOIN CompanyX.Sales.SalesOrderHeader AS h ON h.SalesOrderID = d.SalesOrderID
WHERE h.Status = 5;
*/

/* ---------------------------------------------------------------------
   3. Optional: load staging with T-SQL to test in SSMS
   --------------------------------------------------------------------- */
TRUNCATE TABLE staging.OrderLine;

INSERT INTO staging.OrderLine
    (SalesOrderID, SalesOrderDetailID, ProductID, CustomerID, OrderDate,
     OrderQty, UnitPrice, UnitPriceDiscount, LineTotal, OnlineOrderFlag, ModifiedDate)
SELECT
    d.SalesOrderID,
    d.SalesOrderDetailID,
    d.ProductID,
    h.CustomerID,
    CAST(h.OrderDate AS date),
    d.OrderQty,
    CAST(d.UnitPrice         AS decimal(19,4)),
    CAST(d.UnitPriceDiscount AS decimal(19,4)),
    CAST(d.LineTotal         AS decimal(38,6)),
    h.OnlineOrderFlag,
    CASE WHEN d.ModifiedDate > h.ModifiedDate THEN d.ModifiedDate ELSE h.ModifiedDate END
FROM CompanyX.Sales.SalesOrderDetail AS d
JOIN CompanyX.Sales.SalesOrderHeader AS h ON h.SalesOrderID = d.SalesOrderID
WHERE h.Status = 5;
GO

/* ---------------------------------------------------------------------
   4. Staging checks
   --------------------------------------------------------------------- */

-- 4a. Staging equals the source for shipped orders: both columns should match (about 120,147)
SELECT (SELECT COUNT(*) FROM staging.OrderLine) AS StagingLines,
       (SELECT COUNT(*)
        FROM CompanyX.Sales.SalesOrderDetail d
        JOIN CompanyX.Sales.SalesOrderHeader h ON h.SalesOrderID = d.SalesOrderID
        WHERE h.Status = 5) AS SourceShippedLines;

-- 4b. Shipped orders: expect 31,150
SELECT COUNT(DISTINCT SalesOrderID) AS ShippedOrders FROM staging.OrderLine;

-- 4c. Duplicate line keys: expect 0 rows
SELECT SalesOrderID, SalesOrderDetailID, COUNT(*) AS Dupes
FROM staging.OrderLine
GROUP BY SalesOrderID, SalesOrderDetailID
HAVING COUNT(*) > 1;

-- 4d. Lines whose product or customer is missing from the dimensions: expect 0 and 0
SELECT
  (SELECT COUNT(*) FROM staging.OrderLine s
   WHERE NOT EXISTS (SELECT 1 FROM dw.ProductDim p WHERE p.ProductID = s.ProductID)) AS LinesWithoutProduct,
  (SELECT COUNT(*) FROM staging.OrderLine s
   WHERE NOT EXISTS (SELECT 1 FROM dw.CustomerDim c WHERE c.CustomerID = s.CustomerID)) AS LinesWithoutCustomer;

-- 4e. Lines whose date is outside DateDim: expect 0
SELECT COUNT(*) AS LinesWithoutDate
FROM staging.OrderLine s
WHERE NOT EXISTS (SELECT 1 FROM dw.DateDim d WHERE d.FullDate = s.OrderDate);
GO

/* ---------------------------------------------------------------------
   5. Load dw.OrderLineFact (statement for the package's last Execute SQL Task)
      - ProductKey = the version whose EffectiveFrom-EffectiveTo range contains the order date
      - fallback: when no version contains the date (reseller orders for retired
        products, placed after the product's history ended), use the product's
        latest version instead of dropping the line
      - idempotent: only inserts lines that are not in the fact table yet
   --------------------------------------------------------------------- */
INSERT INTO dw.OrderLineFact
    (SalesOrderID, SalesOrderDetailID, ProductKey, CustomerKey, DateKey,
     OrderQty, UnitPrice, UnitPriceDiscount, LineTotal, DiscountAmount,
     OnlineOrderFlag, ModifiedDate)
SELECT
    s.SalesOrderID,
    s.SalesOrderDetailID,
    pk.ProductKey,
    c.CustomerKey,
    dt.DateKey,
    s.OrderQty,
    s.UnitPrice,
    s.UnitPriceDiscount,
    s.LineTotal,
    CAST(CAST(s.OrderQty AS decimal(10,0)) * s.UnitPrice * s.UnitPriceDiscount AS decimal(38,6)),  -- NULL if qty or price is NULL
    s.OnlineOrderFlag,
    s.ModifiedDate
FROM staging.OrderLine AS s
JOIN dw.CustomerDim AS c  ON c.CustomerID = s.CustomerID
JOIN dw.DateDim     AS dt ON dt.FullDate  = s.OrderDate
CROSS APPLY
(
    SELECT TOP (1) p.ProductKey
    FROM dw.ProductDim AS p
    WHERE p.ProductID = s.ProductID
    ORDER BY CASE WHEN s.OrderDate >= p.EffectiveFrom
                   AND (p.EffectiveTo IS NULL OR s.OrderDate <= p.EffectiveTo)
                  THEN 0 ELSE 1 END,      -- the matching version first
             p.EffectiveFrom DESC          -- otherwise the latest version
) AS pk
WHERE NOT EXISTS (SELECT 1 FROM dw.OrderLineFact AS f
                  WHERE f.SalesOrderID = s.SalesOrderID
                    AND f.SalesOrderDetailID = s.SalesOrderDetailID);
GO

/* ---------------------------------------------------------------------
   6. Reconciliation checks on the loaded fact table
   --------------------------------------------------------------------- */

-- 6a. No line lost in the load: both counts should match (about 120,147)
SELECT (SELECT COUNT(*) FROM staging.OrderLine) AS StagingLines,
       (SELECT COUNT(*) FROM dw.OrderLineFact)  AS FactLines;

-- 6b. Revenue reconciles to the source (shipped orders): three equal totals
SELECT (SELECT SUM(LineTotal) FROM dw.OrderLineFact) AS FactRevenue,
       (SELECT SUM(LineTotal) FROM staging.OrderLine) AS StagingRevenue,
       (SELECT SUM(d.LineTotal)
        FROM CompanyX.Sales.SalesOrderDetail d
        JOIN CompanyX.Sales.SalesOrderHeader h ON h.SalesOrderID = d.SalesOrderID
        WHERE h.Status = 5) AS SourceRevenue;

-- 6c. Lines that used the fallback version because the order date is after the
--     product's last version ended: about 71 (at most 71 for all orders)
SELECT COUNT(*) AS FallbackLines
FROM dw.OrderLineFact f
JOIN dw.ProductDim p ON p.ProductKey = f.ProductKey
JOIN dw.DateDim d    ON d.DateKey = f.DateKey
WHERE p.EffectiveTo IS NOT NULL AND d.FullDate > p.EffectiveTo;

-- 6d. Lines dated BEFORE their version starts (should never happen): expect 0
SELECT COUNT(*) AS LinesBeforeVersion
FROM dw.OrderLineFact f
JOIN dw.ProductDim p ON p.ProductKey = f.ProductKey
JOIN dw.DateDim d    ON d.DateKey = f.DateKey
WHERE d.FullDate < p.EffectiveFrom;

-- 6e. The five anomalous orders are present: expect 5 orders and 59 lines
SELECT COUNT(DISTINCT SalesOrderID) AS AnomalyOrders, COUNT(*) AS AnomalyLines
FROM dw.OrderLineFact
WHERE SalesOrderID BETWEEN 43677 AND 43681;

-- 6f. Channel split of orders: expect 27,382 Individual and 3,768 Reseller
SELECT c.CustomerType, COUNT(DISTINCT f.SalesOrderID) AS Orders
FROM dw.OrderLineFact f
JOIN dw.CustomerDim c ON c.CustomerKey = f.CustomerKey
GROUP BY c.CustomerType;

-- 6g. Mining population (individual run): orders with 2+ distinct models after
--     the OrderQty > 0 AND UnitPrice > 0 filter. Expect 17,805.
SELECT COUNT(*) AS IndividualMultiModelOrders
FROM (
    SELECT f.SalesOrderID
    FROM dw.OrderLineFact f
    JOIN dw.CustomerDim c ON c.CustomerKey = f.CustomerKey
    JOIN dw.ProductDim  p ON p.ProductKey  = f.ProductKey
    WHERE c.CustomerType = 'Individual'
      AND f.OrderQty > 0 AND f.UnitPrice > 0
    GROUP BY f.SalesOrderID
    HAVING COUNT(DISTINCT p.ProductModelID) >= 2
) AS x;
GO
