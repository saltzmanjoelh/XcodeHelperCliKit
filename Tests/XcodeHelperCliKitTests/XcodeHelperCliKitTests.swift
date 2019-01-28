//
//  XcodeHelperCliTests.swift
//  XcodeHelperCliTests
//
//  Created by Joel Saltzman on 7/30/16.
//
//

import XCTest
import ProcessRunner
import CliRunnable
import DockerProcess
import XcodeHelperKit
@testable import XcodeHelperCliKit

//MARK: TESTS

class XcodeHelperCliKitTests: XCTestCase {
    
    let executableRepoURL = "https://github.com/saltzmanjoelh/HelloSwift" //we use a different repo for testing because this repo isn't meant for linux
    let libraryRepoURL = "https://github.com/saltzmanjoelh/Hello"
    let dependenciesURL = "https://github.com/saltzmanjoelh/HelloDependencies.git"
    var sourcePath : String?
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        if sourcePath != nil {
            ProcessRunner.synchronousRun("/bin/rm", arguments: ["-Rf", sourcePath!])
        }
    }
    
    //returns the temp dir that we cloned into
    private func cloneToTempDirectory(repoURL:String) -> String? {
        //use /tmp instead of FileManager.default.temporaryDirectory because Docker for mac specifies /tmp by default and not /var...
//        guard let tempDir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).path.appending("/XcodeHelperCliTests/\(UUID())") else{
//            XCTFail("Failed to get user dir")
//            return nil
//        }
        let tempDir = "/tmp/\(UUID())"
        if !FileManager.default.fileExists(atPath: tempDir) {
            do {
                try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
            }catch _{
                
            }
        }
        let cloneResult = ProcessRunner.synchronousRun("/usr/bin/env", arguments: ["git", "clone", repoURL, tempDir], printOutput: false)
        XCTAssert(cloneResult.exitCode == 0, "Failed to clone repo: \(String(describing: cloneResult.error))")
        XCTAssert(FileManager.default.fileExists(atPath: tempDir))
        print("done cloning temp dir: \(tempDir)")
        return tempDir
    }
    
    func testGetYamlPathFromArgs_short() {
        let fixture = XcodeHelpableFixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        let path = UUID().uuidString
        let args = ["appPath", XCHelper.changeDirectoryOption.short.rawValue, path]
        
        let result = xchelper.getYamlPathFromArgs(args)
        
        XCTAssertEqual(result, path)
    }
    func testGetYamlPathFromArgs_long() {
        let fixture = XcodeHelpableFixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        let path = UUID().uuidString
        let args = ["appPath", XCHelper.changeDirectoryOption.long.rawValue, path]
        
        let result = xchelper.getYamlPathFromArgs(args)
        
        XCTAssertEqual(result, path)
    }
    func testGetYamlPathFromEnv_env() {
        let fixture = XcodeHelpableFixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        let path = UUID().uuidString
        let env = ["COMMAND_\(XCHelper.changeDirectoryOption.envSuffix.rawValue)": path]
        
        let result = xchelper.getYamlPathFromEnv(env)
        
        XCTAssertEqual(result, path)
    }
    func testGetYamlPath_args() {
        let fixture = XcodeHelpableFixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        let path = UUID().uuidString
        let args = ["appPath", XCHelper.changeDirectoryOption.long.rawValue, path]
        
        let result = xchelper.getYamlPath(args: args, env: [:])
        
        XCTAssertEqual(result, path+".xcodehelper")
    }
    func testGetYamlPath_env() {
        let fixture = XcodeHelpableFixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        let path = UUID().uuidString
        let env = ["COMMAND_\(XCHelper.changeDirectoryOption.envSuffix.rawValue)": path]
        
        let result = xchelper.getYamlPath(args: [], env: env)
        
        XCTAssertEqual(result, path+".xcodehelper")
    }
    
    
    func testHelpableStrings() {
        let fixture = XcodeHelpableFixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        
        XCTAssertNotNil(xchelper.appName)
        XCTAssertNotNil(xchelper.description)
        XCTAssertNotNil(xchelper.appUsage)
    }
    func testCliOptionGroups() {
        let fixture = XcodeHelpableFixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        
        XCTAssertEqual(xchelper.cliOptionGroups.count, 1)
        XCTAssertEqual(xchelper.cliOptionGroups.first?.options.count, 8)
    }
    
    func testParseSourceCodePath_custom(){
        let xchelper = XCHelper(xcodeHelpable:XcodeHelper())
        let key = XCHelper.updateMacOsPackages.changeDirectory.keys.first!
        let customPath = "/tmp/path"
        let argumentIndex = [key:[customPath]]
        
        let result = xchelper.parseSourceCodePath(from: argumentIndex, with: key)
        
        XCTAssertEqual(result, customPath)
    }
    
    //MARK: Update Packages
    func testHandleUpdateDockerPackages() {
        do{
            let path = "/tmp/\(UUID().uuidString)"
            var didCallUpdatePackages = false
            let expectations = [XCHelper.updateDockerPackages.changeDirectory: [path],
                                XCHelper.updateDockerPackages.imageName: ["image"],
                                XCHelper.updateDockerPackages.volumeName: ["platform"]]
            var fixture = XcodeHelpableFixture()
            fixture.testUpdateDockerPackages = { (sourcePath:String, dockerImageName: String, volumeName: String, shouldLog: Bool) -> ProcessResult in
                didCallUpdatePackages = true
                XCTAssertEqual(sourcePath, expectations[XCHelper.updateDockerPackages.changeDirectory]?.first)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.updateDockerPackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUpdateDockerPackages(option: option)
            
            XCTAssertTrue(didCallUpdatePackages, "Failed to call updateDockerPackages on XcodeHelpable")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleUpdateDockerPackages_missingImageName() {
        var didCallUpdatePackages = false
        do{
            let path = "/tmp/\(UUID().uuidString)"
            let expectations = [XCHelper.updateDockerPackages.changeDirectory: [path]]
            var fixture = XcodeHelpableFixture()
            fixture.testUpdateDockerPackages = { (sourcePath:String, dockerImageName: String, volumeName: String, shouldLog: Bool) -> ProcessResult in
                didCallUpdatePackages = true
                XCTAssertEqual(dockerImageName, "swift")//it should default to swift if it's missing
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = xchelper.updateDockerPackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUpdateDockerPackages(option: option)
            
        }catch XcodeHelperError.updatePackages(let message){
            XCTAssertTrue(message.contains("image name"), "Image name error should have been thrown.")
            XCTAssertTrue(didCallUpdatePackages)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
//    func testHandleUpdateDockerPackages_missingVolumeName() {
//        do{
//            let path = "/tmp/\(UUID().uuidString)"
//            let expectations = [XCHelper.updateDockerPackages.changeDirectory: [path],
//                                XCHelper.updateDockerPackages.imageName: ["image"]]
//            let xchelper = XCHelper(xcodeHelpable: XcodeHelpableFixture())
//            let option = xchelper.updateDockerPackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
//            
//            try xchelper.handleUpdateDockerPackages(option: option)
//            
//            XCTFail("An error should have been thrown about missing the volume name.")
//        }catch XcodeHelperError.updatePackages(let message){
//            XCTAssertTrue(message.contains("volume name"), "Volume name error should have been thrown.")
//        }catch let e{
//            XCTFail("Error: \(e)")
//        }
//    }
    func testHandleUpdateMacOsPackages() {
        do{
            let path = "/tmp/\(UUID().uuidString)"
            var didCallUpdatePackages = false
            let expectations = [XCHelper.updateMacOsPackages.changeDirectory: [path]]
            var fixture = XcodeHelpableFixture()
            fixture.testUpdateMacOsPackages = { (sourcePath: String) -> ProcessResult in
                didCallUpdatePackages = true
                XCTAssertEqual(sourcePath, expectations[XCHelper.updateMacOsPackages.changeDirectory]?.first)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.updateMacOsPackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUpdatePackages(option: option)
            
            XCTAssertTrue(didCallUpdatePackages, "Failed to call updateMacOsPackages on XcodeHelpable")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleUpdatePackages_generateXcodeProject() {
        do{
            let path = "/tmp/\(UUID().uuidString)"
            let expectations = [XCHelper.updateMacOsPackages.changeDirectory: [path],
                                XCHelper.updateMacOsPackages.generateXcodeProject: ["true"]]
            var fixture = XcodeHelpableFixture()
            fixture.testUpdateMacOsPackages = { (sourcePath:String) -> ProcessResult in
                return emptyProcessResult
            }
            var didCallGenerateXcodeProject = false
            fixture.testGenerateXcodeProject = { (sourcePath:String) -> ProcessResult in
                didCallGenerateXcodeProject = true
                XCTAssertEqual(sourcePath, path)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.updateMacOsPackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUpdatePackages(option: option)

            XCTAssertTrue(didCallGenerateXcodeProject, "Failed to call generateXcodeProject on XcodeHelpable")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    @available(OSX 10.11, *)
    func testHandleUpdatePackages_recursiveXcodeProjects() {
        do{
            let path = "/tmp/\(UUID().uuidString)"
            let expectations = [XCHelper.updateMacOsPackages.changeDirectory: [path],
                                XCHelper.updateMacOsPackages.recursive: ["true"]]
            var fixture = XcodeHelpableFixture()
            fixture.testUpdateMacOsPackages = { (sourcePath:String) -> ProcessResult in
                return emptyProcessResult
            }
            var didCallRecursiveXcodeProjects = false
            fixture.testRecursivePackagePaths = { (sourcePath:String) -> [String] in
                didCallRecursiveXcodeProjects = true
                XCTAssertEqual(sourcePath, path)
                return []
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.updateMacOsPackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUpdatePackages(option: option)
            
            XCTAssertTrue(didCallRecursiveXcodeProjects, "Failed to call recursiveXcodeProjects on XcodeHelpable")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    @available(OSX 10.11, *)
    func testHandleUpdatePackages_dockerBuildPhase() {
        do{
            let path = "/tmp/\(UUID().uuidString)"
            let expectations = [XCHelper.updateMacOsPackages.changeDirectory: [path],
                                XCHelper.updateMacOsPackages.dockerBuildPhase: ["true"]]
            var fixture = XcodeHelpableFixture()
            fixture.testUpdateMacOsPackages = { (sourcePath:String) -> ProcessResult in
                return emptyProcessResult
            }
            fixture.testPackageTargets = { (sourcePath: String) -> [String] in
                return [UUID().uuidString]
            }
            var didAddDockerBuildPhase = false
            fixture.testAddDockerBuildPhase = { (target: String, sourcePath: String) -> ProcessResult in
                didAddDockerBuildPhase = true
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.updateMacOsPackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUpdatePackages(option: option)
            
            XCTAssertTrue(didAddDockerBuildPhase, "Failed to call add docker build phase")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUpdateRecursiveProjects() {
        do{
            let sourcePath = cloneToTempDirectory(repoURL: dependenciesURL)!
            let xchelper = XCHelper()
            let fixtures = [XCHelper.updateMacOsPackages.changeDirectory: [sourcePath],
                            XCHelper.updateMacOsPackages.recursive: ["true"]]
            let option =  xchelper.updateMacOsPackagesOption.preparedWithOptionalArg(fixtureIndex: fixtures)
            
            let result = try xchelper.handleUpdatePackages(option: option)
            
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.output)
            XCTAssertEqual(result.exitCode, 0)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
//    func testHandleUpdatePackages_symlinkDependencies() {
//        do{
//            let path = "/tmp/\(UUID().uuidString)"
//            let expectations = [XCHelper.updateMacOsPackages.changeDirectory: [path],
//                                XCHelper.updateMacOsPackages.symlink: ["true"]]
//            var fixture = XcodeHelpableFixture()
//            fixture.testUpdateMacOsPackages = { (sourcePath:String) -> ProcessResult in
//                return emptyProcessResult
//            }
//            var didCallSymlinkDependencies = false
//            fixture.testSymlinkDependencies = { (sourcePath:String) -> Void in
//                didCallSymlinkDependencies = true
//                XCTAssertEqual(sourcePath, path)
//            }
//            let xchelper = XCHelper(xcodeHelpable:fixture)
//            let option = xchelper.updateMacOsPackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
//
//            try xchelper.handleUpdatePackages(option: option)
//
//            XCTAssertTrue(didCallSymlinkDependencies, "Failed to call symlinkDependencies on XcodeHelpable")
//        }catch let e{
//            XCTFail("Error: \(e)")
//        }
//    }
    
    private func buildConfigurationTest(buildConfiguration: BuildConfiguration){
        do{
            let expectations = [XCHelper.dockerBuild.buildConfiguration: ["\(buildConfiguration)"],
                                XCHelper.dockerBuild.imageName: ["image"]]
            var fixture = XcodeHelpableFixture()
            //dockerBuild() throws -> ProcessResult
            fixture.testDockerBuild = { (sourcePath: String, with: [DockerRunOption]?, using: BuildConfiguration, in: String, persistentBuildDirectory: String?) -> ProcessResult in
                XCTAssertEqual(using, buildConfiguration)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.dockerBuildOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleDockerBuild(option: option)
            
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    //MARK: Build
    func testHandleBuild_buildConfiguration_release() {
        buildConfigurationTest(buildConfiguration: .release)
    }
    func testHandleBuild_buildConfiguration_debug() {
        buildConfigurationTest(buildConfiguration: .debug)
    }
    func testHandleBuild_missingBuildConfiguration() {
        do{
            let xchelper = XCHelper(xcodeHelpable:XcodeHelpableFixture())
            let option = xchelper.dockerBuildOption
            try xchelper.handleDockerBuild(option: option)
            
        }catch XcodeHelperError.dockerBuild(let message, _){
            XCTAssertTrue(message.contains(XCHelper.dockerBuild.buildConfiguration.keys.first!), "buildConfiguration error should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleBuild_missingImageName() {
        do{
            let xchelper = XCHelper(xcodeHelpable:XcodeHelpableFixture())
            var option = xchelper.dockerBuildOption
            option.optionalArguments = prepare(options: option.optionalArguments,
                                               with: [XCHelper.dockerBuild.buildConfiguration: ["\(BuildConfiguration.debug)"]])
            
            try xchelper.handleDockerBuild(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.dockerBuild(let message, _){
            XCTAssertTrue(message.contains(XCHelper.dockerBuild.imageName.keys.first!), "imageName error should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleBuild_buildOnSuccessFailure() {
        do{
            let path = "/tmp/\(UUID().uuidString)"
            let expectations = [XCHelper.dockerBuild.changeDirectory: [path],
                                XCHelper.dockerBuild.buildConfiguration: ["\(BuildConfiguration.debug)"],
                                XCHelper.dockerBuild.imageName: ["image"],
                                XCHelper.dockerBuild.volumeName: ["platform"],
                                XCHelper.dockerBuild.buildOnSuccess: ["/tmp"]]
            var fixture = XcodeHelpableFixture()
            fixture.testDockerBuild = { (_: String, with: [DockerRunOption]?, using: BuildConfiguration, in: String, persistentVolumeName: String?) -> ProcessResult in
                XCTFail("dockerBuild should NOT have been called.")
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.dockerBuildOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleDockerBuild(option: option)
            
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testLastBuildWasSuccess() {
        guard ProcessInfo.processInfo.environment["TRAVIS_OS_NAME"] == nil else { return }
        do{
            let xchelper = XCHelper(xcodeHelpable:XcodeHelpableFixture())
            guard let buildURL = getCurrentBuildURL() else {
                XCTFail("Failed nil returned from getCurrentBuildURL()")
                return
            }
            
            let result = try xchelper.lastBuildWasSuccess(at: buildURL)
            
            XCTAssertTrue(result)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    //XcodeHelperCliKit..lastBuildWasSuccess
    func testLastBuildWasSuccess_missingLogURL(){
        guard ProcessInfo.processInfo.environment["TRAVIS_OS_NAME"] == nil else { return }
        do{
            let xchelper = XCHelper(xcodeHelpable:XcodeHelpableFixture())
            
            let result = try xchelper.lastBuildWasSuccess(at: URL.init(fileURLWithPath: UUID().uuidString))
            
            XCTAssertFalse(result)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testXcodeBuildLogDirectory(){
        guard ProcessInfo.processInfo.environment["TRAVIS_OS_NAME"] == nil else { return }
        let xcodeBuildDir = "/target/Build/Products/"
        let xchelper = XCHelper(xcodeHelpable:XcodeHelpableFixture())
        
        let result = xchelper.xcodeBuildLogDirectory(from: xcodeBuildDir)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.path, "/target/Logs/Build")
    }
    
    func testURLOfLastBuildLog_noFiles(){
        guard ProcessInfo.processInfo.environment["TRAVIS_OS_NAME"] == nil else { return }
        let xchelper = XCHelper(xcodeHelpable:XcodeHelpableFixture())
        guard let buildURL = getCurrentBuildURL() else {//get the build directory for this
            XCTFail("Failed to find XcodeHelperCli build directory")
            return
        }
        //clear all logs
        ProcessRunner.synchronousRun("/bin/bash", arguments: ["-c", "cd \(buildURL.path) && rm *.xcactivitylog"])
        
        let result = xchelper.URLOfLastBuildLog(at: buildURL)//get the most recent build log
        
        XCTAssertNil(result)
    }
    
    func getCurrentBuildURL() -> URL? {
        guard ProcessInfo.processInfo.environment["TRAVIS_OS_NAME"] == nil else { return nil }
        //maybe look at prefs later
        var derivedDataURL: URL
        if #available(OSX 10.12, *) {
            derivedDataURL = FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent("Library", isDirectory: true)
                                .appendingPathComponent("Developer", isDirectory: true)
                                .appendingPathComponent("Xcode", isDirectory: true)
                                .appendingPathComponent("DerivedData", isDirectory: true)
        } else {
            // Fallback on earlier versions
            derivedDataURL = URL(fileURLWithPath: "~/Library/Developer/Xcode/DerivedData")
        }
        let prefixes = ["XcodeHelperCli", "XcodeHelper"] //tests may be running from XcodeHelper workspace
        for prefix in prefixes {
            for directory in FileManager.default.subpaths(atPath: derivedDataURL.path)! {
                if directory.hasPrefix(prefix) {
                    return derivedDataURL.appendingPathComponent(directory, isDirectory: true)
                            .appendingPathComponent("Logs", isDirectory: true)
                            .appendingPathComponent("Build", isDirectory: true)
                }
            }
        }
        return nil
    }
    
    func testDecodeXcactivityLog() {
        guard ProcessInfo.processInfo.environment["TRAVIS_OS_NAME"] == nil else { return }
        let xchelper = XCHelper(xcodeHelpable:XcodeHelpableFixture())
        guard let buildURL = getCurrentBuildURL() else {//get the build directory for this
            XCTFail("Failed to find XcodeHelperCli build directory")
            return
        }
        guard let log = xchelper.URLOfLastBuildLog(at: buildURL) else { //get the most recent build log
            XCTFail("Failed to get build log: \(buildURL)")
            return
        }
        
        do{
            let result = try xchelper.decode(xcactivityLog: URL.init(fileURLWithPath: log.path))
            
            XCTAssertTrue(result!.contains("Build succeeded")) //it should contain "Build succeeded" in order for this test to run
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testDecodeXcactivityLog_invalidFile() {
        do{
            let xchelper = XCHelper(xcodeHelpable:XcodeHelpableFixture())
            
            _ = try xchelper.decode(xcactivityLog: URL.init(fileURLWithPath: "/tmp/invalid"))
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperCliError.xcactivityLogDecode(_){
            
        }catch let e{
            XCTFail("Error: \(e)")
        }
        
    }
    
    func testHandleDockerBuild() {
        guard ProcessInfo.processInfo.environment["TRAVIS_OS_NAME"] == nil else { return }
        do{
            let expectations = [XCHelper.dockerBuild.buildConfiguration: ["\(BuildConfiguration.debug)"],
                                XCHelper.dockerBuild.changeDirectory: ["/tmp"],
                                XCHelper.dockerBuild.imageName: ["image"],
                                XCHelper.dockerBuild.buildOnSuccess: [getCurrentBuildURL()!.path]]
            var fixture = XcodeHelpableFixture()
            var didCallDockerBuild = false
            fixture.testDockerBuild = { (sourcePath: String, withDockerRunOptions: [DockerRunOption]?, usingBuildConfiguration: BuildConfiguration, inDockerImage: String, persistentBuildDirectory: String?) -> ProcessResult in
                didCallDockerBuild = true
                XCTAssertEqual("\(usingBuildConfiguration)", expectations[XCHelper.dockerBuild.buildConfiguration]?.first!)
                XCTAssertEqual(sourcePath, expectations[XCHelper.dockerBuild.changeDirectory]?.first!)
                XCTAssertEqual(inDockerImage, expectations[XCHelper.dockerBuild.imageName]?.first!)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = xchelper.dockerBuildOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleDockerBuild(option: option)

            XCTAssertTrue(didCallDockerBuild, "Failed to call dockerBuild on xcodeHelpable.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }

    
    //MARK: Symlink Dependencies
    func testSymlinkDependencies() {
        do{
            var didCallSymlinkDependencies = false
            let expectations = [XCHelper.symlinkDependencies.changeDirectory: ["/tmp"]]
            var fixture = XcodeHelpableFixture()
            fixture.testSymlinkDependencies = { (sourcePath: String) in
                didCallSymlinkDependencies = true
                XCTAssertEqual(sourcePath, expectations[XCHelper.symlinkDependencies.changeDirectory]?.first!)
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.symlinkDependenciesOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleSymlinkDependencies(option: option)
            
            XCTAssertTrue(didCallSymlinkDependencies)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    //MARK: Create Archive
    func testCreateArchive_missingPaths(){
        do{
            let xchelper = XCHelper(xcodeHelpable: XcodeHelpableFixture())
            let option = xchelper.createArchiveOption
            
            try xchelper.handleCreateArchive(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.createArchive(let message){
            XCTAssertTrue(message.contains("paths"), "An error about missing paths should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testCreateArchive_missingArchivePath(){
        do{
            let expectations = [XCHelper.createArchive.command:[String]()]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createArchiveOption], with: expectations)!.first
            
            try xchelper.handleCreateArchive(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.createArchive(let message){
            XCTAssertTrue(message.contains("archive path"), "An error about missing archive path should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testCreateArchive_missingFilePaths(){
        do{
            let expectations = [XCHelper.createArchive.command:["/tmp/archive.tar"]]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createArchiveOption], with: expectations)!.first
            
            try xchelper.handleCreateArchive(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.createArchive(let message){
            XCTAssertTrue(message.contains("any files"), "An error not providing any files should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testCreateArchive(){
        do{
            var didCallCreateArchive = false
            let expectations = [XCHelper.createArchive.command: ["/tmp/archive.tar", "/tmp/file.swift"],
                                XCHelper.createArchive.flatList: ["true"]]
            var fixture = XcodeHelpableFixture()
            fixture.testCreateArchive = { (archivePath: String, filePaths: [String], flatList: Bool) in
                didCallCreateArchive = true
                XCTAssertEqual(archivePath, expectations[XCHelper.createArchive.command]?[0])
                XCTAssertEqual(filePaths.first, expectations[XCHelper.createArchive.command]?[1])
                XCTAssertTrue(flatList)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createArchiveOption], with: expectations)!.first?.preparedWithOptionalArg(fixtureIndex: [XCHelper.createArchive.flatList: expectations[XCHelper.createArchive.flatList]!])
            
            try xchelper.handleCreateArchive(option: option!)
            
            XCTAssertTrue(didCallCreateArchive)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    //MARK: Upload Archive
    func testUploadFile_missingArchivePath(){
        do{
            let xchelper = XCHelper(xcodeHelpable: XcodeHelpableFixture())
            let option = xchelper.uploadFileOption
            
            try xchelper.handleUploadFile(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadFile(let message){
            XCTAssertTrue(message.contains("path to the archive"), "An error about the path to the archive should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadFile_missingBucketName(){
        do{
            let expectations = [XCHelper.uploadFile.command:["/tmp/archive.tar"]]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.uploadFileOption], with: expectations)!.first
            
            try xchelper.handleUploadFile(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadFile(let message){
            XCTAssertTrue(message.contains("bucket"), "An error not providing the S3 bucket should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadFile_missingRegion(){
        do{
            let expectations = [XCHelper.uploadFile.command: ["/tmp/archive.tar"],
                                XCHelper.uploadFile.bucket: ["bucketName"]]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadFileOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations)
            
            try xchelper.handleUploadFile(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadFile(let message){
            XCTAssertTrue(message.contains("region"), "An error not providing the region should have been thrown instead of \(message).")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadFile_missingAccess(){
        do{
            let expectations = [XCHelper.uploadFile.command: ["/tmp/archive.tar"],
                                XCHelper.uploadFile.bucket: ["bucketName"],
                                XCHelper.uploadFile.region: ["region"]]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadFileOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations)
            
            try xchelper.handleUploadFile(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadFile(let message){
            XCTAssertTrue(message.contains("credentials"), "An error not providing the credentials or secret should have been thrown instead of \(message).")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadFile_missingSecret(){
        do{
            let expectations = [XCHelper.uploadFile.command: ["/tmp/archive.tar"],
                                XCHelper.uploadFile.bucket: ["bucketName"],
                                XCHelper.uploadFile.region: ["region"],
                                XCHelper.uploadFile.key: ["key"]]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadFileOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations)
            
            try xchelper.handleUploadFile(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadFile(let message){
            XCTAssertTrue(message.contains("secret"), "An error about not providing the secret should have been thrown instead of \(message).")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadFile_withKeyAndSecret(){
        do{
            var didCallUploadFile = false
            let commandExpectation = [XCHelper.uploadFile.command: ["/tmp/archive.tar"]]
            let requiredExpectations = [XCHelper.uploadFile.bucket: ["bucketName"],
                                        XCHelper.uploadFile.region: ["region"]]
            let optionalExpectations = [XCHelper.uploadFile.key: ["key"],
                                       XCHelper.uploadFile.secret: ["secret"]]
            var fixture = XcodeHelpableFixture()
            fixture.testUploadFile = { (archivePath: String, s3Bucket: String, region: String, key: String, secret: String) in
                didCallUploadFile = true
                XCTAssertEqual(archivePath, commandExpectation[XCHelper.uploadFile.command]!.first)
                XCTAssertEqual(s3Bucket, requiredExpectations[XCHelper.uploadFile.bucket]!.first)
                XCTAssertEqual(region, requiredExpectations[XCHelper.uploadFile.region]!.first)
                XCTAssertEqual(key, optionalExpectations[XCHelper.uploadFile.key]!.first)
                XCTAssertEqual(secret, optionalExpectations[XCHelper.uploadFile.secret]!.first)
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadFileOption], with: commandExpectation)!.first
            option = option?.preparedWithOptionalArg(fixtureIndex: optionalExpectations)
            option = option?.preparedWithRequiredArg(fixtureIndex: requiredExpectations)
            
            
            try xchelper.handleUploadFile(option: option!)
            
            XCTAssertTrue(didCallUploadFile)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadFile_withCredentials(){
        do{
            var didCallUploadFile = false
            let expectations = [XCHelper.uploadFile.command: ["/tmp/archive.tar"],
                                XCHelper.uploadFile.bucket: ["bucketName"],
                                XCHelper.uploadFile.region: ["region"],
                                XCHelper.uploadFile.credentialsFile: ["credentialsFile"]]
            var fixture = XcodeHelpableFixture()
            fixture.testUploadFileWithCredentials = { (archivePath: String, s3Bucket: String, region: String, credentialsPath: String) in
                didCallUploadFile = true
                XCTAssertEqual(archivePath, expectations[XCHelper.uploadFile.command]!.first)
                XCTAssertEqual(s3Bucket, expectations[XCHelper.uploadFile.bucket]!.first)
                XCTAssertEqual(region, expectations[XCHelper.uploadFile.region]!.first)
                XCTAssertEqual(credentialsPath, expectations[XCHelper.uploadFile.credentialsFile]!.first)
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadFileOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUploadFile(option: option!)
            
            XCTAssertTrue(didCallUploadFile)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    //MARK: Git Tag
    func testHandleGitTag_missingComponent(){
        do{
            let expectations = [XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            var fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String, shouldLog: Bool) -> String in
                return ""
            }
            
            try xchelper.handleGitTag(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.gitTagParse(let message){
            XCTAssertTrue(message.contains("either"), "An error about not providing a version or component should have been thrown instead of \(message).")
        }catch let e{
            XCTFail("Error: \(e)")
        }

    }
    func testHandleGitTag_unknownValue(){
        do{
            let expectations = [XCHelper.gitTag.incrementOption: [UUID().uuidString],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            var fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String, shouldLog: Bool) -> String in
                return ""
            }
            
            try xchelper.handleGitTag(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.gitTagParse(let message){
            XCTAssertTrue(message.contains("Unknown"), "An error about an unknown value should have been thrown instead of \(message).")
        }catch let e{
            XCTFail("Error: \(e)")
        }
        
    }
    func testHandleGitTag_version(){
        do{
            var didCallGitTag = false
            let expectations = [XCHelper.gitTag.versionOption: ["9.9.9"],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            var fixture = XcodeHelpableFixture()
            fixture.testGitTag = { (tag: String, sourcePath: String) in
                didCallGitTag = true
                XCTAssertEqual(tag, expectations[XCHelper.gitTag.versionOption]!.first)
                XCTAssertEqual(sourcePath, expectations[XCHelper.gitTag.changeDirectory]!.first)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleGitTag(option: option!)
            
            XCTAssertTrue(didCallGitTag)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleGitTag_increment(){
        do{
            var didCallIncrementGitTag = false
            let expectations = [XCHelper.gitTag.incrementOption: [],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            var fixture = XcodeHelpableFixture()
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String, shoulLog: Bool) in
                didCallIncrementGitTag = true
                XCTAssertEqual(component, GitTagComponent.patch)
                XCTAssertEqual(sourcePath, expectations[XCHelper.gitTag.changeDirectory]!.first)
                return "1.0.1"
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleGitTag(option: option!)
            
            XCTAssertTrue(didCallIncrementGitTag)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleGitTag_incrementPatch(){
        do{
            var didCallIncrementGitTag = false
            let expectations = [XCHelper.gitTag.incrementOption: ["patch"],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            var fixture = XcodeHelpableFixture()
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String, shouldLog: Bool) in
                didCallIncrementGitTag = true
                XCTAssertEqual(component, GitTagComponent(stringValue: expectations[XCHelper.gitTag.incrementOption]!.first!))
                XCTAssertEqual(sourcePath, expectations[XCHelper.gitTag.changeDirectory]!.first)
                return "1.0.0"
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleGitTag(option: option!)
            
            XCTAssertTrue(didCallIncrementGitTag)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleGitTag_incrementMinor(){
        do{
            var didCallIncrementGitTag = false
            let expectations = [XCHelper.gitTag.incrementOption: ["minor"],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            var fixture = XcodeHelpableFixture()
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String, shouldLog: Bool) in
                didCallIncrementGitTag = true
                XCTAssertEqual(component, GitTagComponent(stringValue: expectations[XCHelper.gitTag.incrementOption]!.first!))
                XCTAssertEqual(sourcePath, expectations[XCHelper.gitTag.changeDirectory]!.first)
                return "1.0.0"
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleGitTag(option: option!)
            
            XCTAssertTrue(didCallIncrementGitTag)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleGitTag_incrementMajor(){
        do{
            var didCallIncrementGitTag = false
            let expectations = [XCHelper.gitTag.incrementOption: ["major"],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            var fixture = XcodeHelpableFixture()
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String, shouldLog: Bool) in
                didCallIncrementGitTag = true
                XCTAssertEqual(component, GitTagComponent(stringValue: expectations[XCHelper.gitTag.incrementOption]!.first!))
                XCTAssertEqual(sourcePath, expectations[XCHelper.gitTag.changeDirectory]!.first)
                return "1.0.0"
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleGitTag(option: option!)
            
            XCTAssertTrue(didCallIncrementGitTag)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testYamlBoolValue_emptyArray() {
        let argumentIndex: [String: [String]] = ["key": []]
        
        let result = argumentIndex.yamlBoolValue(forKey: "key")
        
        XCTAssertTrue(result)
    }
    func testYamlBoolValue_oneArray() {
        let argumentIndex: [String: [String]] = ["key": ["1"]]
        
        let result = argumentIndex.yamlBoolValue(forKey: "key")
        
        XCTAssertTrue(result)
    }
    func testYamlBoolValue_trueArray() {
        let argumentIndex: [String: [String]] = ["key": ["true"]]
        
        let result = argumentIndex.yamlBoolValue(forKey: "key")
        
        XCTAssertTrue(result)
    }
    func testYamlBoolValue_zeroArray() {
        let argumentIndex: [String: [String]] = ["key": ["0"]]
        
        let result = argumentIndex.yamlBoolValue(forKey: "key")
        
        XCTAssertFalse(result)
    }
    func testYamlBoolValue_falseArray() {
        let argumentIndex: [String: [String]] = ["key": ["false"]]
        
        let result = argumentIndex.yamlBoolValue(forKey: "key")
        
        XCTAssertFalse(result)
    }
    func testHandleGitTag_push(){
        do{
            var didCallGitPush = false
            let expectations = [XCHelper.gitTag.versionOption: ["9.9.9"],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"],
                                XCHelper.gitTag.pushOption:[]]
            var fixture = XcodeHelpableFixture()
            fixture.testGitTag = { (_, _) -> ProcessResult in
                return emptyProcessResult
            }
            fixture.testPushGitTag = { (tag: String, sourcePath: String) in
                didCallGitPush = true
                XCTAssertEqual(tag, expectations[XCHelper.gitTag.versionOption]!.first)
                XCTAssertEqual(sourcePath, expectations[XCHelper.gitTag.changeDirectory]!.first)
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleGitTag(option: option!)
            
            XCTAssertTrue(didCallGitPush)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleGitTag_initialTag(){
        do{
            var didCallGitTag = false
            let expectations = [XCHelper.gitTag.versionOption: ["9.9.9"]]
            var fixture = XcodeHelpableFixture()
            fixture.testGitTag = { (tag: String, sourcePath: String) in
                if tag == expectations[XCHelper.gitTag.versionOption]?.first!{
                    throw XcodeHelperError.gitTag(message: "")
                }
                didCallGitTag = true
                XCTAssertEqual(tag, "0.0.1")
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleGitTag(option: option!)
            
            XCTAssertTrue(didCallGitTag)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    //MARK: Create XCArchive
    func testHandleCreateXcarchive_missingPaths(){
        do{
            let expectations: [CliOption: [String]] = [:]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)![0]
            
            _ = try xchelper.handleCreateXcarchive(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.createXcarchive(let message){
            XCTAssertTrue(message.contains("any paths"), "An error about a missing xcarchive path should have been thrown. \"\(message)\"")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleCreateXcarchive_missingArchivePath(){
        do{
            let expectations = [XCHelper.createXcarchive.command: [String]()]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)![0]
            
            _ = try xchelper.handleCreateXcarchive(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.createXcarchive(let message){
            XCTAssertTrue(message.contains("archive path"), "An error about a missing xcarchive path should have been thrown. \"\(message)\"")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleCreateXcarchive_missingBinaryPath(){
        do{
            let expectations = [XCHelper.createXcarchive.command: ["/tmp/binary"]]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)![0]
            
            _ = try xchelper.handleCreateXcarchive(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.createXcarchive(let message){
            XCTAssertTrue(message.contains("binary"), "An error about a missing binary path should have been thrown. \"\(message)\"")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    /*func testCreateXcarchive_missingName(){
        do{
            let expectations = [XCHelper.createXcarchive.command: ["/tmp/file.swift"]]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)!.first
            
            _ = try xchelper.handleCreateXcarchive(option: option!)
            
        }catch XcodeHelperError.createXcarchive(let message){
            XCTAssertTrue(message.contains("name"), "An error about a missing name should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }*/
    func testCreateXcarchive_missingScheme(){
        do{
            let expectations = [XCHelper.createXcarchive.command: ["/tmp/file.swift", "testarchive.tar.gz"]]//XCHelper.createXcarchive.nameOption: ["name"]
            let fixture = XcodeHelpableFixture()
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)!.first
//                            .preparedWithOptionalArg(fixtureIndex: [XCHelper.createXcarchive.nameOption: expectations[XCHelper.createXcarchive.nameOption]!])
            
            _ = try xchelper.handleCreateXcarchive(option: option!)

        }catch XcodeHelperError.createXcarchive(let message){
            XCTAssertTrue(message.contains("scheme"), "An error about a missing scheme should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testCreateXcarchive(){
        do{
            var didCallCreateXcarchive = false
            let expectations = [XCHelper.createXcarchive.command: ["/tmp/archive.xcarchive", "/tmp/file.swift"],
//                                XCHelper.createXcarchive.nameOption: ["name"],
                                XCHelper.createXcarchive.schemeOption: ["scheme"]]
            var fixture = XcodeHelpableFixture()
            fixture.testCreateXcarchive = { (archivePath: String, binaryPath: String, schemeName: String) in
                didCallCreateXcarchive = true
                XCTAssertEqual(archivePath, expectations[XCHelper.createXcarchive.command]?.first!)
                XCTAssertEqual(binaryPath, expectations[XCHelper.createXcarchive.command]?[1])
//                XCTAssertEqual(name, expectations[XCHelper.createXcarchive.nameOption]?.first!)
                XCTAssertEqual(schemeName, expectations[XCHelper.createXcarchive.schemeOption]?.first!)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)!.first?
                .preparedWithOptionalArg(fixtureIndex: [/*XCHelper.createXcarchive.nameOption: expectations[XCHelper.createXcarchive.nameOption]!,*/
                                                        XCHelper.createXcarchive.schemeOption: expectations[XCHelper.createXcarchive.schemeOption]!])
            
            _ = try xchelper.handleCreateXcarchive(option: option!)
            
            XCTAssertTrue(didCallCreateXcarchive)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    
    func testAllEnvironmentKeysAreUnique(){
        let xchelper = XCHelper()
        var allKeys = Set<String>()
        for key in xchelper.environmentKeys {
            XCTAssert(!allKeys.contains(key), "\(key) is in set: \(allKeys)")
            allKeys.insert(key)
        }
    }
    
    func testParseYaml() {
        do{
            //expectations
            let configPath = "/tmp/.xcodehelper"
            let command = "create-xcarchive"
            let archivePath = "/tmp/xchelper_test.xcarchive"
            let name = UUID().uuidString
            let binaryPath = "/tmp/\(name)"
            let scheme =  UUID().uuidString
            //create the yaml file
            let yamlContents = "\(command):\n  args:\n    - \(archivePath)\n    - \(binaryPath)\"\n  name: \(name)\n  scheme: \(scheme)\n  "
            try! yamlContents.write(toFile: configPath, atomically: false, encoding: .utf8)
            //prepare the fixture data
            var didCallCreateXcarchive = false
            var fixture = XcodeHelpableFixture()
            fixture.testCreateXcarchive = { (archivePath: String, binary: String, schemeName: String) in
                didCallCreateXcarchive = true
                XCTAssertEqual(archivePath, archivePath)
                XCTAssertEqual(binary, binaryPath)
//                XCTAssertNotEqual(named, name)//cli option takes precedence over this one
                XCTAssertNotEqual(schemeName, scheme)//cli option takes precedence over this one
                return emptyProcessResult
            }
            let arguments = [XCHelper.createXcarchive.command.keys.first!, archivePath, binaryPath,
                            /*XCHelper.createXcarchive.nameOption.keys.first!, UUID().uuidString,*/
                                XCHelper.createXcarchive.schemeOption.keys.first!, UUID().uuidString]
            let xchelper = XCHelper(xcodeHelpable: fixture)
            _ = try xchelper.run(arguments: arguments, environment: [:])//, yamlConfigurationPath: configPath

            XCTAssertTrue(didCallCreateXcarchive)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
}
