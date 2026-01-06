import Foundation
import AppKit

class SystemVolume {
    static let shared = SystemVolume()
    
    // 获取当前系统音量 (0-100)
    func getVolume() -> Int {
        // 使用 AppleScript 获取当前系统输出音量
        let scriptSource = "output volume of (get volume settings)"
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output = scriptObject.executeAndReturnError(&error)
            return Int(output.int32Value)
        }
        return 0
    }
    
    // 设置系统音量 (0-100)
    func setVolume(_ volume: Int) {
        // 限制音量范围
        let clampedVolume = max(0, min(100, volume))
        let scriptSource = "set volume output volume \(clampedVolume)"
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    // 检查是否静音
    func isMuted() -> Bool {
        let scriptSource = "output muted of (get volume settings)"
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output = scriptObject.executeAndReturnError(&error)
            return output.booleanValue
        }
        return false
    }
    
    // 设置静音状态
    func setMute(_ muted: Bool) {
        let scriptSource = "set volume output muted \(muted)"
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            scriptObject.executeAndReturnError(&error)
        }
    }
}
