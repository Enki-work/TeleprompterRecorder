//
//  LocalCameraFormat.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/24.
//

import Foundation

struct LocalDeviceFormat: Codable {
    static let selectedFormatKey = "selectedFormatKey"
    
    fileprivate(set) var isDefaultCamera: Bool
    let selecedFormatIdentity: String
    let deviceUniqueID: String
}

extension LocalDeviceFormat {
    
    static func getLocalDeviceFormatList() -> [LocalDeviceFormat] {
        guard let data = UserDefaults.standard.value(forKey:  self.selectedFormatKey) as? Data else {
            return []
        }
        return (try? PropertyListDecoder().decode(Array<LocalDeviceFormat>.self, from: data)) ?? []
    }
    
    static func setLocalDeviceFormatList(deviceFormats: [LocalDeviceFormat]) {
        UserDefaults.standard.set(try? PropertyListEncoder().encode(deviceFormats),
                                  forKey:self.selectedFormatKey)
    }
    
    static func addOrUpdateLocalDeviceFormatList(deviceFormat: LocalDeviceFormat) {
        var formats = getLocalDeviceFormatList()
        if let index = formats.firstIndex(where: {$0.deviceUniqueID == deviceFormat.deviceUniqueID}) {
            formats.remove(at: index)
        }
        if (deviceFormat.isDefaultCamera) {
            formats = formats.compactMap { model -> LocalDeviceFormat in
                var new = model
                new.isDefaultCamera = false
                return new
            }
        }
        formats.append(deviceFormat)
        UserDefaults.standard.set(try? PropertyListEncoder().encode(formats),
                                  forKey:self.selectedFormatKey)
    }
}

extension Array where Element == LocalDeviceFormat {
    
}
