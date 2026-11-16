import Flutter
import UIKit
import workmanager_apple
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var saveResult: FlutterResult?
  private var temporaryExport: URL?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.registerLaunchHandlers()
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.example.istudy.calendarSync",
      earliestBeginInSeconds: NSNumber(value: 15 * 60)
    )
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GrowzaFiles") {
      FlutterMethodChannel(name: "growza/files", binaryMessenger: registrar.messenger()).setMethodCallHandler { [weak self] call, result in
        guard call.method == "saveText" else { result(FlutterMethodNotImplemented); return }
        guard let self = self, self.saveResult == nil,
              let args = call.arguments as? [String: Any], let text = args["text"] as? String,
              let name = args["name"] as? String, text.utf8.count <= 10 * 1024 * 1024,
              name.range(of: "^[A-Za-z0-9._-]{1,100}$", options: .regularExpression) != nil else {
          result(FlutterError(code: "invalid", message: "Invalid backup or busy", details: nil)); return
        }
        do {
          let folder = FileManager.default.temporaryDirectory.appendingPathComponent("growza-export-" + UUID().uuidString, isDirectory: true)
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          let file = folder.appendingPathComponent(name)
          try Data(text.utf8).write(to: file, options: .atomic)
          self.saveResult = result; self.temporaryExport = folder
          let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
          picker.delegate = self
          guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            self.finishExport(false); return
          }
          var presenter = root
          while let presented = presenter.presentedViewController { presenter = presented }
          presenter.present(picker, animated: true)
        } catch { result(FlutterError(code: "save_failed", message: "Could not save backup", details: nil)) }
      }
    }
  }
  private func finishExport(_ success: Bool) {
    let result = saveResult; saveResult = nil
    if let folder = temporaryExport { try? FileManager.default.removeItem(at: folder) }
    temporaryExport = nil; result?(success)
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finishExport(false) }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finishExport(!urls.isEmpty) }
}
