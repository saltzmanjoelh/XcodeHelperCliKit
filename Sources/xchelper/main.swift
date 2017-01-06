//
//  XcodeHelperCli.swift
//  XcodeHelper
//
//  Created by Joel Saltzman on 8/28/16.
//
//

import Foundation
import CliRunnable
import XcodeHelperCliKit
import XcodeHelperKit


let helper = XCHelper(xcodeHelpable:XcodeHelper())
do {
    try helper.run(arguments:ProcessInfo.processInfo.arguments, environment:ProcessInfo.processInfo.environment)
} catch let e as XcodeHelperError {
    print(e.description)
    if case XcodeHelperError.dockerBuild(let buildError) = e {
        exit(buildError.exitCode)
    }
    
} catch let e as CliRunnableError {
    print(e.description)
}
