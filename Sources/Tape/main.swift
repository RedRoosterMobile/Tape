import AppKit
import CoreAudio
import Foundation

private enum TapeError: LocalizedError {
    case missingMultiOutputDevice
    case unableToReadDefaultOutput
    case unableToResolvePreviousOutput
    case coreAudioError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingMultiOutputDevice:
            return "Could not find an audio output device named \"Multi-Output Device\"."
        case .unableToReadDefaultOutput:
            return "Could not read the current default output device."
        case .unableToResolvePreviousOutput:
            return "Could not restore the previous output device."
        case .coreAudioError(let status):
            return "CoreAudio returned error code \(status)."
        }
    }
}

private final class AudioDeviceManager {
    private let targetDeviceName = "Multi-Output Device"
    private let previousOutputUIDKey = "previousOutputUID"

    func isRecordModeEnabled() -> Bool {
        guard let currentDeviceID = try? currentDefaultOutputDeviceID(),
              let targetDeviceID = try? deviceID(named: targetDeviceName) else {
            return false
        }

        return currentDeviceID == targetDeviceID
    }

    func enterRecordMode() throws {
        let currentDeviceID = try currentDefaultOutputDeviceID()
        let targetDeviceID = try deviceID(named: targetDeviceName)

        if currentDeviceID != targetDeviceID,
           let currentUID = try? deviceUID(for: currentDeviceID) {
            UserDefaults.standard.set(currentUID, forKey: previousOutputUIDKey)
        }

        try setDefaultOutputDevice(to: targetDeviceID)
    }

    func exitRecordMode() throws {
        guard let previousUID = UserDefaults.standard.string(forKey: previousOutputUIDKey) else {
            throw TapeError.unableToResolvePreviousOutput
        }

        let previousDeviceID = try deviceID(forUID: previousUID)
        try setDefaultOutputDevice(to: previousDeviceID)
    }

    func toggleRecordMode() throws {
        if isRecordModeEnabled() {
            try exitRecordMode()
        } else {
            try enterRecordMode()
        }
    }

    func currentOutputName() -> String? {
        guard let currentDeviceID = try? currentDefaultOutputDeviceID() else {
            return nil
        }

        return try? deviceName(for: currentDeviceID)
    }

    private func currentDefaultOutputDeviceID() throws -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr else {
            throw TapeError.unableToReadDefaultOutput
        }

        return deviceID
    }

    private func setDefaultOutputDevice(to deviceID: AudioDeviceID) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutableDeviceID = deviceID

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )

        guard status == noErr else {
            throw TapeError.coreAudioError(status)
        }
    }

    private func allDeviceIDs() throws -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize: UInt32 = 0

        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        guard sizeStatus == noErr else {
            throw TapeError.coreAudioError(sizeStatus)
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(), count: deviceCount)

        let listStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )

        guard listStatus == noErr else {
            throw TapeError.coreAudioError(listStatus)
        }

        return deviceIDs
    }

    private func deviceID(named expectedName: String) throws -> AudioDeviceID {
        let devices = try allDeviceIDs()

        if let device = devices.first(where: { (try? deviceName(for: $0)) == expectedName }) {
            return device
        }

        throw TapeError.missingMultiOutputDevice
    }

    private func deviceID(forUID expectedUID: String) throws -> AudioDeviceID {
        let devices = try allDeviceIDs()

        if let device = devices.first(where: { (try? deviceUID(for: $0)) == expectedUID }) {
            return device
        }

        throw TapeError.unableToResolvePreviousOutput
    }

    private func deviceName(for deviceID: AudioDeviceID) throws -> String {
        try readStringProperty(
            selector: kAudioObjectPropertyName,
            scope: kAudioObjectPropertyScopeGlobal,
            for: deviceID
        )
    }

    private func deviceUID(for deviceID: AudioDeviceID) throws -> String {
        try readStringProperty(
            selector: kAudioDevicePropertyDeviceUID,
            scope: kAudioObjectPropertyScopeGlobal,
            for: deviceID
        )
    }

    private func readStringProperty(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        for deviceID: AudioDeviceID
    ) throws -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var stringRef: CFString?
        var propertySize = UInt32(MemoryLayout<CFString?>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &stringRef
        )

        guard status == noErr else {
            throw TapeError.coreAudioError(status)
        }

        guard let stringRef else {
            throw TapeError.coreAudioError(OSStatus(unimpErr))
        }

        return stringRef as String
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let audioManager = AudioDeviceManager()
    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private var statusRefreshTimer: Timer?
    private var statusMenuItems: [Mode: NSMenuItem] = [:]

    private enum Mode {
        case `default`
        case record
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupMenu()
        refreshUI()
        startRefreshTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusRefreshTimer?.invalidate()
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else {
            toggleMode()
            return
        }

        switch event.type {
        case .rightMouseUp:
            guard let button = statusItem.button else { return }
            statusItem.menu = statusMenu
            button.performClick(nil)
            statusItem.menu = nil
        default:
            toggleMode()
        }
    }

    @objc private func setDefaultMode() {
        do {
            try audioManager.exitRecordMode()
            refreshUI()
        } catch {
            showFailure(error)
        }
    }

    @objc private func setRecordMode() {
        do {
            try audioManager.enterRecordMode()
            refreshUI()
        } catch {
            showFailure(error)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func refreshUI() {
        let isRecordMode = audioManager.isRecordModeEnabled()
        statusItem.button?.image = currentStatusImage(recordMode: isRecordMode)
        statusItem.button?.toolTip = audioManager.currentOutputName().map { outputName in
            isRecordMode ? "Tape: record mode (\(outputName))" : "Tape: default mode (\(outputName))"
        } ?? "Tape"

        statusMenuItems[.default]?.state = isRecordMode ? .off : .on
        statusMenuItems[.record]?.state = isRecordMode ? .on : .off
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = currentStatusImage(recordMode: false)
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupMenu() {
        let defaultItem = NSMenuItem(
            title: "Default Mode",
            action: #selector(setDefaultMode),
            keyEquivalent: ""
        )
        defaultItem.target = self

        let recordItem = NSMenuItem(
            title: "Record Mode",
            action: #selector(setRecordMode),
            keyEquivalent: ""
        )
        recordItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self

        statusMenu.addItem(defaultItem)
        statusMenu.addItem(recordItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(quitItem)

        statusMenuItems[.default] = defaultItem
        statusMenuItems[.record] = recordItem
    }

    private func toggleMode() {
        do {
            try audioManager.toggleRecordMode()
            refreshUI()
        } catch {
            showFailure(error)
        }
    }

    private func startRefreshTimer() {
        statusRefreshTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(refreshUI),
            userInfo: nil,
            repeats: true
        )
    }

    private func currentStatusImage(recordMode: Bool) -> NSImage? {
        let candidates = recordMode
            ? ["cassette.fill", "cassette", "waveform.badge.mic"]
            : ["speaker.wave.2.fill", "speaker.wave.2"]

        for name in candidates {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: "Tape") {
                image.isTemplate = true
                return image
            }
        }

        return nil
    }

    private func showFailure(_ error: Error) {
        refreshUI()

        let alert = NSAlert()
        alert.messageText = "Tape couldn’t change the audio output"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
