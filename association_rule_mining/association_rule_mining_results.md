# Association Rule Mining: Results
**Topic 3: Product and Association Rules (CompanyX / AdventureWorks)**

Notebook: `association_rule_mining.ipynb`, run on the warehouse `CompanyX_DW`.

**Mining stage: complete.** Every section below is *Current*, meaning it comes from the corrected run (individual analysis from 2013-05-30, reseller analysis on all orders). The seasonality section is an appendix and is not used in the conclusions.

| Mining-stage item | Status |
|---|---|
| Rules mined and stored in `dw.AssociationRulesFact` (126 individual, 2,226 reseller, both from 2013-05-30; 2,352 rows; notebook rerun verified) | Done |
| Plain-label reporting view `rpt.AssociationRules` | Done |
| Validation: time split, June check, sensitivity grid, channel comparison | Done |
| Launch-date correction of the individual support base | Done |
| Reseller base check (category level, and model level for the use-case models) | Done |
| Use cases: three recommended, one extra, one rejected, with sizing grids | Done and confirmed by the team |
| Open: report write-up, lecturer check of the pattern definitions, Power BI | Next stage |

---

## 1. What was run

| Item | Setting |
|---|---|
| Input | `dw.OrderLineFact` joined to `dw.ProductDim` (model level) and `dw.CustomerDim` (channel); shipped orders only |
| Purchase filter | lines with `OrderQty > 0 AND UnitPrice > 0` (the 75 anomalous lines are excluded) |
| Item | Product Model (`ProductModelID`) |
| Algorithm | FP-Growth (`mlxtend`), pair rules only, minimum support 1% |
| Analysis window | **Both channels: from 2013-05-30** (accessories, clothing and new bike models first sold that day to individuals, and the same models first sold to resellers that day). Earlier orders are excluded from the support base |
| Runs | Individual (main analysis) and Reseller (comparison). Both channels use the same window from 2013-05-30. No pooled run |
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

### Reseller run (Current, restricted to 2013-05-30)

| | Value |
|---|---|
| Orders in channel since 2013-05-30 | 1,795 |
| Orders with a valid line (support base) | 1,795 |
| Orders with 2+ models | 1,475 |
| Single-model orders | 320 |
| Product models seen | 74 |
| Frequent pairs | 1,113 |
| **Rules stored (both directions)** | **2,226** |

Change from the earlier, unrestricted reseller run (3,762 orders, 1,418 pairs, 2,836 rules), which is now superseded: about half the reseller orders fall outside the window. The restriction removes pre-launch orders in which several of these models could not appear, which had been depressing support and pulling many pairs down to Hidden gem.

Before the window was applied, the reseller base was 3,762, not 3,768: the six orders 43677 to 43682 contain only anomalous lines, so they cannot form baskets.

---

## 3. Pattern types

The database keeps the brief's five labels. The report uses the plain labels below, which are applied in a reporting view (`rpt.AssociationRules`). The labels describe customer behaviour, not profit.

| Brief label (stored) | Report label | Definition | Individual | Reseller |
|---|---|---|---|---|
| Bundle | **Bought together** | Lift 1.5 or more, support 5% or more | 4 | 980 |
| Hidden gem | **Under-promoted pair** | Lift 1.5 or more, support 1% to 5% | 66 | 824 |
| Chance | **Popular by coincidence** | Lift 1 to 1.5, support 5% or more | 2 | 194 |
| Weak | **Weak link** | Lift 1 to 1.5, support 1% to 5% | 26 | 226 |
| Substitute | **Alternatives** | Lift below 1 | 28 | 2 |
| **Total** | | | **126** | **2,226** |

The individual total rose from 106 to 126 after the launch correction, and Alternatives rose from 10 to 28. The reseller total fell from 2,836 to 2,226 under the restricted window; Bundle rose from 506 to 980 and Hidden gem fell from 2,026 to 824.

---

## 4. Individual candidates: training vs test (Current)

Candidates are rules chosen on the training period (2013-05-30 to 2013-12-31, the individual analysis window) that pass the cross-sell or discounted-bundle thresholds. Test = 2014, January to June.

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

- For the tyre offer, the excluded models are ML Mountain Tire, HL Mountain Tire, LL Road Tire, ML Road Tire, HL Road Tire, Touring Tire, Road Tire Tube and Touring Tire Tube. The last two are not alternatives in the strict sense: a customer holding road or touring gear is unlikely to want a mountain tyre, so they are better described as competing or incompatible items. This makes 869 a **conservative (lower) bound**: the true reach for this offer lies between 869 and 2,584.
- Road-750 → Road Bottle Cage has one alternative, Mountain Bottle Cage, and no Road-750 order without the Road Bottle Cage holds it, so its reach is unchanged.
- **The earlier +514 is withdrawn.** It rested on tube buyers who already held another tyre.

**Why a no-discount suggestion cannot lose money on its own:** it gives nothing away on the sales that would have happened anyway, so profit is the extra sales times their margin. A discount is what creates the loss, because it is also given to customers who already buy both items.

**All 15 candidates re-ranked on the refined reach** (5% conversion, 10% discount): none is profitable. The least negative is LL Road Tire → Road Tire Tube (−167, break-even 21.5%), followed by LL Mountain Tire → Mountain Tire Tube (−186, 23.5%). Touring Tire → Touring Tire Tube (break-even 120.1%) and Road Bottle Cage → Water Bottle (153.0%) cannot pay off at a 10% discount, because almost every trigger order already contains the offer.

**Refined net profit grids** (notebook section 8b)

Mountain Tire Tube → LL Mountain Tire, refined reach 869:

| Discount | Low (2%) | Base (5%) | High (10%) | Break-even conversion |
|---|---|---|---|---|
| 0% | +272 | **+680** | +1,359 | none needed |
| 5% | −342 | +33 | +659 | 4.7% |
| 10% | −956 | −613 | −42 | 10.4% |

Road-750 → Road Bottle Cage, reach 878:

| Discount | Low (2%) | Base (5%) | High (10%) | Break-even conversion |
|---|---|---|---|---|
| 0% | +99 | **+247** | +494 | none needed |
| 5% | −158 | −22 | +206 | 5.5% |
| 10% | −415 | −290 | −83 | 12.0% |

**Reading**
- **Without a discount both offers are profitable at every conversion scenario.** The tyre offer is worth about 2.75 times the cage offer (+680 against +247 at 5% conversion) even on its conservative reach.
- **A 5% discount is marginal for the tyre offer** (+33 at 5% conversion, break-even 4.7%) and loses money for the cage offer at base conversion. **A 10% discount does not pay for either offer** at the base or low scenarios.
- The tyre offer is judgement-dependent (the reach depends on which items count as competing), while the cage offer is not.
- The data does not say which tyre grade to suggest: LL, ML and HL Mountain Tire compete for the same 869 orders, and the higher-margin grades may convert less often.

**Use of the 869 reachable orders.** Several tyre offers (LL, ML or HL Mountain Tire) share the same group of tube buyers who hold no tyre, and they compete with each other, so these rules describe one pool of customers, not three separate opportunities.

---

## 6a. Use-case comparison (Current)

Notebook section 13. Individual customers, conversion 5%, reach = refined reach (excluding customers who already hold an alternative to the offer). Net profit is in the source currency. A discount is applied to the offered item only. Conversion is held constant across discounts, so with no discount a suggestion always earns the most; a discount only pays if it lifts conversion.

| Rule | Categories | Lift train → test | Reseller lift | Reach before → after | Offer revenue / margin | Net profit at 0% / 5% / 10% discount | Break-even at 5% / 10% discount |
|---|---|---|---|---|---|---|---|
| Water Bottle → Hydration Pack | Accessories | 2.07 → 2.06 | 3.86 (restricted; 8.10 full base) | 3,913 → 3,913 | 54.99 / 34.42 | +6,735 / +5,416 / +4,097 | 0.6% / 1.4% |
| Cycling Cap → Short-Sleeve Classic Jersey | Clothing | 2.19 → 2.13 | 2.95 (restricted; 2.40 full base) | 1,829 → 1,557 | 53.99 / 12.42 | +967 / −150 / −1,268 | 6.0% / 16.6% |
| Patch kit → Bike Wash | Accessories | 2.06 → 2.26 | 3.47 (restricted; 7.27 full base) | 2,880 → 2,880 | 7.95 / 4.98 | +717 / +549 / +382 | 0.8% / 1.8% |
| Mountain Tire Tube → LL Mountain Tire | Accessories | 3.84 → 4.13 | not in reseller rules | 2,584 → 869 | 24.99 / 15.64 | +680 / +33 / −613 | 4.7% / 10.4% |
| Road-750 → Road Bottle Cage | Bikes → Accessories | 5.10 → 4.96 | not in reseller rules | 878 → 878 | 8.99 / 5.63 | +247 / −22 / −290 | 5.5% / 12.0% |
| Short-Sleeve Classic Jersey → Cycling Cap | Clothing | 2.19 → 2.13 | 2.95 (restricted) | 1,246 → 1,246 | 8.99 / 2.07 | +129 / −50 / −229 | 7.5% / 20.7% |
| Hydration Pack → Water Bottle | Accessories | 2.07 → 2.06 | 3.86 (restricted) | 438 → 438 | 4.99 / 3.12 | +68 / −8 / −84 | 5.6% / 12.3% |
| Bike Wash → Patch kit | Accessories | 2.06 → 2.26 | 3.47 (restricted) | 620 → 620 | 2.29 / 1.43 | +44 / +9 / −26 | 3.9% / 8.5% |
| Touring-1000 → Sport-100 | Bikes → Accessories | 1.59 → 1.44 | 1.06 (restricted) | 697 → 697 | 34.99 / 21.90 | +763 / −244 / −1,252 | 6.7% / 14.8% |

All nine rules are Under-promoted pairs. All hold in the 2014 test except Touring-1000 → Sport-100.

**Direction matters.** The same pair gives very different value in each direction: Water Bottle → Hydration Pack is worth +6,735, but Hydration Pack → Water Bottle only +68, because the offered item is cheap and the reach is small. Offer the higher-value item to buyers of the common one.

---

## 6b. Use cases (confirmed by the team)

The lecturer asked for at least three use cases. Chosen for evidence and for variety of category and action:

| # | Rule | Type of action | Net profit, no discount (5% conversion) | Why |
|---|---|---|---|---|
| 1 | Water Bottle → Hydration Pack | Accessory upsell | +6,735 | Largest value; stable lift (2.07 → 2.06); strong in both channels (restricted reseller lift 3.86); large reach |
| 2 | Cycling Cap → Short-Sleeve Classic Jersey | Clothing cross-sell | +967 | Second largest; holds in 2014; strong in both channels (restricted reseller lift 2.95); thin margin, so no discount |
| 3 | Mountain Tire Tube → LL Mountain Tire | Maintenance complement | +680 (on a conservative reach) | Lift stable (3.84 → 4.13); a discount of 5% roughly breaks even (+33, break-even 4.7%) |
| 4 (extra) | Road-750 → Road Bottle Cage | Bike with an accessory | +247 | Reach unaffected by the refinement; lift stable (5.10 → 4.96) |
| Rejected | Touring-1000 → Sport-100 | Do not act | — | Lift falls from 1.59 to 1.44 in 2014; for resellers it is near chance (1.06, restricted); shows the validation stopping a weak promotion |

### Use case 1: Water Bottle → Hydration Pack

- **Offer:** a Hydration Pack (average revenue 54.99, margin 34.42) to customers who buy a water bottle but not a hydration pack.
- **Evidence:** 284 orders already contain both, out of about 4,197 water-bottle orders (roughly 7%). Lift is 2.07 in training and 2.06 in 2014, so it is stable; the pair also appears in the restricted reseller run (lift 3.86).
- **Reach:** 3,913 orders; no alternatives to exclude.
- **Sizing at 5% conversion:** +6,735 with no discount, +5,416 at a 5% discount and +4,097 at 10%. Break-even conversion is 0.6% at a 5% discount and 1.4% at 10%.
- **Caution:** a 5% conversion would nearly double the current take-up (about 7%), so treat 5% as an optimistic case and read the 2% column beside it. The result stays positive in every scenario.

| Discount | Low (2%) | Base (5%) | High (10%) |
|---|---|---|---|
| 0% | +2,694 | +6,735 | +13,470 |
| 5% | +1,698 | +5,416 | +11,613 |
| 10% | +702 | +4,097 | +9,757 |

Break-even conversion: 0.6% at a 5% discount and 1.4% at 10%.
- **Action:** suggest at checkout without a discount. The large margin leaves room for a small discount, but the data cannot show whether a discount raises conversion.

### Use case 2: Cycling Cap → Short-Sleeve Classic Jersey

- **Offer:** a jersey (revenue 53.99, margin 12.42) to cap buyers.
- **Evidence:** 336 orders contain both; lift 2.19 in training and 2.13 in 2014; the restricted reseller lift is 2.95, so the pair is robust across channels.
- **Reach:** 1,829 orders, reduced to 1,557 (15% removed) after excluding customers who already hold another jersey (the Long-Sleeve Logo Jersey).
- **Sizing:** the margin is only about 23%, so a discount quickly removes the profit.

| Discount | Low (2%) | Base (5%) | High (10%) |
|---|---|---|---|
| 0% | +387 | +967 | +1,933 |
| 5% | −604 | −150 | +606 |
| 10% | −1,596 | −1,268 | −721 |

Break-even conversion: 6.0% at a 5% discount and 16.6% at 10%.
- **Action:** suggest without a discount. The reverse direction (jersey to cap) is worth only +129.

### Use case 3: Mountain Tire Tube → LL Mountain Tire

- **Offer:** a mountain tyre (revenue 24.99, margin 15.64) to tube buyers who hold no other tyre.
- **Evidence:** 474 orders contain both; lift 3.84 in training and 4.13 in 2014. The pair is not in the reseller rules, so it is individual-specific.
- **Reach:** 869 on a conservative basis (excluding customers holding another tyre or road gear); the true reach lies between 869 and 2,584.
- **Sizing at 5% conversion:** +680 with no discount, +33 at a 5% discount (break-even 4.7%), −613 at 10% (break-even 10.4%).
- **Action:** suggest without a discount, or at most a 5% discount. The data does not say which tyre grade to suggest, because LL, ML and HL compete for the same customers.

### Use case 4 (extra): Road-750 → Road Bottle Cage

- **Offer:** a bottle cage (revenue 8.99, margin 5.63) to buyers of the Road-750 bike.
- **Evidence:** 554 orders contain both; lift 5.10 in training and 4.96 in 2014.
- **Reach:** 878, unaffected by the refinement. Sizing at 5% conversion: +247 with no discount, −22 at 5% (break-even 5.5%), −290 at 10% (12.0%).
- **Action:** suggest at the bike purchase without a discount. The value is small because the cage is a low-priced item.

### Rejected rule: Touring-1000 → Sport-100

Lift of 1.59 in training falls to 1.44 in 2014, below the 1.5 threshold, and resellers show 0.88, below chance. The no-discount value looks positive (+763) but the evidence does not support acting on it, and a discount loses money (−244 at 5%, −1,252 at 10%). Include it in the report as an example of validation preventing a weak promotion.

**Caveats for all use cases:** conversion and discount are assumptions; the data cannot show whether a discount raises conversion; association is not causation; the real test would be a pilot with a control group.

---

## 7. Reseller run: strongest rules by lift (Current, restricted)

The restricted run's strongest reseller rules were not re-extracted in this document. Recompute them from the notebook (section 4 output or the stored rules) before quoting them. The earlier unrestricted top rules (forks and headsets, lift 25 to 37 on small counts) should not be quoted as current.

Support is relative to the 1,795 reseller orders in the window, so it is not comparable with the individual run.

---

## 8. Individual vs reseller comparison (Current, both channels restricted)

Notebook section 7. Counts are rules (both directions of each pair).

| Group | Rules |
|---|---|
| In both channels | 44 (22 pairs) |
| Individual only | 82 |
| Reseller only | 2,182 |

Totals check: 44 + 82 = 126 individual rules; 44 + 2,182 = 2,226 reseller rules.

**Reseller lifts for the use-case pairs (restricted base):**

| Pair | Individual lift | Reseller lift (restricted) | Reseller lift (earlier, full base) |
|---|---|---|---|
| Water Bottle ↔ Hydration Pack | 2.06 | 3.86 | 8.10 (superseded) |
| Patch kit ↔ Bike Wash | 2.15 | 3.47 | 7.27 (superseded) |
| Cycling Cap ↔ Short-Sleeve Classic Jersey | 2.16 | 2.95 | 2.40 (superseded) |
| Touring-1000 → Sport-100 | 1.51 | 1.06 | 0.88 |

The restriction lowered the two accessory pairs as predicted and raised the cap-and-jersey pair, which I'd verify before quoting. Touring-1000 → Sport-100 is now close to chance for resellers rather than below it.

**Reading.** The shared pairs (44 rules) are the robust candidates. The individual-only group is the consumer pattern. The reseller-only group is still far larger, which supports keeping the reseller run as a comparison rather than a source of consumer offers. Compare lift, not support, across channels.

---

## 9. Product-family check (Current, restricted base)

| Share of rules | Individual (126 rules) | Reseller (2,226 rules) |
|---|---|---|
| Same subcategory | 30.2% | 3.8% |
| Same category | 60.3% | 35.2% |
| Both models still on sale | 100% | 100% |

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

## 11. June 2014 check (Current, restricted base)

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
- Reachable orders for tyre and tube offers were reduced by excluding customers who already hold an alternative. The alternatives are found from the baskets with a cut-off (lift below 0.8, at least 30 orders), which is a judgement, and the conversion rate remains an assumption. For the tyre offer the true reach lies between 869 and 2,584, so the break-even at a 10% discount lies between 3.5% and 10.4%.
- The pattern cut-offs (lift 1.5, support 5%) are the team's own definitions and should be checked with the lecturer.
- Labels describe what customers do together, not whether an offer will pay. Profit depends on the break-even check.
- Cancelled orders are excluded from the warehouse (shipped-only load, provisional).
- Seasonality and holidays are not modelled.
- The time split is one split (training to 2013, test on the first half of 2014).
- Reseller product launch dates were checked at category level (all four categories first sold to resellers on 2011-05-31). At model level, the first reseller sales were: Cycling Cap and Long-Sleeve Logo Jersey on 2011-05-31; Water Bottle, Hydration Pack, Bike Wash, Patch kit and Short-Sleeve Classic Jersey on 2013-05-30 (last sale 2014-05-01 for all seven). **The reseller lifts for three use-case pairs were inflated by pre-launch orders in the full base (8.10, 7.27 and 2.40). The restricted base is now used for both channels, which gives 3.86, 3.47 and 2.95. The reseller "strong in both channels" claims are based on the restricted values.**

---

## 15. Open items

The mining stage is complete. Remaining items belong to the next stage.

1. Write the use cases into the report using the structure in section 6b: rule, evidence, reach, sizing, action, caveat.
2. Identify the use-case model whose reseller sales start on 2013-05-30, and rerun its reseller lift with `CHANNEL_START["Reseller"] = "2013-05-30"` as a sensitivity check. If the lift changes materially, restate the reseller figure in section 6a and in the report.
3. Decide whether tyre and tube pairs are natural bundles or trivial rules for the report.
4. Check the pattern definitions and cut-offs (lift 1.5, support 5%) with the lecturer.
5. Build the Power BI pages on `rpt.AssociationRules` and the star schema: sales overview, basket page, rules page (slicers for channel, pattern, lift, confidence) and the use-case page with adjustable conversion and discount.
6. Optional: run mining once on all orders (including cancelled) as a sensitivity test.

Closed during the mining stage: launch-date correction, reseller base check, tyre-and-tube reach refinement, reporting view, use-case selection.