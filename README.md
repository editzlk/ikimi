# OmniStaq POS

Offline POS web app (PWA) with receipt printing, plus an iPhone app wrapper for direct Bluetooth printing to a PT210 thermal printer.

## Files

| File | What it is |
| --- | --- |
| `index.html`, `sw.js`, `manifest.webmanifest`, icons | The POS web app (Android, iPhone, any browser) |
| `server.ps1`, `Start_OmniStaq_Windows.bat` | Windows silent USB/PC printing (see `README.txt`) |
| `OmniStaqApp.swift`, `ContentView.swift`, `WebView.swift`, `PrinterManager.swift` | iPhone app (Xcode) |
| `README_iPhone.txt` | Steps to build the iPhone app |

## Use it online

Enable GitHub Pages for this repo (Settings > Pages > branch `main`, folder `/root`).
The app opens at `https://<user>.github.io/<repo>/` and can be added to the home screen on Android.

## iPhone printing without an app build

Safari on iPhone cannot use Bluetooth. Install the free **Bluefy** browser from the App Store,
open the GitHub Pages address (must be https) in Bluefy, go to Settings > Printer > BLE > Connect printer.

## Android

Open the https address in Chrome > Settings > Printer > BLE > Connect printer.
If the printer does not show up in the Bluetooth list, it is probably classic Bluetooth.
Pair it in Android Bluetooth settings, install the RawBT app and choose the RawBT method in Settings > Printer.
