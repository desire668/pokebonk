import Foundation

/// WebAudio 解锁：iOS 上 AudioContext 在没有用户手势前会是 suspended 状态，
/// 游戏如果不主动 resume 就一直没声音。这里把页面创建的 AudioContext 记下来，
/// 在首次触摸/点击时统一 resume 一次。只做音频解锁，不碰任何游戏逻辑。
enum AudioUnlock {

    static let scriptSource: String = """
    (function () {
      if (window.__pbAudioUnlock) { return; }
      window.__pbAudioUnlock = true;

      var contexts = [];
      var userActivated = false;
      var activationEvents = ['touchend', 'pointerup', 'click'];
      var eventOptions = { capture: true, passive: true };

      function resumeContext(ctx) {
        if (ctx.state && ctx.state !== 'running' && ctx.resume) {
          try { ctx.resume(); } catch (e) {}
        }
      }

      function wrap(name) {
        var Orig = window[name];
        if (!Orig || Orig.__pbWrapped) { return; }
        var Wrapped = function (opts) {
          var ctx = new Orig(opts);
          contexts.push(ctx);
          if (userActivated) { resumeContext(ctx); }
          return ctx;
        };
        Wrapped.prototype = Orig.prototype;
        Wrapped.__pbWrapped = true;
        try { window[name] = Wrapped; } catch (e) {}
      }
      wrap('AudioContext');
      wrap('webkitAudioContext');

      function unlock() {
        userActivated = true;
        if (contexts.length === 0) { return; }
        for (var i = 0; i < contexts.length; i++) {
          resumeContext(contexts[i]);
        }
        for (var i = 0; i < activationEvents.length; i++) {
          document.removeEventListener(activationEvents[i], unlock, eventOptions);
        }
      }

      for (var i = 0; i < activationEvents.length; i++) {
        document.addEventListener(activationEvents[i], unlock, eventOptions);
      }

      document.addEventListener('visibilitychange', function () {
        if (document.visibilityState === 'visible') {
          for (var i = 0; i < contexts.length; i++) {
            resumeContext(contexts[i]);
          }
        }
      }, eventOptions);
    })();
    """
}
