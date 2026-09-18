# SuperMart AI — Complete Beginner Viva Handbook

Read this document in order. Do not memorize every line of code. Understand the
data flow and know which file to open when a lecturer asks for evidence.

## 1. One-minute project explanation

> SuperMart AI is a three-tier, multi-branch supermarket system. Flutter is the
> presentation layer. A Flask REST API contains business rules, security, and
> ML inference. SQL stores users, products, branch stock, staff, orders, order
> items, and alerts. I trained and compared Linear Regression, Random Forest,
> and XGBoost on supermarket transactions. The tuned XGBoost model predicts
> gross income. Separately, a catalog-grounded assistant answers shopping
> questions using live product and stock data.

Do not say the shopping assistant is the XGBoost model. They solve different
problems.

## 2. System architecture

```text
Flutter Web / Android
  screens, forms, cart state
          |
          | JSON over HTTP locally / HTTPS in cloud
          v
Flask REST API
  validation, JWT roles, order transaction, assistant, ML prediction
       |                                      |
       v                                      v
SQLite locally / PostgreSQL cloud       xgb_tuned.pkl
  persistent operational data           prediction model
```

Flutter never opens the database file and never loads the pickle model. It must
call the API. This keeps database credentials and server logic away from users.

## 3. Code map

### Flutter

| File | What it does |
|---|---|
| `mobile_app/supermart_flutter/lib/main.dart` | Theme, login, registration, role-based navigation |
| `mobile_app/supermart_flutter/lib/src/api.dart` | API base URL, JSON requests, bearer token header, errors |
| `mobile_app/supermart_flutter/lib/src/customer.dart` | Shop, offers, cart, checkout, orders, assistant, account panel |
| `mobile_app/supermart_flutter/lib/src/manager.dart` | Insights, inventory, staff, orders and alerts |
| `mobile_app/supermart_flutter/test/widget_test.dart` | Flutter login-screen smoke test |

### Backend

| File | What it does |
|---|---|
| `api/app.py` | Flask routes, JWT authorization, ML loading/inference, business logic |
| `api/database.py` | SQLAlchemy table definitions and relationships |
| `api/seed_data.py` | Creates initial managers, products, branch stock, staff and alerts |
| `api/test_e2e.py` | Tests registration through manager fulfilment and cleans its test data |
| `api/requirements.txt` | Python packages and pinned versions |

### Machine learning

| File | What it does |
|---|---|
| `notebooks/01_eda.ipynb` | Loads, cleans and explores 1,000 transactions |
| `notebooks/02_preprocessing.ipynb` | Features, encoding, temporal split and scaling |
| `notebooks/03_models.ipynb` | Trains and compares three regressors |
| `notebooks/04_tuning.ipynb` | Grid-search tuning and final model export |
| `model/xgb_tuned.pkl` | Serialized final XGBoost estimator |
| `model/scaler.pkl` | Fitted training-data StandardScaler |
| `model/encoders.pkl` | Fitted categorical encoders |
| `data/model_comparison.csv` | Saved evaluation comparison |

### Cloud

| File | What it does |
|---|---|
| `Dockerfile` | Packages Flask, Python dependencies, model and data |
| `render.yaml` | Defines Render API, health check and PostgreSQL |
| `.dockerignore` | Excludes SDKs, notebooks and build junk from the container |
| `CLOUD_AND_VIVA.md` | Cloud deployment and demonstration sequence |

## 4. Registration and authentication

### Registration sequence

1. `RegisterPage` validates name, email, phone, address and password.
2. `Api.post('/auth/register', ...)` sends JSON to Flask.
3. `register()` in `api/app.py` checks required fields and duplicate email.
4. `bcrypt.hashpw()` creates a salted one-way password hash.
5. SQLAlchemy inserts a `User` with role `customer`.
6. Flask creates a signed JWT and returns safe user fields plus the token.
7. Flutter keeps the token for the current session and opens CustomerShell.

### Login sequence

1. Flask finds the user by normalized email.
2. `bcrypt.checkpw()` compares the entered password with the stored hash.
3. A successful login returns a signed 12-hour JWT.
4. The JWT contains user ID, role, branch and expiry.
5. `api.dart` sends it as `Authorization: Bearer <token>`.
6. `require_auth()` verifies the signature and role on protected routes.

Customers cannot call manager APIs: the server returns HTTP 403. This is
server-side security, not only hidden Flutter buttons.

Important limitation: use an environment variable `JWT_SECRET` in production.
The fallback development secret must not be used publicly.

## 5. Database and stored data

Local data is in `api/instance/supermart.db`. Cloud data goes to PostgreSQL when
Render supplies `DATABASE_URL`.

### Tables

- `user`: customer/manager identity, password hash, role, branch, contact data.
- `product`: catalog name, category, price, unit and description.
- `stock`: one product quantity and minimum quantity for one branch.
- `staff`: employee role, branch and shift.
- `order`: customer, branch, type, status, total and delivery address.
- `order_item`: product, quantity and checkout price for an order.
- `alert`: branch low-stock/operational notification.

Relationships are declared in `api/database.py`. An Order belongs to one User
and contains multiple OrderItems. Each OrderItem points to one Product.

### Checkout transaction

`place_order()` verifies:

- authenticated customer owns the supplied customer ID;
- valid branch and delivery/pickup type;
- non-empty delivery address for delivery;
- every product exists;
- every quantity is positive;
- sufficient stock exists in that branch.

Only after all checks pass does it create the order/items, deduct stock,
calculate 5% tax, create low-stock alerts and commit. This prevents a partially
saved basket.

The cart becoming empty after success is correct: a completed cart is cleared.
The order must appear under My Orders. The earlier blank screen was a stale
Orders-page future; `orderVersion` now recreates the page after checkout.

## 6. Machine-learning training

### Phase 1 — EDA

`01_eda.ipynb` loads `supermarket_sales.csv`, examines shape, missing values,
types and distributions, converts dates/times, creates day/month/hour fields,
and studies branch, category, time and income relationships.

### Phase 2 — preprocessing

`02_preprocessing.ipynb`:

1. Removes identifiers, redundant location fields, constant columns and some
   derived leakage fields.
2. Creates `is_weekend`, `day_num`, `month_num`, and
   `price_quantity = Unit price × Quantity`.
3. Label-encodes Branch, Customer type, Gender, Product line and Payment.
4. Uses `gross income` as target `y`.
5. Preserves temporal order: first 800 rows train, last 200 rows test.
6. Fits StandardScaler only on training data and transforms both sets.
7. Saves train/test CSVs, scaler and encoders.

### Phase 3 — model comparison

`03_models.ipynb` trains:

- Linear Regression: interpretable baseline.
- Random Forest: averages many independent decision trees.
- XGBoost: sequential trees correct previous residual errors.

Saved test results:

| Model | Test RMSE | Test MAE | Test R² |
|---|---:|---:|---:|
| Linear Regression | 54.4609 | 42.1347 | 0.8333 |
| Random Forest | 15.8673 | 7.7760 | 0.9859 |
| XGBoost baseline | 10.5496 | 6.8586 | 0.9937 |

RMSE/MAE are prediction errors, so lower is better. R² is explained variance,
so closer to 1 is better.

### Phase 4 — tuning

`04_tuning.ipynb` tries 54 hyperparameter combinations:

- estimators: 100, 200, 300
- max depth: 3, 5, 7
- learning rate: 0.01, 0.1, 0.2
- subsample: 0.8, 1.0

Five-fold TimeSeriesSplit gives 270 fits. The best estimator is retrained and
saved as `model/xgb_tuned.pkl`.

### Runtime prediction

At Flask startup, `api/app.py` loads the model and scaler once. `/predict`
converts request fields to the same numeric feature order, scales them and
calls `model.predict()`.

### Honest ML limitation

`Total` and `price_quantity` are extremely closely related to gross income.
That makes the target highly predictable and can inflate R². If asked, say:

> The score is valid for this held-out dataset, but derived transaction totals
> make the problem close to deterministic. A stronger future experiment would
> predict future branch/category demand using only information known before the
> transaction and validate on a later real time period.

Never call R² “accuracy.” Say “R² score” or “explained variance.”

## 7. Shopping assistant

The assistant code is `shopping_assistant()` in `api/app.py`; its UI is
`AssistantPage` in `customer.dart`.

It uses:

- live Product rows;
- live Stock for the selected branch;
- keyword/intent matching;
- deterministic, grounded responses.

It covers greetings/help, product/category search, price, stock, cheapest/most
expensive items, branches, offers, cart, checkout, delivery, tracking and the
payment limitation.

It is not a general LLM and does not know arbitrary world knowledge. This is a
design choice: answers remain auditable, free, private and cannot invent
products. To answer arbitrary questions naturally, a future version can send
catalog context to a hosted LLM using a secret API key, moderation, retrieval
and cost controls.

The XGBoost predictor and assistant are both called “AI features” broadly, but
only XGBoost is the trained model in this repository.

## 8. Manager functions

- AI Insights calls `/manager/insights/<branch>`.
- It aggregates cleaned historical data by category and hour.
- Rush hours are the top three transaction-count hours.
- Recommended cashiers scale relative to peak transaction count.
- Inventory shows branch Stock and updates quantity.
- Staff shows active branch employees and shifts.
- Orders shows customer purchases and changes fulfilment status.
- Alerts shows unread low-stock/operations messages.

The insight aggregation is analytics, while `/predict` is ML inference.

## 9. Customer functions

- Shop selects branch, searches/categories, shows live stock and adds cart.
- Offers uses past OrderItems to find preferred category and applies a
  explainable 10% demonstration offer.
- Cart changes quantities and places delivery/pickup orders.
- My Orders reads persisted orders and supports pull-to-refresh.
- Assistant answers grounded SuperMart questions and can add returned products.
- Account panel shows the API-returned profile and connected API URL.

## 10. Cloud explanation

Locally:

```text
Browser → localhost:5000 Flask → SQLite
```

Cloud:

```text
Flutter public site → HTTPS Render API → private PostgreSQL connection
```

Render builds the Dockerfile, injects `DATABASE_URL`, monitors `/health`, and
runs the one-time seed hook. PostgreSQL persists independently of web-service
restarts. The Flutter build receives the public API using:

```text
--dart-define=API_URL=https://YOUR-SERVICE.onrender.com
```

The current repository contains cloud configuration. It is only an actual cloud
deployment after the GitHub commit is pushed and the Render Blueprint is
created in the user's Render account.

## 11. Perfect viva demonstration

1. Show `/health`.
2. Show the login page, select Create customer account, register a unique email.
3. Open the customer account panel; show returned profile and API URL.
4. Open the SQL database viewer and show the new `user` row. Never expose the
   complete hash/credentials publicly; explain that password is hashed.
5. Shop from Branch A, add a high-stock item, and place a delivery order.
6. Show it immediately under My Orders.
7. In SQL, show `order` and `order_item`; in Stock, show quantity deduction.
8. Log into Manager A in another browser, open Orders and update status.
9. Pull-to-refresh customer My Orders and show shared database state.
10. Ask assistant: categories, cheapest item, rice price, rice stock, delivery.
11. Open AI Insights and explain analytics versus ML prediction.
12. Open notebook 03 comparison and notebook 04 tuning/model saving.

## 12. Common lecturer questions

**Why Flask?**  
It is lightweight, integrates directly with Python ML libraries, and provides
simple JSON REST routes.

**Why Flutter?**  
One Dart codebase targets Android, web, Windows and other platforms.

**Why PostgreSQL in cloud?**  
It is a managed, durable relational store supporting constraints,
transactions, concurrent users and backups.

**Why not connect Flutter directly to SQL?**  
It would expose credentials and allow users to bypass validation/security.

**How are passwords protected?**  
bcrypt salted one-way hashes; authentication compares hashes, it does not
decrypt passwords.

**How are roles protected?**  
Signed JWT plus server-side `require_auth(role)` returns 401 or 403.

**Does the assistant use XGBoost?**  
No. XGBoost predicts numeric gross income. The assistant queries catalog/stock
and uses deterministic intents.

**Is payment implemented?**  
No external payment gateway. Order checkout and totals work. Never claim that
real card charging exists.

**Is tracking GPS?**  
No. It is order-status tracking controlled by managers. Live GPS needs a driver
app, maps provider and location permissions.

**What happens if stock is insufficient?**  
The API rejects the entire order with HTTP 409 before inserting anything.

**What happens after registration?**  
User row is committed, a JWT is returned, Flutter opens CustomerShell, and
future orders reference that user ID.

## 13. Commands

```powershell
# API
cd D:\ML\Project\api
python app.py

# Clean Flutter web instance
cd D:\ML\Project\mobile_app\supermart_flutter
..\..\flutter\bin\flutter.bat run -d web-server --web-port 8082 `
  --dart-define=API_URL=http://localhost:5000

# Automated backend integration test
cd D:\ML\Project\api
python test_e2e.py

# Flutter verification
cd D:\ML\Project\mobile_app\supermart_flutter
..\..\flutter\bin\flutter.bat analyze
..\..\flutter\bin\flutter.bat test
```

## 14. What not to claim

- Do not say the app is publicly deployed until a real public URL exists.
- Do not say the assistant answers every question.
- Do not say the XGBoost R² is classification accuracy.
- Do not claim real payments or live GPS.
- Do not claim the current demo JWT setup is complete enterprise security.
- Do not show or commit cloud database passwords, JWT secrets or API keys.

Clear, honest boundaries usually improve a viva because they demonstrate
engineering judgment.
