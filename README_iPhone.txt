OMNISTAQ - iPHONE APP (PT210 direct Bluetooth printing)
=======================================================

Meka mokakda?
  iPhone Safari walata Bluetooth printer ekakata print karanna bae.
  Ito OmniStaq page eka (index.html) iPhone app ekak athule open karala,
  print eka Swift (CoreBluetooth) haraha PT210 ekata yawanawa.
  Windows (USB/PC) saha Android (BLE / RawBT) wada karana widiyama thiyenawa.

Oyata one deval
  - Mac ekak + Xcode (App Store eken free)
  - iPhone eka + USB cable
  - Apple ID ekak (free eka hari. Free eke app eka dawas 7kata ekak aye install karanna wenawa.
    Developer Program ($99 / year) thiyenawa nam aye aye karanna ona naha)

Steps
  1. Xcode open karanna.  File > New > Project > iOS > App
       Product Name : OmniStaq
       Interface    : SwiftUI
       Language     : Swift
     Save karanna.

  2. Xcode eke left pane eke thiyena ContentView.swift saha OmniStaqApp.swift
     delete karanna (Move to Trash).

  3. Me folder eke thiyena Swift files 4 ma Xcode project ekata drag karanna:
       OmniStaqApp.swift, ContentView.swift, WebView.swift, PrinterManager.swift
     "Copy items if needed" tick karanna, Target "OmniStaq" tick.

  4. Me web files Xcode project ekata drag karanna (folder ekak nemei, file ewa):
       index.html, icon-192.png, icon-512.png, apple-touch-icon.png
       (manifest.webmanifest saha sw.js app ekata one naha, dammath wedak naha)
     "Copy items if needed" tick karanna, Target "OmniStaq" tick.
     server.ps1, .bat, README files app ekata danna epa.

  5. Left pane eke project eka (blue icon) click > TARGETS > OmniStaq > Info tab.
     "+" ebuwa, me row eka add karanna:
       Key   : Privacy - Bluetooth Always Usage Description
       Value : OmniStaq uses Bluetooth to print receipts on your receipt printer.
     (Meka nathnam app eka Bluetooth use karanakota crash wenawa.)

  6. General tab > Minimum Deployments = iOS 15.0 (ho uda).
     Device Orientation = Portrait witharak tick karanna.

  7. Signing & Capabilities tab > Team = oyage Apple ID.
     (Add account... eken login wenna.)

  8. iPhone eka Mac ekata connect karanna, Xcode uda thiyena device list eken iPhone eka select karala Run (play button).
     First time:
       iPhone > Settings > Privacy & Security > Developer Mode > ON (restart wenawa)
       iPhone > Settings > General > VPN & Device Management > oyage Apple ID eka > Trust

  9. App eka open wenawa. Settings tab > Printer > "iPhone" select karanna >
     "Connect printer" press karanna > Bluetooth allow karanna.
     "Connected: PT210_C983" kiyala enawa. Passe Test receipt print karala balanna.

Wada karanne nathnam
  - "Printer not found"
      * PT210 eka on karanna, iPhone ekata langin thiyanna.
      * Printer eka wena phone / app ekakata connect wela thiyenawa nam eka disconnect karanna.
        (BLE printer ekak eka welawata connection ekak witharai ganne.)
      * Printer eke nama "PT210" ekka patan gannawa nam wedak naha. Wenas nama ekak nam
        PrinterManager.swift eke  nameHint  eka wenas karanna.
  - "Bluetooth is off" : iPhone Settings > Privacy & Security > Bluetooth > OmniStaq ON karanna.
  - "Connected, but this printer has no channel": printer eka BLE nemei (classic Bluetooth witharai).
    Ekata iPhone app ekakin talk karanna bae.
  - Print eka sellam wenna kalin disconnect wenawa nam: printer eka sleep wela. Aye print karanna,
    app eka auto-connect karanawa.

Gannata onama deval
  - PDF report eka WhatsApp share karana button eka (navigator.share) iPhone app eke
    test karala balanna one. File download eka (anchor download) WKWebView eke wada karanne naha.
  - Page eka app athule bundle wela thiyenne. index.html wenas kalama Xcode eken aye Run karanna one.
