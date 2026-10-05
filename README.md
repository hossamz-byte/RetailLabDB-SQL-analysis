# SQL Joins & Business Analysis Practice

Hands-on SQL practice on a retail database (SQL Server / T-SQL), moving from basic joins to real business questions: cancellation risk, data-quality checks, discount impact and stock alerts.

## Database

**JoinPracticeDB** has four tables:

| Table | Rows | Key columns |
|---|---|---|
| `Customers` | 3,000 | CustomerID, CustomerName, Email, City, Country, CustomerSegment, RegistrationDate |
| `Products` | 2,500 | ProductID, ProductName, Category, SubCategory, UnitPrice, StockQuantity |
| `Orders` | 10,000 | OrderID, CustomerID, OrderDate, OrderStatus, ShippingCity, PaymentMethod |
| `OrderDetails` | 30,000 | OrderDetailID, OrderID, ProductID, Quantity, UnitPrice, Discount |

Relationships: `Orders.CustomerID -> Customers`, `OrderDetails.OrderID -> Orders`, `OrderDetails.ProductID -> Products`.

All data is generated with recursive CTEs, so the database is rebuilt from a single script.

**Net revenue** in every query = `Quantity * UnitPrice * (1 - Discount)`.

### Extra test data

- `JoinPracticeDB_mismatch_test.sql` changes some `ShippingCity` values (1,428 mismatches, 43 NULLs) so the mismatch task has something to find.
- `RetailLabDB_create.sql` builds a second database with the same tables but random data (random names, cities, prices, statuses), useful for testing queries on messier data.

## Tasks

All solutions are in [`solutions.sql`](solutions.sql).

| # | Task | Key idea | Result on JoinPracticeDB |
|---|---|---|---|
| 1 | Cancellation rate by PaymentMethod and ShippingCity | flag each order 1/0, then `SUM(flag) / COUNT(*)` | Cash 100%, other methods 0%; five cities 50%, five cities 0% |
| 2 | Orders where ShippingCity differs from the customer's City, and their share of revenue | CTE flag + conditional `SUM` over all revenue | 0 mismatches (0%); about 14.27% on the mismatch test data |
| 3 | Discount impact per Category (gross, net, discount lost) | `SUM` of three formulas, `GROUP BY` Category | about 10% of gross lost to discounts in every category (6.84M of 68.4M in total) |
| 4 | Which discount level sells the most units on average | `AVG(1.0 * Quantity)` per discount | all levels tied at 4.5 units per line |
| 5 | Low stock alert (stock below units sold in the last 90 days) | `GROUP BY` product + `HAVING` on `SUM(Quantity)` | 3 products (depends on the run date) |
| 6 | Price check (sale price vs product price) | data-quality check with `IF EXISTS` | PASS, no mismatches |

## Things I learned

- **Integer division truncates.** In SQL Server `19.93` from `int / int` becomes `19`. Write `100.0 * x / y` to keep decimals.
- **`COUNT` vs `SUM`.** `COUNT` says how many rows; `SUM(Quantity)` says how many units. "Units sold" needs `SUM`.
- **`COUNT(CASE ... ELSE 0 END)` counts every row**, because `0` is not `NULL`. Use `COUNT(CASE ... END)` or `SUM(CASE ... ELSE 0 END)`.
- **A rate needs the right denominator.** Cancelled / cancelled is always 100%. Divide by all orders in the group.
- **`WHERE` filters rows before grouping, `HAVING` filters groups after.** Aggregates like `MAX` or `SUM` can't go in `WHERE`.
- **`<>` ignores NULLs.** `NULL <> 'Chicago'` is unknown, so rows with a missing city are not returned as mismatches.
- **An empty result can mean good data.** Data-quality checks should return a clear PASS/FAIL, not just zero rows.

## Data observations

- Every customer has orders and every product was sold 12 times, so "never ordered" or "never sold" anti-joins return nothing.
- `OrderStatus` is tied to `PaymentMethod` (Completed = Credit Card or PayPal, Pending = Bank Transfer, Cancelled = Cash), which produces the 100% / 0% cancellation split.
- Subcategories do not match their categories (for example Phones sit under Furniture), a data-quality trap.
- Dates are generated relative to `GETDATE()`, so date-based results shift depending on when the script runs.

## How to run

1. Run the `JoinPracticeDB` create script in SQL Server Management Studio (or Azure Data Studio).
2. Run the queries in `solutions.sql`.
3. Optional: run `JoinPracticeDB_mismatch_test.sql` for the mismatch task, or `RetailLabDB_create.sql` for random data.

## Tools

SQL Server, T-SQL, CTEs, joins, aggregates, `CASE`, `GROUP BY` / `HAVING`.
