# OmniStaq local helper: serves the app on http://127.0.0.1:9101/ and prints raw ESC/POS to the Windows printer.
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Log = Join-Path $Root 'helper.log'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class OmniRawPrinter {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public class DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
  }
  [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true)]
  static extern bool OpenPrinter(string name, out IntPtr handle, IntPtr defaults);
  [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true)]
  static extern bool ClosePrinter(IntPtr handle);
  [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true)]
  static extern bool StartDocPrinter(IntPtr handle, int level, [In] DOCINFOA doc);
  [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true)]
  static extern bool EndDocPrinter(IntPtr handle);
  [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true)]
  static extern bool StartPagePrinter(IntPtr handle);
  [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true)]
  static extern bool EndPagePrinter(IntPtr handle);
  [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true)]
  static extern bool WritePrinter(IntPtr handle, IntPtr bytes, int count, out int written);

  public static void Send(string printer, byte[] data) {
    IntPtr handle;
    if (!OpenPrinter(printer, out handle, IntPtr.Zero)) throw new Exception("Cannot open printer '" + printer + "'. Error " + Marshal.GetLastWin32Error());
    try {
      DOCINFOA doc = new DOCINFOA();
      doc.pDocName = "OmniStaq receipt";
      doc.pDataType = "RAW";
      if (!StartDocPrinter(handle, 1, doc)) throw new Exception("StartDocPrinter failed. Error " + Marshal.GetLastWin32Error());
      try {
        StartPagePrinter(handle);
        IntPtr buffer = Marshal.AllocCoTaskMem(data.Length);
        try {
          Marshal.Copy(data, 0, buffer, data.Length);
          int written;
          if (!WritePrinter(handle, buffer, data.Length, out written) || written != data.Length)
            throw new Exception("WritePrinter failed. Error " + Marshal.GetLastWin32Error());
        } finally { Marshal.FreeCoTaskMem(buffer); }
        EndPagePrinter(handle);
      } finally { EndDocPrinter(handle); }
    } finally { ClosePrinter(handle); }
  }
}
'@
Add-Type -AssemblyName System.Drawing
$types = @{ '.html'='text/html; charset=utf-8'; '.png'='image/png'; '.webmanifest'='application/manifest+json'; '.js'='text/javascript; charset=utf-8'; '.txt'='text/plain' }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://127.0.0.1:9101/')
try { $listener.Start() } catch { exit }

function Out($res, [int]$code, [byte[]]$bytes, [string]$type) {
  $res.StatusCode = $code
  $res.ContentType = $type
  $res.Headers.Add('Cache-Control', 'no-store')
  $res.ContentLength64 = $bytes.Length
  $res.OutputStream.Write($bytes, 0, $bytes.Length)
}
function Txt($res, [int]$code, [string]$text) { Out $res $code ([System.Text.Encoding]::UTF8.GetBytes($text)) 'text/plain; charset=utf-8' }
function Pick([string]$name) {
  $all = @([System.Drawing.Printing.PrinterSettings]::InstalledPrinters)
  if ($name -and ($all -contains $name)) { return $name }
  $pick = $all | Where-Object { $_ -match 'PT-?210|POS|Thermal|Receipt|XP-|58' } | Select-Object -First 1
  if ($pick) { return $pick }
  $def = (New-Object System.Drawing.Printing.PrinterSettings).PrinterName
  if ($def) { return $def }
  throw 'No Windows printer was found.'
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    $path = $req.Url.AbsolutePath
    if ($req.HttpMethod -eq 'POST' -and $path -eq '/print') {
      $ms = New-Object System.IO.MemoryStream
      $req.InputStream.CopyTo($ms)
      $printer = Pick ([string]$req.QueryString['printer'])
      [OmniRawPrinter]::Send($printer, $ms.ToArray())
      Txt $res 200 ('Printed on ' + $printer)
    }
    elseif ($path -eq '/printers') {
      $names = @([System.Drawing.Printing.PrinterSettings]::InstalledPrinters | ForEach-Object { '"' + ($_ -replace '\\','\\' -replace '"','\"') + '"' })
      Out $res 200 ([System.Text.Encoding]::UTF8.GetBytes('{"list":[' + ($names -join ',') + ']}')) 'application/json'
    }
    else {
      $rel = $path.TrimStart('/')
      if ($rel -eq '') { $rel = 'index.html' }
      $file = Join-Path $Root $rel
      $ext = [System.IO.Path]::GetExtension($rel).ToLower()
      if ($rel -match '^[A-Za-z0-9_.\-]+$' -and $types.ContainsKey($ext) -and (Test-Path -LiteralPath $file -PathType Leaf)) {
        Out $res 200 ([System.IO.File]::ReadAllBytes($file)) $types[$ext]
      } else { Txt $res 404 'Not found' }
    }
  }
  catch {
    try { Add-Content -Path $Log -Value ((Get-Date).ToString('s') + '  ' + $_.Exception.Message) } catch {}
    try { Txt $res 500 $_.Exception.Message } catch {}
  }
  finally { try { $res.Close() } catch {} }
}
