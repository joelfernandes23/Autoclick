import AppKit
import CoreGraphics

private let debugLoggingEnabled = false

private enum ClickButton: Int32 {
    case left = 0
    case right = 1
    case middle = 2

    var mouseButton: CGMouseButton {
        switch self {
        case .left:
            return .left
        case .right:
            return .right
        case .middle:
            return .center
        }
    }
}

private struct ClickParameters {
    let button: ClickButton
    let rate: Int
    let startAfter: Int
    let stopAfter: Int
    let stationary: Int
}

@objc(Clicker)
@objcMembers
final class Clicker: NSObject {
    private weak var host: ClickerHost?
    private var isWaiting = false
    private var fnPressed = false
    private var waitingTimer: Timer?
    private var stationarySeconds = 0
    private var lastMoved: TimeInterval = 0
    private var clickThread: Thread?
    private var globalMoveMonitor: Any?
    private var localMoveMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?

    private(set) dynamic var isClicking = false

    @objc(initWithHost:)
    init(host: ClickerHost) {
        self.host = host
        fnPressed = NSEvent.modifierFlags.contains(.function)
        super.init()
        installEventMonitors()
    }

    deinit {
        [globalMoveMonitor, localMoveMonitor, globalFlagsMonitor, localFlagsMonitor]
            .compactMap { $0 }
            .forEach(NSEvent.removeMonitor)
    }

    func stopClicking() {
        waitingTimer?.invalidate()
        waitingTimer = nil
        clickThread?.cancel()
        isClicking = false

        DispatchQueue.main.async { [weak self] in
            guard let host = self?.host else { return }
            host.stoppedClicking()
            host.statusLabel.stringValue = "Stopped."
            host.defaultIcon()
        }

        if debugLoggingEnabled { NSLog("Stopped Clicking Thread") }
    }

    @objc(startClicking:rate:startAfter:stopAfter:ifStationaryFor:)
    func startClicking(_ button: Int32, rate: Int, startAfter: Int, stopAfter: Int, ifStationaryFor stationary: Int) {
        if debugLoggingEnabled {
            NSLog("Button: \(button)")
            NSLog("Rate: \(rate)")
            NSLog("Start After: \(startAfter)")
            NSLog("Stop After: \(stopAfter)")
            NSLog("Only if stationary for \(stationary)")
        }

        host?.modeButton.isEnabled = false
        isClicking = true

        let parameters = ClickParameters(
            button: ClickButton(rawValue: button) ?? .left,
            rate: rate,
            startAfter: startAfter,
            stopAfter: stopAfter,
            stationary: stationary
        )

        if startAfter == 0 {
            startClickingThread(parameters)
        } else {
            startClickingThread(parameters, after: startAfter)
        }
    }

    private func installEventMonitors() {
        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.recordMouseMoved(event)
        }

        localMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.recordMouseMoved(event)
            return event
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateFunctionKeyState(from: event)
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateFunctionKeyState(from: event)
            return event
        }
    }

    private func recordMouseMoved(_ event: NSEvent) {
        if debugLoggingEnabled && fnPressed { NSLog("Mouse Moved") }
        lastMoved = Date().timeIntervalSince1970
    }

    private func updateFunctionKeyState(from event: NSEvent) {
        fnPressed = event.modifierFlags.contains(.function)

        guard isClicking, !isWaiting else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateClickingStatusForFunctionKey()
        }
    }

    private func updateClickingStatusForFunctionKey() {
        guard let host else { return }

        if fnPressed {
            host.statusLabel.stringValue = "Paused..."
            host.pausedIcon()
        } else {
            host.statusLabel.stringValue = "Clicking..."
            host.clickingIcon()
        }
    }

    private func startClickingThread(_ parameters: ClickParameters) {
        if debugLoggingEnabled { NSLog("Starting Clicking Thread...") }

        let thread = Thread { [weak self] in
            self?.clickThread(parameters)
        }

        clickThread = thread
        isWaiting = false
        thread.start()
    }

    private func startClickingThread(_ parameters: ClickParameters, after start: Int) {
        isWaiting = true
        waitingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(start), repeats: false) { [weak self] _ in
            self?.startClickingThread(parameters)
        }

        host?.statusLabel.stringValue = "Waiting..."
        host?.waitingIcon()
    }

    private func clickThread(_ parameters: ClickParameters) {
        guard isClicking else { return }

        let timeInterval = TimeInterval(parameters.rate) / 1000
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            self?.click(with: parameters.button.mouseButton)
        }

        if parameters.stopAfter > 0 {
            let thread = Thread.current
            Timer.scheduledTimer(withTimeInterval: TimeInterval(parameters.stopAfter), repeats: false) { [weak self] _ in
                self?.stopClicking(byCancelling: thread)
            }
        }

        stationarySeconds = parameters.stationary

        DispatchQueue.main.async { [weak self] in
            self?.updateClickingStatusForFunctionKey()
        }

        RunLoop.current.run()
    }

    private func stopClicking(byCancelling thread: Thread) {
        waitingTimer?.invalidate()
        waitingTimer = nil
        thread.cancel()
        isClicking = false

        DispatchQueue.main.async { [weak self] in
            guard let host = self?.host else { return }
            host.stoppedClicking()
            host.statusLabel.stringValue = "Stopped automatically."
            host.defaultIcon()
        }

        if debugLoggingEnabled { NSLog("Stopped Clicking Thread") }
    }

    private func checkBeforeClicking() -> Bool {
        if Thread.current.isCancelled { Thread.exit() }
        return Date().timeIntervalSince1970 - lastMoved >= TimeInterval(stationarySeconds) && !fnPressed
    }

    private func click(with mouseButton: CGMouseButton) {
        guard checkBeforeClicking() else { return }

        DispatchQueue.main.sync { [weak self] in
            guard let self, let host else { return }

            var point = NSEvent.mouseLocation

            if let appWindow = host.window, appWindow.isKeyWindow, NSPointInRect(point, appWindow.frame) {
                return
            }

            if debugLoggingEnabled { NSLog("Click with button: \(mouseButton.rawValue)") }

            let mainScreen = actualMainScreen()
            let currentScreen = currentScreen(for: point)
            let screensOverlap = currentScreen.frame.maxY
            let currentScreenTopMargin = mainScreen.frame.height - screensOverlap
            point.y = currentScreenTopMargin + currentScreen.frame.height - point.y + currentScreen.frame.origin.y

            let mouseDownEvent: CGEventType
            let mouseUpEvent: CGEventType

            switch mouseButton {
            case .left:
                mouseDownEvent = .leftMouseDown
                mouseUpEvent = .leftMouseUp
            case .right:
                mouseDownEvent = .rightMouseDown
                mouseUpEvent = .rightMouseUp
            default:
                mouseDownEvent = .otherMouseDown
                mouseUpEvent = .otherMouseUp
            }

            guard let click = CGEvent(
                mouseEventSource: nil,
                mouseType: mouseDownEvent,
                mouseCursorPosition: point,
                mouseButton: mouseButton
            ) else {
                return
            }

            click.post(tap: .cghidEventTap)
            click.type = mouseUpEvent
            click.post(tap: .cghidEventTap)
        }
    }

    private func currentScreen(for mouseLocation: CGPoint) -> NSScreen {
        NSScreen.screens.first { NSPointInRect(mouseLocation, $0.frame) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func actualMainScreen() -> NSScreen {
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
