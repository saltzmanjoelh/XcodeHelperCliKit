//
//  Dictionary+Extensions.swift
//  XcodeHelperCliKit
//
//  Created by Joel Saltzman on 11/22/17.
//

import Foundation

extension Dictionary {
    func yamlBoolValue(forKey key: Key) -> Bool {
        guard let value = self[key] else { return false }
        if let stringValue = value as? String {
            //For cli options, if the key is there it's assumed to be an arg that doesn't require a value
            //Like the -a in `ls -a'
            return stringValue == "true"
        }
        return true
    }
}
