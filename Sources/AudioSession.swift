import AVFoundation

/// WKWebView 里的网页音频默认跟随系统静音拨杆，拨杆一开就没声。
/// 把 App 的音频会话切到 .playback 后，网页音频按"媒体播放"处理，不再受静音拨杆影响。
enum AudioSession {

    static func activateForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playback {
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true)
        } catch {
            // 失败时最多是静音拨杆仍然生效，不影响游戏运行
        }
    }
}
