import Carbon
import AppKit

final class HotkeyService {

    struct Hotkey: Hashable {
        let keyCode: Int
        let modifiers: NSEvent.ModifierFlags

        func hash(into hasher: inout Hasher) {
            hasher.combine(keyCode)
            hasher.combine(modifiers.rawValue)
        }

        static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
            lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
        }
    }

    private struct HotkeyRegistration {
        let ref: EventHotKeyRef
        let id: UInt32
        let handler: () -> Void
    }

    private var registrations: [Hotkey: HotkeyRegistration] = [:]
    private var idToHotkey: [UInt32: Hotkey] = [:]
    private var eventHandler: EventHandlerRef?
    private static var nextHotkeyID: UInt32 = 1
    private static let signature: OSType = 0x54455854 // 'TEXT'
    private static weak var shared: HotkeyService?

    init() {
        HotkeyService.shared = self
        setupEventHandler()
    }

    deinit {
        unregisterAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    func register(keyCode: Int, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)

        if registrations[hotkey] != nil {
            unregister(hotkey)
        }

        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = HotkeyService.nextHotkeyID
        HotkeyService.nextHotkeyID += 1

        let eventHotKeyID = EventHotKeyID(signature: HotkeyService.signature, id: hotkeyID)
        let carbonModifiers = modifiers.carbonFlags

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            eventHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let ref = hotkeyRef {
            registrations[hotkey] = HotkeyRegistration(ref: ref, id: hotkeyID, handler: handler)
            idToHotkey[hotkeyID] = hotkey
        }
    }

    func unregister(_ hotkey: Hotkey) {
        if let registration = registrations[hotkey] {
            UnregisterEventHotKey(registration.ref)
            idToHotkey.removeValue(forKey: registration.id)
            registrations.removeValue(forKey: hotkey)
        }
    }

    func unregisterAll() {
        for (_, registration) in registrations {
            UnregisterEventHotKey(registration.ref)
        }
        registrations.removeAll()
        idToHotkey.removeAll()
    }

    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { (_, event, _) -> OSStatus in
            guard let event = event, let service = HotkeyService.shared else {
                return OSStatus(eventNotHandledErr)
            }
            return service.handleHotkeyEvent(event)
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )
    }

    private func handleHotkeyEvent(_ event: EventRef) -> OSStatus {
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        guard status == noErr else { return status }
        guard hotkeyID.signature == HotkeyService.signature else {
            return OSStatus(eventNotHandledErr)
        }

        if let hotkey = idToHotkey[hotkeyID.id],
           let registration = registrations[hotkey] {
            DispatchQueue.main.async {
                registration.handler()
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    static func hotkeyDisplayString(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    static func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        default: return "?"
        }
    }
}
