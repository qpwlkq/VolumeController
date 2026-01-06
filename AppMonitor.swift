import Foundation
import AppKit
import Combine

// 定义一个简单的应用数据模型
struct AppRule: Identifiable, Codable, Equatable {
    var id: String { bundleId }
    let name: String
    let bundleId: String
    var safeVolume: Int // 启动时的安全音量
    var isEnabled: Bool // 规则是否启用
}

class AppMonitor: ObservableObject {
    static let shared = AppMonitor()
    
    @Published var monitoredApps: [AppRule] = []
    
    private let defaultsKey = "MonitoredApps"
    
    init() {
        loadRules()
    }
    
    // 开始监听系统应用启动通知
    func startMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
    }
    
    @objc func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else { return }
        
        // 检查是否在监控列表中
        if let rule = monitoredApps.first(where: { $0.bundleId == bundleId }), rule.isEnabled {
            print("Detected monitored app launch: \(appName)")
            applySafeVolume(rule: rule)
        }
    }
    
    // 应用安全音量
    private func applySafeVolume(rule: AppRule) {
        let currentVol = SystemVolume.shared.getVolume()
        
        // 只有当当前音量大于设定的安全音量时才降低
        // 这样如果用户本来就开得很小声，就不会被强制调高
        if currentVol > rule.safeVolume {
            print("Volume too high (\(currentVol)%), lowering to safe volume (\(rule.safeVolume)%) for \(rule.name)")
            SystemVolume.shared.setVolume(rule.safeVolume)
            
            // 发送通知告知用户
            sendNotification(appName: rule.name, oldVol: currentVol, newVol: rule.safeVolume)
        }
    }
    
    private func sendNotification(appName: String, oldVol: Int, newVol: Int) {
        let notification = NSUserNotification()
        notification.title = "🛡️ 音量安全保护已触发"
        notification.subtitle = "\(appName) 已启动"
        notification.informativeText = "系统音量已从 \(oldVol)% 自动降低至 \(newVol)% 以保护您的听力。"
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - Rule Management
    
    func addRule(name: String, bundleId: String, safeVolume: Int = 30) {
        if !monitoredApps.contains(where: { $0.bundleId == bundleId }) {
            let newRule = AppRule(name: name, bundleId: bundleId, safeVolume: safeVolume, isEnabled: true)
            monitoredApps.append(newRule)
            saveRules()
        }
    }
    
    func removeRule(id: String) {
        monitoredApps.removeAll { $0.id == id }
        saveRules()
    }
    
    func updateRule(_ rule: AppRule) {
        if let index = monitoredApps.firstIndex(where: { $0.id == rule.id }) {
            monitoredApps[index] = rule
            saveRules()
        }
    }
    
    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(monitoredApps) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
    
    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([AppRule].self, from: data) {
            monitoredApps = decoded
        } else {
            // 默认添加一些常见的音乐/视频软件
            let defaults = [
                AppRule(name: "QQ音乐", bundleId: "com.tencent.QQMusicMac", safeVolume: 20, isEnabled: true),
                AppRule(name: "网易云音乐", bundleId: "com.netease.163music", safeVolume: 20, isEnabled: true),
                AppRule(name: "Spotify", bundleId: "com.spotify.client", safeVolume: 20, isEnabled: true),
                AppRule(name: "IINA", bundleId: "com.colliderli.iina", safeVolume: 30, isEnabled: true)
            ]
            monitoredApps = defaults
            saveRules()
        }
    }
    
    // 获取系统中所有正在运行的应用（简化版应用获取，实际完整获取所有安装应用比较复杂，这里先用运行中的应用作为候选）
    func getRunningApps() -> [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }
}
