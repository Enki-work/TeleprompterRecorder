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
    
    let disposeBag = DisposeBag()
    let selectedFormat = PublishSubject<AVCaptureDevice.Format>()
    
    var formats: (activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])!
    private var datas: BehaviorSubject<[MySection]>? = nil
    
    private var dataSource: RxTableViewSectionedAnimatedDataSource<MySection>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        naviBar.topItem?.title = title
        self.tableView!.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.rowHeight = UITableView.automaticDimension
        
        datas = BehaviorSubject<[MySection]>(value: Array(Set(formats.supportFormats.compactMap({
            let dims = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return "\(dims.width)x\(dims.height)"
        }) as [String])).compactMap({ dimsString in
            MySection(header: dimsString, items: formats.supportFormats.filter({
                let dims = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                return "\(dims.width)x\(dims.height)" == dimsString
            }))
        }).sorted(by: {$0.dimensionsWidth >= $1.dimensionsWidth}))
        
        let dataSource = RxTableViewSectionedAnimatedDataSource<MySection>(
            configureCell: { [weak self] ds, tv, index, item in
                let cell = tv.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
                cell.textLabel?.numberOfLines = 0
//                cell.textLabel?.text = "fps{\(Int64(item.videoSupportedFrameRateRanges.first?.minFrameRate ?? -1))-\(Int64(item.videoSupportedFrameRateRanges.first?.maxFrameRate ?? -1))}," +
//                "ISO{\(Int(item.minISO))-\(Int(item.maxISO))}," +
//                "Rate{\(Int64(item.videoSupportedFrameRateRanges.first?.minFrameRate ?? -1))-\(Int64(item.videoSupportedFrameRateRanges.first?.maxFrameRate ?? -1))}," +
                cell.textLabel?.text = item.debugDescription
                if (item.debugDescription.identity == self?.formats.activeFormat.debugDescription.identity) {
                    print(item)
                    tv.selectRow(at: index, animated: true, scrollPosition: .none)
                }
                return cell
            },
            titleForHeaderInSection: { ds, index in
                return ds.sectionModels[index].header
            }
        )
        
        self.dataSource = dataSource
        
        datas?.bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        tableView.rx.itemSelected.subscribe(onNext: { indexPath in
            print("\(indexPath)")
        }).disposed(by: disposeBag)
         
        tableView.rx.modelSelected(AVCaptureDevice.Format.self).subscribe(onNext: {[weak self] item in
            self?.selectedFormat.onNext(item)
            self?.selectedFormat.onCompleted()
            self?.dismiss(animated: true)
        }).disposed(by: disposeBag)
        
    }
}

struct MySection {
    var header: String
    var items: [AVCaptureDevice.Format]
}

extension MySection: AnimatableSectionModelType {
    
    var identity: String {
        return header
    }
    
    var dimensionsWidth: Int32 {
        guard let first = items.first else {return 0}
        return CMVideoFormatDescriptionGetDimensions(first.formatDescription).width
    }
    
    init(original: MySection, items: [AVCaptureDevice.Format]) {
        self = original
        self.items = items
    }
}

extension AVCaptureDevice.Format: IdentifiableType {
    public var identity: String {
        return self.debugDescription
    }
}
