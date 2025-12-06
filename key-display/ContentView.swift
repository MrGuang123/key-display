import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                
                SectionCard(title: "显示位置", description: "选择浮层预设位置。拖拽窗口可自定义位置，切换预设会重置。") {
                    Picker("位置", selection: $settings.displayPosition) {
                        ForEach(DisplayPosition.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                SectionCard(title: "显示时长", description: "按键显示后自动消失的时间") {
                    HStack {
                        Slider(
                            value: $settings.displayDuration,
                            in: 0.5...5.0,
                            step: 0.5
                        )
                        Text("\(settings.displayDuration, specifier: "%.1f") 秒")
                            .frame(width: 70, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                }
                
                SectionCard(title: "字体大小", description: "调整按键气泡的文字大小") {
                    HStack {
                        Slider(
                            value: $settings.fontSize,
                            in: 8...64,
                            step: 1
                        )
                        Text("\(Int(settings.fontSize)) pt")
                            .frame(width: 70, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                }
                
                SectionCard(title: "常驻显示", description: "开启后按键不会自动消失，最多保留三个按键，继续按会替换最旧的。") {
                    Toggle(isOn: $settings.alwaysShow) {
                        Text("开启常驻显示")
                    }
                    .toggleStyle(.switch)
                }
                
                SectionCard(title: "相同按键策略", description: "合并相同按键并延长显示时间。关闭后会像现在一样连续弹出多个气泡。") {
                    Toggle(isOn: $settings.mergeDuplicates) {
                        Text("合并相同按键并延长显示时间")
                    }
                    .toggleStyle(.switch)
                }
                
                HStack(spacing: 12) {
                    Button("测试显示") {
                        KeyDisplayManager.shared.showKey("⌘A")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("退出应用") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(width: 420, height: 520)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("按键显示设置")
                .font(.title2)
                .fontWeight(.bold)
            Text("位置、样式和行为")
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 4)
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let description: String?
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
