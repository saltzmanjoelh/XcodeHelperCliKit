//
//  XcodeHelperCli.swift
//  XcodeHelper
//
//  Created by Joel Saltzman on 8/28/16.
//
//

import Foundation
import XcodeHelperCliKit
import XcodeHelperKit

let helper = XcodeHelper()
do {
    try helper.run(arguments:ProcessInfo.processInfo.arguments, environment:ProcessInfo.processInfo.environment)
} catch let e as XcodeHelperError {
    print(e.description)
}
