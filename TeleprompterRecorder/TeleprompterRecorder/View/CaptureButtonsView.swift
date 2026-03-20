//
//  CaptureButtonsView.swift
//  TeleprompterRecorder
//

import UIKit
import RxCocoa
import RxSwift

class CaptureButtonsView: UIView {

    // MARK: - Public properties (same names as before for VC / ViewModel compatibility)
    var recordBtn         = UIButton(type: .custom)
    var formatChangeBtn   = UIButton(type: .custom)
    var changeCameraBtn   = UIButton(type: .custom)
    var prompterBtn       = UIButton(type: .custom)
    var textViewEditButton = UIButton(type: .custom)
    var textView          = UITextView()
    var textViewBg        = UIView()          // ViewModel binds isHidden here
    var openPhotoBtn      = UIButton(type: .custom)
    var openMenuBtn       = UIButton(type: .custom)

    let disposeBag = DisposeBag()

    // MARK: - Private
    private let topBlurView    = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let bottomBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let prompterBlur   = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let recordRing     = CAShapeLayer()
    private let recordFill     = CAShapeLayer()
    private var recordLayersReady = false

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
        buildBindings()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
        buildBindings()
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        installRecordLayers()
    }

    // MARK: - Touch passthrough
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        endEditing(true)
    }
}

// MARK: - UI Construction
private extension CaptureButtonsView {

    func buildUI() {
        backgroundColor = .clear
        setupTopBar()
        setupPrompterArea()
        setupBottomBar()
    }

    // ── Top pill: cameraSwitch · prompter · format · menu ──────────────────
    func setupTopBar() {
        changeCameraBtn  = iconButton("camera.rotate",   size: 19)
        prompterBtn      = iconButton("doc.text",        size: 19)
        formatChangeBtn  = iconButton("camera.filters",  size: 19)
        openMenuBtn      = iconButton("line.3.horizontal", size: 19)

        let stack = hStack([changeCameraBtn, prompterBtn, formatChangeBtn, openMenuBtn])

        topBlurView.translatesAutoresizingMaskIntoConstraints = false
        topBlurView.layer.cornerRadius  = 24
        topBlurView.layer.masksToBounds = true
        topBlurView.layer.borderWidth   = 0.5
        topBlurView.layer.borderColor   = UIColor.white.withAlphaComponent(0.18).cgColor
        addSubview(topBlurView)
        topBlurView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            topBlurView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            topBlurView.centerXAnchor.constraint(equalTo: centerXAnchor),
            topBlurView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.82),
            topBlurView.heightAnchor.constraint(equalToConstant: 52),

            stack.leadingAnchor.constraint(equalTo: topBlurView.contentView.leadingAnchor,  constant: 8),
            stack.trailingAnchor.constraint(equalTo: topBlurView.contentView.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topBlurView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: topBlurView.contentView.bottomAnchor),
        ])
    }

    // ── Prompter card (center) ──────────────────────────────────────────────
    func setupPrompterArea() {
        // prompterBlur acts as textViewBg (ViewModel binds isHidden to it)
        textViewBg = prompterBlur

        prompterBlur.translatesAutoresizingMaskIntoConstraints = false
        prompterBlur.layer.cornerRadius  = 18
        prompterBlur.layer.masksToBounds = true
        prompterBlur.layer.borderWidth   = 0.5
        prompterBlur.layer.borderColor   = UIColor.white.withAlphaComponent(0.22).cgColor
        addSubview(prompterBlur)

        // TextView
        textView.backgroundColor   = .clear
        textView.textColor         = .white
        textView.font              = .systemFont(ofSize: 21, weight: .regular)
        textView.isEditable        = false
        textView.isSelectable      = false
        textView.isScrollEnabled   = true
        textView.showsVerticalScrollIndicator = false
        textView.contentInset      = UIEdgeInsets(top: 40, left: 4, bottom: 8, right: 4)
        textView.translatesAutoresizingMaskIntoConstraints = false
        if let saved = UserDefaults.standard.prompterText {
            textView.attributedText = saved
        }

        // Edit button
        textViewEditButton = pillButton(title: "編集")
        textViewEditButton.translatesAutoresizingMaskIntoConstraints = false

        prompterBlur.contentView.addSubview(textView)
        prompterBlur.contentView.addSubview(textViewEditButton)

        // Top gradient fade mask over text
        let fadeHost = UIView()
        fadeHost.isUserInteractionEnabled = false
        fadeHost.translatesAutoresizingMaskIntoConstraints = false
        prompterBlur.contentView.addSubview(fadeHost)

        NSLayoutConstraint.activate([
            prompterBlur.topAnchor.constraint(equalTo: topBlurView.bottomAnchor, constant: 12),
            prompterBlur.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            prompterBlur.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            prompterBlur.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -108),

            textView.topAnchor.constraint(equalTo: prompterBlur.contentView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: prompterBlur.contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: prompterBlur.contentView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: prompterBlur.contentView.bottomAnchor),

            textViewEditButton.topAnchor.constraint(equalTo: prompterBlur.contentView.topAnchor, constant: 10),
            textViewEditButton.trailingAnchor.constraint(equalTo: prompterBlur.contentView.trailingAnchor, constant: -12),

            fadeHost.topAnchor.constraint(equalTo: prompterBlur.contentView.topAnchor),
            fadeHost.leadingAnchor.constraint(equalTo: prompterBlur.contentView.leadingAnchor),
            fadeHost.trailingAnchor.constraint(equalTo: prompterBlur.contentView.trailingAnchor),
            fadeHost.heightAnchor.constraint(equalToConstant: 48),
        ])

        // gradient drawn after layout
        fadeHost.layoutIfNeeded()
        let grad = CAGradientLayer()
        grad.colors = [UIColor.black.withAlphaComponent(0.45).cgColor, UIColor.clear.cgColor]
        grad.frame  = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 48)
        fadeHost.layer.addSublayer(grad)
    }

    // ── Bottom pill: photo · record · (spacer) ─────────────────────────────
    func setupBottomBar() {
        openPhotoBtn = iconButton("photo", size: 22)

        // Record button – ring drawn via CAShapeLayer in installRecordLayers()
        recordBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recordBtn.widthAnchor.constraint(equalToConstant: 72),
            recordBtn.heightAnchor.constraint(equalToConstant: 72),
        ])

        // Symmetric spacer on the right
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spacer.widthAnchor.constraint(equalToConstant: 52),
            spacer.heightAnchor.constraint(equalToConstant: 52),
        ])

        let stack = hStack([openPhotoBtn, recordBtn, spacer])

        bottomBlurView.translatesAutoresizingMaskIntoConstraints = false
        bottomBlurView.layer.cornerRadius  = 36
        bottomBlurView.layer.masksToBounds = true
        bottomBlurView.layer.borderWidth   = 0.5
        bottomBlurView.layer.borderColor   = UIColor.white.withAlphaComponent(0.18).cgColor
        addSubview(bottomBlurView)
        bottomBlurView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            bottomBlurView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -14),
            bottomBlurView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottomBlurView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.72),
            bottomBlurView.heightAnchor.constraint(equalToConstant: 84),

            stack.leadingAnchor.constraint(equalTo: bottomBlurView.contentView.leadingAnchor,  constant: 16),
            stack.trailingAnchor.constraint(equalTo: bottomBlurView.contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: bottomBlurView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomBlurView.contentView.bottomAnchor),
        ])
    }

    // ── Record button CALayer rings ─────────────────────────────────────────
    func installRecordLayers() {
        guard !recordLayersReady, recordBtn.bounds.width > 0 else { return }
        recordLayersReady = true

        let s: CGFloat = 72
        let c = CGPoint(x: s / 2, y: s / 2)

        recordRing.path        = UIBezierPath(arcCenter: c, radius: 32, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        recordRing.strokeColor = UIColor.white.cgColor
        recordRing.fillColor   = UIColor.clear.cgColor
        recordRing.lineWidth   = 3

        recordFill.path      = UIBezierPath(arcCenter: c, radius: 26, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        recordFill.fillColor = UIColor.white.cgColor

        recordBtn.layer.addSublayer(recordRing)
        recordBtn.layer.addSublayer(recordFill)
    }
}

// MARK: - Bindings
private extension CaptureButtonsView {

    func buildBindings() {
        // Mirror original awakeFromNib: disable format/camera while recording.
        // Reads isSelected BEFORE the VC flip so values are naturally inverted.
        recordBtn.rx.tap
            .map { [weak self] in self?.recordBtn.isSelected ?? true }
            .bind(to: formatChangeBtn.rx.isEnabled)
            .disposed(by: disposeBag)
        recordBtn.rx.tap
            .map { [weak self] in self?.recordBtn.isSelected ?? true }
            .bind(to: changeCameraBtn.rx.isEnabled)
            .disposed(by: disposeBag)

        // React to isSelected KVO so visuals update after the VC sets the flag
        recordBtn.rx.observe(Bool.self, "isSelected")
            .compactMap { $0 }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isRecording in
                self?.animateRecordButton(isRecording: isRecording)
            })
            .disposed(by: disposeBag)

        // Edit button: swap title / tint between normal and active
        textViewEditButton.rx.observe(Bool.self, "isSelected")
            .compactMap { $0 }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] selected in
                guard let self else { return }
                let title = selected ? "完了" : "編集"
                let color: UIColor = selected ? .systemCyan : .white
                self.textViewEditButton.setTitle(title, for: .normal)
                self.textViewEditButton.setTitleColor(color, for: .normal)
                self.textViewEditButton.layer.borderColor = color.withAlphaComponent(0.6).cgColor
            })
            .disposed(by: disposeBag)

        // Prompter button tint when selected
        prompterBtn.rx.observe(Bool.self, "isSelected")
            .compactMap { $0 }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] selected in
                self?.prompterBtn.tintColor = selected ? .systemCyan : .white
            })
            .disposed(by: disposeBag)
    }

    func animateRecordButton(isRecording: Bool) {
        let s: CGFloat = 72
        let c = CGPoint(x: s / 2, y: s / 2)

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        if isRecording {
            // Rounded red square
            let sq = UIBezierPath(roundedRect: CGRect(x: s / 2 - 13, y: s / 2 - 13, width: 26, height: 26), cornerRadius: 5)
            recordFill.path      = sq.cgPath
            recordFill.fillColor = UIColor.systemRed.cgColor
            recordRing.strokeColor = UIColor.systemRed.cgColor

            // Subtle pulse
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue    = 1.0
            pulse.toValue      = 1.06
            pulse.duration     = 0.85
            pulse.autoreverses = true
            pulse.repeatCount  = .infinity
            recordRing.add(pulse, forKey: "pulse")
        } else {
            // White circle
            recordFill.path      = UIBezierPath(arcCenter: c, radius: 26, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
            recordFill.fillColor = UIColor.white.cgColor
            recordRing.strokeColor = UIColor.white.cgColor
            recordRing.removeAnimation(forKey: "pulse")
        }
        CATransaction.commit()
    }
}

// MARK: - Factory helpers
private extension CaptureButtonsView {

    func iconButton(_ systemName: String, size: CGFloat) -> UIButton {
        let btn = UIButton(type: .custom)
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .light)
        btn.setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 52),
            btn.heightAnchor.constraint(equalToConstant: 52),
        ])
        return btn
    }

    func pillButton(title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        btn.backgroundColor  = UIColor.white.withAlphaComponent(0.12)
        btn.layer.cornerRadius  = 10
        btn.layer.masksToBounds = true
        btn.layer.borderWidth   = 0.5
        btn.layer.borderColor   = UIColor.white.withAlphaComponent(0.3).cgColor
        btn.contentEdgeInsets   = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        return btn
    }

    func hStack(_ views: [UIView]) -> UIStackView {
        let sv = UIStackView(arrangedSubviews: views)
        sv.axis         = .horizontal
        sv.distribution = .equalSpacing
        sv.alignment    = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }
}
