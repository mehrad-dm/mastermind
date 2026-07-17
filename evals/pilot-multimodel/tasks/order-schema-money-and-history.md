---
id: order-schema-money-and-history
domain: backend
difficulty: hard
---

## Prompt

You inherit this PostgreSQL schema for a small shop's orders. Finance reports that historical order totals CHANGE whenever a product's price is edited, that some totals are off by a cent, and that deleting a discontinued product wiped out old orders referencing it. Redesign the schema to fix these problems. Return the corrected DDL plus a short note on how an order's total is computed.

```sql
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  price FLOAT NOT NULL
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  customer_id INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE order_items (
  order_id INT REFERENCES orders(id) ON DELETE CASCADE,
  product_id INT REFERENCES products(id) ON DELETE CASCADE,
  quantity INT
);
-- An order's total is computed at read time as SUM(products.price * order_items.quantity)
```

## Rubric

1. Price is snapshotted onto each order line at purchase time (e.g. order_items.unit_price), so later product price edits cannot change historical totals
2. Money is stored as an exact type — integer cents (with the unit named/commented) or NUMERIC/DECIMAL — never FLOAT/REAL, fixing the off-by-a-cent errors
3. Product deletion can no longer destroy order history: ON DELETE CASCADE from order_items to products is removed in favor of RESTRICT / soft-delete (e.g. discontinued_at flag), and the note explains the choice
4. order_items gains integrity constraints: quantity with CHECK (quantity > 0), NOT NULL on its columns, and a primary key or unique constraint on (order_id, product_id) or a surrogate key
5. Deleting an order still cleans up (or restricts) its own order_items deliberately — the orders→order_items relationship remains consistent, not orphanable
6. The total-computation note derives the total from the snapshotted line data (SUM(unit_price * quantity)), not from the live products table
