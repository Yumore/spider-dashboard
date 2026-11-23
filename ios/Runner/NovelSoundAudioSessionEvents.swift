import Flutter

final class NovelSoundAudioSessionEvents: NSObject, FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    AudioSessionBridge.setEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    AudioSessionBridge.setEventSink(nil)
    return nil
  }
}
