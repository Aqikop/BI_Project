/* =====================================================================
   Step 4: Replay (near-real-time simulation) for CompanyX_DW
   How it works:
     - etl.Watermark row 'dw.OrderLineFact' is the replay clock: the date
       up to which orders are loaded (orders with OrderDate <= LastWatermark).
     - etl.vReplayWindow gives the next window: FromDate (exclusive) and
       ToDate (inclusive) = FromDate + WindowDays, capped at the last date in DateDim.
     - The ProductDim and OrderLine source queries join that view, so
       ProductDim shows only the price versions that exist "as of" ToDate and
       OrderLine loads only the orders inside the window.
     - After all packages succeed, the watermark moves forward to ToDate.
   Run sections 1-3 once (they only create objects; no data is changed except
   the clock is set to 2011-05-30 if it still holds the 1900 seed value).
   ===================================================================== */

USE CompanyX_DW;
GO

/* ---------------------------------------------------------------------
   1. Config: how many days one replay run advances (single-row table)
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'etl.ReplayConfig', N'U') IS NULL
CREATE TABLE etl.ReplayConfig
(
    ConfigID   tinyint NOT NULL CONSTRAINT PK_ReplayConfig PRIMARY KEY
                       CONSTRAINT CK_ReplayConfig_Single CHECK (ConfigID = 1),
    WindowDays int     NOT NULL CONSTRAINT CK_ReplayConfig_Window CHECK (WindowDays > 0)
);
GO

IF NOT EXISTS (SELECT 1 FROM etl.ReplayConfig)
    INSERT INTO etl.ReplayConfig (ConfigID, WindowDays) VALUES (1, 7);
GO

-- the clock must start just before the first order (2011-05-31)
UPDATE etl.Watermark
SET    LastWatermark = '2011-05-30'
WHERE  TableName = N'dw.OrderLineFact'
  AND  LastWatermark < '2011-05-30';
GO

/* ---------------------------------------------------------------------
   2. The next replay window (read by all source queries)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW etl.vReplayWindow
AS
SELECT
    CAST(w.LastWatermark AS date) AS FromDate,      -- exclusive
    CASE WHEN DATEADD(DAY, c.WindowDays, CAST(w.LastWatermark AS date)) > e.EndDate
         THEN e.EndDate
         ELSE DATEADD(DAY, c.WindowDays, CAST(w.LastWatermark AS date)) END AS ToDate   -- inclusive
FROM etl.Watermark AS w
CROSS JOIN etl.ReplayConfig AS c
CROSS JOIN (SELECT MAX(FullDate) AS EndDate FROM dw.DateDim) AS e
WHERE w.TableName = N'dw.OrderLineFact';
GO

/* ---------------------------------------------------------------------
   3. Reset procedure: empties the loaded warehouse data and rewinds the clock
      (keeps DateDim and AssociationRulesFact). Use it before each demo.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE etl.usp_ReplayReset
    @StartClock date = '2011-05-30'
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dw.OrderLineFact;      -- fact first: it references both dimensions
    DELETE FROM dw.ProductDim;
    DELETE FROM dw.CustomerDim;
    DBCC CHECKIDENT ('dw.ProductDim',  RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dw.CustomerDim', RESEED, 0) WITH NO_INFOMSGS;

    TRUNCATE TABLE staging.ProductVersion;
    TRUNCATE TABLE staging.Customer;
    TRUNCATE TABLE staging.OrderLine;

    UPDATE etl.Watermark
    SET    LastWatermark = @StartClock, LastRunAt = NULL, RowsLoaded = NULL
    WHERE  TableName = N'dw.OrderLineFact';
END
GO

/* =====================================================================
   SSIS CHANGES
   ===================================================================== */

/* ---------------------------------------------------------------------
   A. LoadProductDim - replace the OLE DB Source query with this "as of ToDate" version.
      A version appears once its StartDate <= ToDate; it is open (current) until
      ToDate reaches its EndDate. The existing SCD2 UPDATE + INSERT task is unchanged.
   --------------------------------------------------------------------- */
/*
SELECT
    p.ProductID,
    p.[Name],
    p.ProductNumber,
    p.Color,
    CAST(lp.ListPrice   AS decimal(19,4)) AS ListPrice,
    CAST(c.StandardCost AS decimal(19,4)) AS StandardCost,
    CAST(lp.StartDate AS date)            AS EffectiveFrom,
    CAST(CASE WHEN lp.EndDate IS NULL OR lp.EndDate > w.ToDate THEN NULL ELSE lp.EndDate END AS date) AS EffectiveTo,
    CASE WHEN lp.EndDate IS NULL OR lp.EndDate > w.ToDate THEN 1 ELSE 0 END AS IsCurrent,
    pm.ProductModelID,
    pm.[Name]  AS ModelName,
    psc.[Name] AS SubcategoryName,
    pc.[Name]  AS CategoryName,
    CAST(CASE WHEN p.SellEndDate <= w.ToDate THEN p.SellEndDate ELSE NULL END AS date) AS SellEndDate
FROM CompanyX.Production.Product                 AS p
JOIN CompanyX.Production.ProductListPriceHistory AS lp  ON lp.ProductID = p.ProductID
JOIN CompanyX.Production.ProductCostHistory      AS c   ON c.ProductID  = lp.ProductID
                                                       AND c.StartDate  = lp.StartDate
JOIN CompanyX.Production.ProductModel            AS pm  ON pm.ProductModelID = p.ProductModelID
JOIN CompanyX.Production.ProductSubcategory      AS psc ON psc.ProductSubcategoryID = p.ProductSubcategoryID
JOIN CompanyX.Production.ProductCategory         AS pc  ON pc.ProductCategoryID = psc.ProductCategoryID
CROSS JOIN CompanyX_DW.etl.vReplayWindow         AS w
WHERE lp.StartDate <= w.ToDate
  AND EXISTS (SELECT 1 FROM CompanyX.Sales.SalesOrderDetail AS d WHERE d.ProductID = p.ProductID);
*/

/* ---------------------------------------------------------------------
   B. LoadOrderLineFact - replace the OLE DB Source query with this windowed version.
      FromDate is exclusive and ToDate is inclusive, so windows never overlap.
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
CROSS JOIN CompanyX_DW.etl.vReplayWindow AS w
WHERE h.Status = 5
  AND CAST(h.OrderDate AS date) >  w.FromDate
  AND CAST(h.OrderDate AS date) <= w.ToDate;
*/

/* ---------------------------------------------------------------------
   C. MasterLoad - add a 4th Execute SQL Task (connection CompanyX_DW) AFTER the
      three Execute Package Tasks, name it AdvanceWatermark. It runs only when
      all three succeeded, so a failed run does not move the clock.
   --------------------------------------------------------------------- */
/*
DECLARE @To date = (SELECT ToDate FROM etl.vReplayWindow);
DECLARE @Rows int = (SELECT COUNT(*) FROM staging.OrderLine);

UPDATE etl.Watermark
SET    LastWatermark = @To,
       LastRunAt     = SYSDATETIME(),
       RowsLoaded    = @Rows
WHERE  TableName = N'dw.OrderLineFact';

INSERT INTO etl.RunLog (PackageName, FinishedAt, [Status], RowsRead, RowsInserted, Message)
VALUES (N'MasterLoad', SYSDATETIME(), 'Succeeded', @Rows, @Rows,
        CONCAT(N'Window loaded up to ', CONVERT(nvarchar(10), @To, 23)));
*/

/* =====================================================================
   TEST SEQUENCE (run in SSMS; run MasterLoad in Visual Studio where noted)
   ===================================================================== */

/*
-- T1. Rewind: empties fact + dimensions, clock = 2011-05-30
EXEC etl.usp_ReplayReset;

-- T2. Catch-up window: 2011-05-30 + 358 days = 2012-05-22 (just before the first price change)
UPDATE etl.ReplayConfig SET WindowDays = 358;
SELECT * FROM etl.vReplayWindow;          -- expect FromDate 2011-05-30, ToDate 2012-05-22

-- >>> run MasterLoad in Visual Studio <<<

-- T3. State after the catch-up. Expect: every product version open (IsCurrent = 1),
--     latest order date 2012-05-22 or earlier, clock at 2012-05-22.
SELECT COUNT(*) AS ProductVersions, SUM(CAST(IsCurrent AS int)) AS CurrentVersions FROM dw.ProductDim;
SELECT COUNT(*) AS FactLines, MAX(d.FullDate) AS LastOrderDate
FROM dw.OrderLineFact f JOIN dw.DateDim d ON d.DateKey = f.DateKey;
SELECT LastWatermark, RowsLoaded FROM etl.Watermark WHERE TableName = N'dw.OrderLineFact';

-- T4. Normal window: 7 days at a time
UPDATE etl.ReplayConfig SET WindowDays = 7;
-- >>> run MasterLoad (-> 2012-05-29, still no price change) <<<
-- >>> run MasterLoad (-> 2012-06-05, crosses 2012-05-30: SCD2 versions appear) <<<

-- T5. SCD2 evidence: products now having a closed version and a new current version
SELECT COUNT(*) AS ProductVersions,
       SUM(CAST(IsCurrent AS int)) AS CurrentVersions,
       SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END) AS ClosedVersions
FROM dw.ProductDim;

-- T6. Finish the replay: one huge window is capped at the last date (2014-06-30)
UPDATE etl.ReplayConfig SET WindowDays = 2000;
-- >>> run MasterLoad <<<

-- T7. Final state must equal the earlier one-shot full load:
--     353 versions, 19,119 customers, 120,147 lines, revenue 108,734,796.040861, clock 2014-06-30
SELECT (SELECT COUNT(*) FROM dw.ProductDim)    AS ProductVersions,
       (SELECT COUNT(*) FROM dw.CustomerDim)   AS Customers,
       (SELECT COUNT(*) FROM dw.OrderLineFact) AS FactLines,
       (SELECT SUM(LineTotal) FROM dw.OrderLineFact) AS Revenue,
       (SELECT LastWatermark FROM etl.Watermark WHERE TableName = N'dw.OrderLineFact') AS Clock;
*/
