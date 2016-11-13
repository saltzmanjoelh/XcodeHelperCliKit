//
//  XcodeHelperCliTests.swift
//  XcodeHelperCliTests
//
//  Created by Joel Saltzman on 7/30/16.
//
//

import XCTest
import XcodeHelperKit
import XcodeHelperCliKit

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
    
    
    func testHandleGitTagMajor() {
        do{
            let helper = XcodeHelper()
            sourcePath = cloneToTempDirectory(repoURL: libraryRepoURL)
            var gitTagCommand = helper.cliOptionGroups.first!.options.last!//get the command
            gitTagCommand.values = [sourcePath!]
            var incrementOption = gitTagCommand.optionalArguments![1]
            incrementOption.values = [GitTagComponent.major.rawValue]//simulate -i "patch"
            gitTagCommand.optionalArguments = [incrementOption]
            let currentTag = try helper.getGitTag(sourcePath: sourcePath!)
            let targetTag = Int(currentTag.components(separatedBy: ".")[0])!+1
            
            try helper.handleGitTag(option: gitTagCommand)
            
            let updatedTag = try helper.getGitTag(sourcePath: sourcePath!)
            XCTAssertEqual(updatedTag.components(separatedBy: ".")[0], String(targetTag))
            
        } catch let e {
            XCTFail("Error: \(e)")
        }
    }
    func testHandleGitTagMinor() {
        do{
            let helper = XcodeHelper()
            sourcePath = cloneToTempDirectory(repoURL: libraryRepoURL)
            var gitTagCommand = helper.cliOptionGroups.first!.options.last!//get the command
            gitTagCommand.values = [sourcePath!]
            var incrementOption = gitTagCommand.optionalArguments![1]
            incrementOption.values = [GitTagComponent.minor.rawValue]//simulate -i "patch"
            gitTagCommand.optionalArguments = [incrementOption]
            let currentTag = try helper.getGitTag(sourcePath: sourcePath!)
            let targetTag = Int(currentTag.components(separatedBy: ".")[1])!+1
            
            try helper.handleGitTag(option: gitTagCommand)
            
            let updatedTag = try helper.getGitTag(sourcePath: sourcePath!)
            XCTAssertEqual(updatedTag.components(separatedBy: ".")[1], String(targetTag))
            
        } catch let e {
            XCTFail("Error: \(e)")
        }
    }
    func testHandleGitTagPatch() {
        do{
            let helper = XcodeHelper()
            sourcePath = cloneToTempDirectory(repoURL: libraryRepoURL)
            var gitTagCommand = helper.cliOptionGroups.first!.options.last!//get the command
            gitTagCommand.values = [sourcePath!]
            var incrementOption = gitTagCommand.optionalArguments![1]
            incrementOption.values = [GitTagComponent.patch.rawValue]//simulate -i "patch"
            gitTagCommand.optionalArguments = [incrementOption]
            let currentTag = try helper.getGitTag(sourcePath: sourcePath!)
            let targetTag = Int(currentTag.components(separatedBy: ".")[2])!+1
            
            try helper.handleGitTag(option: gitTagCommand)
            
            let updatedTag = try helper.getGitTag(sourcePath: sourcePath!)
            XCTAssertEqual(updatedTag.components(separatedBy: ".")[2], String(targetTag))
            
        } catch let e {
            XCTFail("Error: \(e)")
        }
    }
}
