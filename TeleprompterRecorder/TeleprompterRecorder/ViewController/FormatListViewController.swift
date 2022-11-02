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
        naviBar.topItem?.title = title
        self.tableView!.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        let dataSource = RxTableViewSectionedAnimatedDataSource<MySection>(
            configureCell: { [weak self] ds, tv, index, item in
                let cell = tv.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
                cell.textLabel?.numberOfLines = 0
                let formatDimensions = CMVideoFormatDescriptionGetDimensions(item.formatDescription)
                let formatMediaType = CMFormatDescriptionGetMediaType(item.formatDescription)
                let formatMediaSubType = CMFormatDescriptionGetMediaSubType(item.formatDescription)
                cell.textLabel?.text =
                "mediaType: \(formatMediaType.toString()) / \(formatMediaSubType.toString())  " +
                "FrameRate: \(Int64(item.videoSupportedFrameRateRanges.first?.minFrameRate ?? -1)) ~ \(Int64(item.videoSupportedFrameRateRanges.first?.maxFrameRate ?? -1))  " +
                "dimensions: \(formatDimensions.height) x \(formatDimensions.width)  " +
                "ISO: \(Int(item.minISO)) ~ \(Int(item.maxISO))   " +
                "MaxZoom: \(Int64(item.videoMaxZoomFactor))    " +
                "ZoomUpscale: \(String(format: "%.3f", item.videoZoomFactorUpscaleThreshold))   \n" +
                "FOV: \(item.videoFieldOfView)   " +
                "videoHDRSupported: \(item.isVideoHDRSupported ? "YES" : "NO")    " +
                "isVideoBinned: \(item.isVideoBinned ? "YES" : "NO")    "
                if (item.debugDescription.identity == self?.formats.activeFormat.debugDescription.identity) {
                    tv.selectRow(at: index, animated: true, scrollPosition: .none)
                }
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
            if #available(iOS 14.1, *) {
                let HDRFormats = formats.supportFormats.filter({$0.supportedColorSpaces.contains(where: {$0 == .HLG_BT2020})})
                let input = FormatListViewModel.Input(formats: .just((activeFormat: formats.activeFormat,
                                                                      supportFormats: HDRFormats)))
                let output = viewModel.transform(input: input)
                tableViewDisposable = output.datas.asObservable().bind(to: tableView.rx.items(dataSource: dataSource))
            } else {
                tableViewDisposable = Observable<[MySection]>.just([]).bind(to: tableView.rx.items(dataSource: dataSource))
            }
        } else {
            var SDRFormats: [AVCaptureDevice.Format] = []
            if #available(iOS 14.1, *) {
                SDRFormats = formats.supportFormats.filter({$0.supportedColorSpaces.contains(where: {($0 == .P3_D65 || $0 == .sRGB) && $0 != .HLG_BT2020})})
            } else {
                
                SDRFormats = formats.supportFormats.filter({$0.supportedColorSpaces.contains(where: {$0 == .P3_D65 || $0 == .sRGB})})
            }
            let input = FormatListViewModel.Input(formats: .just((activeFormat: formats.activeFormat,
                                                                  supportFormats: SDRFormats)))
            let output = viewModel.transform(input: input)
            tableViewDisposable = output.datas.asObservable().bind(to: tableView.rx.items(dataSource: dataSource))
        }
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
