import UIKit

protocol LookPadViewDelegate: AnyObject {
    /// 一次触摸产生的位移（点，屏幕坐标系）
    func lookPad(_ sender: LookPadView, didDrag delta: CGVector)
    func lookPadDidBegin(_ sender: LookPadView)
    func lookPadDidEnd(_ sender: LookPadView)
}

/// 右侧视角触控区：手指拖动 -> 相对位移，交给 JS 转成鼠标 movementX/Y。
final class LookPadView: UIView {

    weak var delegate: LookPadViewDelegate?

    private var origins: [UITouch: CGPoint] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { origins[t] = t.location(in: self) }
        if origins.count == 1 { delegate?.lookPadDidBegin(self) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let prev = origins[t] else { continue }
            let p = t.location(in: self)
            origins[t] = p
            let dx = p.x - prev.x
            let dy = p.y - prev.y
            if dx != 0 || dy != 0 { delegate?.lookPad(self, didDrag: CGVector(dx: dx, dy: dy)) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { origins.removeValue(forKey: t) }
        if origins.isEmpty { delegate?.lookPadDidEnd(self) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { origins.removeValue(forKey: t) }
        if origins.isEmpty { delegate?.lookPadDidEnd(self) }
    }
}
