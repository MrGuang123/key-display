import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // 标题
            Text("按键显示设置")
                .font(.title)
                .fontWeight(.bold)
            
            Divider()
            
            // 显示位置设置
            VStack(alignment: .leading, spacing: 12) {
                Text("显示位置")
                    .font(.headline)
                
                Picker("位置", selection: $settings.displayPosition) {
                    ForEach(DisplayPosition.allCases, id: \.self) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // 显示时长设置
            VStack(alignment: .leading, spacing: 12) {
                Text("显示时长")
                    .font(.headline)
                
                HStack {
                    Slider(
                        value: $settings.displayDuration,
                        in: 0.5...5.0,
                        step: 0.5
                    )
                    
                    Text("\(settings.displayDuration, specifier: "%.1f") 秒")
                        .frame(width: 60)
                        .foregroundColor(.secondary)
                }
                
                Text("按键显示后自动消失的时间")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 操作按钮
            HStack(spacing: 16) {
                Button("退出应用") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                
                Button("测试显示") {
                    KeyDisplayManager.shared.showKey("⌘A")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 400, height: 350)
    }
}