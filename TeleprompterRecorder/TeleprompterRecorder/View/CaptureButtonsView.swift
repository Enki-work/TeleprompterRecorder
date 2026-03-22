//
//  CaptureButtonsView.swift
//  TeleprompterRecorder
//

import RxCocoa
import RxSwift
import UIKit

class CaptureButtonsView: UIView {

    // MARK: - Public (same property names for VC / ViewModel compatibility)
    var recordBtn = UIButton(type: .custom)
    var formatChangeBtn = UIButton(type: .custom)
    var changeCameraBtn = UIButton(type: .custom)
    var prompterBtn = UIButton(type: .custom)
    var textViewEditButton = UIButton(type: .custom)
    var textView = UITextView()
    var textViewBg = UIView()  // ViewModel binds isHidden here
    var openPhotoBtn = UIButton(type: .custom)
    var openMenuBtn = UIButton(type: .custom)

    let disposeBag = DisposeBag()

    // MARK: - Private layout views
    private let topBlurView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let bottomBlurView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let prompterBlur = UIVisualEffectView(effect: nil)
    private let prompterBgColorView = UIView()
    private var blurAnimator: UIViewPropertyAnimator?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
        buildBindings()
        applyPrompterSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applyPrompterSettings),
                                               name: .prompterSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLanguageChanged),
                                               name: LanguageManager.languageChangedNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
        buildBindings()
        applyPrompterSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applyPrompterSettings),
                                               name: .prompterSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLanguageChanged),
                                               name: LanguageManager.languageChangedNotification, object: nil)
    }

    deinit {
        blurAnimator?.stopAnimation(true)
        NotificationCenter.default.removeObserver(self, name: .prompterSettingsChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: LanguageManager.languageChangedNotification, object: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        endEditing(true)
    }
}

// MARK: - UI Construction
extension CaptureButtonsView {

    fileprivate func buildUI() {
        backgroundColor = .clear
        setupTopBar()
        setupPrompterArea()
        setupBottomBar()
        setupPrompterTapGesture()
    }

    // ── Top pill ─────────────────────────────────────────────────────────────
    // Matches original layout: camera_rotate (left) · doc_plaintext (center) · linked_camera (right)
    fileprivate func setupTopBar() {
        changeCameraBtn = assetButton("camera_rotate")
        prompterBtn = assetButton("doc_plaintext", selected: "doc_plaintext_clear")
        formatChangeBtn = assetButton("linked_camera")

        let stack = hStack([changeCameraBtn, prompterBtn, formatChangeBtn])

        styleBlurPill(topBlurView, cornerRadius: 24)
        addSubview(topBlurView)
        topBlurView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            topBlurView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            topBlurView.centerXAnchor.constraint(equalTo: centerXAnchor),
            topBlurView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.72),
            topBlurView.heightAnchor.constraint(equalToConstant: 44),

            stack.leadingAnchor.constraint(
                equalTo: topBlurView.contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(
                equalTo: topBlurView.contentView.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topBlurView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: topBlurView.contentView.bottomAnchor),
        ])
    }

    // ── Prompter card ────────────────────────────────────────────────────────
    fileprivate func setupPrompterArea() {
        textViewBg = prompterBlur  // ViewModel sets isHidden on this

        styleBlurPill(prompterBlur, cornerRadius: 18)
        addSubview(prompterBlur)

        prompterBgColorView.translatesAutoresizingMaskIntoConstraints = false
        prompterBgColorView.layer.cornerRadius = 18
        prompterBgColorView.layer.masksToBounds = true
        prompterBlur.contentView.insertSubview(prompterBgColorView, at: 0)

        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = .systemFont(ofSize: 21, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.contentInset = UIEdgeInsets(top: 36, left: 4, bottom: 8, right: 4)
        textView.translatesAutoresizingMaskIntoConstraints = false

        // Restore saved text, or show original default text from XIB
        if let saved = UserDefaults.standard.prompterText {
            textView.attributedText = saved
        } else {
            textView.attributedText = defaultPrompterText()
        }

        textViewEditButton = pillButton(title: L("prompter.edit"))
        textViewEditButton.translatesAutoresizingMaskIntoConstraints = false

        let fadeHost = makeTopFade()
        fadeHost.translatesAutoresizingMaskIntoConstraints = false

        prompterBlur.contentView.addSubview(textView)
        prompterBlur.contentView.addSubview(textViewEditButton)
        prompterBlur.contentView.addSubview(fadeHost)

        NSLayoutConstraint.activate([
            prompterBgColorView.topAnchor.constraint(equalTo: prompterBlur.contentView.topAnchor),
            prompterBgColorView.leadingAnchor.constraint(equalTo: prompterBlur.contentView.leadingAnchor),
            prompterBgColorView.trailingAnchor.constraint(equalTo: prompterBlur.contentView.trailingAnchor),
            prompterBgColorView.bottomAnchor.constraint(equalTo: prompterBlur.contentView.bottomAnchor),

            prompterBlur.topAnchor.constraint(equalTo: topBlurView.bottomAnchor, constant: 4),
            prompterBlur.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            prompterBlur.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            prompterBlur.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -114),

            textView.topAnchor.constraint(equalTo: prompterBlur.contentView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: prompterBlur.contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: prompterBlur.contentView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: prompterBlur.contentView.bottomAnchor),

            textViewEditButton.topAnchor.constraint(
                equalTo: prompterBlur.contentView.topAnchor, constant: 8),
            textViewEditButton.trailingAnchor.constraint(
                equalTo: prompterBlur.contentView.trailingAnchor, constant: -10),

            fadeHost.topAnchor.constraint(equalTo: prompterBlur.contentView.topAnchor),
            fadeHost.leadingAnchor.constraint(equalTo: prompterBlur.contentView.leadingAnchor),
            fadeHost.trailingAnchor.constraint(equalTo: prompterBlur.contentView.trailingAnchor),
            fadeHost.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // ── Bottom pill ──────────────────────────────────────────────────────────
    // Matches original: photo (left) · videocam_circle/stop (center) · menu (right)
    fileprivate func setupBottomBar() {
        openPhotoBtn = assetButton("photo")
        openMenuBtn = assetButton("menu")

        // Record: videocam_circle → stop_circle_fill when recording
        recordBtn.setImage(UIImage(named: "videocam_circle"), for: .normal)
        recordBtn.setImage(UIImage(named: "stop_circle_fill"), for: .selected)
        recordBtn.imageView?.contentMode = .scaleAspectFit
        recordBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recordBtn.widthAnchor.constraint(equalToConstant: 42),
            recordBtn.heightAnchor.constraint(equalToConstant: 42),
        ])

        let stack = hStack([openPhotoBtn, recordBtn, openMenuBtn])

        styleBlurPill(bottomBlurView, cornerRadius: 34)
        addSubview(bottomBlurView)
        bottomBlurView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            bottomBlurView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            bottomBlurView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottomBlurView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.85),
            bottomBlurView.heightAnchor.constraint(equalToConstant: 60),

            stack.leadingAnchor.constraint(
                equalTo: bottomBlurView.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(
                equalTo: bottomBlurView.contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: bottomBlurView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomBlurView.contentView.bottomAnchor),
        ])
    }
}

// MARK: - Tap to hide prompter
extension CaptureButtonsView {

    fileprivate func setupPrompterTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handlePrompterTap))
        // スクロールジェスチャーと競合しないよう同時認識を許可
        tap.cancelsTouchesInView = false
        prompterBlur.contentView.addGestureRecognizer(tap)
    }

    @objc private func handlePrompterTap(_ gesture: UITapGestureRecognizer) {
        // 編集モード中はタップでキーボードを操作するため非表示トリガーをスキップ
        guard !textView.isEditable else { return }
        // 既存の prompterBtn タップと同じパスを通して ViewModel の状態管理に乗せる
        prompterBtn.sendActions(for: .touchUpInside)
    }
}

// MARK: - Bindings
extension CaptureButtonsView {

    fileprivate func buildBindings() {
        // Disable format/camera while recording.
        // Reads isSelected BEFORE the VC flips it → value is naturally inverted.
        recordBtn.rx.tap
            .map { [weak self] in self?.recordBtn.isSelected ?? true }
            .bind(to: formatChangeBtn.rx.isEnabled)
            .disposed(by: disposeBag)
        recordBtn.rx.tap
            .map { [weak self] in self?.recordBtn.isSelected ?? true }
            .bind(to: changeCameraBtn.rx.isEnabled)
            .disposed(by: disposeBag)

        // Edit button title/tint reflects editing state
        textViewEditButton.rx.observe(Bool.self, "isSelected")
            .compactMap { $0 }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] selected in
                guard let self else { return }
                self.textViewEditButton.setTitle(selected ? L("prompter.done") : L("prompter.edit"), for: .normal)
                let c: UIColor = selected ? .systemCyan : .white
                self.textViewEditButton.setTitleColor(c, for: .normal)
                self.textViewEditButton.layer.borderColor = c.withAlphaComponent(0.5).cgColor
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Prompter settings
extension CaptureButtonsView {

    @objc private func handleLanguageChanged() {
        let selected = textViewEditButton.isSelected
        textViewEditButton.setTitle(selected ? L("prompter.done") : L("prompter.edit"), for: .normal)
    }

    @objc func applyPrompterSettings() {
        let defaults = UserDefaults.standard
        applyBlurIntensity(defaults.prompterBlurIntensity)
        prompterBgColorView.backgroundColor = defaults.prompterBgColor
        textView.textColor = defaults.prompterTextColor
        let size = defaults.prompterFontSize
        textView.font = .systemFont(ofSize: size, weight: .regular)
    }

    private func applyBlurIntensity(_ intensity: Float) {
        blurAnimator?.stopAnimation(true)
        blurAnimator = nil
        prompterBlur.effect = nil

        let clamped = CGFloat(max(0, min(1, intensity)))
        if clamped >= 1.0 {
            prompterBlur.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            return
        }
        blurAnimator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
            self?.prompterBlur.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        blurAnimator?.startAnimation()
        blurAnimator?.pauseAnimation()
        blurAnimator?.fractionComplete = clamped
    }
}

// MARK: - Default prompter text (matches original XIB content)
extension CaptureButtonsView {

    fileprivate func defaultPrompterText() -> NSAttributedString {
        NSAttributedString(
            string: L("prompter.default_text"),
            attributes: [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 21, weight: .regular),
            ]
        )
    }
}

// MARK: - Factory helpers
extension CaptureButtonsView {

    /// Button using a named image asset (with optional selected-state asset)
    fileprivate func assetButton(_ name: String, selected selectedName: String? = nil) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(named: name), for: .normal)
        if let sel = selectedName {
            btn.setImage(UIImage(named: sel), for: .selected)
        }
        btn.imageView?.contentMode = .scaleAspectFit
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 36),
            btn.heightAnchor.constraint(equalToConstant: 36),
        ])
        return btn
    }

    fileprivate func pillButton(title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        btn.layer.cornerRadius = 10
        btn.layer.masksToBounds = true
        btn.layer.borderWidth = 0.5
        btn.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        return btn
    }

    fileprivate func hStack(_ views: [UIView]) -> UIStackView {
        let sv = UIStackView(arrangedSubviews: views)
        sv.axis = .horizontal
        sv.distribution = .equalSpacing
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }

    fileprivate func styleBlurPill(_ v: UIVisualEffectView, cornerRadius: CGFloat) {
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = cornerRadius
        v.layer.masksToBounds = true
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
    }

    fileprivate func makeTopFade() -> UIView {
        let host = UIView()
        host.isUserInteractionEnabled = false
        let g = CAGradientLayer()
        g.colors = [UIColor.black.withAlphaComponent(0.4).cgColor, UIColor.clear.cgColor]
        g.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
        host.layer.addSublayer(g)
        return host
    }
}
