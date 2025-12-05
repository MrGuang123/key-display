import SwiftUI
import AppKit

@main
struct key_displayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 移除 Settings Scene，改用自定义窗口
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyDisplayWindow: KeyDisplayWindow?
    private var keyboardMonitor: KeyboardMonitor?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("应用启动中...")
        
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 创建菜单栏图标
        setupMenuBar()
        
        // 创建显示窗口
        keyDisplayWindow = KeyDisplayWindow()
        keyDisplayWindow?.orderFront(nil)
        print("窗口已创建: \(keyDisplayWindow?.frame ?? .zero)")
        
        // 启动键盘监听
        keyboardMonitor = KeyboardMonitor()
        keyboardMonitor?.onKeyEvent = { keyName, isKeyDown in
            print("按键事件: \(keyName), isKeyDown: \(isKeyDown)")
            if isKeyDown {
                DispatchQueue.main.async {
                    KeyDisplayManager.shared.showKey(keyName)
                }
            }
        }
        keyboardMonitor?.startMonitoring()
        print("键盘监听已启动")
    }
    
    func setupMenuBar() {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // 设置图标
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "按键显示")
            button.image?.isTemplate = true
            button.toolTip = "按键显示"
            
            // 点击事件
            button.action = #selector(toggleSettings)
            button.target = self
        }
    }
    
    @objc func toggleSettings() {
        if let window = settingsWindow, window.isVisible {
            window.close()
        } else {
            openSettings()
        }
    }
    
    func openSettings() {
        if settingsWindow == nil {
            let settingsView = ContentView()
            let hostingView = NSHostingView(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.title = "按键显示设置"
            settingsWindow?.contentView = hostingView
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.delegate = self
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor?.stopMonitoring()
        KeyDisplayManager.shared.clearAll()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时不需要清理，保持引用以便下次打开
    }
}