//
//  Fixture.swift
//  XcodeHelperCli
//
//  Created by Joel Saltzman on 11/24/16.
//
//

import XCTest
import XcodeHelperKit
@testable import XcodeHelperCliKit
import SynchronousProcess
import CliRunnable

let emptyProcessResult = ProcessResult(output:nil, error:nil, exitCode:0)
struct Fixture: XcodeHelpable {
    var expectations: [CliOption: [String]]?
    init(){}
    init(expectations:[CliOption: [String]]){
        self.expectations = expectations
    }
    @discardableResult func fetchPackages(at sourcePath: String, forLinux:Bool, inDockerImage imageName: String?) throws -> ProcessResult
    {
        return (output:nil, error:nil, exitCode:0)
    }
    
    var testUpdatePackages: ((String, Bool, String) -> ProcessResult)?
    @discardableResult func updatePackages(at sourcePath: String, forLinux: Bool, inDockerImage imageName: String) throws -> ProcessResult
    {
        return (testUpdatePackages?(sourcePath, forLinux, imageName))!
    }
    
    var testBuild: ((String, BuildConfiguration, String, Bool) -> ProcessResult)?
    @discardableResult func build(source sourcePath: String, usingConfiguration configuration:BuildConfiguration, inDockerImage imageName: String, removeWhenDone: Bool) throws -> ProcessResult
    {
        return (testBuild?(sourcePath, configuration, imageName, removeWhenDone))!
    }
    
    var testClean: ((String) -> ProcessResult)?
    @discardableResult func clean(sourcePath: String) throws -> ProcessResult
    {
        return (testClean?(sourcePath))!
    }
    
    var testSymlinkDependencies: ((String) -> Void)?
    @discardableResult func symlinkDependencies(sourcePath: String) throws
    {
        testSymlinkDependencies?(sourcePath)
    }
    @discardableResult func createArchive(at archivePath: String, with filePaths: [String], flatList: Bool) throws -> ProcessResult
    {
        return (output:nil, error:nil, exitCode:0)
    }
    @discardableResult func uploadArchive(at archivePath: String, to s3Bucket: String, in region: String, key: String, secret: String) throws
    {
        
    }
    @discardableResult func uploadArchive(at archivePath: String, to s3Bucket: String, in region: String, using credentialsPath: String) throws
    {
        
    }
    @discardableResult func incrementGitTag(components: [GitTagComponent], at sourcePath: String) throws -> String
    {
        return "1.0.0"
    }
    func gitTag(tag: String, at sourcePath: String) throws
    {
        
    }
    func pushGitTag(tag: String, at sourcePath: String) throws
    {
        
    }
    @discardableResult func createXcarchive(in dirPath: String, with binaryPath: String, from schemeName: String) throws -> String
    {
        return "tmp/app.xcarchive"
    }
}

extension CliOption: Hashable {
    public var hashValue: Int {
        if let key = keys.last {
            return key.hashValue
        }
        return 0
    }
    
    static func == (lhs: CliOption, rhs: CliOption) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}
extension CliOption {
    func preparedWithOptionalArg(fixtures: [CliOption]) -> CliOption {
        var copy = self
        copy.optionalArguments = prepare(options: copy.optionalArguments, with: fixtures)
        return copy
    }
    func preparedWithRequiredArg(fixtures: [CliOption]) -> CliOption {
        var copy = self
        copy.requiredArguments = prepare(options: copy.requiredArguments, with: fixtures)
        return copy
    }
    func preparedWithOptionalArg(fixtureIndex: [CliOption: [String]]) -> CliOption {
        var copy = self
        copy.optionalArguments = prepare(options: copy.optionalArguments, with: fixtureIndex)
        return copy
    }
    func preparedWithRequiredArg(fixtureIndex: [CliOption: [String]]) -> CliOption {
        var copy = self
        copy.requiredArguments = prepare(options: copy.requiredArguments, with: fixtureIndex)
        return copy
    }
}
func prepare(options: [CliOption]?, with fixtures: [CliOption]) -> [CliOption]? {
    var fixtureIndex = [CliOption: [String]]()
    for option in fixtures {
        let key: String = option.keys.joined(separator:",")
        print("index: \(key)")
        fixtureIndex[option] = [UUID().uuidString]
    }
    return prepare(options: options, with: fixtureIndex)
}
func prepare(options: [CliOption]?, with fixtureIndex: [CliOption:[String]]) -> [CliOption]? {
    if var copy = options {
        for valuePair in fixtureIndex {
            if let index = copy.index(of: valuePair.key) {
                copy[index].values = valuePair.value
            }
        }
        return copy
    }
    return options
}
