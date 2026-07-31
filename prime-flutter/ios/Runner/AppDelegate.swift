import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var apnsToken: String?
  private var pendingNotification: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureNotificationCategories()
    UNUserNotificationCenter.current().delegate = self
    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingNotification = stringKeyedPayload(remote)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    pushChannel = FlutterMethodChannel(
      name: "prime/native_push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pushChannel?.setMethodCallHandler { [weak self] call, result in
      if call.method == "disableNotifications" {
        UIApplication.shared.unregisterForRemoteNotifications()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
        result(nil)
        return
      }
      guard call.method == "requestAuthorization" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.requestPushAuthorization(result: result)
    }
  }

  private func requestPushAuthorization(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { [weak self] granted, error in
      guard error == nil else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "permission_error",
              message: "Не удалось запросить разрешение на уведомления",
              details: nil
            )
          )
        }
        return
      }
      DispatchQueue.main.async {
        if granted {
          UIApplication.shared.registerForRemoteNotifications()
        }
        var response: [String: Any] = ["granted": granted]
        if let token = self?.apnsToken {
          response["token"] = token
        }
        if let pending = self?.pendingNotification {
          response["pending_notification"] = pending
        }
        result(response)
        self?.pendingNotification = nil
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    apnsToken = token
    pushChannel?.invokeMethod("token", arguments: ["token": token])
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // The app remains fully usable with durable in-app notifications and SSE.
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .badge, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    var payload = stringKeyedPayload(
      response.notification.request.content.userInfo
    )
    let action: String
    switch response.actionIdentifier {
    case "PRIME_CONFIRM_EARLY_START":
      action = "confirm"
    case "PRIME_KEEP_WAITING":
      action = "keep_waiting"
    case "PRIME_OPEN_SEARCH":
      action = "open_search"
    default:
      action = "open"
    }
    payload["action"] = action
    let method =
      response.actionIdentifier == UNNotificationDefaultActionIdentifier
      ? "notificationOpened"
      : "notificationAction"
    if let channel = pushChannel {
      channel.invokeMethod(method, arguments: payload)
    } else {
      pendingNotification = payload
    }
    completionHandler()
  }

  private func configureNotificationCategories() {
    let confirm = UNNotificationAction(
      identifier: "PRIME_CONFIRM_EARLY_START",
      title: "Подтвердить старт",
      options: [.foreground]
    )
    let wait = UNNotificationAction(
      identifier: "PRIME_KEEP_WAITING",
      title: "Продолжить ждать",
      options: []
    )
    let open = UNNotificationAction(
      identifier: "PRIME_OPEN_SEARCH",
      title: "Открыть поиск",
      options: [.foreground]
    )
    let category = UNNotificationCategory(
      identifier: "PRIME_EARLY_START",
      actions: [confirm, wait, open],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  private func stringKeyedPayload(
    _ payload: [AnyHashable: Any]
  ) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in payload {
      result[String(describing: key)] = value
    }
    return result
  }
}
