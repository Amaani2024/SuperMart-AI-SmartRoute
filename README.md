# SuperMart AI

Multi-branch supermarket platform with a Flutter client, Flask API, relational
database, and trained XGBoost income model.

Manager flows include AI KPIs, category income, rush-hour staffing guidance,
inventory, staff schedules, fulfilment, and alerts. Customer flows include a
branch-aware catalog, AI offers, cart, delivery/pickup checkout, tracking, and
a catalog-grounded assistant.

## Local setup

> **GitHub note:** Do not commit local database files or secrets. The root `.gitignore` excludes the local SQLite database and generated build files. After running `flutter pub get` locally, keep the generated `pubspec.lock` in version control because this is an application project.


```powershell
cd api
python -m pip install -r requirements.txt
python seed_data.py
python app.py
```

In a second terminal:

```powershell
cd mobile_app\supermart_flutter
flutter pub get
flutter run
```

The Android emulator uses `http://10.0.2.2:5000`. For a real device or hosted
API, use `--dart-define=API_URL=https://your-api.example.com`.

Demo accounts (password `password123`):

- Manager: `manager.a@supermart.com`
- Customer: `hamdhan@customer.com`

## Cloud deployment

Push to GitHub and create the Render services from `render.yaml`. After the
first deployment, run `python api/seed_data.py` once in the service shell.

Build the Flutter web client:

```powershell
flutter build web --release --dart-define=API_URL=https://your-api.example.com
```

Deploy `mobile_app/supermart_flutter/build/web` to Firebase Hosting, Cloudflare
Pages, Netlify, or another static host. Build Android with:

```powershell
flutter build appbundle --release --dart-define=API_URL=https://your-api.example.com
```

Before public launch, replace demo passwords, restrict CORS, add token-based
authentication, and store secrets in the cloud provider's secrets service.

## SmartRoute doorstep delivery

This version includes GPS doorstep selection, stock-aware branch recommendation,
distance-based delivery fees, time slots, rider assignment, live demo tracking,
a solid completed route, a dotted remaining route, and four-digit delivery PIN
verification. See `SMARTROUTE_DOORSTEP_GUIDE.md` for setup and demonstration steps.
