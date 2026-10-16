/* =====================================================================
   Step 3a: ProductDim - staging table, version-stream query, checks
   Run in SSMS against the same instance as CompanyX / CompanyX_DW.
   Source objects use three-part names, so the query also works as the
   OLE DB Source query in SSIS (connected to CompanyX or CompanyX_DW).
   Expected: 353 version rows for 266 ordered products.
   ===================================================================== */

USE CompanyX_DW;
GO

/* ---------------------------------------------------------------------
   1. Staging table (heap; truncated and reloaded on every run)
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'staging.ProductVersion', N'U') IS NULL
CREATE TABLE staging.ProductVersion
(
    ProductID       int           NOT NULL,
    [Name]          nvarchar(50)  NOT NULL,
    ProductNumber   nvarchar(25)  NOT NULL,
    Color           nvarchar(15)  NULL,
    ListPrice       decimal(19,4) NOT NULL,
    StandardCost    decimal(19,4) NOT NULL,
    EffectiveFrom   date          NOT NULL,
    EffectiveTo     date          NULL,        -- NULL = open-ended
    IsCurrent       bit           NOT NULL,
    ProductModelID  int           NOT NULL,
    ModelName       nvarchar(50)  NOT NULL,
    SubcategoryName nvarchar(50)  NOT NULL,
    CategoryName    nvarchar(50)  NOT NULL,
    SellEndDate     date          NULL,
    LoadedAt        datetime      NOT NULL CONSTRAINT DF_stgProductVersion_LoadedAt DEFAULT (SYSDATETIME())
);
GO

/* ---------------------------------------------------------------------
   2. The version-stream extraction query (this is the SSIS source query)
      - list-price and cost histories share identical version boundaries,
        so they join on ProductID + StartDate into one stream
      - only products that appear on at least one order line
      - EffectiveTo / IsCurrent come from the history EndDate
        (NULL EndDate = open-ended = current version)
   --------------------------------------------------------------------- */
/*
SELECT
    p.ProductID,
    p.[Name],
    p.ProductNumber,
    p.Color,
    CAST(lp.ListPrice  AS decimal(19,4)) AS ListPrice,
    CAST(c.StandardCost AS decimal(19,4)) AS StandardCost,
    CAST(lp.StartDate AS date)           AS EffectiveFrom,
    CAST(lp.EndDate   AS date)           AS EffectiveTo,
    CASE WHEN lp.EndDate IS NULL THEN 1 ELSE 0 END AS IsCurrent,
    pm.ProductModelID,
    pm.[Name]  AS ModelName,
    psc.[Name] AS SubcategoryName,
    pc.[Name]  AS CategoryName,
    CAST(p.SellEndDate AS date)          AS SellEndDate
FROM CompanyX.Production.Product              AS p
JOIN CompanyX.Production.ProductListPriceHistory AS lp  ON lp.ProductID = p.ProductID
JOIN CompanyX.Production.ProductCostHistory      AS c   ON c.ProductID  = lp.ProductID
                                                       AND c.StartDate  = lp.StartDate
JOIN CompanyX.Production.ProductModel            AS pm  ON pm.ProductModelID = p.ProductModelID
JOIN CompanyX.Production.ProductSubcategory      AS psc ON psc.ProductSubcategoryID = p.ProductSubcategoryID
JOIN CompanyX.Production.ProductCategory         AS pc  ON pc.ProductCategoryID = psc.ProductCategoryID
WHERE EXISTS (SELECT 1 FROM CompanyX.Sales.SalesOrderDetail AS d WHERE d.ProductID = p.ProductID);
*/

/* ---------------------------------------------------------------------
   3. Load staging with T-SQL (for testing in SSMS; the SSIS data flow
      will do the same: truncate, then source query -> staging table)
   --------------------------------------------------------------------- */
TRUNCATE TABLE staging.ProductVersion;

INSERT INTO staging.ProductVersion
    (ProductID, [Name], ProductNumber, Color, ListPrice, StandardCost,
     EffectiveFrom, EffectiveTo, IsCurrent,
     ProductModelID, ModelName, SubcategoryName, CategoryName, SellEndDate)
SELECT
    p.ProductID,
    p.[Name],
    p.ProductNumber,
    p.Color,
    CAST(lp.ListPrice   AS decimal(19,4)),
    CAST(c.StandardCost AS decimal(19,4)),
    CAST(lp.StartDate AS date),
    CAST(lp.EndDate   AS date),
    CASE WHEN lp.EndDate IS NULL THEN 1 ELSE 0 END,
    pm.ProductModelID,
    pm.[Name],
    psc.[Name],
    pc.[Name],
    CAST(p.SellEndDate AS date)
FROM CompanyX.Production.Product              AS p
JOIN CompanyX.Production.ProductListPriceHistory AS lp  ON lp.ProductID = p.ProductID
JOIN CompanyX.Production.ProductCostHistory      AS c   ON c.ProductID  = lp.ProductID
                                                       AND c.StartDate  = lp.StartDate
JOIN CompanyX.Production.ProductModel            AS pm  ON pm.ProductModelID = p.ProductModelID
JOIN CompanyX.Production.ProductSubcategory      AS psc ON psc.ProductSubcategoryID = p.ProductSubcategoryID
JOIN CompanyX.Production.ProductCategory         AS pc  ON pc.ProductCategoryID = psc.ProductCategoryID
WHERE EXISTS (SELECT 1 FROM CompanyX.Sales.SalesOrderDetail AS d WHERE d.ProductID = p.ProductID);
GO

/* ---------------------------------------------------------------------
   4. Checks (expected values in the comments)
   --------------------------------------------------------------------- */

-- 4a. Row counts: expect 353 version rows, 266 distinct products
SELECT COUNT(*) AS VersionRows, COUNT(DISTINCT ProductID) AS Products
FROM staging.ProductVersion;

-- 4b. Current vs retired: expect 183 products with a current version, 83 without
SELECT
    SUM(CASE WHEN HasCurrent = 1 THEN 1 ELSE 0 END) AS ProductsWithCurrentVersion,
    SUM(CASE WHEN HasCurrent = 0 THEN 1 ELSE 0 END) AS RetiredProducts
FROM (SELECT ProductID, MAX(CAST(IsCurrent AS int)) AS HasCurrent
      FROM staging.ProductVersion GROUP BY ProductID) AS x;

-- 4c. More than one current version for a product: expect 0 rows
SELECT ProductID, COUNT(*) AS CurrentRows
FROM staging.ProductVersion
WHERE IsCurrent = 1
GROUP BY ProductID
HAVING COUNT(*) > 1;

-- 4d. List-price rows that found no matching cost row (boundaries should be identical): expect 0
SELECT COUNT(*) AS ListRowsWithoutCost
FROM CompanyX.Production.ProductListPriceHistory AS lp
WHERE EXISTS (SELECT 1 FROM CompanyX.Sales.SalesOrderDetail d WHERE d.ProductID = lp.ProductID)
  AND NOT EXISTS (SELECT 1 FROM CompanyX.Production.ProductCostHistory c
                  WHERE c.ProductID = lp.ProductID AND c.StartDate = lp.StartDate);

-- 4e. Ordered products dropped by the joins (no history or a broken hierarchy): expect 0
SELECT COUNT(*) AS OrderedProductsMissing
FROM (SELECT DISTINCT ProductID FROM CompanyX.Sales.SalesOrderDetail) AS o
WHERE NOT EXISTS (SELECT 1 FROM staging.ProductVersion s WHERE s.ProductID = o.ProductID);

-- 4f. Gaps or overlaps between consecutive versions: expect 0 rows
--     (each version should start exactly one day after the previous one ends)
SELECT ProductID, EffectiveFrom, PrevEffectiveTo
FROM (
    SELECT ProductID, EffectiveFrom,
           LAG(EffectiveTo) OVER (PARTITION BY ProductID ORDER BY EffectiveFrom) AS PrevEffectiveTo
    FROM staging.ProductVersion
) AS v
WHERE PrevEffectiveTo IS NOT NULL
  AND DATEADD(DAY, 1, PrevEffectiveTo) <> EffectiveFrom;
GO

/* ---------------------------------------------------------------------
   5. Optional: manual initial load into dw.ProductDim
      The SSIS package will replace this. To re-test the package later,
      run DELETE FROM dw.ProductDim first (only safe while OrderLineFact is empty).
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dw.ProductDim)
BEGIN
    INSERT INTO dw.ProductDim
        (ProductID, [Name], ProductNumber, Color, ListPrice, StandardCost,
         EffectiveFrom, EffectiveTo, IsCurrent,
         ProductModelID, ModelName, SubcategoryName, CategoryName, SellEndDate)
    SELECT
        ProductID, [Name], ProductNumber, Color, ListPrice, StandardCost,
        EffectiveFrom, EffectiveTo, IsCurrent,
        ProductModelID, ModelName, SubcategoryName, CategoryName, SellEndDate
    FROM staging.ProductVersion
    ORDER BY ProductID, EffectiveFrom;   -- gives ProductKey a stable, readable order
END
GO

-- Expect 353 rows, 266 products, 183 current rows
SELECT COUNT(*) AS DimRows,
       COUNT(DISTINCT ProductID) AS Products,
       SUM(CAST(IsCurrent AS int)) AS CurrentRows
FROM dw.ProductDim;
GO
