//
//  String+Extensions.swift
//  XcodeHelperCliKit
//
//  Created by Joel Saltzman on 6/28/18.
//

import Foundation

extension String {
    public func boolValue() -> Bool {
        return self == "true" || self == "1"
    }
}
