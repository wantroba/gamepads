import Flutter
import GameController
import UIKit

public class GamepadsIosPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel!
  private var controllerIds = [GCController: Int]()
  private var nextControllerId = 1

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = GamepadsIosPlugin()
    instance.channel = FlutterMethodChannel(name: "xyz.luan/gamepads", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: instance.channel)

    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.controllerConnected),
      name: .GCControllerDidConnect,
      object: nil
    )

    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.controllerDisconnected),
      name: .GCControllerDidDisconnect,
      object: nil
    )

    for controller in GCController.controllers() {
      instance.setupController(controller)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "listGamepads" {
      let gamepads = controllerIds.compactMap { (controller, id) -> [String: Any]? in
        guard let vendorName = controller.vendorName else { return nil }
        return [
          "id": id,
          "name": vendorName
        ]
      }
      result(gamepads)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func controllerConnected(notification: Notification) {
    if let controller = notification.object as? GCController {
      setupController(controller)
    }
  }

  @objc private func controllerDisconnected(notification: Notification) {
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

    // CORREÇÃO: dpad agora envia tipo "analog" e mapeia corretamente X e Y
    gamepad.dpad.valueChangedHandler = { [weak self] element, xValue, yValue in
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "dpad - xAxis", value: xValue, element: element)
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "dpad - yAxis", value: yValue, element: element)
    }

    gamepad.leftThumbstick.valueChangedHandler = { [weak self] element, xValue, yValue in
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "leftStick - xAxis", value: xValue, element: element)
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "leftStick - yAxis", value: yValue, element: element)
    }

    gamepad.rightThumbstick.valueChangedHandler = { [weak self] element, xValue, yValue in
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "rightStick - xAxis", value: xValue, element: element)
      self?.sendAnalogEvent(gamepadId: gamepadId, key: "rightStick - yAxis", value: yValue, element: element)
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
      button?.valueChangedHandler = { [weak self] element, _, pressed in
        self?.sendButtonEvent(gamepadId: gamepadId, key: name, value: pressed ? 1.0 : 0.0, element: element)
      }
    }
  }

  private func sendAnalogEvent(gamepadId: Int, key: String, value: Float, element: GCControllerElement) {
    channel.invokeMethod("event", arguments: [
      "type": "analog",
      "gamepadId": gamepadId,
      "key": key,
      "value": value,
      "time": Int(element.timestamp)
    ])
  }

  private func sendButtonEvent(gamepadId: Int, key: String, value: Float, element: GCControllerElement) {
    channel.invokeMethod("event", arguments: [
      "type": "button",
      "gamepadId": gamepadId,
      "key": key,
      "value": value,
      "time": Int(element.timestamp)
    ])
  }
}
