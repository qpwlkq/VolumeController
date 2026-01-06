import SwiftUI
import AppKit

// 主入口
@main
struct VolumeControllerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// 应用程序代理，管理菜单栏状态
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化应用逻辑
        AppMonitor.shared.startMonitoring()
        
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // 使用系统图标
            button.image = NSImage(systemSymbolName: "speaker.wave.2.circle", accessibilityDescription: "Volume Control")
            button.action = #selector(togglePopover(_:))
        }
        
        // 创建弹出窗口
        popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 500)
        popover.behavior = .transient // 点击外部自动关闭
        
        // 设置 SwiftUI 视图作为内容
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // 每次打开窗口时激活应用，确保窗口在前
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
