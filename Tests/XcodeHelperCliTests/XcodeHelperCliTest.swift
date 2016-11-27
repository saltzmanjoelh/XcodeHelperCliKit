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

class XcodeHelperCliTests: XCTestCase {
    
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
    
    func testParseSourceCodePath_custom(){
        let xchelper = XCHelper(xcodeHelpable:XcodeHelper())
        let key = XCHelper.updatePackages.changeDirectory.keys.first!
        let customPath = "/tmp/path"
        let argumentIndex = [key:[customPath]]
        
        let result = xchelper.parseSourceCodePath(from: argumentIndex, with: key)
        
        XCTAssertEqual(result, customPath)
    }
    /*
    func testHandleFetchPackages_missingLinuxPackage() {
        do{
            struct HelpableFixture: XcodeHelpable {}
            let xchelper = XCHelper(xcodeHelpable:HelpableFixture())
            let option = xchelper.fetchPackagesOption
            
            try xchelper.handleFetchPackages(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.fetch(let message){
            XCTAssertTrue(message.contains(XCHelper.fetchPackages.linuxPackages.keys.first!), "linuxPackages error should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleFetchPackages_missingImageName() {
        do{
            struct HelpableFixture: XcodeHelpable {}
            let xchelper = XCHelper(xcodeHelpable:HelpableFixture())
            //set the linuxPackages command to have a value so we move further down the function
            let option = xchelper.fetchPackagesOption.preparedWithOptionalArg(fixtures: [XCHelper.fetchPackages.linuxPackages])
            
            try xchelper.handleFetchPackages(option: option)
            
            XCTFail("An error should have been thrown")
        }catch XcodeHelperError.fetch(let message){
            XCTAssertTrue(message.contains(XCHelper.fetchPackages.imageName.keys.first!), "imageName error should have been thrown.")
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }
    func testHandleFetchPackages() {
        do{
            struct HelpableFixture: XcodeHelpable, Fulfillable {
                let linuxPackages = true
                let imageName = "image"
                var fulfill: ((Void) -> (Void))?
                init(){}
                @discardableResult func fetchPackages(at sourcePath: String, forLinux: Bool, inDockerImage imageName: String?) throws -> ProcessResult {
                    fulfill?()
                    return (output:nil, error:nil, exitCode:0)
                }
            }
            var didCallFetchPackages = false
            let xchelper = XCHelper(xcodeHelpable:HelpableFixture(){ didCallFetchPackages = true })
            let option = xchelper.fetchPackagesOption.preparedWithOptionalArg(fixtures: [XCHelper.fetchPackages.linuxPackages,
                                                                                         XCHelper.fetchPackages.imageName])
            
            try xchelper.handleFetchPackages(option: option)
            
            XCTAssertTrue(didCallFetchPackages, "Failed to call fetchPackages on xcodeHelpable")
            
        }catch let e{
            XCTFail("Error: \(e)")
        }
    }*/
    
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
                                 XCHelper.updatePackages.imageName: ["image"]]
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
    
    //MARK: SymlinkDependencies
    func testSymlinkDependencies() {
        //everything in function is already tested
    }
}
