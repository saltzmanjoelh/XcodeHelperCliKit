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
import DockerProcess

let emptyProcessResult = ProcessResult(output:nil, error:nil, exitCode:0)
struct Fixture: XcodeHelpable {
    

    
    var expectations: [CliOption: [String]]?
    init(){}
    init(expectations:[CliOption: [String]]){
        self.expectations = expectations
    }
    
    var testUpdateMacOsPackages: ((String) -> ProcessResult)?
    @discardableResult
    public func updateMacOsPackages(at sourcePath: String) throws -> ProcessResult
    {
        return (testUpdateMacOsPackages?(sourcePath))!
    }
    
    var testUpdateDockerPackages: ((String, String, String) -> ProcessResult)?
    @discardableResult
    public func updateDockerPackages(at sourcePath: String, in dockerImageName: String, with persistentVolumeName: String) throws -> ProcessResult {
        return (testUpdateDockerPackages?(sourcePath, dockerImageName, persistentVolumeName))!
    }
    
    var testDockerBuild: ((String, [DockerRunOption]?, BuildConfiguration, String, String?) -> ProcessResult)?
    @discardableResult  func dockerBuild(_ sourcePath: String, with runOptions: [DockerRunOption]?, using configuration: BuildConfiguration, in dockerImageName: String, persistentVolumeName persistentBuildDirectory: String?) throws -> ProcessResult {
        return (testDockerBuild?(sourcePath, runOptions, configuration, dockerImageName, persistentBuildDirectory))!
    }
    
    var testClean: ((String) -> ProcessResult)?
    @discardableResult func clean(sourcePath: String) throws -> ProcessResult
    {
        return (testClean?(sourcePath))!
    }
    
    var testSymlinkDependencies: ((String) -> Void)?
    @discardableResult func symlinkDependencies(at sourcePath: String) throws
    {
        testSymlinkDependencies?(sourcePath)
    }
    
    var testGenerateXcodeProject: ((String) -> ProcessResult )?
    @discardableResult func generateXcodeProject(at sourcePath: String) throws -> ProcessResult {
        return (testGenerateXcodeProject?(sourcePath))!
    }
    
    var testCreateArchive: ((String, [String], Bool) -> ProcessResult)?
    @discardableResult func createArchive(at archivePath: String, with filePaths: [String], flatList: Bool) throws -> ProcessResult
    {
        return (testCreateArchive?(archivePath, filePaths, flatList))!
    }
    
    var testUploadArchive: ((String, String, String, String, String) -> Void)?
    @discardableResult func uploadArchive(at archivePath: String, to s3Bucket: String, in region: String, key: String, secret: String) throws
    {
        (testUploadArchive?(archivePath, s3Bucket, region, key, secret))
    }
    
    var testUploadArchiveWithCredentials: ((String, String, String, String) -> Void)?
    @discardableResult func uploadArchive(at archivePath: String, to s3Bucket: String, in region: String, using credentialsPath: String) throws
    {
        (testUploadArchiveWithCredentials?(archivePath, s3Bucket, region, credentialsPath))
    }
    
    var testIncrementGitTag: ((GitTagComponent, String) -> String)?
    @discardableResult func incrementGitTag(component: GitTagComponent, at sourcePath: String) throws -> String
    {
        return (testIncrementGitTag?(component, sourcePath))!
    }
    var testGitTag: ((String, String) throws -> Void)?
    func gitTag(_ tag: String, repo sourcePath: String) throws
    {
        (try testGitTag?(tag, sourcePath))
    }
    var testPushGitTag: ((String, String) -> Void)?
    func pushGitTag(tag: String, at sourcePath: String) throws
    {
        (testPushGitTag?(tag, sourcePath))
    }
    
    var testCreateXcarchive: ((String, String, String) throws -> String)?
    @discardableResult func createXcarchive(in dirPath: String, with binaryPath: String, from schemeName: String) throws -> String
    {
        return (try testCreateXcarchive?(dirPath, binaryPath, schemeName))!
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
        let options = copy.optionalArguments ?? [CliOption]()
        copy.optionalArguments = prepare(options: options, with: fixtures)
        return copy
    }
    func preparedWithRequiredArg(fixtures: [CliOption]) -> CliOption {
        var copy = self
        let options = copy.requiredArguments ?? [CliOption]()
        copy.requiredArguments = prepare(options: options, with: fixtures)
        return copy
    }
    func preparedWithOptionalArg(fixtureIndex: [CliOption: [String]]) -> CliOption {
        var copy = self
        let options = copy.optionalArguments ?? [CliOption]()
        copy.optionalArguments = prepare(options: options, with: fixtureIndex)
        return copy
    }
    func preparedWithRequiredArg(fixtureIndex: [CliOption: [String]]) -> CliOption {
        var copy = self
        let options = copy.requiredArguments ?? [CliOption]()
        copy.requiredArguments = prepare(options: options, with: fixtureIndex)
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
            }else{
                var option = valuePair.key
                option.values = valuePair.value
                copy.append(option)
            }
        }
        return copy
    }
    return options
}
