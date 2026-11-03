const bool jsRuntimeSupported = false;

String evaluateJavascript(String script) {
  throw UnsupportedError(
    'This platform does not provide a JavaScript runtime.',
  );
}
