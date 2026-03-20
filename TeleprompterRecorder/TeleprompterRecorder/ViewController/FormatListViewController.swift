//
//  FormatListViewController.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/23.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import AVFoundation

class FormatListViewController: UIViewController {

    @IBOutlet weak var naviBar: UINavigationBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var isHDRSwitch: UISwitch! {
        didSet {
            isHDRSwitch.isOn = UserDefaults.standard.isHDRSwitch
        }
    }
    @IBOutlet weak var isHDRBtn: UIBarButtonItem!
    
    let disposeBag = DisposeBag()
    var tableViewDisposable: Disposable?
    
    let selectedFormat = PublishSubject<AVCaptureDevice.Format>()
    let viewModel = FormatListViewModel()
    
    var formats: (activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])!
    
    private var dataSource: RxTableViewSectionedAnimatedDataSource<MySection>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        applyDarkStyle()
        naviBar.topItem?.title = title
        self.tableView!.register(FormatCell.self, forCellReuseIdentifier: "Cell")

        let dataSource = RxTableViewSectionedAnimatedDataSource<MySection>(
            configureCell: { [weak self] ds, tv, index, item in
                let cell = (tv.dequeueReusableCell(withIdentifier: "Cell") as? FormatCell) ?? FormatCell(style: .default, reuseIdentifier: "Cell")
                let formatDimensions = CMVideoFormatDescriptionGetDimensions(item.formatDescription)
                let formatMediaType = CMFormatDescriptionGetMediaType(item.formatDescription)
                let formatMediaSubType = CMFormatDescriptionGetMediaSubType(item.formatDescription)
                let fps = "\(Int64(item.videoSupportedFrameRateRanges.first?.minFrameRate ?? -1))–\(Int64(item.videoSupportedFrameRateRanges.first?.maxFrameRate ?? -1)) fps"
                let dims = "\(formatDimensions.width) × \(formatDimensions.height)"
                let codec = "\(formatMediaType.toString())/\(formatMediaSubType.toString())"
                let hdr = item.isVideoHDRSupported ? "HDR" : ""
                let binned = item.isVideoBinned ? "Binned" : ""
                let tags = [codec, fps, dims, hdr, binned].filter { !$0.isEmpty }.joined(separator: "  ·  ")
                let detail = "ISO \(Int(item.minISO))–\(Int(item.maxISO))  ·  Zoom ×\(Int64(item.videoMaxZoomFactor))  ·  FOV \(Int(item.videoFieldOfView))°"
                cell.configure(title: tags, subtitle: detail, description: item.japaneseDescription)
                let isActive = item.debugDescription.identity == self?.formats.activeFormat.debugDescription.identity
                if isActive { tv.selectRow(at: index, animated: true, scrollPosition: .none) }
                return cell
            },
            titleForHeaderInSection: { ds, index in
                return ds.sectionModels[index].header
            }
        )
        
        self.dataSource = dataSource
         
        tableView.rx.modelSelected(AVCaptureDevice.Format.self).subscribe(onNext: {[weak self] item in
            self?.selectedFormat.onNext(item)
            self?.selectedFormat.onCompleted()
            self?.dismiss(animated: true)
        }).disposed(by: disposeBag)
        
        
        isHDRSwitch.rx.value.subscribe(onNext: { [weak self] value in
            guard let self = self else {return}
            self.bindViewModel(value: value)
            UserDefaults.standard.setHDRSwitch(value: value)
        }).disposed(by: disposeBag)
        
    }
    
    @IBAction func backBtnClick(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
    private func bindViewModel(value: Bool) {
        tableView.delegate = nil
        tableView.dataSource = nil
        tableViewDisposable?.dispose()
        if value {
            // HDR ON: HLG_BT2020 カラースペースをサポートするフォーマットのみ
            let HDRFormats = formats.supportFormats.filter {
                $0.supportedColorSpaces.contains(.HLG_BT2020)
            }
            let input = FormatListViewModel.Input(formats: .just((activeFormat: formats.activeFormat, supportFormats: HDRFormats)))
            tableViewDisposable = viewModel.transform(input: input).datas.asObservable().bind(to: tableView.rx.items(dataSource: dataSource))
        } else {
            // HDR OFF: P3_D65 または sRGB をサポートし、かつ HLG_BT2020（HDR）を含まないフォーマット
            // 修正前は ($0 == .P3_D65 || $0 == .sRGB) && $0 != .HLG_BT2020 と書いていたが、
            // これは各要素が(P3_D65かsRGB)かつ(HLG_BT2020でない)を確認するだけで、
            // フォーマット自体がHLG_BT2020を持つかどうかを除外できていなかった。
            let SDRFormats = formats.supportFormats.filter {
                !$0.supportedColorSpaces.contains(.HLG_BT2020) &&
                $0.supportedColorSpaces.contains(where: { $0 == .P3_D65 || $0 == .sRGB })
            }
            let input = FormatListViewModel.Input(formats: .just((activeFormat: formats.activeFormat, supportFormats: SDRFormats)))
            tableViewDisposable = viewModel.transform(input: input).datas.asObservable().bind(to: tableView.rx.items(dataSource: dataSource))
        }
    }
}
// MARK: - Dark appearance
private extension FormatListViewController {
    func applyDarkStyle() {
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)

        // Navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor    = UIColor(white: 0.10, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        naviBar.standardAppearance = appearance
        naviBar.tintColor = .systemCyan

        // Table
        tableView.backgroundColor          = .clear
        tableView.separatorColor           = UIColor.white.withAlphaComponent(0.08)
        tableView.separatorInset           = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        // HDR switch
        isHDRSwitch.onTintColor = .systemCyan
    }
}

// MARK: - Custom cell
private final class FormatCell: UITableViewCell {
    private let titleLabel       = UILabel()
    private let subtitleLabel    = UILabel()
    private let descriptionLabel = UILabel()
    private let activeBar        = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor      = .clear
        selectedBackgroundView = {
            let v = UIView()
            v.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.12)
            return v
        }()

        activeBar.backgroundColor    = .systemCyan
        activeBar.layer.cornerRadius = 2
        activeBar.translatesAutoresizingMaskIntoConstraints = false
        activeBar.isHidden           = true

        titleLabel.font          = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor     = .white
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font      = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Natural language description (Japanese)
        descriptionLabel.font          = .systemFont(ofSize: 12, weight: .regular)
        descriptionLabel.textColor     = UIColor.systemCyan.withAlphaComponent(0.85)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(activeBar)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            activeBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            activeBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            activeBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            activeBar.widthAnchor.constraint(equalToConstant: 3),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 5),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, subtitle: String, description: String) {
        titleLabel.text       = title
        subtitleLabel.text    = subtitle
        descriptionLabel.text = description
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        activeBar.isHidden   = !selected
        titleLabel.textColor = selected ? .systemCyan : .white
    }
}

fileprivate extension FourCharCode {
    func toString() -> String {
        let n = Int(self)
        var s: String = String(UnicodeScalar((n >> 24) & 255)!)
        s.append(String(UnicodeScalar((n >> 16) & 255)!))
        s.append(String(UnicodeScalar((n >> 8) & 255)!))
        s.append(String(UnicodeScalar(n & 255)!))
        return s.trimmingCharacters(in: CharacterSet.whitespaces)
    }
}

// MARK: - Japanese natural language description
fileprivate extension AVCaptureDevice.Format {

    var japaneseDescription: String {
        let dims    = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let w = dims.width, h = dims.height
        let maxFPS  = Int(videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0)
        let fov     = Int(videoFieldOfView)
        // フィルターと同じ判定基準を使う（isVideoHDRSupported はハードウェアフラグで
        // HLG_BT2020 色空間とは別物。HDR OFF リストに出るフォーマットが
        // 「HDR撮影対応」と表示されてしまう矛盾を防ぐ）
        let isHDR   = supportedColorSpaces.contains(.HLG_BT2020)
        let binned  = isVideoBinned
        let maxZoom = Int64(videoMaxZoomFactor)

        // ── 解像度ラベル ──────────────────────────────────────────
        let resLabel: String
        switch max(w, h) {
        case 3840...: resLabel = "4K"
        case 2560...: resLabel = "2.7K"
        case 1920...: resLabel = "フルHD"
        case 1280...: resLabel = "HD（720p）"
        default:      resLabel = "SD（\(w)×\(h)）"
        }

        // ── フレームレート説明 ────────────────────────────────────
        let fpsNote: String
        switch maxFPS {
        case 240...: fpsNote = "最大\(maxFPS)fpsのスーパースローモーション撮影が可能"
        case 120...: fpsNote = "最大\(maxFPS)fpsのスローモーション撮影が可能"
        case 60...:  fpsNote = "最大\(maxFPS)fpsで滑らかな動画撮影が可能"
        default:     fpsNote = "最大\(maxFPS)fpsの標準撮影"
        }

        // ── 画角説明 ──────────────────────────────────────────────
        let fovNote: String
        switch fov {
        case 100...: fovNote = "超広角（視野角\(fov)°）"
        case 80...:  fovNote = "広角（視野角\(fov)°）"
        case 60...:  fovNote = "標準画角（視野角\(fov)°）"
        default:     fovNote = "望遠（視野角\(fov)°）"
        }

        // ── 各機能の説明 ──────────────────────────────────────────
        var parts: [String] = [
            "\(resLabel)（\(w)×\(h)）",
            fpsNote,
            fovNote,
        ]

        if isHDR   { parts.append("HDR撮影対応（高輝度・高コントラスト）") }
        if binned  { parts.append("ピクセルビニング処理あり（暗所撮影に有利）") }
        if maxZoom >= 10 { parts.append("最大\(maxZoom)倍デジタルズーム") }

        return parts.joined(separator: "。") + "。"
    }
}
