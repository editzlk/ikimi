OmniStaq POS - PWA (Android + iPhone, offline)
==============================================

A) WINDOWS PC (USB printer, POS-58 / PT210 driver)  -  hosting / internet one nae
   1. Zip eka extract karanna (Desktop eke folder ekakata). Zip ekak athulen open karanna epa.
   2. Start_OmniStaq_Windows.bat double-click karanna. App eka window ekak widiyata open wenawa.
      (Desktop ekata e .bat eke shortcut ekak hadaganna. Hama dawasama e shortcut eken open karanna.)
   3. Settings -> Thermal paper width = 58 mm. Print method = USB/PC (auto select wenawa). "Windows printer" eken printer eka thoragannath puluwan.
   4. "Print test receipt" press karanna. Charge karoth popup nathuwa, ikmanata raw ESC/POS eken print wela tick ekak enawa
      (oyage Flutter app eke thibba RAW print code ekamai - printer eke self-test eke wage sharp).
   Wada karanne nathnam: OmniStaq folder eke helper.log eka balanna (error eka ethana liyenawa).
   Note: me address eka (127.0.0.1:9101) aluth nisa products/sales aluthin thiyenawa; kalin demo data nam ewa nehe.

B) ANDROID / IPHONE (home screen icon + offline)  -  mulinma HTTPS hosting ekak ona (eka parak)
   Free: Netlify Drop (app.netlify.com/drop) / Cloudflare Pages / GitHub Pages. Folder eka upload karanna.
   Android (Chrome): link eka -> menu -> "Install app".  iPhone (Safari ONLY): Share -> "Add to Home Screen".
   Print: Android BLE nam Method = BLE -> Connect printer. Classic Bluetooth nam RawBT app (free) + Method = RawBT.
   iPhone walata Apple silent print denne nae (AirPrint sheet).

3) PAPER: Settings -> Thermal paper width = 58 mm (PT210 / POS-58). 80 dammoth bill eka kapenawa.

4) REPORT -> "Share report on WhatsApp"
   PDF eka hadala phone eke share sheet eka open wenawa (WhatsApp icon eka thoragena send). Summary text eka caption widiyata yanawa.

5) UPDATE KARANAWA NAM: index.html replace karala sw.js eke  const V='omnistaq-v1'  eka v2, v3... karanna.
