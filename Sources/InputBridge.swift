import Foundation

enum InputBridge {

    /// 读取 bundle 里的 InputBridge.js；缺失时退化成空实现，避免崩溃。
    static let scriptSource: String = {
        guard let url = Bundle.main.url(forResource: "InputBridge", withExtension: "js"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return fallbackSource
        }
        return text
    }()

    private static let fallbackSource = """
    window.__pb={move:function(){},look:function(){},lookEnd:function(){},setKey:function(){},\
    tapKey:function(){},setSensitivity:function(){},setInvertY:function(){},setLookMode:function(){},\
    ready:function(){},reset:function(){},getState:function(){return{};}};
    """
}
