import Flutter
import GameController
import UIKit

public class GamepadsIosPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?

  // Map controllers to ids
  private var controllerIds = [GCController: Int]()
  private var nextControllerId = 1

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = GamepadsIosPlugin()
    let messenger = registrar.messenger()
    instance.channel = FlutterEventChannel(name: "xyz.luan/", binaryMessenger: messenger)
    instance.channel?.setStreamHandler(instance)

    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(controllerConnected),
      name: .GCControllerDidConnect,
      object: nil
    )

    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(controllerDisconnected),
      name: .GCControllerDidDisconnect,
      object: nil
    )

    for controller in GCController.controllers() {
      instance.setupController(controller)
    }
  }
}

extension GamepadsIosPlugin: FlutterStreamHandler {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  @objc func controllerConnected(notification: Notification) {
    if let controller = notification.object as? GCController {
      setupController(controller)
    }
  }

  @objc func controllerDisconnected(notification: Notification) {
    if let controller = notification.object as? GCController {
      controllerIds.removeValue(forKey: controller)
      // Optional: send disconnection event
    }
  }

  private func setupController(_ controller: GCController) {
    if controllerIds[controller] == nil {
      controllerIds[controller] = nextControllerId
      nextControllerId += 1
    }

    guard let gamepad = controller.extendedGamepad else { return }
    let gamepadId = controllerIds[controller]!

    gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "dpad - xAxis", value: xValue)
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "dpad - yAxis", value: yValue)
    }

    gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "leftStick - xAxis", value: xValue)
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "leftStick - yAxis", value: yValue)
    }

    gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "rightStick - xAxis", value: xValue)
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "rightStick - yAxis", value: yValue)
    }

    let buttons: [(GCControllerButtonInput?, String)] = [
      (gamepad.buttonA, "buttonA"),
      (gamepad.buttonB, "buttonB"),
      (gamepad.buttonX, "buttonX"),
      (gamepad.buttonY, "buttonY"),
      (gamepad.leftShoulder, "leftShoulder"),
      (gamepad.rightShoulder, "rightShoulder"),
      (gamepad.leftTrigger, "leftTrigger"),
      (gamepad.rightTrigger, "rightTrigger")
    ]

    for (button, name) in buttons {
      button?.valueChangedHandler = { [weak self] _, _, pressed in
        self?.sendButtonEvent(gamepadId: gamepadId, key: name, value: pressed ? 1.0 : 0.0)
      }
    }
  }

  private func sendAnalogEvent(gamepadId: Int, key: String, value: Float) {
    eventSink?([
      "type": "analog",
      "gamepadId": gamepadId,
      "key": key,
      "value": value,
      "time": Int(Date().timeIntervalSince1970)
    ])
  }

  private func sendButtonEvent(gamepadId: Int, key: String, value: Float) {
    eventSink?([
      "type": "button",
      "gamepadId": gamepadId,
      "key": key,
      "value": value,
      "time": Int(Date().timeIntervalSince1970)
    ])
  }
}
