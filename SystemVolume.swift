import Foundation
import CoreAudio
import Combine

// 1. C-style Callback Function
// This function is called by CoreAudio whenever a monitored property changes.
private func audioObjectPropertyListener(
    objectID: AudioObjectID,
    numberAddresses: UInt32,
    addresses: UnsafePointer<AudioObjectPropertyAddress>,
    clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = clientData else { return noErr }
    
    // Convert the raw pointer back to our SystemVolume instance
    let systemVolume = Unmanaged<SystemVolume>.fromOpaque(clientData).takeUnretainedValue()
    
    // CoreAudio calls this on a background thread; dispatch to Main for UI updates
    DispatchQueue.main.async {
        systemVolume.updateVolumeInfo()
    }
    return noErr
}

class SystemVolume: ObservableObject {
    static let shared = SystemVolume()
    
    // Publish changes so SwiftUI views update automatically
    @Published var volume: Int = 0
    @Published var isMutedVal: Bool = false
    
    private var outputDeviceID: AudioObjectID = kAudioObjectUnknown
    
    private init() {
        setupAudioListener()
        // Initial fetch
        updateVolumeInfo()
    }
    
    deinit {
        // Cleanup listeners
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        // Remove default device listener
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, audioObjectPropertyListener, selfPointer)
        
        if outputDeviceID != kAudioObjectUnknown {
            removeDeviceListeners(deviceID: outputDeviceID)
        }
    }
    
    // MARK: - Setup
    
    private func setupAudioListener() {
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        // 1. Listen for changes to the Default Output Device (e.g. user switches to Headphones)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, audioObjectPropertyListener, selfPointer)
        if status != noErr {
            print("Error adding listener for default output device: \(status)")
        }
    }
    
    // MARK: - Device Listeners
    
    private func addDeviceListeners(deviceID: AudioObjectID) {
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        // Listen for Volume changes
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        // Fallback to channel 1 if master channel (0) is not supported
        if !AudioObjectHasProperty(deviceID, &volumeAddress) { volumeAddress.mElement = 1 }
        
        AudioObjectAddPropertyListener(deviceID, &volumeAddress, audioObjectPropertyListener, selfPointer)
        
        // Listen for Mute changes
        var muteAddress = AudioObjectPropertyAddress(
             mSelector: kAudioDevicePropertyMute,
             mScope: kAudioDevicePropertyScopeOutput,
             mElement: kAudioObjectPropertyElementMain
         )
        if !AudioObjectHasProperty(deviceID, &muteAddress) { muteAddress.mElement = 1 }
        
        AudioObjectAddPropertyListener(deviceID, &muteAddress, audioObjectPropertyListener, selfPointer)
    }
    
    private func removeDeviceListeners(deviceID: AudioObjectID) {
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(deviceID, &volumeAddress) { volumeAddress.mElement = 1 }
        AudioObjectRemovePropertyListener(deviceID, &volumeAddress, audioObjectPropertyListener, selfPointer)
        
        var muteAddress = AudioObjectPropertyAddress(
             mSelector: kAudioDevicePropertyMute,
             mScope: kAudioDevicePropertyScopeOutput,
             mElement: kAudioObjectPropertyElementMain
         )
        if !AudioObjectHasProperty(deviceID, &muteAddress) { muteAddress.mElement = 1 }
        AudioObjectRemovePropertyListener(deviceID, &muteAddress, audioObjectPropertyListener, selfPointer)
    }
    
    // MARK: - Update Logic
    
    func updateVolumeInfo() {
        // 1. Get current default output device
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        
        if status == noErr {
            // If device changed, re-attach listeners
            if deviceID != outputDeviceID {
                if outputDeviceID != kAudioObjectUnknown {
                    removeDeviceListeners(deviceID: outputDeviceID)
                }
                if deviceID != kAudioObjectUnknown {
                    addDeviceListeners(deviceID: deviceID)
                }
                outputDeviceID = deviceID
            }
        }
        
        guard outputDeviceID != kAudioObjectUnknown else { return }
        
        // 2. Get Volume (Scalar 0.0 - 1.0)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(outputDeviceID, &volumeAddress) { volumeAddress.mElement = 1 }
        
        var volumeScalar: Float32 = 0
        size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectGetPropertyData(outputDeviceID, &volumeAddress, 0, nil, &size, &volumeScalar)
        
        let newVol = Int(volumeScalar * 100)
        if self.volume != newVol {
             self.volume = newVol
        }
        
        // 3. Get Mute
        var muteAddress = AudioObjectPropertyAddress(
             mSelector: kAudioDevicePropertyMute,
             mScope: kAudioDevicePropertyScopeOutput,
             mElement: kAudioObjectPropertyElementMain
         )
        if !AudioObjectHasProperty(outputDeviceID, &muteAddress) { muteAddress.mElement = 1 }
        
        var muted: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(outputDeviceID, &muteAddress, 0, nil, &size, &muted)
        
        self.isMutedVal = (muted != 0)
    }
    
    // MARK: - Public API
    
    func getVolume() -> Int {
        return volume
    }
    
    func setVolume(_ volume: Int) {
        guard outputDeviceID != kAudioObjectUnknown else { return }
        
        let clamped = max(0, min(100, volume))
        var volumeScalar = Float32(clamped) / 100.0
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(outputDeviceID, &volumeAddress) { volumeAddress.mElement = 1 }
        
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(outputDeviceID, &volumeAddress, 0, nil, size, &volumeScalar)
        
        // Update local state immediately for responsiveness
        self.volume = clamped
    }
    
    func isMuted() -> Bool {
        return isMutedVal
    }
    
    func setMute(_ muted: Bool) {
        guard outputDeviceID != kAudioObjectUnknown else { return }
        
        var val: UInt32 = muted ? 1 : 0
        var muteAddress = AudioObjectPropertyAddress(
             mSelector: kAudioDevicePropertyMute,
             mScope: kAudioDevicePropertyScopeOutput,
             mElement: kAudioObjectPropertyElementMain
         )
        if !AudioObjectHasProperty(outputDeviceID, &muteAddress) { muteAddress.mElement = 1 }
        
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(outputDeviceID, &muteAddress, 0, nil, size, &val)
        
        self.isMutedVal = muted
    }
}
