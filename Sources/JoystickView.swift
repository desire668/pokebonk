import UIKit

protocol JoystickViewDelegate: AnyObject {
    /// x 右为正，y 上为正，取值 -1 ~ 1
    func joystick(_ sender: JoystickView, didChange vector: CGVector)
    func joystickDidRelease(_ sender: JoystickView)
}

/// 浮动虚拟摇杆：手指落在左侧区域任意位置，摇杆就在那里出现。
final class JoystickView: UIView {

    weak var delegate: JoystickViewDelegate?

    private let baseRadius: CGFloat = 62
    private let thumbRadius: CGFloat = 27
    private let baseLayer = CAShapeLayer()
    private let thumbLayer = CAShapeLayer()

    private var tracking: UITouch?
    private var originPoint: CGPoint = .zero
    private var currentVector: CGVector = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        isOpaque = false

        baseLayer.fillColor = UIColor(white: 0.06, alpha: 0.30).cgColor
        baseLayer.strokeColor = UIColor(white: 1.0, alpha: 0.42).cgColor
        baseLayer.lineWidth = 2.0
        layer.addSublayer(baseLayer)

        thumbLayer.fillColor = UIColor(white: 1.0, alpha: 0.62).cgColor
        thumbLayer.strokeColor = UIColor(white: 1.0, alpha: 0.85).cgColor
        thumbLayer.lineWidth = 2.0
        layer.addSublayer(thumbLayer)

        baseLayer.opacity = 0
        thumbLayer.opacity = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 绘制

    private func updateLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseLayer.path = UIBezierPath(arcCenter: originPoint,
                                      radius: baseRadius,
                                      startAngle: 0,
                                      endAngle: .pi * 2,
                                      clockwise: true).cgPath
        let thumbCenter = CGPoint(x: originPoint.x + currentVector.dx * baseRadius,
                                  y: originPoint.y - currentVector.dy * baseRadius)
        thumbLayer.path = UIBezierPath(arcCenter: thumbCenter,
                                       radius: thumbRadius,
                                       startAngle: 0,
                                       endAngle: .pi * 2,
                                       clockwise: true).cgPath
        CATransaction.commit()
    }

    private func setActive(_ active: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseLayer.opacity = active ? 1 : 0
        thumbLayer.opacity = active ? 1 : 0
        CATransaction.commit()
    }

    // MARK: - 触摸

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracking == nil, let touch = touches.first else { return }
        let p = touch.location(in: self)
        let inset = baseRadius + 8
        originPoint = CGPoint(x: min(max(p.x, inset), bounds.width - inset),
                              y: min(max(p.y, inset), bounds.height - inset))
        tracking = touch
        currentVector = .zero
        updateLayers()
        setActive(true)
        delegate?.joystick(self, didChange: .zero)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tracking = tracking, touches.contains(tracking) else { return }
        apply(touch: tracking)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tracking = tracking, touches.contains(tracking) else { return }
        finish()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tracking = tracking, touches.contains(tracking) else { return }
        finish()
    }

    private func apply(touch: UITouch) {
        let p = touch.location(in: self)
        var dx = p.x - originPoint.x
        var dy = p.y - originPoint.y
        let len = hypot(dx, dy)
        if len > baseRadius {
            dx = dx / len * baseRadius
            dy = dy / len * baseRadius
        }
        let nx = dx / baseRadius
        let ny = dy / baseRadius
        // 死区
        let mag = hypot(nx, ny)
        let vector = mag < 0.16 ? .zero : CGVector(dx: nx, dy: -ny)
        if vector.dx != currentVector.dx || vector.dy != currentVector.dy {
            currentVector = vector
            updateLayers()
            delegate?.joystick(self, didChange: vector)
        }
    }

    private func finish() {
        tracking = nil
        currentVector = .zero
        setActive(false)
        delegate?.joystick(self, didChange: .zero)
        delegate?.joystickDidRelease(self)
    }
}
