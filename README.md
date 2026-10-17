# BI Project: Data Warehouse and Association Rule Mining

This repository contains a SQL Server data-warehouse build and a Python
association-rule-mining notebook for the CompanyX/AdventureWorks sales data.
The workflow is:

```text
CompanyX (source database)
        |
        | SQL Server / SSIS load
        v
CompanyX_DW
  staging -> dw.DateDim, ProductDim, CustomerDim, OrderLineFact
        |
        | Python FP-Growth notebook
        v
dw.AssociationRulesFact
```

The warehouse scripts are intended for SQL Server Developer edition, with
SQL Server Integration Services (SSIS) packages run from Visual Studio. The
notebook reads shipped-order baskets at product-model level and writes the
resulting rules back to the warehouse.

## Repository layout

| Path | Purpose |
|---|---|
| [`data_warehouse_script/01_create_CompanyX_DW.sql`](./data_warehouse_script/01_create_CompanyX_DW.sql) | Creates `CompanyX_DW`, schemas, star-schema tables, ETL control tables, and `DateDim`. |
| [`data_warehouse_script/02_staging_and_productdim_query.sql`](./data_warehouse_script/02_staging_and_productdim_query.sql) | Creates and loads product staging data and the SCD Type 2 `ProductDim`. |
| [`data_warehouse_script/03_staging_and_customerdim.sql`](./data_warehouse_script/03_staging_and_customerdim.sql) | Creates and loads customer staging data and the SCD Type 1 `CustomerDim`. |
| [`data_warehouse_script/04_staging_and_orderlinefact.sql`](./data_warehouse_script/04_staging_and_orderlinefact.sql) | Creates and loads order-line staging data and `OrderLineFact`. |
| [`data_warehouse_script/05_replay_setup.sql`](./data_warehouse_script/05_replay_setup.sql) | Configures the date-window replay and provides reset/test SQL. |
| [`data_warehouse_script/06_ssis_transformations.sql`](./data_warehouse_script/06_ssis_transformations.sql) | Creates replay-related helpers and documents/validates SSIS transformations. |
| [`association_rule_mining/association_rule_mining.ipynb`](./association_rule_mining/association_rule_mining.ipynb) | Connects to `CompanyX_DW`, mines Individual and Reseller rules, and writes them to `AssociationRulesFact`. |
| [`association_rule_mining/requirements.txt`](./association_rule_mining/requirements.txt) | Python dependencies for the notebook. |
| [`association_rule_mining/association_rule_mining_results.md`](./association_rule_mining/association_rule_mining_results.md) | Example results and interpretation from a completed run. |
| [`CompanyX_ETL/`](./CompanyX_ETL) | Git submodule containing the Visual Studio SSIS ETL project. |

## Prerequisites

### SQL Server and source data

Install or have access to:

- SQL Server Developer edition (or a compatible SQL Server instance).
- The `CompanyX` source database, including the `Production` and `Sales`
  schemas used by the scripts.
- SQL Server Management Studio (SSMS).
- Visual Studio with the SQL Server Integration Services Projects extension
  if running the SSIS workflow.

The scripts assume that `CompanyX` and `CompanyX_DW` are on the same SQL
Server instance. Run the scripts using an account that can create databases,
schemas, tables, procedures, and views.

### Python and ODBC

- Python 3.10-3.12 is recommended.
- Microsoft ODBC Driver 17 or 18 for SQL Server.
- JupyterLab or another environment that can run `.ipynb` notebooks.

The notebook uses Windows integrated authentication
(`Trusted_Connection=yes`), so the Windows account running Jupyter must have
permission to read and update `CompanyX_DW`.

## 1. Build the warehouse

Open SSMS and connect to the SQL Server instance containing `CompanyX`.
Execute the SQL scripts in this order:

1. `01_create_CompanyX_DW.sql`
2. `02_staging_and_productdim_query.sql`
3. `03_staging_and_customerdim.sql`
4. `04_staging_and_orderlinefact.sql`

The scripts are designed to be rerunnable. The later scripts use three-part
source names such as `CompanyX.Sales...`, so do not rename the source database
without updating the scripts and SSIS source connections.

The normal one-shot load should produce approximately:

- `dw.DateDim`: 1,127 dates
- `dw.ProductDim`: 353 product price versions for 266 products
- `dw.CustomerDim`: 19,119 customers
- `dw.OrderLineFact`: 120,147 shipped order lines

Each script includes row-count and data-quality checks. Review those checks
after each load, especially the prerequisites noted at the top of
`04_staging_and_orderlinefact.sql`.

### SSIS load

The [`CompanyX_ETL/`](./CompanyX_ETL) directory is a Git submodule containing
the Visual Studio SSIS project. It loads the source database into
`CompanyX_DW`. Configure connections to `CompanyX` and `CompanyX_DW`, then
use these packages:

1. `LoadProductDim`
2. `LoadCustomerDim`
3. `LoadOrderLineFact`
4. `MasterLoad`, which runs the three packages in that order

Open `CompanyX_ETL.slnx` or `CompanyX_ETL.dtproj` in Visual Studio with the
SQL Server Integration Services Projects extension installed. The packages
currently use Windows integrated authentication and default to a SQL Server
instance named `localhost`; change the connection managers if your instance
uses a different server or instance name.

Run `MasterLoad.dtsx` for the complete ETL process. It runs the dimension
loads before the fact load and advances the replay watermark only after the
preceding packages succeed. For package-level setup, validation, replay
instructions, and troubleshooting, see the
[`CompanyX_ETL/README.md`](./CompanyX_ETL/README.md).

The staging tables are truncated and reloaded for each package. The product
dimension uses SCD Type 2 behavior, the customer dimension uses SCD Type 1
behavior, and the fact load resolves the correct product-dimension version
for the order date.

### Clone and initialize the submodule

Clone the complete project with:

```powershell
git clone --recurse-submodules <main-repository-url>
```

If the main repository is already cloned, initialize the submodule with:

```powershell
git submodule update --init --recursive
```

The parent repository stores the submodule commit reference. Changes to the
SSIS project must be committed and pushed in the `CompanyX_ETL` repository
first, then the updated submodule pointer must be committed and pushed in
this repository:

```powershell
cd D:\BI_mining\CompanyX_ETL
git add README.md
git commit -m "Update ETL documentation"
git push origin main

cd D:\BI_mining
git -C .\CompanyX_ETL pull --ff-only origin main
git add .\CompanyX_ETL
git commit -m "Update CompanyX_ETL submodule"
git push origin main
```

## 2. Optional: run the date-window replay

The replay simulates incremental loading rather than loading all source data
at once. After the base warehouse objects exist, execute
`05_replay_setup.sql` once in `CompanyX_DW`. It creates:

- `etl.ReplayConfig`, which controls the window size.
- `etl.vReplayWindow`, which calculates the next date window.
- `etl.usp_ReplayReset`, which clears dimensions/facts and rewinds the clock.

To use replay:

1. Run `EXEC etl.usp_ReplayReset;` in SSMS before a fresh demonstration.
2. Set `etl.ReplayConfig.WindowDays` to the desired increment, such as `7`.
3. Run `MasterLoad` from Visual Studio/SSIS.
4. Repeat the package run until `etl.vReplayWindow` reaches `2014-06-30`.
5. Inspect `etl.RunLog` and `etl.Watermark` after each run.

The replay-specific source queries and the required `AdvanceWatermark` task
are documented in `05_replay_setup.sql`. The watermark must advance only
after all three load packages succeed. For a normal full load, replay is
optional.

`06_ssis_transformations.sql` contains the SQL helper procedure and
validation queries for the SSIS-derived columns. Run it when configuring or
checking the SSIS transformations.

## 3. Install Python dependencies

From the repository root, create and activate a virtual environment:

```powershell
cd D:\BI_mining
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r .\association_rule_mining\requirements.txt
```

If PowerShell blocks script activation, activate the environment using
Command Prompt instead:

```bat
D:\BI_mining\.venv\Scripts\activate.bat
```

Confirm that a SQL Server driver is available:

```powershell
python -c "import pyodbc; print(pyodbc.drivers())"
```

The output must include `ODBC Driver 18 for SQL Server`, `ODBC Driver 17 for
SQL Server`, or `SQL Server`.

## 4. Configure and run the notebook

Start JupyterLab from the activated environment:

```powershell
cd D:\BI_mining
python -m jupyter lab
```

Open [`association_rule_mining.ipynb`](./association_rule_mining/association_rule_mining.ipynb)
and run the cells from top to bottom.

Before running the connection cell, edit the configuration cell:

```python
SERVER = "YOUR_SQL_SERVER_INSTANCE"
DATABASE = "CompanyX_DW"
```

For a local default SQL Server instance, `SERVER` may be `localhost`,
`localhost\SQLEXPRESS`, or the instance name shown in SSMS. Keep
`DATABASE = "CompanyX_DW"` unless the warehouse was intentionally renamed.
The notebook automatically selects ODBC Driver 18, then 17, then the legacy
`SQL Server` driver from the installed drivers.

The notebook:

1. Reads valid shipped lines from `dw.OrderLineFact`.
2. Joins to `dw.ProductDim` and `dw.CustomerDim`.
3. Keeps lines with `OrderQty > 0` and `UnitPrice > 0`.
4. Builds order baskets using `ProductModelID`, not SKU/ProductID.
5. Runs FP-Growth for `Individual` and `Reseller` channels.
6. Stores pair rules in both directions in `dw.AssociationRulesFact`.
7. Displays summary tables, candidate flags, charts, and opportunity sizing.

Single-model orders remain in the support denominator. Rules below 1% support
are not stored. The notebook replaces each channel's previous rules by
default (`KEEP_HISTORY = False`); set it to `True` only when historical
generated dates are intentionally being retained.

The main analysis is the `Individual` channel. `Reseller` is included as a
comparison and has a different support base, so its support values should not
be compared directly with Individual support values.

## Expected outputs

After a completed mining run, query the warehouse with:

```sql
USE CompanyX_DW;

SELECT Channel, RuleClassification, COUNT(*) AS RuleCount
FROM dw.AssociationRulesFact
GROUP BY Channel, RuleClassification
ORDER BY Channel, RuleClassification;

SELECT TOP (50) *
FROM dw.AssociationRulesFact
ORDER BY Lift DESC, Support DESC;
```

The included results document records one completed run with 106 Individual
rules and 2,836 Reseller rules. Counts can change if the source data,
warehouse contents, thresholds, or history setting changes.

## Troubleshooting

### Cannot connect to SQL Server

- Verify the `SERVER` value in the notebook matches the server/instance in
  SSMS.
- Verify SQL Server is running and accepts Windows authentication.
- Install Microsoft ODBC Driver 17 or 18 for SQL Server.
- Confirm the notebook's Windows account has access to `CompanyX_DW`.
- Check that `dw.OrderLineFact` exists before running the mining cells.

### A SQL script reports missing source objects

The `CompanyX` source database is a prerequisite. Confirm that the source
contains the expected AdventureWorks-style schemas and tables, including
`Sales.SalesOrderHeader`, `Sales.SalesOrderDetail`, `Sales.Customer`,
`Sales.Store`, and the relevant `Production` tables.

### The notebook reports zero rows or no rules

Check that the warehouse load completed and that the fact table contains
shipped lines. Also check the valid-line filter: rows with null, zero, or
negative quantity/price are deliberately excluded from mining.

### SSIS replay does not advance

Inspect `etl.vReplayWindow`, `etl.Watermark`, and `etl.RunLog`. The watermark
must be advanced only by the final `AdvanceWatermark` task after the three
load packages succeed. Do not schedule replay after the clock reaches
`2014-06-30`; later runs load no additional rows.

## Data and interpretation notes

- The warehouse currently loads shipped orders (`Status = 5`) only.
- The fact table retains anomalous lines for reconciliation, but mining
  excludes invalid quantity/price lines.
- Association rules describe co-occurrence; they do not prove causation.
- Product price history is represented as SCD Type 2, while customer records
  are maintained as SCD Type 1.
- Do not commit connection strings containing credentials or other secrets.
