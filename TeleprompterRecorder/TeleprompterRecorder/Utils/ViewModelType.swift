//
//  ViewModelType.swift
//
//  Created by YanQi on 2021/11/19.
//

import Foundation

protocol ViewModelType {
    associatedtype Input
    associatedtype Output
    
    func transform(input: Input) -> Output
}
