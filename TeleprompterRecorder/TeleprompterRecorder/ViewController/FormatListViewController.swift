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
//                cell.textLabel?.text = "fps{\(Int64(item.videoSupportedFrameRateRanges.first?.minFrameRate ?? -1))-\(Int64(item.videoSupportedFrameRateRanges.first?.maxFrameRate ?? -1))}," +
//                "ISO{\(Int(item.minISO))-\(Int(item.maxISO))}," +
//                "Rate{\(Int64(item.videoSupportedFrameRateRanges.first?.minFrameRate ?? -1))-\(Int64(item.videoSupportedFrameRateRanges.first?.maxFrameRate ?? -1))}," +
                cell.textLabel?.text = item.debugDescription
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
        
        bindViewModel()
    }
    
    private func bindViewModel() {
        let input = FormatListViewModel.Input(formats: .just(formats))

        let output = viewModel.transform(input: input)
        
        output.datas.asObservable().bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }
}
