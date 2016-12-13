//
//  XcodeHelperCliTests.swift
//  XcodeHelperCliTests
//
//  Created by Joel Saltzman on 7/30/16.
//
//

import XCTest
import XcodeHelperKit
@testable import XcodeHelperCliKit
import SynchronousProcess
import CliRunnable

//MARK: TESTS

class XcodeHelperCliKitTests: XCTestCase {
    
    let executableRepoURL = "https://github.com/saltzmanjoelh/HelloSwift" //we use a different repo for testing because this repo isn't meant for linux
    let libraryRepoURL = "https://github.com/saltzmanjoelh/Hello"
    var sourcePath : String?
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        if sourcePath != nil {
            Process.run("/bin/rm", arguments: ["-Rf", sourcePath!])
        }
    }
    
    //returns the temp dir that we cloned into
    private func cloneToTempDirectory(repoURL:String) -> String? {
        //use /tmp instead of FileManager.default.temporaryDirectory because Docker for mac specifies /tmp by default and not /var...
        guard let tempDir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).path.appending("/XcodeHelperCliTests/\(UUID())") else{
            XCTFail("Failed to get user dir")
            return nil
        }
        if !FileManager.default.fileExists(atPath: tempDir) {
            do {
                try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
            }catch _{
                
            }
        }
        let cloneResult = Process.run("/usr/bin/env", arguments: ["git", "clone", repoURL, tempDir], silenceOutput: false)
        XCTAssert(cloneResult.exitCode == 0, "Failed to clone repo: \(cloneResult.error)")
        XCTAssert(FileManager.default.fileExists(atPath: tempDir))
        print("done cloning temp dir: \(tempDir)")
        return tempDir
    }
    
    func testHelpableStrings() {
        let fixture = Fixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        
        XCTAssertNotNil(xchelper.appName)
        XCTAssertNotNil(xchelper.description)
        XCTAssertNotNil(xchelper.appUsage)
    }
    func testCliOptionGroups() {
        let fixture = Fixture()
        let xchelper = XCHelper(xcodeHelpable: fixture)
        
        XCTAssertEqual(xchelper.cliOptionGroups.count, 1)
        XCTAssertEqual(xchelper.cliOptionGroups.first?.options.count, 8)
    }
    
    func testParseSourceCodePath_custom(){
        let xchelper = XCHelper(xcodeHelpable:XcodeHelper())
        let key = XCHelper.updatePackages.changeDirectory.keys.first!
        let customPath = "/tmp/path"
        let argumentIndex = [key:[customPath]]
        
        let result = xchelper.parseSourceCodePath(from: argumentIndex, with: key)
        
        XCTAssertEqual(result, customPath)
    }
    
    //MARK: Update Packages
    func testHandleUpdatePackages_missingLinuxPackage() {
        //missing linuxPackage option should still proceed, just default to false
        do{
            
            var didCallUpdatePackages = false
            let expectations = [XCHelper.updatePackages.changeDirectory:["/tmp"],
                                XCHelper.updatePackages.imageName: ["image"]]
            var fixture = Fixture(expectations: expectations)
            fixture.testUpdatePackages = { (sourcePath:String, forLinux:Bool, imageName:String?) -> ProcessResult in
                didCallUpdatePackages = true
                XCTAssertFalse(forLinux, "forLinux param should have defaulted to false")
                XCTAssertEqual(sourcePath, expectations[XCHelper.updatePackages.changeDirectory]?.first)
                XCTAssertEqual(imageName, expectations[XCHelper.updatePackages.imageName]?.first)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.updatePackagesOption.preparedWithOptionalArg(fixtureIndex: fixture.expectations!)
            
            try xchelper.handleUpdatePackages(option: option)
            
            XCTAssertTrue(didCallUpdatePackages, "Failed to call updatePackages on XcodeHelpable")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleUpdatePackages_missingImageName() {
        
        do{
            let xchelper = XCHelper(xcodeHelpable:Fixture())
            let option = xchelper.updatePackagesOption.preparedWithOptionalArg(fixtures: [XCHelper.updatePackages.linuxPackages])
            
            try xchelper.handleUpdatePackages(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.update(let message){
            XCTAssertTrue(message.contains(XCHelper.updatePackages.imageName.keys.first!), "imageName error should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleUpdatePackages() {
        do{
            var didCallUpdatePackages = false
            let expectations = [XCHelper.updatePackages.changeDirectory: ["/tmp"],
                                 XCHelper.updatePackages.linuxPackages: ["true"],
                                 XCHelper.updatePackages.imageName: ["image"],
                                 XCHelper.updatePackages.symlink: []]
            var fixture = Fixture(expectations: expectations)
            fixture.testUpdatePackages = { (sourcePath:String, forLinux:Bool, imageName:String?) -> ProcessResult in
                didCallUpdatePackages = true
                XCTAssertEqual(sourcePath, expectations[XCHelper.updatePackages.changeDirectory]?.first)
                XCTAssertEqual("\(forLinux)", expectations[XCHelper.updatePackages.linuxPackages]?.first)
                XCTAssertEqual(imageName, expectations[XCHelper.updatePackages.imageName]?.first)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.updatePackagesOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUpdatePackages(option: option)
            
            XCTAssertTrue(didCallUpdatePackages, "Failed to call updatePackages on XcodeHelpable")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    private func buildConfigurationTest(buildConfiguration: BuildConfiguration){
        do{
            let expectations = [XCHelper.build.buildConfiguration: ["\(buildConfiguration)"],
                                XCHelper.build.imageName: ["image"]]
            var fixture = Fixture(expectations: expectations)
            fixture.testBuild = { (sourcePath: String, configuration:BuildConfiguration, imageName: String, removeWhenDone: Bool) in
                XCTAssertEqual(configuration, buildConfiguration)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.buildOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleBuild(option: option)
            
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
            let xchelper = XCHelper(xcodeHelpable:Fixture())
            let option = xchelper.buildOption
            try xchelper.handleBuild(option: option)
            
        }catch XcodeHelperError.build(let message, _){
            XCTAssertTrue(message.contains(XCHelper.build.buildConfiguration.keys.first!), "buildConfiguration error should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleBuild_missingImageName() {
        do{
            let xchelper = XCHelper(xcodeHelpable:Fixture())
            var option = xchelper.buildOption
            option.optionalArguments = prepare(options: option.optionalArguments,
                                               with: [XCHelper.build.buildConfiguration: ["\(BuildConfiguration.debug)"]])
            
            try xchelper.handleBuild(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.build(let message, _){
            XCTAssertTrue(message.contains(XCHelper.build.imageName.keys.first!), "imageName error should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleBuild() {
        do{
            var didCallBuild = false
            let expectations = [XCHelper.build.buildConfiguration: ["\(BuildConfiguration.debug)"],
                                XCHelper.build.changeDirectory: ["/tmp"],
                                XCHelper.build.imageName: ["image"]]
            var fixture = Fixture(expectations:expectations)
            fixture.testBuild = { (sourcePath: String, configuration:BuildConfiguration, imageName: String, removeWhenDone: Bool) in
                didCallBuild = true
                XCTAssertEqual("\(configuration)", expectations[XCHelper.build.buildConfiguration]?.first!)
                XCTAssertEqual(sourcePath, expectations[XCHelper.build.changeDirectory]?.first!)
                XCTAssertEqual(imageName, expectations[XCHelper.build.imageName]?.first!)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.buildOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleBuild(option: option)

            XCTAssertTrue(didCallBuild, "Failed to call build on xcodeHelpable.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    //MARK: Clean
    func testHandleClean() {
        do{
            var didCallClean = false
            let expectations = [XCHelper.clean.changeDirectory: ["/tmp"]]
            var fixture = Fixture(expectations: expectations)
            fixture.testClean = { (sourcePath: String) in
                didCallClean = true
                XCTAssertEqual(sourcePath, expectations[XCHelper.clean.changeDirectory]?.first!)
                return emptyProcessResult
            }
            let xchelper = XCHelper(xcodeHelpable:fixture)
            let option = xchelper.cleanOption.preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleClean(option: option)
            
            XCTAssertTrue(didCallClean)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    //MARK: Symlink Dependencies
    func testSymlinkDependencies() {
        do{
            var didCallSymlinkDependencies = false
            let expectations = [XCHelper.symlinkDependencies.changeDirectory: ["/tmp"]]
            var fixture = Fixture(expectations: expectations)
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
            let xchelper = XCHelper(xcodeHelpable: Fixture())
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
            let fixture = Fixture(expectations: expectations)
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
            let fixture = Fixture(expectations: expectations)
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
            var fixture = Fixture(expectations: expectations)
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
    func testUploadArchive_missingArchivePath(){
        do{
            let xchelper = XCHelper(xcodeHelpable: Fixture())
            let option = xchelper.uploadArchiveOption
            
            try xchelper.handleUploadArchive(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadArchive(let message){
            XCTAssertTrue(message.contains("path to the archive"), "An error about the path to the archive should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadArchive_missingBucketName(){
        do{
            let expectations = [XCHelper.uploadArchive.command:["/tmp/archive.tar"]]
            let fixture = Fixture(expectations: expectations)
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.uploadArchiveOption], with: expectations)!.first
            
            try xchelper.handleUploadArchive(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadArchive(let message){
            XCTAssertTrue(message.contains("bucket"), "An error not providing the S3 bucket should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadArchive_missingRegion(){
        do{
            let expectations = [XCHelper.uploadArchive.command: ["/tmp/archive.tar"],
                                XCHelper.uploadArchive.bucket: ["bucketName"]]
            let fixture = Fixture(expectations: expectations)
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadArchiveOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations)
            
            try xchelper.handleUploadArchive(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadArchive(let message){
            XCTAssertTrue(message.contains("region"), "An error not providing the region should have been thrown instead of \(message).")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadArchive_missingAccess(){
        do{
            let expectations = [XCHelper.uploadArchive.command: ["/tmp/archive.tar"],
                                XCHelper.uploadArchive.bucket: ["bucketName"],
                                XCHelper.uploadArchive.region: ["region"]]
            let fixture = Fixture(expectations: expectations)
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadArchiveOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations)
            
            try xchelper.handleUploadArchive(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadArchive(let message){
            XCTAssertTrue(message.contains("credentials"), "An error not providing the credentials or secret should have been thrown instead of \(message).")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadArchive_missingSecret(){
        do{
            let expectations = [XCHelper.uploadArchive.command: ["/tmp/archive.tar"],
                                XCHelper.uploadArchive.bucket: ["bucketName"],
                                XCHelper.uploadArchive.region: ["region"],
                                XCHelper.uploadArchive.key: ["key"]]
            let fixture = Fixture(expectations: expectations)
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadArchiveOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations)
            
            try xchelper.handleUploadArchive(option: option!)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.uploadArchive(let message){
            XCTAssertTrue(message.contains("secret"), "An error about not providing the secret should have been thrown instead of \(message).")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadArchive_withKeyAndSecret(){
        do{
            var didCallUploadArchive = false
            let commandExpectation = [XCHelper.uploadArchive.command: ["/tmp/archive.tar"]]
            let requiredExpectations = [XCHelper.uploadArchive.bucket: ["bucketName"],
                                        XCHelper.uploadArchive.region: ["region"]]
            let optionalExpectations = [XCHelper.uploadArchive.key: ["key"],
                                       XCHelper.uploadArchive.secret: ["secret"]]
            var fixture = Fixture()
            fixture.testUploadArchive = { (archivePath: String, s3Bucket: String, region: String, key: String, secret: String) in
                didCallUploadArchive = true
                XCTAssertEqual(archivePath, commandExpectation[XCHelper.uploadArchive.command]!.first)
                XCTAssertEqual(s3Bucket, requiredExpectations[XCHelper.uploadArchive.bucket]!.first)
                XCTAssertEqual(region, requiredExpectations[XCHelper.uploadArchive.region]!.first)
                XCTAssertEqual(key, optionalExpectations[XCHelper.uploadArchive.key]!.first)
                XCTAssertEqual(secret, optionalExpectations[XCHelper.uploadArchive.secret]!.first)
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadArchiveOption], with: commandExpectation)!.first
            option = option?.preparedWithOptionalArg(fixtureIndex: optionalExpectations)
            option = option?.preparedWithRequiredArg(fixtureIndex: requiredExpectations)
            
            
            try xchelper.handleUploadArchive(option: option!)
            
            XCTAssertTrue(didCallUploadArchive)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testUploadArchive_withCredentials(){
        do{
            var didCallUploadArchive = false
            let expectations = [XCHelper.uploadArchive.command: ["/tmp/archive.tar"],
                                XCHelper.uploadArchive.bucket: ["bucketName"],
                                XCHelper.uploadArchive.region: ["region"],
                                XCHelper.uploadArchive.credentialsFile: ["credentialsFile"]]
            var fixture = Fixture(expectations: expectations)
            fixture.testUploadArchiveWithCredentials = { (archivePath: String, s3Bucket: String, region: String, credentialsPath: String) in
                didCallUploadArchive = true
                XCTAssertEqual(archivePath, expectations[XCHelper.uploadArchive.command]!.first)
                XCTAssertEqual(s3Bucket, expectations[XCHelper.uploadArchive.bucket]!.first)
                XCTAssertEqual(region, expectations[XCHelper.uploadArchive.region]!.first)
                XCTAssertEqual(credentialsPath, expectations[XCHelper.uploadArchive.credentialsFile]!.first)
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.uploadArchiveOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
            try xchelper.handleUploadArchive(option: option!)
            
            XCTAssertTrue(didCallUploadArchive)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
    //MARK: Git Tag
    func testHandleGitTag_missingComponent(){
        do{
            let expectations = [XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            let fixture = Fixture(expectations: expectations)
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
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
            let fixture = Fixture(expectations: expectations)
            let xchelper = XCHelper(xcodeHelpable: fixture)
            var option = prepare(options: [xchelper.gitTagOption], with: expectations)!.first
            option = option?.preparedWithRequiredArg(fixtureIndex: expectations).preparedWithOptionalArg(fixtureIndex: expectations)
            
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
            var fixture = Fixture(expectations: expectations)
            fixture.testGitTag = { (tag: String, sourcePath: String) in
                didCallGitTag = true
                XCTAssertEqual(tag, expectations[XCHelper.gitTag.versionOption]!.first)
                XCTAssertEqual(sourcePath, expectations[XCHelper.gitTag.changeDirectory]!.first)
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
    func testHandleGitTag_incrementPatch(){
        do{
            var didCallIncrementGitTag = false
            let expectations = [XCHelper.gitTag.incrementOption: ["patch"],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"]]
            var fixture = Fixture(expectations: expectations)
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String) in
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
            var fixture = Fixture(expectations: expectations)
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String) in
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
            var fixture = Fixture(expectations: expectations)
            fixture.testIncrementGitTag = { (component: GitTagComponent, sourcePath: String) in
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
    
    func testHandleGitTag_push(){
        do{
            var didCallGitPush = false
            let expectations = [XCHelper.gitTag.versionOption: ["9.9.9"],
                                XCHelper.gitTag.changeDirectory: ["/tmp/path"],
                                XCHelper.gitTag.pushOption:[]]
            var fixture = Fixture(expectations: expectations)
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
            var fixture = Fixture(expectations: expectations)
            fixture.testGitTag = { (tag: String, sourcePath: String) in
                if tag == expectations[XCHelper.gitTag.versionOption]?.first!{
                    throw XcodeHelperError.gitTag(message: "")
                }
                didCallGitTag = true
                XCTAssertEqual(tag, "0.0.1")
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
    func testHandleCreateXcarchive_missingArchive(){
        do{
            let xchelper = XCHelper(xcodeHelpable: Fixture())
            let option = xchelper.createXcarchiveOption
            
            _ = try xchelper.handleCreateXcarchive(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.createXcarchive(let message){
            XCTAssertTrue(message.contains("xcarchive"), "An error about a missing xcarchive path should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testCreateXcarchive_missingName(){
        do{
            let expectations = [XCHelper.createXcarchive.command: ["/tmp/file.swift"]]
            let fixture = Fixture(expectations: expectations)
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)!.first
            
            _ = try xchelper.handleCreateXcarchive(option: option!)
            
        }catch XcodeHelperError.createXcarchive(let message){
            XCTAssertTrue(message.contains("name"), "An error about a missing name should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testCreateXcarchive_missingScheme(){
        do{
            let expectations = [XCHelper.createXcarchive.command: ["/tmp/file.swift"],
                                XCHelper.createXcarchive.nameOption: ["name"]]
            let fixture = Fixture(expectations: expectations)
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)!.first?
                            .preparedWithOptionalArg(fixtureIndex: [XCHelper.createXcarchive.nameOption: expectations[XCHelper.createXcarchive.nameOption]!])
            
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
            let expectations = [XCHelper.createXcarchive.command: ["/tmp/file.swift"],
                                XCHelper.createXcarchive.nameOption: ["name"],
                                XCHelper.createXcarchive.schemeOption: ["scheme"]]
            var fixture = Fixture(expectations: expectations)
            fixture.testCreateXcarchive = { (dirPath: String, binaryPath: String, schemeName: String) in
                didCallCreateXcarchive = true
                XCTAssertEqual(dirPath, expectations[XCHelper.createXcarchive.command]?.first!)
                XCTAssertEqual(binaryPath, expectations[XCHelper.createXcarchive.nameOption]?.first!)
                XCTAssertEqual(schemeName, expectations[XCHelper.createXcarchive.schemeOption]?.first!)
                return ""
            }
            let xchelper = XCHelper(xcodeHelpable: fixture)
            let option = prepare(options: [xchelper.createXcarchiveOption], with: expectations)!.first?
                .preparedWithOptionalArg(fixtureIndex: [XCHelper.createXcarchive.nameOption: expectations[XCHelper.createXcarchive.nameOption]!,
                                                        XCHelper.createXcarchive.schemeOption: expectations[XCHelper.createXcarchive.schemeOption]!])
            
            _ = try xchelper.handleCreateXcarchive(option: option!)
            
            XCTAssertTrue(didCallCreateXcarchive)
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    
}
