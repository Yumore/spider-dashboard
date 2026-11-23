import AVFoundation
import Flutter

final class SystemTtsBridge: NSObject, FlutterStreamHandler, AVSpeechSynthesizerDelegate {
  private static var instance: SystemTtsBridge?
  private lazy var synthesizer: AVSpeechSynthesizer = {
    let synthesizer = AVSpeechSynthesizer()
    synthesizer.delegate = self
    synthesizer.usesApplicationAudioSession = true
    return synthesizer
  }()
  private var sink: FlutterEventSink?
  private var utterances: [ObjectIdentifier: String] = [:]
  private var voice: AVSpeechSynthesisVoice?
  private var rate = AVSpeechUtteranceDefaultSpeechRate
  private var volume: Float = 1

  static func register(messenger: FlutterBinaryMessenger) {
    let bridge = SystemTtsBridge()
    instance = bridge
    let events = FlutterEventChannel(name: "fqapp/system_tts_events", binaryMessenger: messenger)
    events.setStreamHandler(bridge)
    let methods = FlutterMethodChannel(name: "fqapp/system_tts", binaryMessenger: messenger)
    methods.setMethodCallHandler { call, result in bridge.handle(call, result: result) }
  }

  private func stop() {
    // Clear identities before cancellation: late delegate callbacks belong to old speech.
    utterances.removeAll()
    synthesizer.stopSpeaking(at: .immediate)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "engines":
      let voices: [[String: String]] = AVSpeechSynthesisVoice.speechVoices().compactMap { voice in
        guard let data = try? JSONSerialization.data(withJSONObject: ["name": voice.name, "locale": voice.language]),
              let package = String(data: data, encoding: .utf8) else { return nil }
        return ["package": package, "label": "\(voice.name) (\(voice.language))"]
      }
      result(["defaultEngine": "ios", "engines": [["package": "ios", "label": "系统默认语音"]] + voices])
    case "initialize":
      stop()
      if let engine = args["engine"] as? String, engine.hasPrefix("{"),
         let data = engine.data(using: .utf8),
         let selection = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] {
        voice = AVSpeechSynthesisVoice.speechVoices().first {
          $0.name == selection["name"] && $0.language == selection["locale"]
        }
      } else {
        voice = AVSpeechSynthesisVoice(language: "zh-CN")
      }
      guard voice != nil else {
        result(FlutterError(code: "tts_failed", message: "系统语音不可用，请在设置中安装中文语音", details: nil))
        return
      }
      let requestedRate = (args["rate"] as? NSNumber)?.floatValue ?? 1
      rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, requestedRate * 0.5))
      result(300)
    case "speak":
      guard let text = args["text"] as? String, let id = args["id"] as? String,
            !text.isEmpty, !id.isEmpty, let voice else {
        result(FlutterError(code: "tts_failed", message: "缺少朗读内容或系统语音", details: nil))
        return
      }
      if args["queue"] as? Bool != true { stop() }
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voice
      utterance.rate = rate
      utterance.volume = volume
      utterances[ObjectIdentifier(utterance)] = id
      synthesizer.speak(utterance)
      result(nil)
    case "setVolume":
      volume = min(1, max(0, (args["volume"] as? NSNumber)?.floatValue ?? 1))
      result(nil)
    case "pause", "stop", "shutdown":
      stop()
      result(nil)
    case "settings":
      result(FlutterError(code: "unsupported_platform", message: "请在「设置 › 辅助功能 › 朗读内容」里调整系统语音", details: nil))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    guard let id = utterances[ObjectIdentifier(utterance)] else { return }
    sink?(["type": "start", "id": id])
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
    guard let id = utterances[ObjectIdentifier(utterance)] else { return }
    sink?(["type": "range", "id": id, "start": range.location, "end": NSMaxRange(range)])
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    guard let id = utterances.removeValue(forKey: ObjectIdentifier(utterance)) else { return }
    sink?(["type": "done", "id": id])
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    guard let id = utterances.removeValue(forKey: ObjectIdentifier(utterance)) else { return }
    sink?(["type": "error", "id": id])
  }
}
