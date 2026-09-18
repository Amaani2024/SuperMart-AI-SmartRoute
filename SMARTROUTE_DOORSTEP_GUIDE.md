# SuperMart SmartRoute Doorstep Delivery — OpenStreetMap Setup

This version uses **OpenStreetMap with `flutter_map`**. It does not need Google Cloud, a Google Maps API key, a credit card, or a billing account.

## What was changed

1. Removed `google_maps_flutter`.
2. Added `flutter_map`, `flutter_map_dragmarker`, and `latlong2`.
3. Removed the Google Maps key from `AndroidManifest.xml`.
4. Removed Google Maps setup from iOS and web files.
5. Kept customer GPS selection, draggable doorstep pin, live rider marker, completed route, dotted remaining route, delivery fee, delivery PIN, and order tracking.
6. Added required OpenStreetMap attribution and an application user-agent identifier.

## Step 1 — Open the correct Flutter folder

In VS Code, open a terminal and run:

```powershell
cd mobile_app\supermart_flutter
```

If your terminal is currently in the project root named `Super_Market`, this command is correct.

## Step 2 — Clean the old Google Maps packages

Run:

```powershell
flutter clean
```

Delete the old generated package cache only if Flutter reports an old Google Maps error:

```powershell
rmdir /s /q .dart_tool
```

PowerShell alternative:

```powershell
Remove-Item -Recurse -Force .dart_tool
```

## Step 3 — Install the OpenStreetMap packages

Run:

```powershell
flutter pub get
```

The important dependencies are now:

```yaml
flutter_map: ^8.3.1
flutter_map_dragmarker: ^8.0.3
latlong2: ^0.10.1
geolocator: ^14.0.2
geocoding: ^5.0.0
url_launcher: ^6.3.2
```

You do not need to add any API key.

## Step 4 — Confirm Android permissions

Open:

```text
mobile_app/supermart_flutter/android/app/src/main/AndroidManifest.xml
```

Confirm these permissions exist above `<application>`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

There should not be a Google Maps metadata section such as:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="..." />
```

## Step 5 — Start the Flask backend

Open a first terminal from the project root:

```powershell
cd api
python -m pip install -r requirements.txt
python app.py
```

Keep this terminal running.

## Step 6 — Run Flutter

Open a second terminal:

```powershell
cd mobile_app\supermart_flutter
flutter run
```

For an Android emulator, the existing API configuration should use:

```text
http://10.0.2.2:5000
```

For a physical phone, first find the laptop IPv4 address:

```powershell
ipconfig
```

Then run, replacing the example address:

```powershell
flutter run --dart-define=API_URL=http://192.168.1.8:5000
```

The laptop and phone must use the same Wi-Fi network. Allow Python through Windows Firewall when asked.

## Step 7 — Test the delivery location page

1. Log in as a customer.
2. Add products to the cart.
3. Select **Delivery**.
4. Press **Select Doorstep Location**.
5. Press **Use My Current Location**.
6. Allow location permission.
7. Tap the map or drag the red pin to the exact gate.
8. Enter the address and landmark.
9. Confirm the location.
10. Place the order.

The map tiles come from OpenStreetMap. An internet connection is required to load them.

## Step 8 — Test the live delivery route

1. Open the customer order from **My Orders**.
2. Log in as the manager for the selected branch.
3. Change the order status through:

```text
CONFIRMED
PREPARING
READY
RIDER ASSIGNED
OUT FOR DELIVERY
```

4. Return to the customer tracking page.
5. The rider marker updates every four seconds.
6. The travelled section appears as a solid line.
7. The remaining section appears as a dotted line.
8. The remaining distance and arrival time reduce as the rider moves.
9. Use the delivery PIN to complete the delivery.

## Important note about the demonstration route

The customer GPS location is real. The rider currently follows the project’s simulated route points. This is suitable for the coursework demonstration and does not require a separate rider application.

A future production version can connect the rider’s real GPS and a routing provider such as OSRM, Valhalla, MapTiler, or another hosted routing service.

## Common problems

### Map is grey or blank

1. Confirm the phone or emulator has internet access.
2. Run `flutter clean` and `flutter pub get`.
3. Fully stop the app and run it again.
4. Confirm `android.permission.INTERNET` exists.
5. Do not add a Google Maps key; it is not used in this version.

### Current location does not work

1. Turn on GPS on the phone.
2. Give the app location permission.
3. On an emulator, set a simulated location from the emulator controls.
4. If permission was permanently denied, enable it from Android Settings → Apps → SuperMart → Permissions.

### Backend connection fails on a real phone

1. Use the laptop IPv4 address, not `localhost`.
2. Keep `python app.py` running.
3. Keep the phone and laptop on the same Wi-Fi.
4. Allow port 5000 through Windows Firewall.

### Package error after the conversion

Run:

```powershell
flutter clean
flutter pub get
flutter run
```

If the error still mentions `google_maps_flutter`, delete `.dart_tool` and run `flutter pub get` again.

## OpenStreetMap usage note

This project identifies itself using the Android package name and displays OpenStreetMap contributor attribution. The public OpenStreetMap tile server is appropriate for a small classroom demonstration. For a large public or commercial deployment, use a suitable hosted tile provider rather than depending heavily on the community tile server.
