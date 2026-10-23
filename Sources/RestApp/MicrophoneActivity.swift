import CoreAudio
import Foundation

/// Reads only Core Audio's input-running flags. Never opens an input stream,
/// records audio, reads app names, or asks for microphone capture permission.
struct MicrophoneActivity {
    static func sample() -> Bool? {
        guard #available(macOS 14.2, *) else { return nil }
        var address = AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyProcessObjectList,
            mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system,&address,0,nil,&size) == noErr else { return nil }
        guard size > 0 else { return false }
        var processes = [AudioObjectID](repeating:0,count:Int(size)/MemoryLayout<AudioObjectID>.size)
        let result = processes.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(system,&address,0,nil,&size,$0.baseAddress!)
        }
        guard result == noErr else { return nil }
        var failed = false
        for process in processes.prefix(Int(size)/MemoryLayout<AudioObjectID>.size) {
            var property = AudioObjectPropertyAddress(mSelector:kAudioProcessPropertyIsRunningInput,
                mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
            var value: UInt32 = 0, bytes = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(process,&property,0,nil,&bytes,&value) == noErr {
                if value != 0 { return true }
            } else { failed = true }
        }
        return failed ? nil : false
    }
}
