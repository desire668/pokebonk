import UIKit

/// 按住 = keydown，松开 = keyup 的动作按钮（跳跃 / 滑行 / 大招 / 互动）。
final class ActionButton: UIControl {

    let code: String
    let title: String
    private let label = UILabel()
    private let shapeLayer = CAShapeLayer()

    init(code: String, title: String) {
        self.code = code
        self.title = title
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false

        shapeLayer.fillColor = UIColor(white: 0.06, alpha: 0.34).cgColor
        shapeLayer.strokeColor = UIColor(white: 1.0, alpha: 0.5).cgColor
        shapeLayer.lineWidth = 2
        layer.addSublayer(shapeLayer)

        label.text = title
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = UIColor(white: 1.0, alpha: 0.9)
        label.isUserInteractionEnabled = false
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).cgPath
        label.frame = bounds
    }

    override var isHighlighted: Bool {
        didSet {
            shapeLayer.fillColor = isHighlighted
                ? UIColor(white: 1.0, alpha: 0.35).cgColor
                : UIColor(white: 0.06, alpha: 0.34).cgColor
        }
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        isHighlighted = true
        sendActions(for: .touchDown)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isHighlighted = false
        if let touch, bounds.contains(touch.location(in: self)) {
            sendActions(for: .touchUpInside)
        } else {
            sendActions(for: .touchUpOutside)
        }
    }

    override func cancelTracking(with event: UIEvent?) {
        isHighlighted = false
        sendActions(for: .touchCancel)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // 把可点区域放大一圈，手指更容易按到
        let expand = bounds.insetBy(dx: -8, dy: -8)
        return expand.contains(point)
    }
}
