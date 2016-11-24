//
//  XcodeHelperCli.swift
//  XcodeHelper
//
//  Created by Joel Saltzman on 8/28/16.
//
//

//TODO: add pushGitTag
//TODO: make an struct xchelper: CliRunnable  that owns and parses the options, then when handling I can pass in XcodeHelper generic for testing purposesf

import Foundation
import CliRunnable
import XcodeHelperCliKit
import XcodeHelperKit


let helper = XCHelper(xcodeHelpable:XcodeHelper())
do {
    try helper.run(arguments:ProcessInfo.processInfo.arguments, environment:ProcessInfo.processInfo.environment)
} catch let e as XcodeHelperError {
    print(e.description)
    if case XcodeHelperError.build(let buildError) = e {
        exit(buildError.exitCode)
    }
    
} catch let e as CliRunnableError {
    print(e.description)
}
