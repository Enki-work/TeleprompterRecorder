//
//  PrompterSettingsViewController.swift
//  TeleprompterRecorder
//

import UIKit

final class PrompterSettingsViewController: UIViewController {

    // MARK: - UI elements
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Blur
    private let blurSlider = UISlider()
    private let blurValueLabel = UILabel()

    // Font size
    private let fontSizeSlider = UISlider()
    private let fontSizeValueLabel = UILabel()

    // Colors
    private let bgColorSwatch = UIView()
    private let textColorSwatch = UIView()

    private var pendingColorTarget: ColorTarget = .background
    private enum ColorTarget { case background, text }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        title = "プロンプター設定"
        setupNavBar()
        buildUI()
        loadCurrentValues()
    }

    // MARK: - Navigation
    private func setupNavBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.10, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemCyan

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "閉じる", style: .plain, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "リセット", style: .plain, target: self, action: #selector(resetTapped))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func resetTapped() {
        let alert = UIAlertController(title: "設定をリセット",
                                      message: "すべての設定を初期値に戻しますか？",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "リセット", style: .destructive) { [weak self] _ in
            self?.applyReset()
        })
        present(alert, animated: true)
    }

    private func applyReset() {
        let d = UserDefaults.standard
        d.setPrompterBlurIntensity(0.7)
        d.setPrompterFontSize(21)
        d.removeObject(forKey: UserDefaults.prompterBgColorKey)
        d.removeObject(forKey: UserDefaults.prompterTextColorKey)
        loadCurrentValues()
        notifyChange()
    }

    // MARK: - Build UI
    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // ── Section: Blur ─────────────────────────────────────────────────────
        contentStack.addArrangedSubview(sectionHeader("ぼかし強度"))
        let blurCard = makeCard()
        blurSlider.minimumValue = 0
        blurSlider.maximumValue = 1
        blurSlider.tintColor = .systemCyan
        blurSlider.addTarget(self, action: #selector(blurSliderChanged), for: .valueChanged)
        blurValueLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        blurValueLabel.font = .systemFont(ofSize: 13)
        let blurRow = sliderRow(label: blurValueLabel, slider: blurSlider)
        blurCard.addSubview(blurRow)
        NSLayoutConstraint.activate([
            blurRow.topAnchor.constraint(equalTo: blurCard.topAnchor, constant: 14),
            blurRow.leadingAnchor.constraint(equalTo: blurCard.leadingAnchor, constant: 16),
            blurRow.trailingAnchor.constraint(equalTo: blurCard.trailingAnchor, constant: -16),
            blurRow.bottomAnchor.constraint(equalTo: blurCard.bottomAnchor, constant: -14),
        ])
        contentStack.addArrangedSubview(blurCard)
        contentStack.setCustomSpacing(20, after: blurCard)

        // ── Section: Font Size ────────────────────────────────────────────────
        contentStack.addArrangedSubview(sectionHeader("文字サイズ"))
        let fontCard = makeCard()
        fontSizeSlider.minimumValue = 12
        fontSizeSlider.maximumValue = 60
        fontSizeSlider.tintColor = .systemCyan
        fontSizeSlider.addTarget(self, action: #selector(fontSizeSliderChanged), for: .valueChanged)
        fontSizeValueLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        fontSizeValueLabel.font = .systemFont(ofSize: 13)
        let fontRow = sliderRow(label: fontSizeValueLabel, slider: fontSizeSlider)
        fontCard.addSubview(fontRow)
        NSLayoutConstraint.activate([
            fontRow.topAnchor.constraint(equalTo: fontCard.topAnchor, constant: 14),
            fontRow.leadingAnchor.constraint(equalTo: fontCard.leadingAnchor, constant: 16),
            fontRow.trailingAnchor.constraint(equalTo: fontCard.trailingAnchor, constant: -16),
            fontRow.bottomAnchor.constraint(equalTo: fontCard.bottomAnchor, constant: -14),
        ])
        contentStack.addArrangedSubview(fontCard)
        contentStack.setCustomSpacing(20, after: fontCard)

        // ── Section: Colors ───────────────────────────────────────────────────
        contentStack.addArrangedSubview(sectionHeader("カラー"))
        let colorCard = makeCard()

        let bgRow = colorRow(title: "背景色", swatch: bgColorSwatch, action: #selector(bgColorTapped))
        let separator = makeSeparator()
        let textRow = colorRow(title: "文字色", swatch: textColorSwatch, action: #selector(textColorTapped))

        let colorStack = UIStackView(arrangedSubviews: [bgRow, separator, textRow])
        colorStack.axis = .vertical
        colorStack.spacing = 0
        colorStack.translatesAutoresizingMaskIntoConstraints = false
        colorCard.addSubview(colorStack)
        NSLayoutConstraint.activate([
            colorStack.topAnchor.constraint(equalTo: colorCard.topAnchor),
            colorStack.leadingAnchor.constraint(equalTo: colorCard.leadingAnchor),
            colorStack.trailingAnchor.constraint(equalTo: colorCard.trailingAnchor),
            colorStack.bottomAnchor.constraint(equalTo: colorCard.bottomAnchor),
        ])
        contentStack.addArrangedSubview(colorCard)

        // ── Preview label ─────────────────────────────────────────────────────
        contentStack.setCustomSpacing(20, after: colorCard)
        contentStack.addArrangedSubview(sectionHeader("プレビュー"))
        let previewCard = makePrompterPreview()
        contentStack.addArrangedSubview(previewCard)
    }

    // MARK: - Load values
    private func loadCurrentValues() {
        let d = UserDefaults.standard
        blurSlider.value = d.prompterBlurIntensity
        updateBlurLabel(d.prompterBlurIntensity)
        fontSizeSlider.value = Float(d.prompterFontSize)
        updateFontSizeLabel(Float(d.prompterFontSize))
        bgColorSwatch.backgroundColor = d.prompterBgColor
        textColorSwatch.backgroundColor = d.prompterTextColor
    }

    // MARK: - Slider actions
    @objc private func blurSliderChanged() {
        let v = blurSlider.value
        updateBlurLabel(v)
        UserDefaults.standard.setPrompterBlurIntensity(v)
        notifyChange()
    }

    @objc private func fontSizeSliderChanged() {
        let v = fontSizeSlider.value
        updateFontSizeLabel(v)
        UserDefaults.standard.setPrompterFontSize(CGFloat(v))
        notifyChange()
    }

    private func updateBlurLabel(_ v: Float) {
        blurValueLabel.text = String(format: "%.0f%%", v * 100)
    }

    private func updateFontSizeLabel(_ v: Float) {
        fontSizeValueLabel.text = String(format: "%.0fpt", v)
    }

    // MARK: - Color picker
    @objc private func bgColorTapped() {
        pendingColorTarget = .background
        presentColorPicker(initialColor: UserDefaults.standard.prompterBgColor)
    }

    @objc private func textColorTapped() {
        pendingColorTarget = .text
        presentColorPicker(initialColor: UserDefaults.standard.prompterTextColor)
    }

    private func presentColorPicker(initialColor: UIColor) {
        let picker = UIColorPickerViewController()
        picker.selectedColor = initialColor
        picker.supportsAlpha = true
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Notify
    private func notifyChange() {
        NotificationCenter.default.post(name: .prompterSettingsChanged, object: nil)
    }

    // MARK: - Factory helpers
    private func sectionHeader(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.45)
        label.translatesAutoresizingMaskIntoConstraints = false
        let wrapper = UIView()
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -4),
        ])
        return wrapper
    }

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.12, alpha: 1)
        v.layer.cornerRadius = 12
        v.layer.masksToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func sliderRow(label: UILabel, slider: UISlider) -> UIView {
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(arrangedSubviews: [slider, label])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func colorRow(title: String, swatch: UIView, action: Selector) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = .white

        swatch.layer.cornerRadius = 14
        swatch.layer.masksToBounds = true
        swatch.layer.borderWidth = 1
        swatch.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 28),
            swatch.heightAnchor.constraint(equalToConstant: 28),
        ])

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.3)
        chevron.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 16),
        ])

        let stack = UIStackView(arrangedSubviews: [titleLabel, UIView(), swatch, chevron])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            row.heightAnchor.constraint(equalToConstant: 56),
        ])

        let btn = UIButton(type: .system)
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: row.topAnchor),
            btn.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            btn.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: row.trailingAnchor),
        ])

        return row
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.heightAnchor.constraint(equalToConstant: 0.5),
        ])
        let wrapper = UIView()
        wrapper.addSubview(v)
        v.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16).isActive = true
        v.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor).isActive = true
        v.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
        v.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
        return wrapper
    }

    private func makePrompterPreview() -> UIView {
        let d = UserDefaults.standard
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.layer.cornerRadius = 14
        blur.layer.masksToBounds = true
        blur.layer.borderWidth = 0.5
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        blur.translatesAutoresizingMaskIntoConstraints = false

        let bg = UIView()
        bg.backgroundColor = d.prompterBgColor
        bg.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "サンプルテキスト\nSample Text"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = d.prompterTextColor
        label.font = .systemFont(ofSize: min(d.prompterFontSize, 24), weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false

        blur.contentView.addSubview(bg)
        blur.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            bg.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),
            label.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -12),
            blur.heightAnchor.constraint(equalToConstant: 100),
        ])

        return blur
    }
}

// MARK: - UIColorPickerViewControllerDelegate
extension PrompterSettingsViewController: UIColorPickerViewControllerDelegate {

    func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                   didSelect color: UIColor, continuously: Bool) {
        switch pendingColorTarget {
        case .background:
            bgColorSwatch.backgroundColor = color
            UserDefaults.standard.setPrompterBgColor(color)
        case .text:
            textColorSwatch.backgroundColor = color
            UserDefaults.standard.setPrompterTextColor(color)
        }
        notifyChange()
    }
}
