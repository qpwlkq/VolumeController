import SwiftUI

struct ContentView: View {
    @State private var systemVolume: Double = 0
    @ObservedObject var appMonitor = AppMonitor.shared
    @State private var showAddAppSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部：系统全局音量控制
            VStack(alignment: .leading, spacing: 8) {
                Text("系统总音量")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: systemVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                    
                    Slider(value: $systemVolume, in: 0...100, onEditingChanged: { _ in
                        SystemVolume.shared.setVolume(Int(systemVolume))
                    })
                    
                    Text("\(Int(systemVolume))%")
                        .frame(width: 40, alignment: .trailing)
                        .font(.monospacedDigit(.body)())
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 中间：应用规则列表
            List {
                Section(header: Text("应用启动安全音量锁")) {
                    if appMonitor.monitoredApps.isEmpty {
                        Text("暂无监控应用")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach($appMonitor.monitoredApps) { $rule in
                            AppRuleRow(rule: $rule, onDelete: {
                                appMonitor.removeRule(id: rule.id)
                            })
                        }
                        .onDelete { indices in
                            indices.forEach { index in
                                let rule = appMonitor.monitoredApps[index]
                                appMonitor.removeRule(id: rule.id)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetListStyle())
            
            Divider()
            
            // 底部：操作按钮
            HStack {
                Button(action: {
                    showAddAppSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加应用规则")
                    }
                }
                .buttonStyle(BorderedButtonStyle())
                
                Spacer()
                
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 320, height: 480)
        .onAppear {
            updateVolume()
            // 定时刷新音量显示（因为用户可能通过键盘调节音量）
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateVolume()
            }
        }
        .sheet(isPresented: $showAddAppSheet) {
            AddAppSheet(isPresented: $showAddAppSheet)
        }
    }
    
    func updateVolume() {
        let vol = Double(SystemVolume.shared.getVolume())
        if abs(vol - systemVolume) > 1 { // 简单的防抖动
            systemVolume = vol
        }
    }
}

// 单个应用规则行视图
struct AppRuleRow: View {
    @Binding var rule: AppRule
    var onDelete: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("", isOn: $rule.isEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: rule.isEnabled) { _ in
                        AppMonitor.shared.updateRule(rule)
                    }
                
                Text(rule.name)
                    .font(.headline)
                
                Spacer()
                
                Text("限: \(rule.safeVolume)%")
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Button(action: {
                    onDelete?()
                }) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .opacity(0.7)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
            }
            
            HStack {
                Text("启动限制:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: $rule.safeVolumeDouble,
                    in: 0...100,
                    step: 1,
                    onEditingChanged: { isEditing in
                        // 只在编辑结束时更新规则，避免频繁IO操作
                        if !isEditing {
                            print("Updated safeVolume for \(rule.name) to \(rule.safeVolume)")
                            AppMonitor.shared.updateRule(rule)
                        }
                    }
                )
                .disabled(!rule.isEnabled)
            }
        }
        .padding(.vertical, 4)
    }
}

// 添加应用弹窗
struct AddAppSheet: View {
    @Binding var isPresented: Bool
    @State private var runningApps: [NSRunningApplication] = []
    
    var body: some View {
        VStack {
            Text("选择要监控的应用")
                .font(.headline)
                .padding()
            
            List(runningApps, id: \.bundleIdentifier) { app in
                Button(action: {
                    if let name = app.localizedName, let id = app.bundleIdentifier {
                        AppMonitor.shared.addRule(name: name, bundleId: id)
                        isPresented = false
                    }
                }) {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(app.localizedName ?? "Unknown")
                        Spacer()
                        Image(systemName: "plus.circle")
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Button("取消") {
                isPresented = false
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .onAppear {
            runningApps = AppMonitor.shared.getRunningApps()
        }
    }
}
