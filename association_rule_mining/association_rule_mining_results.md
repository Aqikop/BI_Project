# Association Rule Mining: Results
**Topic 3: Product and Association Rules (CompanyX / AdventureWorks)**

Notebook: `association_rule_mining.ipynb`, run on the warehouse `CompanyX_DW`.

**Status key:** *Current* = from the corrected run (individual analysis from 2013-05-30). *Pending rerun* = figures from the earlier run, superseded by the launch-date correction; refresh them before they go in the report.

---

## 1. What was run

| Item | Setting |
|---|---|
| Input | `dw.OrderLineFact` joined to `dw.ProductDim` (model level) and `dw.CustomerDim` (channel); shipped orders only |
| Purchase filter | lines with `OrderQty > 0 AND UnitPrice > 0` (the 75 anomalous lines are excluded) |
| Item | Product Model (`ProductModelID`) |
| Algorithm | FP-Growth (`mlxtend`), pair rules only, minimum support 1% |
| Analysis window | **Individual: from 2013-05-30** (accessories, clothing and new bike models first sold to individuals that day). **Reseller: all orders** |
| Runs | Individual (main analysis) and Reseller (comparison only). No pooled run |
| Stored in | `dw.AssociationRulesFact` (both directions of each pair), labelled with the brief's pattern types |

---

## 2. Run summary

### Individual run (Current)

| | Value |
|---|---|
| Orders in window | 22,008 |
| Orders with a valid line (support base) | 22,008 |
| Orders with 2+ models | 17,805 (matches the SQL count: OK) |
| Single-model orders | 4,203 |
| Product models seen | 37 |
| Frequent single models (support 1% or more) | 37 |
| Frequent pairs | 63 |
| **Rules stored (both directions)** | **126** |
| Max gap, count vs support × orders | 0.0 |

### Reseller run (Current; the launch-date correction does not apply to it)

| | Value |
|---|---|
| Orders in channel | 3,768 |
| Orders with a valid line (support base) | 3,762 |
| Orders with 2+ models | 3,025 |
| Single-model orders | 737 |
| Product models seen | 93 |
| Frequent pairs | 1,418 |
| **Rules stored (both directions)** | **2,836** |

The reseller base is 3,762, not 3,768: the six orders 43677 to 43682 contain only anomalous lines, so they cannot form baskets.

---

## 3. Pattern types

The database keeps the brief's five labels. The report uses the plain labels below, which are applied in a reporting view (`rpt.AssociationRules`). The labels describe customer behaviour, not profit.

| Brief label (stored) | Report label | Definition | Individual | Reseller |
|---|---|---|---|---|
| Bundle | **Bought together** | Lift 1.5 or more, support 5% or more | 4 | 506 |
| Hidden gem | **Under-promoted pair** | Lift 1.5 or more, support 1% to 5% | 66 | 2,026 |
| Chance | **Popular by coincidence** | Lift 1 to 1.5, support 5% or more | 2 | 30 |
| Weak | **Weak link** | Lift 1 to 1.5, support 1% to 5% | 26 | 248 |
| Substitute | **Alternatives** | Lift below 1 | 28 | 26 |
| **Total** | | | **126** | **2,836** |

The individual total rose from 106 to 126 after the launch correction, and Alternatives rose from 10 to 28.

---

## 4. Individual candidates: training vs test (Current)

Candidates are rules chosen on the training period (2011 to 2013, from the launch date) that pass the cross-sell or discounted-bundle thresholds. Test = 2014, January to June.

| Rule | Support | Confidence | Lift (train) | Orders with both (train) | Lift (test) | Holds |
|---|---|---|---|---|---|---|
| Touring Tire → Touring Tire Tube | 3.4% | 85.6% | 13.33 | 375 | 12.51 | Yes |
| Touring Tire Tube → Touring Tire | 3.4% | 53.1% | 13.33 | 375 | 12.51 | Yes |
| HL Road Tire → Road Tire Tube | 2.9% | 68.7% | 6.25 | 322 | 6.79 | Yes |
| Road Tire Tube → HL Road Tire | 2.9% | 26.7% | 6.25 | 322 | 6.79 | Yes |
| ML Road Tire → Road Tire Tube | 2.7% | 63.5% | 5.78 | 294 | 6.46 | Yes |
| Road Tire Tube → ML Road Tire | 2.7% | 24.3% | 5.78 | 294 | 6.46 | Yes |
| HL Mountain Tire → Mountain Tire Tube | 4.4% | 68.8% | 4.79 | 483 | 5.07 | Yes |
| Mountain Tire Tube → HL Mountain Tire | 4.4% | 30.6% | 4.79 | 483 | 5.07 | Yes |
| Road Tire Tube → LL Road Tire | 2.5% | 22.4% | 4.79 | 271 | 5.15 | Yes |
| LL Road Tire → Road Tire Tube | 2.5% | 52.6% | 4.79 | 271 | 5.15 | Yes |
| Mountain Tire Tube → ML Mountain Tire | 3.8% | 26.3% | 4.77 | 415 | 4.84 | Yes |
| ML Mountain Tire → Mountain Tire Tube | 3.8% | 68.5% | 4.77 | 415 | 4.84 | Yes |
| Road Bottle Cage → Water Bottle | 6.9% | 88.8% | 4.66 | 753 | 4.67 | Yes |
| Mountain Bottle Cage → Water Bottle | 7.6% | 83.3% | 4.37 | 830 | 4.37 | Yes |
| Mountain Tire Tube → LL Mountain Tire | 2.2% | 15.0% | 3.84 | 237 | 4.13 | Yes |
| LL Mountain Tire → Mountain Tire Tube | 2.2% | 55.1% | 3.84 | 237 | 4.13 | Yes |
| Touring-1000 → Sport-100 | 2.3% | 45.6% | 1.59 | 252 | 1.44 | **No** |

---

## 5. Time split (Current)

Training: 2013-05-30 to 2013-12-31 (10,989 orders). Test: 2014-01-01 to 2014-06-30 (11,019 orders).

| Measure | Result |
|---|---|
| Rules mined on the training period | 130 |
| Strong rules in training (lift 1.5 or more) | 68 |
| Strong rules judged in the test period | 68 |
| **Strong rules that hold (test lift 1.5 or more)** | **62 of 68 (91%)** |
| Strong rules still above lift 1 in the test period | 68 of 68 |
| **Median test lift ÷ training lift** | **1.00** |
| Rank correlation of lift, training vs test | 0.98 |
| Frequent pairs: training / test / both | 65 / 63 / 58 |
| Cross-sell candidates chosen on training | 11, of which 10 hold |
| Discounted-bundle candidates chosen on training | 14, of which all 14 hold |

**Reading.** Lift is stable between the two periods. The six strong rules that do not hold are a minority, and the one cross-sell candidate that fails is Touring-1000 → Sport-100 (lift 1.59 to 1.44). Rules that hold in 2014 are the ones worth reporting.

**Why this is a correction.** The earlier run counted orders from 2011 to May 2013 in the base, when accessories could not be bought, so every accessory pair's lift was understated in the test period. The median ratio was 0.68 then and is 1.00 now, which confirms the explanation.

---

## 6. Use-case rules

### Lift and support (Current)

Full-window figures for Road-750 → Road Bottle Cage (from the sizing cell): support 2.52%, confidence 38.7%, lift 5.03, Hidden gem, both models still on sale.

| | Mountain Tire Tube → LL Mountain Tire | Road-750 → Road Bottle Cage |
|---|---|---|
| Training: orders with the trigger | 1,578 | 711 |
| Training: orders with both | 237 | 280 |
| Training: support | 2.2% | 2.5% |
| Training: confidence | 15.0% | 39.4% |
| **Training: lift** | **3.84** | **5.10** |
| Test: orders with the trigger | 1,480 | 721 |
| Test: orders with both | 237 | 274 |
| Test: support | 2.2% | 2.5% |
| Test: confidence | 16.0% | 38.0% |
| **Test: lift** | **4.13** | **4.96** |
| Holds in 2014 | Yes | Yes |

Both rules hold. Road-750 → Road Bottle Cage has the more stable lift, moving from 5.10 to 4.96.

### Economics (Current)

Base case: 5% of reachable orders add the offered model, with a 10% discount on it. Reach = orders with the trigger and without the offer. **Refined reach** also leaves out orders that already hold an alternative to the offer (same subcategory, lift below 0.8 against it, at least 30 orders), because a customer with another grade of tyre will not add a second one.

| Rule | Reach before → after | Net profit before → after | Break-even before → after |
|---|---|---|---|
| Mountain Tire Tube → LL Mountain Tire | 2,584 → **869** (66% removed) | +514 → **−613** | 3.5% → **10.4%** |
| Road-750 → Road Bottle Cage | 878 → 878 (0% removed) | −290 → −290 | 12.0% → 12.0% |

- For the tyre offer, the alternatives excluded include ML Mountain Tire, HL Mountain Tire and LL Road Tire (the notebook prints the full list).
- Road-750 → Road Bottle Cage has one alternative, Mountain Bottle Cage, and no Road-750 order without the Road Bottle Cage holds it, so its reach is unchanged.
- **The earlier +514 is withdrawn.** It rested on tube buyers who already held another tyre.

**No-discount result (unchanged, Road-750 → Road Bottle Cage):** net profit +99, +247 and +494 at 2%, 5% and 10% conversion. Without a discount a suggestion cannot lose money on its own, because the only cost is the missed margin on sales that would have happened anyway, which is zero.

**All 15 candidates re-ranked on the refined reach** (5% conversion, 10% discount): none is profitable. The least negative is LL Road Tire → Road Tire Tube (−167, break-even 21.5%), followed by LL Mountain Tire → Mountain Tire Tube (−186, 23.5%). Touring Tire → Touring Tire Tube (break-even 120.1%) and Road Bottle Cage → Water Bottle (153.0%) cannot pay off at a 10% discount, because almost every trigger order already contains the offer.

*Pending:* the refined net profit grid for discounts of 0%, 5% and 10% (printed by notebook section 8b). It will show whether a small discount of about 5% or less can work for the tyre offer.

**Use of the 869 reachable orders.** Several tyre offers (LL, ML or HL Mountain Tire) share the same group of tube buyers who hold no tyre, and they compete with each other, so these rules describe one pool of customers, not three separate opportunities.

---

## 7. Reseller run: strongest rules by lift (Current)

The top rules are forks and headsets across grades, with lift 25 to 37 and small counts (38 to 97 orders). HL Touring Handlebars with Touring Pedal (lift 25.1, 50 orders) is also in the top group.

| Pair | Support | Lift | Co-occurrence |
|---|---|---|---|
| LL Fork / LL Headset | 1.01% | 37.44 | 38 |
| LL Fork / HL Headset | 1.89% | 29.26 | 71 |
| HL Fork / ML Headset | 2.58% | 28.86 | 97 |
| ML Headset / HL Headset | 2.39% | 28.24 | 90 |
| HL Fork / HL Headset | 2.50% | 27.71 | 94 |
| LL Fork / ML Headset | 1.75% | 27.44 | 66 |
| LL Fork / HL Fork | 1.78% | 26.18 | 67 |

Support here is relative to the 3,762 reseller orders, so it is not comparable with the individual run.

---

## 8. Individual vs reseller comparison (Current)

Notebook section 7. Counts are rules (both directions of each pair).

| Group | Rules | Pairs |
|---|---|---|
| In both channels | 44 | 22 |
| Individual only | 82 | 41 |
| Reseller only | 2,792 | 1,396 |

Totals check: 44 + 82 = 126 individual rules; 44 + 2,792 = 2,836 reseller rules.

**Pairs in both channels (lift individual / lift reseller)**

| Pair | Individual | Reseller | Reading |
|---|---|---|---|
| Bike Wash / Patch kit | 2.15 / 7.27 | Hidden gem / Hidden gem | Robust in both |
| Water Bottle / Hydration Pack | 2.06 / 8.10 | Hidden gem / Bundle | Robust; stronger for resellers |
| Road-750 / Water Bottle | 1.76 / 3.47 | Hidden gem / Hidden gem | Robust |
| Short-Sleeve Classic Jersey / Cycling Cap | 2.16 / 2.40 | Hidden gem / Bundle | Robust |
| Cycling Cap / Long-Sleeve Logo Jersey | 1.60 / 2.69 | Hidden gem / Bundle | Robust |
| Water Bottle / Cycling Cap | 1.50 / 2.83 | Hidden gem / Bundle | Robust |
| **Cycling Cap / Women's Mountain Shorts** | **2.22 / 0.99** | **Hidden gem / Alternatives** | Individuals buy together; resellers do not |
| **Sport-100 / Touring-1000** | **1.51 / 0.88** | **Hidden gem / Alternatives** | Borderline for individuals; resellers below chance |

**Reading.** Most of the 22 shared pairs are strong in both channels, which makes them the most defensible candidates. Two pairs reverse: Cycling Cap with Women's Mountain Shorts looks like a consumer pattern, and resellers appear to buy those items separately. The reseller-only group (2,792 rules) remains far larger than the individual one, which supports keeping the reseller run as a comparison rather than a source of consumer offers. Tyre-and-tube pairs are not among the shared pairs at the 1% threshold, so the strongest individual rules are consumer-specific.

Support is relative to each channel's own orders, so compare lift, not support.

---

## 9. Product-family check (Current)

| Share of rules | Individual (126 rules) | Reseller (2,836 rules) |
|---|---|---|
| Same subcategory | 30.2% | 4.7% |
| Same category | 60.3% | 32.1% |
| Both models still on sale | 100% | 68.3% |

**Finding that still holds for the reseller side:** reseller rules are less often within one product family than individual rules, so the restocking-within-family explanation is not supported. The data does not show why the reseller associations exist.

---

## 10. Sensitivity to the minimum support (Current)

Individual run on 22,008 orders. Rules are counted in both directions.

| Min support | Pairs | Rules | Smallest co-occurrence | Rules with lift 1.5 or more | Cross-sell at confidence 30% / 40% / 50% | Top-20 rules still present | Top-20 overlap with brief |
|---|---|---|---|---|---|---|---|
| 0.5% | 134 | 268 | 112 | 122 | 28 / 11 / 10 | 20/20 | 14/20 |
| **1% (brief)** | **63** | **126** | **221** | **70** | **25 / 11 / 10** | **20/20** | **20/20** |
| 2% | 30 | 60 | 447 | 36 | 20 / 11 / 10 | 18/20 | 18/20 |
| 3% | 12 | 24 | 704 | 16 | 11 / 6 / 6 | 10/20 | 10/20 |
| 5% | 3 | 6 | 1,310 | 4 | 4 / 2 / 2 | 4/20 | 4/20 |

**Lift and confidence at the brief's 1% support**

| | Confidence 30% | Confidence 40% | Confidence 50% |
|---|---|---|---|
| Lift 1.2 or more | 29 | 14 | 10 |
| Lift 1.5 or more | 25 | 11 | 10 |
| Lift 2.0 or more | 23 | 10 | 10 |
| Lift 3.0 or more | 19 | 10 | 10 |

**Reading**
- **The brief's 1% setting is defensible.** It gives 63 pairs, the smallest pair has 221 orders behind it, and all of the 20 strongest rules are present.
- **Stability holds up to 2%.** At 2%, 18 of the top 20 remain and the 40% cross-sell set falls only from 11 to 10.
- **Going below 1% adds rules, not decisions.** At 0.5% there are 71 more pairs, but the 40% cross-sell set stays at 11, so the extra pairs rest on as few as 112 orders.
- **Confidence decides the cross-sell set, lift barely matters.** At 40% confidence the count is 10 to 14 whatever the lift cut-off, and at 50% it is 10 throughout.
- **Correction to an earlier statement.** The use-case pair Mountain Tire Tube → LL Mountain Tire was said to drop out at 2% support. That was on the old base. On the corrected base it has 474 orders, 2.2% support, so it survives 2%. Road-750 → Road Bottle Cage (2.5%) also survives 2%. Neither survives 3%.

*Caveat:* the stability columns measure which pairs pass each support filter. They do not test whether the rules are real. The time split in section 5 is that test.

## 11. June 2014 check (Current)

Test period Jan to Jun 2014 against Jan to May 2014 (training unchanged).

| Measure | Jan to Jun 2014 | Jan to May 2014 |
|---|---|---|
| Test orders | 11,019 | 10,089 |
| Judged strong rules | 68 | 68 |
| Hold (test lift 1.5 or more) | 62 | 62 |
| Hold rate | 91.2% | 91.2% |
| Median test lift ÷ training lift | 1.00 | 1.01 |
| Rank correlation of lift | 0.98 | 0.98 |

The holding set is identical with and without June. The use-case rules move by less than 10%:

| Use-case rule | Test lift, to June | Test lift, to May |
|---|---|---|
| Mountain Tire Tube → LL Mountain Tire | 4.13 | 4.41 |
| Road-750 → Road Bottle Cage | 4.96 | 4.60 |

June 2014 does not change any decision. The two use cases move in opposite directions, so the report should quote the full six-month figures.

---

## 12. Seasonality (Appendix, not used in the conclusions)

The quarterly index and lift results were dominated by the 2013 launch of accessories and clothing, not by seasons. About one year of post-launch data cannot separate seasonality from growth, so seasonal timing of offers is listed as a limitation. Lift did not vary by quarter for most strong pairs.

---

## 13. Method changes and why

| Change | Reason |
|---|---|
| Individual analysis starts 2013-05-30 | Individual customers could not buy accessories or clothing before that date, so earlier orders inflated the support base and understated lift |
| Reconciliation counted inside SQL | Replaces a hard-coded expected value that belonged to the old base |
| Seasonality moved to an appendix | Quarterly indices reflected the launch and growth, not seasons |
| Pattern labels shown as plain names | Brief labels are kept in the database; plain labels describe behaviour for non-specialist readers |

---

## 14. Limitations to state in the report

- The individual analysis covers about 13 months after launch (training about seven months), not the full dataset. Accessory and clothing rules are only as reliable as that history.
- Association is co-occurrence, not causation.
- Conversion rates and discounts are assumptions. The real test is a pilot with a control group.
- Reachable orders for tyre and tube offers were reduced by excluding customers who already hold an alternative. The alternatives are found from the baskets with a cut-off (lift below 0.8, at least 30 orders), which is a judgement, and the conversion rate remains an assumption.
- The pattern cut-offs (lift 1.5, support 5%) are the team's own definitions and should be checked with the lecturer.
- Labels describe what customers do together, not whether an offer will pay. Profit depends on the break-even check.
- Cancelled orders are excluded from the warehouse (shipped-only load, provisional).
- Seasonality and holidays are not modelled.
- The time split is one split (training to 2013, test on the first half of 2014).
- The reseller support base has not yet been checked for product launch dates.

---

## 15. Open items

1. Rerun notebook section 8b to print the refined net profit grid by discount, add it to section 6, and choose the use-case rule (the no-discount Road-750 → Road Bottle Cage offer is the most robust so far).
2. Check reseller category start dates (`CustomerType = 'Reseller'`) before treating the reseller base as clean.
3. Apply the reporting view (`07_reporting_view.sql`) so Power BI reads the plain names. Done: the view returns 2,962 rows, matching the table.
4. Choose the use-case rule after the economics rerun.
5. Decide whether tyre and tube pairs are natural bundles or trivial rules for the report.
6. Check the pattern definitions with the lecturer.
7. Build the Power BI pages: rules (slicers for channel, pattern, lift, confidence), sales and basket pages, and the use-case page.