//
//  XcodeHelpableFixture.swift
//  XcodeHelperCli
//
//  Created by Joel Saltzman on 11/24/16.
//
//

import XCTest
import ProcessRunner
import CliRunnable
import DockerProcess
import xcodeproj
import XcodeHelperKit
@testable import XcodeHelperCliKit

let emptyProcessResult = ProcessResult(output:nil, error:nil, exitCode:0)
struct XcodeHelpableFixture: XcodeHelpable {

//    var expectations: [CliOption: [String]]?
    init(){}
//    init(expectations:[CliOption: [String]]){
//        self.expectations = expectations
//    }
    
    var testXcodeProjectPath: ((String) throws -> String)?
    func xcodeProjectPath(inSourcePath sourcePath: String) throws -> String {
        return (try testXcodeProjectPath?(sourcePath))!
    }
    
    var testProjectBuilderPath: ((String) throws -> String)?
    func projectBuilderPath(inSourcePath sourcePath: String) throws -> String {
        return (try testProjectBuilderPath?(sourcePath))!
    }
    
    var testPackageTargets: ((String) throws -> [String])?
    func packageTargets(inProject xcprojPath: String) throws -> [String] {
        return (try testPackageTargets?(xcprojPath))!
    }
    
    
    var testUpdateMacOsPackages: ((String) -> ProcessResult)?
    @discardableResult
    public func updateMacOsPackages(at sourcePath: String, shouldLog: Bool) throws -> ProcessResult
    {
        return (testUpdateMacOsPackages?(sourcePath))!
    }
    
    var testUpdateDockerPackages: ((String, String, String, Bool) -> ProcessResult)?
    @discardableResult
    public func updateDockerPackages(at sourcePath: String, inImage dockerImageName: String, withVolume persistentVolumeName: String, shouldLog: Bool) throws -> ProcessResult {
        return (testUpdateDockerPackages?(sourcePath, dockerImageName, persistentVolumeName, shouldLog))!
    }
    
    var testDockerBuild: ((String, [DockerRunOption]?, BuildConfiguration, String, String?) -> ProcessResult)?
    @discardableResult  func dockerBuild(_ sourcePath: String, with runOptions: [DockerRunOption]?, using configuration: BuildConfiguration, in dockerImageName: String, persistentVolumeName persistentBuildDirectory: String?, shouldLog: Bool) throws -> ProcessResult {
        return (testDockerBuild?(sourcePath, runOptions, configuration, dockerImageName, persistentBuildDirectory))!
    }
    var testAddDockerBuildPhase: ((String, String) throws -> ProcessResult)?
    func addDockerBuildPhase(toTarget target: String, inProject xcprojPath: String) throws -> ProcessResult {
        return (try testAddDockerBuildPhase?(target, xcprojPath))!
    }
    
    var testAddBuildPhases: (([String : [PBXShellScriptBuildPhase]], String) -> Void)?
    func addBuildPhases(_ buildPhases: [String : [PBXShellScriptBuildPhase]], toProject xcprojPath: String) throws {
        testAddBuildPhases?(buildPhases, xcprojPath)
    }
    
    
    var testClean: ((String) -> ProcessResult)?
    @discardableResult func clean(sourcePath: String, shouldLog: Bool) throws -> ProcessResult
    {
        return (testClean?(sourcePath))!
    }
    
    var testSymlinkDependencies: ((String) -> Void)?
    func symlinkDependencies(at sourcePath: String, shouldLog: Bool) throws
    {
        testSymlinkDependencies?(sourcePath)
    }
    
    var testGenerateXcodeProject: ((String) -> ProcessResult )?
    @discardableResult func generateXcodeProject(at sourcePath: String, shouldLog: Bool) throws -> ProcessResult {
        return (testGenerateXcodeProject?(sourcePath))!
    }
    
    var testRecursivePackagePaths: ((String) -> [String] )?
    @available(OSX 10.11, *)
    func recursivePackagePaths(at sourcePath: String) -> [String] {
        return (testRecursivePackagePaths?(sourcePath))!
    }
    
    var testCreateArchive: ((String, [String], Bool) -> ProcessResult)?
    @discardableResult func createArchive(at archivePath: String, with filePaths: [String], flatList: Bool, shouldLog: Bool) throws -> ProcessResult
    {
        return (testCreateArchive?(archivePath, filePaths, flatList))!
    }
    
    var testUploadArchive: ((String, String, String, String, String) -> Void)?
    func uploadArchive(at archivePath: String, to s3Bucket: String, in region: String, key: String, secret: String, shouldLog: Bool) throws
    {
        (testUploadArchive?(archivePath, s3Bucket, region, key, secret))
    }
    
    var testUploadArchiveWithCredentials: ((String, String, String, String) -> Void)?
    func uploadArchive(at archivePath: String, to s3Bucket: String, in region: String, using credentialsPath: String, shouldLog: Bool) throws
    {
        (testUploadArchiveWithCredentials?(archivePath, s3Bucket, region, credentialsPath))
    }
    
    var testGetGitTag: ((String, Bool) throws -> String)?
    func getGitTag(at sourcePath: String, shouldLog: Bool) throws -> String {
        return (try testGetGitTag?(sourcePath, shouldLog))!
    }
    
    var testIncrementGitTag: ((GitTagComponent, String, Bool) -> String)?
    @discardableResult func incrementGitTag(component: GitTagComponent, at sourcePath: String, shouldLog: Bool) throws -> String
    {
        return (testIncrementGitTag?(component, sourcePath, shouldLog))!
    }
    var testGitTag: ((String, String) throws -> ProcessResult)?
    func gitTag(_ tag: String, repo sourcePath: String, shouldLog: Bool) throws -> ProcessResult
    {
        return (try testGitTag?(tag, sourcePath))!
    }
    var testPushGitTag: ((String, String) -> Void)?
    func pushGitTag(tag: String, at sourcePath: String, shouldLog: Bool) throws
    {
        (testPushGitTag?(tag, sourcePath))
    }
    
    var testCreateXcarchive: ((String, String, String) throws -> ProcessResult)?
    @discardableResult func createXcarchive(in dirPath: String, with binaryPath: String, from schemeName: String, shouldLog: Bool) throws -> ProcessResult
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
