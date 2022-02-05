//
//  VideoRecorderViewModel.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/20.
//

import RxSwift
import RxCocoa
import UIKit
import AVFoundation
import Photos
import AudioToolbox

final class VideoRecorderViewModel: ViewModelType {
    
    struct Input {
        let ready: Driver<CameraPreview>
        let isVideoWillStart: Driver<Bool>
        let formats: Driver<Void>
        let changeCamera: Driver<UIView?>
        let prompterTextEditBtnClick: Driver<CaptureButtonsView?>
        let openPhotoBtnClick: Driver<Void>
    }
    
    struct Output {
        let requestAuthorizationFailed: Driver<Bool>
        let formats: Driver<(activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])?>
        let selectedFormat: Binder<AVCaptureDevice.Format>
        let didChangeCamera: Driver<Bool>
    }
    
    struct Dependencies {
        let captureManager: CaptureManager
        let videoRecorderVC: VideoRecorderViewController
    }
    
    private let dependencies: Dependencies
    private let disposeBag = DisposeBag()
    private var backgroundTaskID = UIBackgroundTaskIdentifier(rawValue: 0)
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    func transform(input: Input) -> Output {
        
        let requestAuthorization = input.ready.flatMap { _ in
            AVCaptureDevice.rx.requestAuthorization(for: .video).map({$0 == .authorized}).flatMap({ element -> Single<Bool> in
                if (element) {
                    return AVCaptureDevice.rx.requestAuthorization(for: .audio).map({$0 == .authorized})
                } else {
                    return Single.just(false)
                }
            }).flatMap({ element -> Single<Bool> in
                if (element) {
                    return PHPhotoLibrary.rx.requestAuthorization().map({$0 == .authorized})
                } else {
                    return Single.just(false)
                }
            }).asDriver(onErrorJustReturn: false)
        }
        
        let requestAuthorizationFailed: Driver<Bool> = Driver.combineLatest(input.ready, requestAuthorization).flatMap {
            if ($0.1) {
                let cameraPreview = $0.0
                cameraPreview.cameraPreviewLayer.session = self.dependencies.captureManager.captureSession
                self.dependencies.captureManager.initSetting()
            }
            return Driver<Bool>.just($0.1)
        }
        var isStopping = false
        input.isVideoWillStart.drive(onNext: { isVideoWillStart in
            guard !isStopping else {return}
            if (isVideoWillStart) {
                self.dependencies.captureManager.startRecording()
                self.sound(id: 1113)
            } else {
                isStopping = true
                self.dependencies.captureManager.stopRecording {
                    isStopping = false
                }
                self.sound(id: 1114)
            }
        }).disposed(by: disposeBag)
        
        input.prompterTextEditBtnClick.drive(onNext: {captureButtonsView in
            guard let captureButtonsView = captureButtonsView else {return}
            
            if UserDefaults.standard.isPrompterAdsShow && !captureButtonsView.textViewEditButton.isSelected {
                
                UIAlertController.showTwoBtnAlert(title: "リワード広告見たら\n24時間プロンプター自由に編集可能となります",
                                                  message: nil,
                                                  cancelBtnTitle: "キャンセル",
                                                  secondBtnTitle: "広告表示する") { action in
                    captureButtonsView.isUserInteractionEnabled = false
                    let rewardedVideoManager = RewardedVideoManager()
                    rewardedVideoManager.showRewardedVideoAd {result in
                        guard result else {return}
                        captureButtonsView.isUserInteractionEnabled = true
                        UserDefaults.standard.setPrompterAdsDate(value: .init())
                    }
                }
            } else {
                
                captureButtonsView.textViewEditButton.isSelected = !captureButtonsView.textViewEditButton.isSelected
                captureButtonsView.textView.isEditable = captureButtonsView.textViewEditButton.isSelected
                captureButtonsView.textView.isSelectable = captureButtonsView.textViewEditButton.isSelected
                if captureButtonsView.textViewEditButton.isSelected {
                    captureButtonsView.textView.becomeFirstResponder()
                } else {
                    captureButtonsView.textView.resignFirstResponder()
                }
            }
            
            
        }).disposed(by: disposeBag)
        
        
        let formats: Driver<(activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])?> = input.formats.flatMap { _ in
            return self.dependencies.captureManager.currentCameraFormat
        }
        
        let didChangeCamera: Driver<Bool> = input.changeCamera.flatMap({ [weak self] sourceView in
            guard let self = self else {return .just(false)}
            return self.dependencies.captureManager.changeCamera(sourceView: sourceView)
        })
        
        var isVCShowing = true
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).subscribe { [weak self] notification in
            guard let self = self else {return}
            isVCShowing = false
            if self.dependencies.captureManager.isCapturing {
                self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {[weak self] in
                    guard let self = self else {return}
                    UIApplication.shared.endBackgroundTask((self.backgroundTaskID))
                })
                self.dependencies.captureManager.stopRecording {[weak self] in
                    guard let self = self else {return}
                    UIApplication.shared.endBackgroundTask((self.backgroundTaskID))
                }
            }
        }.disposed(by: disposeBag)
        NotificationCenter.default.rx.notification(UIApplication.didBecomeActiveNotification).subscribe { _ in
            isVCShowing = true
        }.disposed(by: disposeBag)
        
        dependencies.videoRecorderVC.rx.viewWillDisappear.subscribe(onNext: {_ in
            isVCShowing = false
        }).disposed(by: disposeBag)
        dependencies.videoRecorderVC.rx.viewDidAppear.subscribe(onNext: {_ in
            isVCShowing = true
        }).disposed(by: disposeBag)
        
        var notificationKey = ""
        if #available(iOS 15.0, *) {
            notificationKey = "SystemVolumeDidChange"
        } else {
            notificationKey = "AVSystemController_SystemVolumeDidChangeNotification"
        }
        
        let obserable = NotificationCenter.default.rx.notification(Notification.Name.init(rawValue: notificationKey)).take(until: dependencies.videoRecorderVC.rx.deallocated).distinctUntilChanged({ a, b in
            if #available(iOS 15.0, *) {
                guard let aSequenceNumber = a.userInfo?["SequenceNumber"] as? Int,
                      let bSequenceNumber = b.userInfo?["SequenceNumber"] as? Int,
                      let aVolume = a.userInfo?["Volume"] as? Float,
                      let bVolume = b.userInfo?["Volume"] as? Float else {
                          return false
                      }
                if (aVolume == 1 && bVolume == 1) || (aVolume == 0 && bVolume == 0) {
                    return aSequenceNumber == bSequenceNumber
                } else {
                    return aSequenceNumber == bSequenceNumber || aVolume == bVolume
                }
            } else {
                guard let aVolume = a.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float,
                      let bVolume = b.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float else {
                          return false
                      }
                if (aVolume == 1 && bVolume == 1) || (aVolume == 0 && bVolume == 0) {
                    return false
                } else {
                    return aVolume == bVolume
                }
            }
        }).map { _ in}
        let manualTap = PublishSubject<Void>()
        obserable.observe(on: MainScheduler.asyncInstance).subscribe(on: MainScheduler.asyncInstance)
            .flatMapFirst {_ in
                obserable
                    .take(until: obserable.startWith(()).debounce(.milliseconds(500), scheduler: MainScheduler.instance))
                    .startWith(())
                    .reduce(0) { acc, _ in acc + 1 }
            }.delaySubscription(.milliseconds(1000), scheduler: MainScheduler.instance).subscribe(onNext: { [weak self] times in
                guard isVCShowing else {
                    return
                }
                let offset: CGFloat = 30
                if (times == 1) {
                    guard let self = self,
                          !self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.isHidden,
                          self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.contentSize.height >= self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.contentOffset.y else {return}

                    let shouldY = min(self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.contentOffset.y + self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.bounds.height - offset , self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.contentSize.height - self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.bounds.height)
                    self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.setContentOffset(.init(x: self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.contentOffset.x, y: shouldY), animated: true)
                } else if times == 2 {
                    guard let self = self,
                    !self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.isHidden,
                          self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.contentOffset.y >= 0 else {return}

                    let shouldY = max(self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.contentOffset.y - self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.bounds.height + offset , 0)
                    self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.setContentOffset(.init(x: self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.contentOffset.x, y: shouldY), animated: true)
                } else {
                    manualTap.onNext(())
                }
                
            }).disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).subscribe { [weak self] notification in
            guard let self = self else {return}
            self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.recordBtn.isSelected = false
            self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.formatChangeBtn.isEnabled = true
            self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.changeCameraBtn.isEnabled = true
        }.disposed(by: disposeBag)
        let repos = Driver.merge(manualTap.asDriver(onErrorJustReturn: ()), self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.prompterBtn.rx.tap.asDriver())
        let willPrompterBtnSelect = repos.map({ [weak self] () -> Bool in
                guard let self = self else {return false}
            UserDefaults.standard.setPrompterViewShow(value: !UserDefaults.standard.isPrompterViewShow)
            return self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.prompterBtn.isSelected
        }).startWith(UserDefaults.standard.isPrompterViewShow).map({!$0})
        willPrompterBtnSelect.asObservable().bind(to: self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.prompterBtn.rx.isSelected).disposed(by: disposeBag)
        willPrompterBtnSelect.asObservable().bind(to: self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textViewBg.rx.isHidden).disposed(by: disposeBag)
        self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.rx.didEndEditing.subscribe(onNext: { [weak self] in
            guard let self = self else {return}
            UserDefaults.standard.setPrompterText(text: self.dependencies.videoRecorderVC.cameraPreview.captureButtonsView.textView.attributedText)
        }).disposed(by: disposeBag)
        
        input.openPhotoBtnClick.drive(onNext: {captureButtonsView in
            let urlStr = "cGhvdG9zLXJlZGlyZWN0Oi8v".decodeFromBase64()
            
            if let url = URL(string:urlStr) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, options: Dictionary(), completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }}).disposed(by: disposeBag)

        return Output(requestAuthorizationFailed: requestAuthorizationFailed,
                      formats: formats,
                      selectedFormat: dependencies.captureManager.selectedFormat,
                      didChangeCamera: didChangeCamera)
    }
    
    private func sound(id: SystemSoundID) {
        var id = id
        if let soundUrl = CFBundleCopyResourceURL(CFBundleGetMainBundle(), nil, nil, nil) {
            AudioServicesCreateSystemSoundID(soundUrl, &id)
            AudioServicesPlaySystemSound(id)
        }
    }
}
