import Cocoa
import Carbon

class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryCount = 0
    private let maxRetries = 5
    private var hasPromptedPermission = false  // 标记是否已经提示过权限
    private var permissionCheckTimer: Timer?   // 权限检查定时器
    private var lastPermissionStatus = false   // 记录上次权限状态
    
    var onKeyEvent: ((String, Bool) -> Void)? // (keyName, isKeyDown)
    
    func startMonitoring() {
        checkAndSetupMonitoring()
        startPermissionMonitoring()
    }
    
    // 启动权限状态监听
    private func startPermissionMonitoring() {
        // 每2秒检查一次权限状态并尝试创建监听
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissionStatus()
        }
    }
    
    // 检查权限状态并尝试创建监听（不弹窗）
    private func checkPermissionStatus() {
        // 使用 false，确保不会弹窗
        let checkOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(checkOptions)
        
        // 如果权限状态发生变化
        if isTrusted != lastPermissionStatus {
            print("🔄 权限状态变化: \(lastPermissionStatus) -> \(isTrusted)")
            lastPermissionStatus = isTrusted
        }
        
        // 如果还没有创建事件监听，尝试创建（即使权限检查返回 false）
        if eventTap == nil {
            print("🔄 定时检查：尝试创建事件监听...")
            let success = setupEventTap()
            if success {
                print("✅ 定时检查：事件监听创建成功！")
                retryCount = 0  // 重置重试计数
            } else {
                // 如果权限检查返回 true 但创建失败，可能是其他原因
                if isTrusted {
                    print("⚠️ 权限已授予但事件监听创建失败，可能是其他应用占用")
                }
            }
        }
    }
    
    private func checkAndSetupMonitoring() {
        // 检查权限状态（不弹窗）
        let checkOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(checkOptions)
        lastPermissionStatus = isTrusted
        
        print("辅助功能权限状态: \(isTrusted)")
        print("应用路径: \(Bundle.main.bundlePath)")
        
        if isTrusted {
            print("✅ 权限检查通过，尝试创建事件监听")
            setupEventTap()
        } else {
            // 即使权限检查失败，也尝试创建事件监听
            print("⚠️ 权限检查失败，但尝试创建事件监听...")
            
            if setupEventTap() {
                print("✅ 事件监听创建成功（尽管权限检查失败）")
            } else {
                // 如果创建失败，只在第一次提示用户
                if !hasPromptedPermission {
                    print("❌ 无法创建事件监听")
                    print("请确保在系统设置 → 隐私与安全性 → 辅助功能中已启用此应用")
                    print("应用路径: \(Bundle.main.bundlePath)")
                    
                    // 只提示一次权限（使用 true 会弹窗）
                    let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(promptOptions)
                    hasPromptedPermission = true  // 标记已提示，之后不再弹窗
                    
                    // 延迟重试（不弹窗）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.checkAndSetupMonitoring()
                    }
                } else {
                    // 已经提示过，不再弹窗，只打印日志
                    print("⚠️ 权限未授予，等待用户手动在系统设置中启用...")
                    print("💡 提示：授予权限后，应用会在2秒内自动检测并开始监听")
                    // 定时器会持续检查权限状态（不弹窗）
                }
            }
        }
    }
    
    @discardableResult
    private func setupEventTap() -> Bool {
        // 如果已经创建了，先清理
        if eventTap != nil {
            stopMonitoring()
        }
        
        // 创建事件监听
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            // 不打印错误，因为定时器会持续尝试
            return false
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            print("❌ 无法创建 RunLoop Source")
            self.eventTap = nil
            return false
        }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("✅ 事件监听已创建并启用")
        // 注意：不要重置 hasPromptedPermission，确保只弹窗一次
        return true
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 检查事件监听是否被禁用（可能因为权限问题）
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            print("⚠️ 事件监听被禁用: \(type == .tapDisabledByTimeout ? "超时" : "用户输入")")
            print("尝试重新启用...")
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            } else {
                // 如果 eventTap 为 nil，重新创建（不弹窗）
                print("🔄 事件监听丢失，重新创建...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    _ = self.setupEventTap()
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        if type == .keyDown || type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isKeyDown = type == .keyDown
            
            if isKeyDown {
                let keyName = getKeyName(keyCode: Int(keyCode), flags: event.flags)
                DispatchQueue.main.async {
                    self.onKeyEvent?(keyName, isKeyDown)
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func getKeyName(keyCode: Int, flags: CGEventFlags) -> String {
        // 修饰键
        var modifiers: [String] = []
        if flags.contains(.maskCommand) { modifiers.append("⌘") }
        if flags.contains(.maskShift) { modifiers.append("⇧") }
        if flags.contains(.maskAlternate) { modifiers.append("⌥") }
        if flags.contains(.maskControl) { modifiers.append("⌃") }
        
        // 按键名称映射
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
            13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-",
            28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
            33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
            39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab",
            49: "Space", 50: "`", 51: "Delete", 52: "Enter",
            53: "Esc", 36: "Return",
            // 功能键
            96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 105: "F13",
            106: "F16", 107: "F14", 109: "F10", 111: "F12",
            113: "F15", 114: "Help", 115: "Home", 116: "PageUp",
            117: "Forward Delete", 118: "F4", 119: "End",
            120: "F2", 121: "PageDown", 122: "F1",
            // 方向键
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        
        let keyName = keyMap[keyCode] ?? "Key\(keyCode)"
        let modifierString = modifiers.joined(separator: "")
        
        return modifierString.isEmpty ? keyName : modifierString + keyName
    }
    
    func stopMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}