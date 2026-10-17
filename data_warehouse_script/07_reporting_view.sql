/* =====================================================================
   Reporting view for association rules: plain names for outside readers.
   The table keeps the brief's pattern labels and technical column names,
   so the mining code and checks do not change. Power BI reads this view.
   ===================================================================== */
USE CompanyX_DW;
GO

IF SCHEMA_ID(N'rpt') IS NULL EXEC (N'CREATE SCHEMA rpt');
GO

CREATE OR ALTER VIEW rpt.AssociationRules
AS
SELECT
    r.RuleKey,
    r.Channel,
    r.AntecedentModelName                AS TriggerModel,       -- already in the basket
    r.ConsequentModelName                AS OfferModel,         -- suggested to the customer
    r.AntecedentModelID                  AS TriggerModelID,
    r.ConsequentModelID                  AS OfferModelID,
    r.Support                            AS ShareOfAllOrdersWithBoth,
    r.Confidence                         AS ShareOfTriggerOrdersWithOffer,
    r.Lift                               AS Lift,
    r.CoOccurrenceCount                  AS OrdersWithBoth,
    r.AntecedentSupport                  AS ShareOfOrdersWithTrigger,
    r.ConsequentSupport                  AS ShareOfOrdersWithOffer,
    r.RuleClassification                 AS BriefPatternType,
    CASE r.RuleClassification
         WHEN 'Bundle'     THEN N'Bought together'
         WHEN 'Hidden gem' THEN N'Under-promoted pair'
         WHEN 'Chance'     THEN N'Popular by coincidence'
         WHEN 'Weak'       THEN N'Weak link'
         WHEN 'Substitute' THEN N'Alternatives'
    END                                  AS PatternLabel,
    r.GeneratedDate
FROM dw.AssociationRulesFact AS r;
GO

-- Check: every stored pattern type has a plain label (expect 0 rows)
SELECT DISTINCT BriefPatternType FROM rpt.AssociationRules WHERE PatternLabel IS NULL;

-- Check: row count matches the table (expect the same numbers)
SELECT (SELECT COUNT(*) FROM dw.AssociationRulesFact) AS TableRows,
       (SELECT COUNT(*) FROM rpt.AssociationRules)    AS ViewRows;
GO
