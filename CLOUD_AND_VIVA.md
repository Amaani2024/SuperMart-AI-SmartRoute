# SuperMart AI: Cloud Architecture and Viva Guide

## 1. Where does a new user go?

When a customer selects **Create customer account**, Flutter sends:

```http
POST /auth/register
Content-Type: application/json
```

The JSON body contains the name, email, phone, delivery address, and password.
Flask validates the required values and checks whether the email already exists.
The password is passed through `bcrypt`; the plain password is never stored.
SQLAlchemy then inserts one row in the `user` table with role `customer`.

- Local development database: `api/instance/supermart.db` (SQLite)
- Cloud database: managed PostgreSQL selected through `DATABASE_URL`

The API returns the safe user fields only. It never returns the password hash.
Flutter uses the returned `role` to open either `ManagerShell` or
`CustomerShell`.

## 2. What is stored?

| Table | Purpose | Important links |
|---|---|---|
| `user` | Managers and customers | Customer owns orders |
| `product` | Shared product catalog | Product has branch stocks |
| `stock` | Quantity per product and branch | Links product + branch |
| `staff` | Staff assignments and shifts | Belongs to a branch |
| `order` | Checkout, delivery address and status | Links customer + branch |
| `order_item` | Products and quantities in an order | Links order + product |
| `alert` | Low-stock and operational warnings | Belongs to a branch |

An order is committed in one database transaction. Before inserting it, the
server validates every item and available branch stock. It then creates the
order/items, deducts stock, and creates low-stock alerts where necessary.

## 3. Where cloud computing is used

The deployable architecture has three tiers:

```text
Flutter Web / Android
        |
      HTTPS
        |
Dockerized Flask + Gunicorn API
   |                  |
PostgreSQL         XGBoost model
database           + sales dataset
```

- **Cloud application service:** runs the Docker image and Gunicorn API.
- **Managed cloud database:** PostgreSQL persists users, stock, staff, orders,
  and alerts independently of API restarts.
- **Static hosting/CDN:** serves the compiled Flutter web application.
- **Health monitoring:** the provider checks `GET /health`.
- **Configuration:** the API URL and database connection are injected at
  deployment time rather than hard-coded.
- **Scalability:** Gunicorn serves concurrent requests; the stateless API can
  be replicated while all instances use one central database.

The included `Dockerfile` packages the API, dataset, and trained model.
`render.yaml` describes the web service, health check, and PostgreSQL service.

## 4. Viva demonstration sequence

### Before the demonstration

1. Start/deploy the API and open `/health`; show `{"status":"healthy"}`.
2. Start Flutter with the correct API URL.
3. Keep one manager account ready in a second browser/incognito window.

### Live customer flow

1. Select **Create customer account**.
2. Use a new email that has never been registered.
3. Explain that the password is bcrypt-hashed before persistence.
4. Submit; the API creates the database row and the app opens as a customer.
5. Select a branch and add products to the cart.
6. Choose delivery, confirm the new customer's saved address, and place order.
7. Open **My Orders** and show the `pending` status.
8. Open **AI Offers** and explain that order categories drive preferences.
9. Ask the assistant to find a catalog item. Explain that its answers are
   grounded in current products and branch stock.

### Live manager flow

1. Sign in as the manager for the order's branch.
2. Open **Orders** and show the new order from the central database.
3. Change its status to `confirmed`, `preparing`, then `out for delivery`.
4. Return to the customer and refresh **My Orders** to show the shared state.
5. Open **Inventory** and show that checkout reduced stock.
6. Open **AI Insights** and explain:
   - category income is aggregated from the cleaned training dataset;
   - rush hours are the highest transaction-count hours;
   - recommended cashier count scales with rush-hour demand;
   - the trained XGBoost model has test R² `0.9937`.

## 5. Commands for the demonstration

Local API:

```powershell
cd D:\ML\Project\api
python seed_data.py
python app.py
```

Flutter web:

```powershell
cd D:\ML\Project\mobile_app\supermart_flutter
..\..\flutter\bin\flutter.bat run -d chrome
```

Deployed API:

```powershell
flutter run -d chrome --dart-define=API_URL=https://YOUR-API-HOST
```

Production web build:

```powershell
flutter build web --release --dart-define=API_URL=https://YOUR-API-HOST
```

## 6. Important honest answers

- The trained XGBoost model predicts gross income from transaction features.
- Rush-hour and category recommendations are data analytics built from the
  same cleaned supermarket dataset; they are not fabricated values.
- The shopping assistant is a deterministic, catalog-grounded assistant. It
  does not send customer data to an external generative-AI service.
- The project is cloud-ready, but it only becomes a cloud deployment after the
  repository is connected to a provider and the public API/client URLs exist.
- Payments and live GPS are not simulated as completed cloud integrations.
  Checkout, delivery addresses, and status tracking work; a real payment
  gateway and driver-location provider require external accounts and keys.
