import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Канал app/background_time: Dart просит подержать процесс живым после
  /// сворачивания (beginBackgroundTask, ~30 секунд), пока конвейер интейка
  /// «Фото автомобиля» дожимает сжатие/presign/enqueue и vision-вызовы.
  private var intakeBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBackgroundTimeChannel(with: engineBridge.pluginRegistry)
  }

  private func registerBackgroundTimeChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "AppBackgroundTimeChannel") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "app/background_time",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "gone", message: "AppDelegate released", details: nil))
        return
      }
      switch call.method {
      case "hold":
        self.holdBackgroundTime()
        result(nil)
      case "release":
        self.releaseBackgroundTime()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func holdBackgroundTime() {
    guard intakeBackgroundTask == .invalid else { return }
    intakeBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "sparkIntakePipeline"
    ) { [weak self] in
      // Система забирает время — обязаны отпустить, иначе процесс убьют.
      self?.releaseBackgroundTime()
    }
  }

  private func releaseBackgroundTime() {
    guard intakeBackgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(intakeBackgroundTask)
    intakeBackgroundTask = .invalid
  }
}
