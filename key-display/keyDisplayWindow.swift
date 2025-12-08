import SwiftUI
import AppKit
import Combine

// 按键项结构
struct KeyItem: Identifiable {
    let id: UUID
    let name: String
    let timestamp: Date
    
    init(id: UUID = UUID(), name: String, timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
    }
}

// 显示位置枚举
enum DisplayPosition: String, CaseIterable {
    case topLeft = "左上"
    case topCenter = "上中"
    case topRight = "右上"
    case bottomLeft = "左下"
    case bottomCenter = "下中"
    case bottomRight = "右下"
    case center = "居中"
    
    func frame(in screenFrame: CGRect, windowSize: CGSize) -> CGRect {
        let margin: CGFloat = 20
        let x: CGFloat
        let y: CGFloat
        let minX = screenFrame.minX
        let minY = screenFrame.minY
        let width = screenFrame.width
        let height = screenFrame.height
        
        switch self {
        case .topLeft:
            x = minX + margin
            y = minY + height - windowSize.height - margin
        case .topCenter:
            x = minX + (width - windowSize.width) / 2
            y = minY + height - windowSize.height - margin
        case .topRight:
            x = minX + width - windowSize.width - margin
            y = minY + height - windowSize.height - margin
        case .bottomLeft:
            x = minX + margin
            y = minY + margin
        case .bottomCenter:
            x = minX + (width - windowSize.width) / 2
            y = minY + margin
        case .bottomRight:
            x = minX + width - windowSize.width - margin
            y = minY + margin
        case .center:
            x = minX + (width - windowSize.width) / 2
            y = minY + (height - windowSize.height) / 2
        }
        
        return CGRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }
}

struct ScreenIdentifier {
    static func key(for screen: NSScreen) -> String {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let id = number?.uint32Value ?? 0
        return "screen-\(id)"
    }
}

class KeyDisplayWindow: NSWindow {
    static var shared: KeyDisplayWindow?
    private var initialDragLocation: NSPoint?
    private var cancellables = Set<AnyCancellable>()
    private let fixedWindowWidth: CGFloat = 370
    private var isResizing = false
    
    private static func windowSize(for fontSize: Double, width: CGFloat) -> CGSize {
        let height = max(64, CGFloat(fontSize + 32))
        return CGSize(width: width, height: height)
    }
    
    private var windowSize: CGSize {
        KeyDisplayWindow.windowSize(for: AppSettings.shared.fontSize, width: fixedWindowWidth)
    }
    
    init() {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = KeyDisplayWindow.windowSize(for: AppSettings.shared.fontSize, width: fixedWindowWidth)
        let position = AppSettings.shared.displayPosition
        let frame = position.frame(in: screenFrame, windowSize: windowSize)
        
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        
        let contentView = KeyDisplayView()
        self.contentView = NSHostingView(rootView: contentView)
        
        KeyDisplayWindow.shared = self
        applySavedPosition()
        
        // 监听设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updatePosition),
            name: .displayPositionChanged,
            object: nil
        )
        
        AppSettings.shared.$fontSize
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.resizeWindow()
            }
            .store(in: &cancellables)
    }
    
    @objc private func updatePosition() {
        let screenFrame = (self.screen ?? NSScreen.main)?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let position = AppSettings.shared.displayPosition
        let newFrame = position.frame(in: screenFrame, windowSize: windowSize)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().setFrame(newFrame, display: true)
        }
    }
    
    private func resizeWindow() {
        guard !isResizing else { return }
        isResizing = true
        var frame = self.frame
        if frame.size != windowSize {
            frame.size = windowSize
        } else {
            isResizing = false
            return
        }
        let targetScreen = screen(containing: frame.origin) ?? self.screen ?? NSScreen.main
        if let screen = targetScreen {
            frame.origin = clampedOrigin(frame.origin, in: screen.frame)
            AppSettings.shared.savePosition(frame.origin, for: screen)
        }
        self.setFrame(frame, display: true, animate: false)
        isResizing = false
    }
    
    private func applySavedPosition() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        if let point = AppSettings.shared.savedPosition(for: screen) {
            let clamped = clampedOrigin(point, in: screen.frame)
            setFrameOrigin(clamped)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        initialDragLocation = event.locationInWindow
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let initialDragLocation = initialDragLocation else { return }
        
        let currentLocation = event.locationInWindow
        var newOrigin = frame.origin
        newOrigin.x += currentLocation.x - initialDragLocation.x
        newOrigin.y += currentLocation.y - initialDragLocation.y
        
        let targetScreen = screen(containing: newOrigin, allowExtended: true) ?? self.screen ?? NSScreen.main
        if let screen = targetScreen {
            let clamped = clampedOrigin(newOrigin, in: screen.frame)
            setFrameOrigin(clamped)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        defer { initialDragLocation = nil }
        let targetScreen = screen(containing: frame.origin) ?? self.screen ?? NSScreen.main
        if let screen = targetScreen {
            AppSettings.shared.savePosition(frame.origin, for: screen)
        }
    }
    
    private func clampedOrigin(_ origin: CGPoint, in screenFrame: CGRect) -> CGPoint {
        let maxX = screenFrame.maxX - windowSize.width
        let maxY = screenFrame.maxY - windowSize.height
        
        let clampedX = min(max(screenFrame.minX, origin.x), maxX)
        let clampedY = min(max(screenFrame.minY, origin.y), maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    private func screen(containing origin: CGPoint, allowExtended: Bool = false) -> NSScreen? {
        let targetRect = CGRect(origin: origin, size: windowSize)
        
        // 按与屏幕的交集面积选择最佳屏幕，必要时扩展屏幕区域方便跨屏拖拽
        let best = NSScreen.screens
            .map { screen -> (NSScreen, CGFloat) in
                let frame = allowExtended ? screen.frame.insetBy(dx: -max(windowSize.width, 120), dy: 0) : screen.frame
                let intersection = frame.intersection(targetRect)
                let area = intersection.width > 0 && intersection.height > 0 ? intersection.width * intersection.height : 0
                return (screen, area)
            }
            .max { $0.1 < $1.1 }
        
        // 如果有交集面积，则用面积最大的屏幕；否则退回包含中心点的屏幕；再否则取主屏
        if let (screen, area) = best, area > 0 {
            return screen
        }
        let center = CGPoint(x: targetRect.midX, y: targetRect.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main
    }
    
    override var canBecomeKey: Bool {
        return false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    static let displayPositionChanged = Notification.Name("displayPositionChanged")
    static let alwaysShowChanged = Notification.Name("alwaysShowChanged")
}

struct KeyDisplayView: View {
    @StateObject private var keyDisplayManager = KeyDisplayManager.shared
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        let height = max(64, settings.fontSize + 32)
        let showPlaceholder = settings.alwaysShow && keyDisplayManager.keys.isEmpty
        let showContainer = showPlaceholder || !keyDisplayManager.keys.isEmpty
        
        if showContainer {
            Group {
                if !keyDisplayManager.keys.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(keyDisplayManager.keys) { keyItem in
                            KeyItemView(keyName: keyItem.name)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    // 常驻模式下保持容器可见，即便当前没有按键
                    HStack {
                        Text("等待按键…")
                            .font(.system(size: settings.fontSize * 0.8, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: height, alignment: .leading)
                }
            }
            .frame(width:370, height: height)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
            )
            .animation(.easeOut(duration: 0.2), value: keyDisplayManager.keys.map { $0.id })
        } else {
            // 非常驻且无按键时完全隐藏容器
            Color.clear
        }
    }
}

// 单个按键视图
struct KeyItemView: View {
    let keyName: String
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        let backgroundColor = ColorHelper.colorForKey(keyName)
        let textColor = ColorHelper.contrastColor(for: backgroundColor)
        let fontSize = settings.fontSize
        let verticalPadding = max(6, fontSize * 0.35)
        let horizontalPadding = max(12, fontSize * 0.45)
        
        HStack(spacing: 8) {
            Text(keyName)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
        )
        .shadow(color: backgroundColor.opacity(0.7), radius: 15, x: 0, y: 5)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
}

// 颜色辅助类
class ColorHelper {
    // 彩虹色数组（纯色）
    static let rainbowColors: [Color] = [
        Color(red: 1.0, green: 0.2, blue: 0.4),      // 粉红
        Color(red: 1.0, green: 0.5, blue: 0.0),      // 橙
        Color(red: 1.0, green: 0.8, blue: 0.0),      // 黄
        Color(red: 0.2, green: 1.0, blue: 0.3),      // 绿
        Color(red: 0.0, green: 0.6, blue: 1.0),      // 蓝
        Color(red: 0.6, green: 0.2, blue: 1.0),      // 紫
        Color(red: 1.0, green: 0.0, blue: 0.5),      // 玫红
        Color(red: 0.0, green: 0.8, blue: 0.8),      // 青
    ]
    
    // 根据按键名称生成稳定的颜色
    static func colorForKey(_ keyName: String) -> Color {
        // 使用按键名称的哈希值来选择颜色
        let hash = keyName.hashValue
        let index = abs(hash) % rainbowColors.count
        return rainbowColors[index]
    }
    
    // 根据背景色计算对比度高的文字颜色
    static func contrastColor(for backgroundColor: Color) -> Color {
        // 将 SwiftUI Color 转换为 NSColor 以获取 RGB 值
        let nsColor = NSColor(backgroundColor)
        
        // 获取 RGB 分量（0-1）
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // 计算亮度（使用相对亮度公式）
        // L = 0.299*R + 0.587*G + 0.114*B
        let luminance = 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
        
        // 如果背景较亮，使用深色文字；如果背景较暗，使用浅色文字
        return luminance > 0.5 ? Color.black : Color.white
    }
}

// 设置管理类
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let displayPositionKey = "displayPosition"
    private let displayDurationKey = "displayDuration"
    private let fontSizeKey = "fontSize"
    private let mergeDuplicatesKey = "mergeDuplicates"
    private let alwaysShowKey = "alwaysShow"
    private let customPositionsKey = "customPositions"
    
    @Published var displayPosition: DisplayPosition {
        didSet {
            UserDefaults.standard.set(displayPosition.rawValue, forKey: displayPositionKey)
            NotificationCenter.default.post(name: .displayPositionChanged, object: nil)
            clearSavedPositions()
        }
    }
    
    @Published var displayDuration: Double {
        didSet {
            UserDefaults.standard.set(displayDuration, forKey: displayDurationKey)
        }
    }
    
    @Published var fontSize: Double {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: fontSizeKey)
        }
    }
    
    @Published var mergeDuplicates: Bool {
        didSet {
            UserDefaults.standard.set(mergeDuplicates, forKey: mergeDuplicatesKey)
        }
    }
    
    @Published var alwaysShow: Bool {
        didSet {
            UserDefaults.standard.set(alwaysShow, forKey: alwaysShowKey)
            NotificationCenter.default.post(name: .alwaysShowChanged, object: nil)
        }
    }
    
    // 按屏幕记录拖拽位置
    @Published private var savedPositions: [String: CGPoint] {
        didSet {
            let encoded = savedPositions.mapValues { "\($0.x),\($0.y)" }
            UserDefaults.standard.set(encoded, forKey: customPositionsKey)
        }
    }
    
    private init() {
        // 从 UserDefaults 加载设置
        if let positionString = UserDefaults.standard.string(forKey: displayPositionKey),
           let position = DisplayPosition(rawValue: positionString) {
            self.displayPosition = position
        } else {
            self.displayPosition = .topCenter  // 默认位置
        }
        
        let duration = UserDefaults.standard.double(forKey: displayDurationKey)
        self.displayDuration = duration > 0 ? duration : 2.0  // 默认2秒
        
        let storedFont = UserDefaults.standard.double(forKey: fontSizeKey)
        self.fontSize = storedFont > 0 ? storedFont : 28.0
        
        if UserDefaults.standard.object(forKey: mergeDuplicatesKey) == nil {
            self.mergeDuplicates = true
        } else {
            self.mergeDuplicates = UserDefaults.standard.bool(forKey: mergeDuplicatesKey)
        }
        
        if UserDefaults.standard.object(forKey: alwaysShowKey) == nil {
            self.alwaysShow = false
        } else {
            self.alwaysShow = UserDefaults.standard.bool(forKey: alwaysShowKey)
        }
        
        if let rawPositions = UserDefaults.standard.dictionary(forKey: customPositionsKey) as? [String: String] {
            var decoded: [String: CGPoint] = [:]
            for (key, value) in rawPositions {
                let parts = value.split(separator: ",")
                if parts.count == 2,
                   let x = Double(parts[0]),
                   let y = Double(parts[1]) {
                    decoded[key] = CGPoint(x: x, y: y)
                }
            }
            self.savedPositions = decoded
        } else {
            self.savedPositions = [:]
        }
    }
    
    func savePosition(_ point: CGPoint, for screen: NSScreen) {
        let key = ScreenIdentifier.key(for: screen)
        savedPositions[key] = point
    }
    
    func savedPosition(for screen: NSScreen) -> CGPoint? {
        let key = ScreenIdentifier.key(for: screen)
        return savedPositions[key]
    }
    
    func clearSavedPositions() {
        savedPositions.removeAll()
    }
}

class KeyDisplayManager: ObservableObject {
    static let shared = KeyDisplayManager()
    
    @Published var keys: [KeyItem] = []
    private var hideTasks: [UUID: DispatchWorkItem] = [:]
    private let maxKeys = 3
    
    private var displayDuration: TimeInterval {
        return AppSettings.shared.displayDuration
    }
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlwaysShowChanged),
            name: .alwaysShowChanged,
            object: nil
        )
    }
    
    func showKey(_ keyName: String) {
        DispatchQueue.main.async {
            // 创建新的按键项
            let newKey = KeyItem(name: keyName, timestamp: Date())
            
            // 合并相同按键：延长时间并移动到末尾
            if AppSettings.shared.mergeDuplicates,
               let existingIndex = self.keys.firstIndex(where: { $0.name == keyName }) {
                let existingKey = self.keys[existingIndex]
                let updatedKey = KeyItem(id: existingKey.id, name: keyName, timestamp: Date())
                
                // 取消旧的隐藏任务
                self.hideTasks[existingKey.id]?.cancel()
                self.hideTasks.removeValue(forKey: existingKey.id)
                
                // 更新位置到末尾
                self.keys.remove(at: existingIndex)
                self.keys.append(updatedKey)
                
                // 重置隐藏计时
                self.scheduleHide(for: updatedKey.id)
                return
            }
            
            // 如果已经有3个按键，移除最旧的（第一个）
            if self.keys.count >= self.maxKeys {
                if let oldestKey = self.keys.first {
                    self.removeKey(oldestKey.id)
                }
            }
            
            // 添加新按键到末尾
            self.keys.append(newKey)
            
            // 为新按键设置自动隐藏
            self.scheduleHide(for: newKey.id)
        }
    }
    
    private func scheduleHide(for keyId: UUID) {
        if AppSettings.shared.alwaysShow {
            return
        }
        
        // 取消之前的隐藏任务（如果存在）
        hideTasks[keyId]?.cancel()
        
        // 创建新的隐藏任务
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 检查按键是否还存在
            if self.keys.contains(where: { $0.id == keyId }) {
                self.removeKey(keyId)
            }
        }
        
        hideTasks[keyId] = task
        
        // 使用设置中的显示时长
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: task)
    }
    
    private func removeKey(_ keyId: UUID) {
        // 取消隐藏任务
        hideTasks[keyId]?.cancel()
        hideTasks.removeValue(forKey: keyId)
        
        // 从数组中移除
        withAnimation(.easeOut(duration: 0.2)) {
            self.keys.removeAll { $0.id == keyId }
        }
    }
    
    // 清理所有按键（用于应用退出时）
    func clearAll() {
        hideTasks.values.forEach { $0.cancel() }
        hideTasks.removeAll()
        keys.removeAll()
    }
    
    @objc private func handleAlwaysShowChanged() {
        if AppSettings.shared.alwaysShow {
            // 取消所有隐藏任务，保留当前按键
            hideTasks.values.forEach { $0.cancel() }
            hideTasks.removeAll()
        } else {
            // 重新为现有按键设置隐藏
            keys.forEach { scheduleHide(for: $0.id) }
        }
    }
}
