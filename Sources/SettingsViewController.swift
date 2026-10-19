import UIKit

final class SettingsViewController: UIViewController {

    var onChange: ((_ sensitivity: Float, _ invertY: Bool, _ lookMode: String) -> Void)?
    var onReload: (() -> Void)?

    private let initialSensitivity: Float
    private let initialInvertY: Bool
    private let initialLookMode: String

    private let slider = UISlider()
    private let valueLabel = UILabel()
    private let invertSwitch = UISwitch()
    private let modeControl = UISegmentedControl(items: ["鼠标模拟", "触屏拖拽"])

    init(sensitivity: Float, invertY: Bool, lookMode: String) {
        self.initialSensitivity = sensitivity
        self.initialInvertY = invertY
        self.initialLookMode = lookMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.13, green: 0.12, blue: 0.20, alpha: 1.0)
        preferredContentSize = CGSize(width: 340, height: 320)

        slider.minimumValue = 0.3
        slider.maximumValue = 2.5
        slider.value = initialSensitivity
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        valueLabel.text = String(format: "%.2f", initialSensitivity)
        valueLabel.textColor = .white
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        valueLabel.textAlignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 46).isActive = true

        invertSwitch.isOn = initialInvertY
        invertSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)

        modeControl.selectedSegmentIndex = initialLookMode == "touch" ? 1 : 0
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [
            row("视角灵敏度", accessory: sliderRow()),
            row("反转 Y 轴", accessory: invertSwitch),
            row("视角方案", accessory: modeControl),
            tipLabel(),
            reloadRow(),
            doneRow()
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18)
        ])
    }

    // MARK: - 行

    private func row(_ title: String, accessory: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        accessory.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        container.addSubview(accessory)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            accessory.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            accessory.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 36)
        ])
        return container
    }

    private func sliderRow() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(slider)
        container.addSubview(valueLabel)
        NSLayoutConstraint.activate([
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -10),
            slider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 190)
        ])
        return container
    }

    private func tipLabel() -> UIView {
        let label = UILabel()
        label.text = "视角转不动时，把「视角方案」切到「触屏拖拽」再试。"
        label.textColor = UIColor(white: 1.0, alpha: 0.6)
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        return label
    }

    private func reloadRow() -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("重新加载游戏", for: .normal)
        button.setTitleColor(.systemOrange, for: .normal)
        button.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        return button
    }

    private func doneRow() -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("完成", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return button
    }

    // MARK: - 事件

    @objc private func sliderChanged() {
        valueLabel.text = String(format: "%.2f", slider.value)
        notify()
    }

    @objc private func switchChanged() { notify() }

    @objc private func modeChanged() { notify() }

    private func notify() {
        let mode = modeControl.selectedSegmentIndex == 1 ? "touch" : "mouse"
        onChange?(slider.value, invertSwitch.isOn, mode)
    }

    @objc private func reloadTapped() {
        dismiss(animated: true) { [weak self] in self?.onReload?() }
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
