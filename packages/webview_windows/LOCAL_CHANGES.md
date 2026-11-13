# Local changes

Base source: [Predidit/flutter-webview-windows](https://github.com/Predidit/flutter-webview-windows), commit `2b3306d2bfb9f22cbb328743b60e547cf50f0c3c` (BSD-3-Clause; license retained in this directory).

The package is the shared Windows WebView implementation for Kazumi and Novel Sound. It retains the upstream headless WebView and response attachment support. The Novel Sound change adds `getFanqieCookies`, which reads cookies only for the fixed `https://fanqienovel.com/` origin so the desktop account importer can access HttpOnly session cookies. No caller-supplied origin is accepted. The change is implemented through the WebView2 cookie protocol, exposed over the existing Flutter method channel, and consumed in memory by the importer.
