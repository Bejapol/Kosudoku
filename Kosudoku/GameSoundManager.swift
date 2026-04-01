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
    
    /// Play a celebratory sound (applause + whistle) for winning
    func playWinSound() {
        guard isSetUp, let buffer = generateWinBuffer() else { return }
        playBuffer(buffer)
    }
    
    /// Play a crowd laughing sound for losing
    func playLoseSound() {
        guard isSetUp, let buffer = generateLoseBuffer() else { return }
        playBuffer(buffer)
    }
    
    /// Play a short click sound for notifications
    func playNotificationSound() {
        guard isSetUp, let buffer = generateNotificationClickBuffer() else { return }
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
    
    /// Generates applause (noise bursts) layered with a rising whistle
    private func generateWinBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 2.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration
            
            // Applause: rapid random bursts shaped by an envelope
            let clapEnvelope = Float(sin(Double.pi * progress) * 0.3)
            // Rapid amplitude modulation simulates individual "claps"
            let clapMod = Float(abs(sin(t * 40.0 * Double.pi))) // ~20 claps/sec
            let noise = Float.random(in: -1...1) * clapEnvelope * clapMod
            
            // Whistle: sine that sweeps from ~1200 Hz to ~2400 Hz
            let whistleFreq = 1200.0 + 1200.0 * progress
            let whistleEnv: Float
            if progress < 0.1 {
                whistleEnv = Float(progress / 0.1) * 0.25 // fade in
            } else if progress > 0.7 {
                whistleEnv = Float((1.0 - progress) / 0.3) * 0.25 // fade out
            } else {
                whistleEnv = 0.25
            }
            // Add slight vibrato for realism
            let vibrato = sin(t * 6.0 * Double.pi) * 30.0
            let whistle = Float(sin(2.0 * Double.pi * (whistleFreq + vibrato) * t)) * whistleEnv
            
            data[i] = noise + whistle
        }
        
        return buffer
    }
    
    /// Generates a rhythmic "ha-ha-ha" laughing sound
    private func generateLoseBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 1.8
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        // Laugh rhythm: ~5 "ha" bursts per second
        let laughRate = 5.0
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration
            
            // Overall envelope: fade in then out
            let overallEnv: Float
            if progress < 0.05 {
                overallEnv = Float(progress / 0.05)
            } else if progress > 0.75 {
                overallEnv = Float((1.0 - progress) / 0.25)
            } else {
                overallEnv = 1.0
            }
            
            // Rhythmic bursts — each "ha" is a quick ramp up/down
            let laughPhase = t * laughRate
            let burstPhase = laughPhase - floor(laughPhase) // 0..1 within each burst
            let burstEnv: Float
            if burstPhase < 0.15 {
                burstEnv = Float(burstPhase / 0.15)
            } else if burstPhase < 0.5 {
                burstEnv = Float(1.0 - (burstPhase - 0.15) / 0.35)
            } else {
                burstEnv = 0
            }
            
            // Voice-like tone: fundamental ~250 Hz with harmonics
            let fundamental = 250.0 + 20.0 * sin(t * 3.0 * Double.pi) // slight pitch wobble
            let h1 = Float(sin(2.0 * Double.pi * fundamental * t))
            let h2 = Float(sin(2.0 * Double.pi * fundamental * 2.0 * t)) * 0.5
            let h3 = Float(sin(2.0 * Double.pi * fundamental * 3.0 * t)) * 0.3
            let voice = (h1 + h2 + h3) / 1.8
            
            // Add a small amount of noise for breathiness
            let breath = Float.random(in: -1...1) * 0.1
            
            data[i] = (voice + breath) * burstEnv * overallEnv * 0.4
        }
        
        return buffer
    }
    
    /// Generates a short, soft click/pop for notification banners
    private func generateNotificationClickBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.08
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        // A quick "pop" — short sine burst at ~880 Hz with rapid decay
        let freq: Double = 880
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            // Fast exponential decay
            let envelope = Float(exp(-progress * 8.0) * 0.35)
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
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
