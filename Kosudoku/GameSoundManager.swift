//
//  GameSoundManager.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/22/26.
//

import AVFoundation

/// Manages gameplay sound effects using synthesized tones
final class GameSoundManager {
    static let shared = GameSoundManager()
    
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let sampleRate: Double = 44100
    private var isSetUp = false
    
    private init() {
        setUp()
    }
    
    private func setUp() {
        let eng = AVAudioEngine()
        let node = AVAudioPlayerNode()
        eng.attach(node)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        eng.connect(node, to: eng.mainMixerNode, format: format)
        engine = eng
        playerNode = node
        isSetUp = true
    }
    
    /// Play a brief pleasant chime for a correct guess
    func playCorrectSound() {
        guard isSetUp, let buffer = generateChimeBuffer() else { return }
        playBuffer(buffer)
    }
    
    /// Play a short buzzer sound for an incorrect guess
    func playIncorrectSound() {
        guard isSetUp, let buffer = generateBuzzerBuffer() else { return }
        playBuffer(buffer)
    }
    
    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let engine, let playerNode else { return }
        do {
            if !engine.isRunning {
                try engine.start()
            }
            playerNode.stop()
            playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self?.playerNode?.isPlaying == false {
                        self?.engine?.pause()
                    }
                }
            }
            playerNode.play()
        } catch {
            print("Sound playback error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Tone Generation
    
    /// Generates a bright two-tone chime (C6 → E6) with a quick fade-out
    private func generateChimeBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.25
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let freq1: Double = 1047  // C6
        let freq2: Double = 1319  // E6
        let halfFrames = Int(frameCount / 2)
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Envelope: quick attack, smooth decay
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress * progress) * 0.4)
            
            if i < halfFrames {
                // First half: C6
                data[i] = Float(sin(2.0 * .pi * freq1 * t)) * envelope
            } else {
                // Second half: E6
                data[i] = Float(sin(2.0 * .pi * freq2 * t)) * envelope
            }
        }
        
        return buffer
    }
    
    /// Generates a short abrupt buzzer (low frequency with slight noise)
    private func generateBuzzerBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.2
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let freq: Double = 150  // Low buzz frequency
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Sharp cutoff envelope for abrupt feel
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.5)
            
            // Square-ish wave (clipped sine) for harsh buzzer timbre
            let sine = sin(2.0 * .pi * freq * t)
            let clipped = max(-0.6, min(0.6, sine * 1.5))
            data[i] = Float(clipped) * envelope
        }
        
        return buffer
    }
}
