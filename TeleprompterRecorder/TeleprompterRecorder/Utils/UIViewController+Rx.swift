//
//  UIViewController+Rx.swift
//
//  Created by YanQi on 2021/11/19.
//

import RxSwift
import RxCocoa
import UIKit

extension Reactive where Base: UIViewController {
    var viewWillAppear: ControlEvent<Void> {
        let source = self.methodInvoked(#selector(Base.viewWillAppear(_:))).map { _ in }
        return ControlEvent(events: source)
    }
    var viewDidAppear: ControlEvent<Void> {
        let source = self.methodInvoked(#selector(Base.viewDidAppear(_:))).map { _ in }
        return ControlEvent(events: source)
    }
}
