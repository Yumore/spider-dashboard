import 'package:flutter_js/flutter_js.dart';

const bool jsRuntimeSupported = true;

JavascriptRuntime? _runtime;

String evaluateJavascript(String script) {
  final runtime = _runtime ??= getJavascriptRuntime();
  final result = runtime.evaluate(script);
  if (result.isError) {
    throw StateError(result.stringResult);
  }
  return result.stringResult;
}
