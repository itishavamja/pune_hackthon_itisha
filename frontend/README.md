# Dukaan360 mobile app (Flutter)

The mobile app for **Dukaan360 – Predict Before You Lose**. It shows a shopkeeper their sales, the regular
customers who stopped coming, warnings, and AI-written offers to win customers back. The shopkeeper
approves every message; nothing is sent without them.

It talks to the FastAPI backend in [`../backend`](../backend). Start the backend first (see its README).

## What is in the app

| Tab | What the shopkeeper sees |
|---|---|
| **Home** | Plain-language "what needs your attention" card, sales numbers, past + expected sales chart |
| **Customers** | Who stopped coming, who is coming less often, spending and visit rhythm |
| **Warnings** | Sales drop, customers leaving, unusual payments, each with a "What to do" line |
| **Offers** | A 3-step guide and AI-written offers (Hindi / Marathi / English): change, send or don't send |
| **Ask AI** | Ask a question about the shop; answers use only the shop's own data |

Written in simple words on purpose (for example "Stopped coming", not "At-risk"). A short welcome walkthrough
runs on first launch, and "?" buttons explain each screen.

## Requirements

* Flutter 3.35+ (Dart 3.9+) and the Android SDK
* The backend running at `http://localhost:8000`

## Run it

All commands are for Windows PowerShell, from this `frontend` folder.

```powershell
flutter pub get
```

**On a real Android phone over USB** (recommended for demos; no Wi-Fi or firewall setup):

1. Turn on *Developer options → USB debugging* on the phone, plug it in, tap *Allow*.
2. Make the phone's `127.0.0.1:8000` point at your PC's backend, then run the app:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_URL=http://127.0.0.1:8000
```

If the app says "Can't connect" after you unplug/replug the cable, run the `adb reverse` line again.
The app also retries by itself every few seconds, so it reconnects as soon as the backend is reachable.

**Android emulator:** just `flutter run` (the emulator reaches your PC at `10.0.2.2:8000`, which is the default).

**Phone on Wi-Fi instead of USB:** start the backend with `--host 0.0.0.0`, then in the app tap the
gear icon (Connection settings) and enter `http://YOUR-PC-IP:8000`. Allow port 8000 in Windows Firewall.

## Tests

```powershell
flutter analyze
flutter test
```

The tests use a fake in-memory API, so they need no backend. They cover the screens, the approve / edit /
reject flow, the welcome walkthrough, offline recovery, plain-language wording, and the API client.

## Project layout

```
lib/
  main.dart, app.dart        entry point, theme, splash + welcome
  core/                      API client, config, theme, number formatting, plain-language labels
  models/                    data classes for the backend JSON
  providers/                 Riverpod state (one provider per backend endpoint)
  widgets/                   shared UI pieces (cards, skeleton loaders, sheets, toasts)
  features/                  home, customers, alerts (Warnings), growth (Offers), ask, onboarding, settings
test/                        unit, API client and widget tests
```

## Honest notes

* The demo data is synthetic and message sending is **Demo Mode** (no real WhatsApp/SMS goes out).
* Plain HTTP is allowed in the Android manifest because the demo backend runs on a developer PC.
  Serve the API over HTTPS and remove `usesCleartextTraffic` before any real deployment.

## Run on a physical Android phone (USB)

```powershell
adb reverse tcp:8000 tcp:8000
flutter run -d <device-id> --dart-define=API_URL=http://localhost:8000
```

`adb reverse` forwards the phone's `localhost:8000` to the backend on your PC, so no Wi-Fi setup is needed.
If the cable disconnects, re-run the `adb reverse` command. The API address can also be changed in the app's settings sheet.
