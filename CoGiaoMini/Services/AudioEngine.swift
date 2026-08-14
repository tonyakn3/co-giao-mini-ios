import Foundation
import AVFoundation

final class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24_000, channels: 1, interleaved: false)!
    var onPCM16k: ((Data) -> Void)?

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setPreferredSampleRate(48_000)
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard let converter = AVAudioConverter(from: inputFormat, to: target) else { return }

            let ratio = 16_000.0 / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
            guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

            var error: NSError?
            var used = false
            converter.convert(to: converted, error: &error) { _, status in
                if used {
                    status.pointee = .noDataNow
                    return nil
                }
                used = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, converted.frameLength > 0,
                  let channel = converted.floatChannelData?[0] else { return }

            var samples = [Int16](repeating: 0, count: Int(converted.frameLength))
            for i in 0..<samples.count {
                let v = max(-1, min(1, channel[i]))
                samples[i] = Int16(v * Float(Int16.max))
            }
            self.onPCM16k?(Data(bytes: samples, count: samples.count * MemoryLayout<Int16>.size))
        }

        try engine.start()
        player.play()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        player.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func playPCM24k(_ data: Data) {
        let sampleCount = data.count / MemoryLayout<Int16>.size
        guard sampleCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        data.withUnsafeBytes { raw in
            guard let src = raw.bindMemory(to: Int16.self).baseAddress,
                  let dst = buffer.int16ChannelData?[0] else { return }
            dst.assign(from: src, count: sampleCount)
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    func interruptPlayback() {
        player.stop()
        player.play()
    }
}
