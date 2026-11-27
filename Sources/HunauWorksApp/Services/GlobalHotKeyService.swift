import Carbon
import Foundation

@MainActor
final class GlobalHotKeyService {
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var eventHandlerRef: EventHandlerRef?
    private var handler: (@MainActor () -> Void)?

    private static weak var sharedInstance: GlobalHotKeyService?

    /// Default shortcut: Option + Shift + H (keyCode 4)
    private let keyCode: UInt32 = UInt32(kVK_ANSI_H)
    private let modifiers: UInt32 = UInt32(optionKey | shiftKey)

    init() {
        Self.sharedInstance = self
    }

    deinit {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func setEnabled(_ enabled: Bool, onTrigger: @escaping @MainActor () -> Void) {
        self.handler = onTrigger
        if enabled {
            registerIfNeeded()
        } else {
            unregister()
        }
    }

    private func registerIfNeeded() {
        guard hotKeyRef == nil else { return }

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr && hotKeyID.id == 1 {
                    Task { @MainActor in
                        GlobalHotKeyService.sharedInstance?.handler?()
                    }
                }
                return noErr
            }

            InstallEventHandler(
                GetApplicationEventTarget(),
                callback,
                1,
                &eventType,
                nil,
                &eventHandlerRef
            )
        }

        let signature: OSType = 0x484E574B // 'HNWK'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
