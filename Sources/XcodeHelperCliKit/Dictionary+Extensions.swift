//
//  Dictionary+Extensions.swift
//  XcodeHelperCliKit
//
//  Created by Joel Saltzman on 11/22/17.
//

import Foundation

extension Dictionary where Value: Collection {
    //For cli options, if the key is there it's assumed to be an arg that doesn't require a value
    //Like the -a in `ls -a'
    func yamlBoolValue(forKey key: Key) -> Bool {
        guard let values = self[key] else { return self.keys.contains(key) }
        if let stringValue = values as? [String],
            let boolValue = stringValue.first?.boolValue() {
            return boolValue
        }
        return true //it's a
    }
}
extension Dictionary where Value: StringProtocol {
    func yamlBoolValue(forKey key: Key) -> Bool {
        //For cli options, if the key is there it's assumed to be an arg that doesn't require a value
        //Like the -a in `ls -a'
        guard let value = self[key] else { return self.keys.contains(key) }
        if let stringValue = value as? String {
            return stringValue.boolValue()
        }
        return true //it's a
    }
}
