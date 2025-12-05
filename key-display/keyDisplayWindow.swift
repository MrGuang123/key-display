import SwiftUI
import AppKit
import Combine

// 按键项结构
struct KeyItem: Identifiable {
    let id = UUID()
    let name: String
    let timestamp: Date
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
    
    func frame(in screenSize: CGSize, windowSize: CGSize) -> CGRect {
        let margin: CGFloat = 20
        let x: CGFloat
        let y: CGFloat
        
        switch self {
        case .topLeft:
            x = margin
            y = screenSize.height - windowSize.height - margin
        case .topCenter:
            x = (screenSize.width - windowSize.width) / 2
            y = screenSize.height - windowSize.height - margin
        case .topRight:
            x = screenSize.width - windowSize.width - margin
            y = screenSize.height - windowSize.height - margin
        case .bottomLeft:
            x = margin
            y = margin
        case .bottomCenter:
            x = (screenSize.width - windowSize.width) / 2
            y = margin
        case .bottomRight:
            x = screenSize.width - windowSize.width - margin
            y = margin
        case .center:
            x = (screenSize.width - windowSize.width) / 2
            y = (screenSize.height - windowSize.height) / 2
        }
        
        return CGRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }
}

class KeyDisplayWindow: NSWindow {
    static var shared: KeyDisplayWindow?
    
    init() {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let windowSize = CGSize(width: 500, height: 80)
        let position = AppSettings.shared.displayPosition
        let frame = position.frame(in: screenSize, windowSize: windowSize)
        
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
        self.ignoresMouseEvents = true
        self.acceptsMouseMovedEvents = false
        
        let contentView = KeyDisplayView()
        self.contentView = NSHostingView(rootView: contentView)
        
        KeyDisplayWindow.shared = self
        
        // 监听设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updatePosition),
            name: .displayPositionChanged,
            object: nil
        )
    }
    
    @objc private func updatePosition() {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let windowSize = CGSize(width: 500, height: 80)
        let position = AppSettings.shared.displayPosition
        let newFrame = position.frame(in: screenSize, windowSize: windowSize)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().setFrame(newFrame, display: true)
        }
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
}

struct KeyDisplayView: View {
    @StateObject private var keyDisplayManager = KeyDisplayManager.shared
    
    var body: some View {
        Group {
            if !keyDisplayManager.keys.isEmpty {
                HStack(spacing: 12) {
                    ForEach(keyDisplayManager.keys) { keyItem in
                        KeyItemView(keyName: keyItem.name)
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)  // 右对齐优化
            } else {
                Color.clear
                    .frame(width: 500, height: 80)
            }
        }
        .frame(width: 500, height: 80)
        .animation(.easeOut(duration: 0.2), value: keyDisplayManager.keys.map { $0.id })
    }
}

// 单个按键视图
struct KeyItemView: View {
    let keyName: String
    
    var body: some View {
        let backgroundColor = ColorHelper.colorForKey(keyName)
        let textColor = ColorHelper.contrastColor(for: backgroundColor)
        
        HStack(spacing: 8) {
            Text(keyName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
    
    @Published var displayPosition: DisplayPosition {
        didSet {
            UserDefaults.standard.set(displayPosition.rawValue, forKey: displayPositionKey)
            NotificationCenter.default.post(name: .displayPositionChanged, object: nil)
        }
    }
    
    @Published var displayDuration: Double {
        didSet {
            UserDefaults.standard.set(displayDuration, forKey: displayDurationKey)
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
    
    func showKey(_ keyName: String) {
        DispatchQueue.main.async {
            // 创建新的按键项
            let newKey = KeyItem(name: keyName, timestamp: Date())
            
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
}