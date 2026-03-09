# Ramadan Compass

A dynamic Islamic web app that uses your location to show:

- Suhoor / Sehri ending time
- Iftar time
- Current prayer waqt
- When the current waqt expires
- The next prayer waqt
- A Ramadan calendar with today's day highlighted when applicable

## Run locally

```bash
npm start
```

Then open `http://127.0.0.1:3000`.

Allow location access so the app can load prayer times for your area.

## iOS app

This repo now also includes a native SwiftUI iPhone/iPad app in:

- `RamadanCompassIOS.xcodeproj`
- `RamadanCompassIOS/`

Open the Xcode project, choose a simulator or device, and run the app. The iOS app uses:

- `CoreLocation` for local prayer times
- `CLGeocoder` for place naming
- AlAdhan API for prayer timing data
