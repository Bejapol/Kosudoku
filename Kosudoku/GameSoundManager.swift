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
    
    /// Play a shimmering shield activation sound
    func playShieldSound() {
        guard isSetUp, let buffer = generateShieldBuffer() else { return }
        playBuffer(buffer)
    }
    
    /// Play a soft hint reveal sound
    func playHintSound() {
        guard isSetUp, let buffer = generateHintBuffer() else { return }
        playBuffer(buffer)
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
    
    /// Generates a shimmering ascending tone for shield activation
    private func generateShieldBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.35
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.4)
            // Rising shimmer: two tones sweeping up
            let freq1 = 800.0 + 600.0 * progress
            let freq2 = 1200.0 + 800.0 * progress
            let tone = Float(sin(2.0 * .pi * freq1 * t)) * 0.6 + Float(sin(2.0 * .pi * freq2 * t)) * 0.4
            data[i] = tone * envelope
        }
        return buffer
    }
    
    /// Generates a crystalline descending tone for time freeze
    /// Play a sound effect for a specific emote
    func playEmoteSound(for emote: GameEmote) {
        guard isSetUp else { return }
        let buffer: AVAudioPCMBuffer?
        switch emote {
        case .gg:       buffer = generateGGBuffer()
        case .sweat:    buffer = generateSweatBuffer()
        case .fire:     buffer = generateFireBuffer()
        case .flex:     buffer = generateFlexBuffer()
        case .cool:     buffer = generateCoolBuffer()
        case .mindBlown: buffer = generateMindBlownBuffer()
        }
        guard let buffer else { return }
        playBuffer(buffer)
    }
    
    // MARK: - Emote Sound Generation
    
    /// Quick double-tap percussion for 👏
    private func generateGGBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.35
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            // Two quick taps at t=0 and t=0.15
            let tap1 = t < 0.12 ? Float(exp(-t * 40.0) * 0.4) : Float(0)
            let tap2 = t > 0.15 && t < 0.27 ? Float(exp(-(t - 0.15) * 40.0) * 0.35) : Float(0)
            let freq1 = 1200.0 + 200.0 * progress
            let tone = Float(sin(2.0 * .pi * freq1 * t))
            data[i] = tone * (tap1 + tap2)
        }
        return buffer
    }
    
    /// Descending "whomp" slide for 😅
    private func generateSweatBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.4)
            // Descending frequency from 600 Hz to 150 Hz
            let freq = 600.0 - 450.0 * progress
            let tone = Float(sin(2.0 * .pi * freq * t))
            data[i] = tone * envelope
        }
        return buffer
    }
    
    /// Rising crackle/sizzle for 🔥
    private func generateFireBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.45
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.35)
            // Rising tone with noise for crackle
            let freq = 400.0 + 800.0 * progress
            let tone = Float(sin(2.0 * .pi * freq * t)) * 0.6
            let noise = Float.random(in: -1...1) * 0.4 * Float(progress)
            data[i] = (tone + noise) * envelope
        }
        return buffer
    }
    
    /// Punchy bass hit for 💪
    private func generateFlexBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            // Fast attack, medium decay
            let envelope = Float(exp(-progress * 6.0) * 0.5)
            // Low bass with a punchy transient
            let bass = Float(sin(2.0 * .pi * 80.0 * t))
            let transient = Float(sin(2.0 * .pi * 400.0 * t)) * Float(exp(-progress * 20.0))
            data[i] = (bass * 0.7 + transient * 0.3) * envelope
        }
        return buffer
    }
    
    /// Smooth two-note riff for 😎
    private func generateCoolBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let halfFrames = Int(frameCount / 2)
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.35)
            // E4 → G4 (jazzy minor third)
            let freq = i < halfFrames ? 330.0 : 392.0
            let tone = Float(sin(2.0 * .pi * freq * t))
            let harmonic = Float(sin(2.0 * .pi * freq * 2.0 * t)) * 0.3
            data[i] = (tone + harmonic) * envelope
        }
        return buffer
    }
    
    /// Ascending sweep ending in sparkle burst for 🤯
    private func generateMindBlownBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.4)
            // Ascending sweep from 300 Hz to 2000 Hz
            let freq = 300.0 + 1700.0 * progress * progress
            let sweep = Float(sin(2.0 * .pi * freq * t))
            // Add sparkle in the last 30%
            let sparkle: Float
            if progress > 0.7 {
                let sparkleProgress = (progress - 0.7) / 0.3
                sparkle = Float(sin(2.0 * .pi * 3000.0 * t)) * Float(sparkleProgress) * 0.4
            } else {
                sparkle = 0
            }
            data[i] = (sweep + sparkle) * envelope
        }
        return buffer
    }
    
    /// Generates a gentle ascending chime for hint reveal
    private func generateHintBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let freq1: Double = 880   // A5
        let freq2: Double = 1320  // E6
        let thirdFrames = Int(frameCount / 3)
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress * progress) * 0.35)
            if i < thirdFrames {
                data[i] = Float(sin(2.0 * .pi * freq1 * t)) * envelope
            } else {
                data[i] = Float(sin(2.0 * .pi * freq2 * t)) * envelope
            }
        }
        return buffer
    }
}
