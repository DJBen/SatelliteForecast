//
//  UIDevice+Extension.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/27/25.
//

import UIKit

extension UIDevice {
    public var machineName: String {
        var info = utsname()
        return withUnsafeMutablePointer(to: &info) { info in
            guard uname(info) == 0 else { return model }
            let offset = MemoryLayout.offset(of: \utsname.machine)!
            let machine = UnsafeRawPointer(info).advanced(by: offset).assumingMemoryBound(to: CChar.self)
            return String(cString: machine)
        }
    }
}
