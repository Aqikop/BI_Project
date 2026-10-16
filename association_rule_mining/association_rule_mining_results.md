# Association Rule Mining: Results So Far
**Topic 3: Product and Association Rules (CompanyX / AdventureWorks)**
Notebook: `association_rule_mining.ipynb`, run on the real warehouse `CompanyX_DW`. Figures below are copied from the notebook outputs (sections 4, 5, 7 and 8). Nothing in this document is a final team decision.

---

## 1. What was run

| Item | Setting |
|---|---|
| Input | `dw.OrderLineFact` joined to `dw.ProductDim` (model level) and `dw.CustomerDim` (channel); shipped orders only |
| Purchase filter | lines with `OrderQty > 0 AND UnitPrice > 0` (drops the 75 anomalous lines) |
| Item | Product Model (`ProductModelID`) |
| Algorithm | FP-Growth (`mlxtend`), pair rules only (`max_len = 2`), minimum support 1% |
| Runs | Individual (main analysis) and Reseller (comparison only); no pooled run |
| Support base | all orders with at least one valid line; single-model orders stay in the base |
| Stored in | `dw.AssociationRulesFact` (both directions of each pair), one type per rule |

Rule types (the team's own definitions, to be checked with the lecturer):

| Type | Lift | Support |
|---|---|---|
| `Substitute` | below 1 | any (at least 1%) |
| `Bundle` | 1.5 or more | 5% or more |
| `Hidden gem` | 1.5 or more | 1% to 5% |
| `Chance` | 1 to 1.5 | 5% or more |
| `Weak` | 1 to 1.5 | 1% to 5% |

On-screen candidate flags use the brief's thresholds and are not stored: **cross-sell** (lift 1.5 or more, support 1% or more, confidence 40% or more) and **discounted bundle** (lift 1.5 or more, support 1% to 5%, confidence 50% or more in at least one direction).

---

## 2. Run summary

| | Individual | Reseller |
|---|---|---|
| Orders in channel (all lines) | 27,382 | 3,768 |
| Orders with a valid line (support base) | 27,382 | 3,762 |
| Orders with 2+ models | 17,805 | 3,025 |
| Single-model orders | 9,577 | 737 |
| Product models seen | 40 | 93 |
| Frequent single models (support 1% or more) | 39 | 89 |
| Frequent pairs | 53 | 1,418 |
| **Rules stored (both directions)** | **106** | **2,836** |
| Max gap, count vs support x orders | 0.0 | 0.0 |

Reconciliation with the warehouse checks:
- The individual run has **17,805 orders with 2+ models**, equal to the warehouse figure (the notebook reported OK).
- Individual orders: 27,382 = 17,805 + 9,577.
- The reseller support base is **3,762, not 3,768**. The six missing orders are 43677 to 43682, where every line is anomalous (null, zero or negative quantity or price), so they cannot be baskets.
- Rules are stored in both directions, so the number of pairs is half the number of rules (53 and 1,418).

### Rules by type

| Type | Individual | Reseller |
|---|---|---|
| Hidden gem | 64 | 2,026 |
| Bundle | 4 | 506 |
| Weak | 28 | 248 |
| Chance | 0 | 30 |
| Substitute | 10 | 26 |
| **Total** | **106** | **2,836** |

Candidates flagged with the brief's thresholds: Individual 13 cross-sell and 14 discounted-bundle; Reseller 1,223 cross-sell and 858 discounted-bundle (too many to be selective).

---

## 3. Individual run: top rules by lift

All of the top 15 are `Hidden gem` (lift 1.5 or more, support 1% to 5%), with large co-occurrence counts (332 to 948 orders). They form 8 pairs.

| Pair (both directions stored) | Support | Lift | Co-occurrence | Confidence A to B / B to A |
|---|---|---|---|---|
| Touring Tire / Touring Tire Tube | 2.93% | 16.06 | 802 | 86.3% / 54.5% |
| HL Road Tire / Road Tire Tube | 2.15% | 8.09 | 590 | 69.5% / 25.1% |
| ML Road Tire / Road Tire Tube | 2.20% | 7.60 | 602 | 65.3% / 25.6% |
| Road Bottle Cage / Road-750 | 2.02% | 6.26 | 554 | 32.7% / 38.7% |
| LL Road Tire / Road Tire Tube | 1.99% | 6.18 | 546 | 53.1% / 23.2% |
| LL Road Tire / Road-750 | 1.21% | 6.17 | 332 | 32.3% / 23.2% |
| HL Mountain Tire / Mountain Tire Tube | 3.46% | 6.13 | 948 | 68.4% / 31.0% |
| ML Mountain Tire / Mountain Tire Tube | 2.80% | 5.98 | 767 | 66.8% / 25.1% |

Most are functional complements (a tire and its tube); the rest are a bike model with an accessory.

---

## 4. Reseller run: top rules by lift

The top rules are forks and headsets across grades (LL, ML, HL), with lift 25 to 37 but small counts (38 to 97 orders), plus HL Touring Handlebars with Touring Pedal (lift 25.1, 50 orders).

| Pair | Support | Lift | Co-occurrence |
|---|---|---|---|
| LL Fork / LL Headset | 1.01% | 37.44 | 38 |
| LL Fork / HL Headset | 1.89% | 29.26 | 71 |
| HL Fork / ML Headset | 2.58% | 28.86 | 97 |
| ML Headset / HL Headset | 2.39% | 28.24 | 90 |
| HL Fork / HL Headset | 2.50% | 27.71 | 94 |
| LL Fork / ML Headset | 1.75% | 27.44 | 66 |
| LL Fork / HL Fork | 1.78% | 26.18 | 67 |

Support values are relative to the 3,762 reseller orders and are not comparable with the individual run.

---

## 5. Individual vs reseller comparison

| Group | Rules | Pairs |
|---|---|---|
| In both channels | 38 | 19 |
| Individual only | 68 | 34 |
| Reseller only | 2,798 | 1,399 |

"Individual only" means the pair is below 1% support among reseller orders, not that it never occurs there.

Pairs in both channels (top by individual lift):

| Pair | Lift Ind / Res | Support Ind / Res | Type Ind / Res |
|---|---|---|---|
| Cycling Cap / Short-Sleeve Classic Jersey | 2.69 / 2.40 | 1.2% / 11.5% | Hidden gem / Bundle |
| Bike Wash / Patch kit | 2.68 / 7.27 | 1.0% / 3.5% | Hidden gem / Hidden gem |
| Hydration Pack / Water Bottle | 2.57 / 8.10 | 1.0% / 8.5% | Hidden gem / Bundle |
| Water Bottle / Road-750 | 2.19 / 3.47 | 1.8% / 4.3% | Hidden gem / Hidden gem |
| Touring-1000 / Sport-100 | 1.88 / 0.88 | 2.0% / 2.7% | Hidden gem / **Substitute** |
| Cycling Cap / Water Bottle | 1.87 / 2.83 | 2.3% / 10.3% | Hidden gem / Bundle |
| Sport-100 / Half-Finger Gloves | 1.80 / 2.96 | 2.2% / 14.8% | Hidden gem / Bundle |
| Water Bottle / Short-Sleeve Classic Jersey | 1.65 / 6.07 | 1.5% / 10.9% | Hidden gem / Bundle |

Notes:
- Raw support differs strongly between channels because reseller baskets are large; compare lift.
- Touring-1000 / Sport-100 has lift above 1 for individuals but below 1 for resellers, so the pattern is channel-specific.
- The strongest individual pairs (tire and tube) are not in the both-channel list: they are individual-only at the 1% threshold.

---

## 6. Product-family check

Share of each channel's rules that stay within the same product family, and that involve only models still on sale:

| | Individual | Reseller |
|---|---|---|
| Rules | 106 | 2,836 |
| Same subcategory | 30.2% | 4.7% |
| Same category | 58.5% | 32.1% |
| Both models still on sale | 100% | 68.3% |

**Finding:** reseller rules are *less* often within the same subcategory or category than individual rules. An earlier suggestion that reseller associations reflect stocking within product families is therefore **not supported** by this test, and should not appear in the report. The data does not show why the reseller associations exist. About 32% of reseller rules involve a model that is no longer on sale.

---

## 7. Opportunity sizing (individual candidates)

Assumptions (placeholders, not forecasts): 5% of reachable orders add the offered model, and a 10% bundle discount on it. Reachable orders are orders with A but not B. Margin is revenue minus the standard cost in force on the order date. Amounts are in the source currency.

Net profit = extra sales x (B margin - discount x B revenue) - discount x B revenue x orders already buying both. Break-even conversion is the rate at which net profit is zero; above 100% the bundle cannot pay off.

| Rule (A to B) | Reachable orders | B avg revenue | B avg margin | Net profit (5%, 10%) | Break-even conversion |
|---|---|---|---|---|---|
| Mountain Tire Tube to LL Mountain Tire | 2,584 | 24.99 | 15.64 | **+513.8** | **3.5%** |
| Road Tire Tube to LL Road Tire | 1,806 | 21.49 | 13.45 | -152.6 | 5.7% |
| LL Road Tire to Road Tire Tube | 483 | 3.99 | 2.50 | -167.2 | 21.5% |
| LL Mountain Tire to Mountain Tire Tube | 383 | 4.99 | 3.12 | -186.3 | 23.5% |
| ML Road Tire to Road Tire Tube | 320 | 3.99 | 2.50 | -206.6 | 35.8% |
| HL Road Tire to Road Tire Tube | 259 | 3.99 | 2.50 | -208.2 | 43.3% |
| ML Mountain Tire to Mountain Tire Tube | 381 | 4.99 | 3.12 | -332.7 | 38.3% |
| Road Tire Tube to ML Road Tire | 1,750 | 24.99 | 15.64 | -354.2 | 6.5% |
| Touring Tire to Touring Tire Tube | 127 | 4.99 | 3.12 | -383.5 | **120.1%** |
| Road Tire Tube to HL Road Tire | 1,762 | 32.60 | 20.41 | -412.7 | 6.4% |
| HL Mountain Tire to Mountain Tire Tube | 437 | 4.99 | 3.12 | -415.7 | 41.2% |
| Mountain Tire Tube to ML Mountain Tire | 2,291 | 29.99 | 18.77 | -493.2 | 6.4% |
| Road Bottle Cage to Water Bottle | 187 | 4.99 | 3.12 | -726.5 | **153.0%** |
| Mountain Bottle Cage to Water Bottle | 332 | 4.99 | 3.12 | -790.3 | 95.7% |
| Touring-1000 to Sport-100 | 697 | 34.99 | 21.90 | -1,251.6 | 14.8% |

(Candidates ranked by net profit, models still on sale; all listed rules have both models on sale.)

### Use case under evaluation: Road-750 to Road Bottle Cage

Not a candidate under the brief's thresholds (confidence 38.7% is below 40%, and neither direction reaches 50%), but evaluated directly.

| Item | Value |
|---|---|
| Support / confidence / lift / type | 2.02% / 38.7% / 6.26 / Hidden gem |
| Orders with Road-750 | 1,432 |
| Already with Road Bottle Cage | 554 |
| Reachable (without the cage) | 878 |
| Cage average line revenue / margin | 8.99 / 5.63 |

Net profit by discount (rows) and assumed conversion (columns):

| | Low (2%) | Base (5%) | High (10%) |
|---|---|---|---|
| Discount 0% | 99 | 247 | 494 |
| Discount 5% | -158 | -22 | 206 |
| Discount 10% | -415 | -290 | -83 |

Break-even conversion: 0% discount, none needed; 5% discount, 5.5%; 10% discount, 12.0%.

---

## 8. Interpretation

1. **Highest lift does not mean best promotion.** For Touring Tire to Touring Tire Tube and Road Bottle Cage to Water Bottle, break-even is above 100%: almost every buyer of A already buys B, so a discount mostly goes to customers who would have paid full price. These pairs suit a suggestion at checkout or product placement, without a discount.
2. **Direction matters.** Mountain Tire Tube to LL Mountain Tire is profitable (break-even 3.5%), while the reverse direction needs 23.5%.
3. **The absolute upside is small.** The offered items cost roughly 4 to 35, so even the best rule adds a few hundred in profit over the whole period under the placeholder assumptions. The value of the use case is in showing the method and the break-even check.
4. **Candidate use cases:**
   - Mountain Tire Tube to LL Mountain Tire as a discounted bundle: the only profitable candidate at the base assumptions; meets the discounted-bundle thresholds (support 1.7%, reverse confidence 55.3%, lift 4.95).
   - Road-750 to Road Bottle Cage as a cross-sell without discount: a bike-to-accessory story; 247 at 5% conversion with no discount.
5. **Reseller run stays a comparison.** Its support is not comparable with the individual run, its rule set is very large, and its associations are not explained by product family (section 6).

---

## 9. Limitations and open items

**Limitations to state in the report**
- Association is not causation; the data covers shipped orders from 2011-05-31 to 2014-06-30.
- Conversion rates and discounts are assumptions. The real test would be a pilot with a control group.
- **"Reachable" is overstated for tire and tube rules.** Reachable orders include orders that already contain another model of the same subcategory (for example an ML or HL Mountain Tire when the offer is the LL Mountain Tire). Those customers are unlikely to take the offer.
- The rule types and their cutoffs are the team's own definitions.
- Cancelled orders are not in the warehouse (shipped-only load, provisional), so no sensitivity test on all orders has been run.

**Open items**
- Choose the use-case rule.
- Optional refinement: recompute reachable orders excluding orders that contain another model from B's subcategory, and re-rank.
- Decide whether tire and tube pairs should be called natural bundles or trivial rules in the report (the brief treats same-function sets as natural bundles).
- Check the five rule types and cutoffs with the lecturer.
- Seasonality: the rules table has no date or season scope.
- Build the Power BI pages: rules (slicers for channel, type, lift, confidence), sales and basket pages, and the use-case page.
