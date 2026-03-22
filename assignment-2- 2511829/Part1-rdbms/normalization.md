## Anomaly Analysis
 It's a **flat/denormalized orders table** that bundles customers, products, and sales reps all in one place. This is a perfect example for demonstrating all three anomalies. 
## Table Structure
Every row has: `order_id, customer_id, customer_name, customer_email, customer_city, productids, product_name, category, unit_price, quantity, order_date, sales_rep_id, sales_rep_name, sales_rep_email, office_address`

---

## Insert Anomaly
**Problem: ** We cannot record a new product or sales rep until an order is placed.
**Example from the data: **
Suppose you hire a new sales rep **SR04 – Meera Pillai** based out of Chennai. You **cannot insert her** into this table until she gets her first order — because every row requires an `order_id`. Her information has nowhere to live independently.

Similarly, if a new product **P009 – Projector** is added to the catalogue at ₹35,000, it **cannot be stored** until a customer orders it.
> **Root cause:** Product and sales rep data are embedded inside the Orders table, which requires an order to exist first.

---

## Update Anomaly
**Problem:** The same fact is repeated across many rows — changing it requires updating every row, and missing one creates a contradiction.
**Example from the data:**
Sales rep **SR01 – Deepak Joshi** is listed with office address `"Mumbai HQ, Nariman Point, Mumbai - 400021"` across dozens of rows. Now look at these two rows:

| order_id | sales_rep_id |office_address |row_number
|----------|-------------|----------------|
| ORD1180 | SR01 | `Mumbai HQ, Nariman Pt, Mumbai - 400021` *(truncated!)* |39
| ORD1176 | SR01 | `Mumbai HQ, Nariman Pt, Mumbai - 400021` *(truncated!)* |182
| ORD1094 | SR01 | `Mumbai HQ, Nariman Point, Mumbai - 400021` *(full)* |40

**This inconsistency already exists in the data** — SR01's office address appears in two slightly different formats (`"Nariman Pt"` vs `"Nariman Point"`). This is a real update anomaly: the address was likely edited in some rows but not all.

> **Root cause:** `office address` is a fact about the sales rep, not the order — but it's duplicated in every order row they're associated with.

---

##   Delete Anomaly

**Problem:** Deleting an order accidentally destroys other important information.

**Example from the  data:**
**ORD1185** in row number 13 is the only order placed by **Amit Verma (C003)** for product **P008 – Webcam (Electronics, ₹2,100)**. If this order is deleted (e.g., it was cancelled or returned), the entire record of the Webcam product **disappears from the database** — you lose the product name, category, and price entirely, since no other order references P008.

Similarly, if all orders by a particular sales rep were deleted, that rep's contact details and office address would vanish with them.

> **Root cause:** Product and sales rep information only exists as part of order rows — deleting orders means losing that data permanently.

---

##   The Fix: Normalize into Separate Tables

| Table | Columns |
|-------|---------|
| **Orders** | order_id, customer_id, product_id, sales_rep_id, quantity, order_date |
| **Customers** | customer_id, customer_name, customer_email, customer_city |
| **Products** | product_id, product_name, category, unit_price |
| **Sales_Reps** | sales_rep_id, sales_rep_name, sales_rep_email, office_address |

With this structure, each entity lives in its own table — insert/update/delete operations on orders no longer affect the integrity of customer, product, or sales rep data.


## Normalization Justification
The "Everything in one table is simpler" argument sounds reasonable until the data breaks. Here's what happens with this specific dataset:
We can't onboard a new sales rep. Suppose SR04 joins the team in January. In the flat table, there is nowhere to record her name, email, or office until she closes her first order. The business exists; the database can't reflect it. Similarly, if a new product **P009 – Projector** is added to the catalogue, it cannot be stored until a customer orders it
The address inconsistency is already there. Sales rep SR01 (Deepak Joshi) has two different office addresses in the flat file — "Nariman Point" in most rows and "Nariman Pt" in 15 0rders. This isn't hypothetical. The data is already corrupted. In the normalized schema, SR01's address exists in exactly one row in Sales_Reps. Fix it once, it's fixed everywhere. In the flat file, we must hunt down every affected row and hope we don't miss one.
Deleting an order destroys product knowledge. ORD1185 is the only order for P008 (Webcam, ₹2,100). Cancel that order, delete the row, and the Webcam product — its name, category, and price — ceases to exist in the database. The business hasn't discontinued the product, but the database now thinks it never existed. No normalized schema would allow this.
"Simpler" shifts the burden onto every query. Every report that needs a customer's city, a product's price, or a rep's email must navigate duplicated, potentially inconsistent copies of that data scattered across hundreds of rows. Every application update must remember to change every copy. The flat table doesn't remove complexity — it hides it until it causes damage.
Normalization is the formal solution to problems that are already visible in this exact dataset. Hence the Insert, Update, delete anomalies are problems "simpler" table has created and cannot fix. Hence normalization is not over-engineering.
