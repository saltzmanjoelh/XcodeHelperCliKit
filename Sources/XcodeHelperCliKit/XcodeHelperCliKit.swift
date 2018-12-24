//
//  XcodeHelperCli.swift
//  XcodeHelper
//
//  Created by Joel Saltzman on 8/28/16.
//
//

import Foundation
import XcodeHelperKit
import CliRunnable
import DockerProcess
import ProcessRunner
import xcodeproj

public enum XcodeHelperCliError : Error, CustomStringConvertible {
    case xcactivityLogDecode(message:String)
    public var description : String {
        get {
            switch (self) {
            case let .xcactivityLogDecode(message): return message
            }
        }
    }
}
public struct XCHelper : CliRunnable {
    
    public var xcodeHelpable: XcodeHelpable
    
    public init(xcodeHelpable:XcodeHelpable = XcodeHelper()) {
        self.xcodeHelpable = xcodeHelpable
    }
    
    public var appName: String {
        get {
            return "xchelper"
        }
    }
    public var description: String? {
        get {
            return "xchelper keeps you in Xcode and off the command line. You can build and run tests on other platforms through Docker, fetch Swift packages, keep your dependencies in Xcode referencing the correct paths and updates and tar and upload your binary to AWS S3 buckets."
        }
    }
    public var appUsage: String? {
        return "xchelper COMMAND [OPTIONS]"
    }
    public enum changeDirectoryOption: String {
        case short = "-d"
        case long = "--chdir"
        case envSuffix = "CHDIR"
        static var allRawValues: [String] {
            return [changeDirectoryOption.short.rawValue,
                    changeDirectoryOption.long.rawValue,
                    changeDirectoryOption.envSuffix.rawValue]
        }
    }
    public func parseSourceCodePath(from argumentIndex: [String:[String]], with optionKey: String?) -> String {
        if let key = optionKey, let customDirectory = argumentIndex[key]?.first {
            return customDirectory
        }
        return FileManager.default.currentDirectoryPath
    }
    public func getYamlPath(args: [String], env: [String: String]) -> String {
        var path = ProcessInfo.processInfo.environment["PWD"] ?? ""
        if let argPath = getYamlPathFromArgs(args) {
            path = argPath
        }
        if let envPath = getYamlPathFromEnv(env) {
            path = envPath
        }
        return path.appending(".xcodehelper")
    }
    public func getYamlPathFromArgs(_ args: [String]) -> String? {
        var path: String?
        //skip first arg, it's app path
        if args.count > 1 {
            for i in 1..<args.count-1 {//-1 last index but the last index won't have a value after it. -2
                if args[i] == XCHelper.changeDirectoryOption.short.rawValue {
                    path = args[i+1]
                }else if args[i] == XCHelper.changeDirectoryOption.long.rawValue {
                    path = args[i+1]
                }
            }
            if let result = path {
                return result
            }
        }
        return nil
    }
    public func getYamlPathFromEnv(_ env: [String: String]) -> String? {
        for key in env.keys {
            if key.hasSuffix(XCHelper.changeDirectoryOption.envSuffix.rawValue),
                let value = env[key] {
                return value
            }
        }
        return nil
    }
    
    
    public var cliOptionGroups: [CliOptionGroup] {
        get {
            return [CliOptionGroup(description:"Commands:",
                                   options:[updateMacOsPackagesOption, updateDockerPackagesOption, dockerBuildOption, /*cleanOption,*/ symlinkDependenciesOption, createArchiveOption, uploadArchiveOption, gitTagOption, createXcarchiveOption])]
        }
    }
    public var environmentKeys: [String] {
        return cliOptionGroups.flatMap{ (optionGroup: CliOptionGroup) in
            return optionGroup.options.flatMap{ (option: CliOption) in
                return option.allKeys.filter{ (key: String) -> Bool in
                    return key.uppercased() == key
                }
            }
        }
    }
    
    // MARK: UpdatePackages
    struct updateMacOsPackages {
        static let command          = CliOption(keys: [Command.updateMacOSPackages.cliName, Command.updateMacOSPackages.envName],
                                                description: Command.updateMacOSPackages.description,
                                                usage: "xchelper \(Command.updateMacOSPackages.cliName) [OPTIONS]",
            requiresValue: false,
            defaultValue:nil)
        static let changeDirectory  = CliOption(keys:[changeDirectoryOption.short.rawValue, changeDirectoryOption.long.rawValue, "UPDATE_MACOS_PACKAGES_\(changeDirectoryOption.envSuffix)"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
        static let generateXcodeProject  = CliOption(keys:["-g", "--generate", "UPDATE_PACKAGES_GENERATE_XCPROJECT"],
                                                     description:"Generate a new Xcode project",
                                                     usage: nil,
                                                     requiresValue:false,
                                                     defaultValue: nil)
        static let recursive          = CliOption(keys:["-r", "--recursive", "UPDATE_PACKAGES_RECURSIVE"],
                                                  description:"Recursively search subdirectories for .xcodeprojs that need their dependencies updated. If you have a main application project which is not managed by SPM, you can create a subdirectory which is an SPM managed project. Then, use this to update those dependencies from the main project.",
                                                  usage: nil,
                                                  requiresValue:false,
                                                  defaultValue: nil)
//        static let gitPull          = CliOption(keys:["-p", "--git-pull", "UPDATE_PACKAGES_GIT_PULL"],
//                                                description:"Pull the latest",
//                                                usage: nil,
//                                                requiresValue:false,
//                                                defaultValue: nil)
        static let dockerBuildPhase          = CliOption(keys:["-b", "--docker-build-phase", "UPDATE_PACKAGES_DOCKER_BUILD_PHASE"],
                                                    description:"Add a `docker-build` \"Run Script Phase\" to Xcode. `docker-build` will use the .xcodehelper config file to determine the docker configuration. Run `xchelper docker-build --help` for more details on which options you can include in your .xcodehelper file. ",
                                                  usage: nil,
                                                  requiresValue:false,
                                                  defaultValue: nil)
        //        static let symlink          = CliOption(keys:["-s", "--symlink", "UPDATE_PACKAGES_SYMLINK"],
        //                                                description:"Create symbolic links for the dependency 'Packages' after `swift package update` so you don't have to generate a new xcode project.",
        //                                                usage: nil,
        //                                                requiresValue:false,
        //                                                defaultValue: nil)
    }
    public var updateMacOsPackagesOption: CliOption {
        var updateMacOsPackagesOption = updateMacOsPackages.command
        updateMacOsPackagesOption.optionalArguments = [updateMacOsPackages.changeDirectory, updateMacOsPackages.generateXcodeProject, updateMacOsPackages.recursive, updateMacOsPackages.dockerBuildPhase]
        updateMacOsPackagesOption.action = handleUpdatePackages
        return updateMacOsPackagesOption
    }
    @discardableResult
    public func handleUpdatePackages(option:CliOption) throws -> ProcessResult {
        XcodeHelper.logger = Logger(category: Command.updateMacOSPackages.title)
        
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: updateMacOsPackages.changeDirectory.keys.first)
        var sourcePaths = [sourcePath]
        XcodeHelper.logger?.logWithNotification("Updating %@", URL.init(fileURLWithPath: sourcePath).lastPathComponent)
        
        if argumentIndex.yamlBoolValue(forKey: updateMacOsPackages.recursive.keys.first!) == true {
            if #available(OSX 10.11, *) {
                sourcePaths = xcodeHelpable.recursivePackagePaths(at: sourcePath)
            } else {
                print("--recursive is only available on 10.11 or higher")
            }
        }
        var outputs = [String]()
        var errors = [String]()
        for path in sourcePaths {
            var url = URL.init(fileURLWithPath: path)
            if url.lastPathComponent == "Package.swift" {
                url = url.deletingLastPathComponent()
            }
            
            XcodeHelper.logger?.logWithNotification("Updating %@" as StaticString, url.lastPathComponent)
            do {
                let result = try xcodeHelpable.updateMacOsPackages(at: path.replacingOccurrences(of: "Package.swift", with: ""),
                                                                   shouldLog: true)
                outputs.append(result.output ?? "")
                //        When I populate the argumentIndex i'm not populating with all keys
                //        from the xc exten we pass long version of arg
                if argumentIndex.yamlBoolValue(forKey: updateMacOsPackages.generateXcodeProject.keys.first!) == true {
                    try xcodeHelpable.generateXcodeProject(at: sourcePath, shouldLog: true)
                }
                //        if argumentIndex.yamlBoolValue(forKey: updateMacOsPackages.symlink.keys.first!) == true {
                //            try xcodeHelpable.symlinkDependencies(at: sourcePath, shouldLog: true)
                //        }
            } catch let error {
                let errorMessage = String(describing: error)
                if path == sourcePath && errorMessage.contains("root manifest") && sourcePaths.count > 1 {
                    continue //It's possible that the root path isn't managed by SPM but the subproject is. Don't log it
                }
                errors.append(errorMessage)
                continue
            }
            XcodeHelper.logger?.logWithNotification("%@ packages updated", url.lastPathComponent)
        }
        if argumentIndex.yamlBoolValue(forKey: updateMacOsPackages.dockerBuildPhase.keys.first!) == true {
            let targetNames = try xcodeHelpable.packageTargets(inProject: sourcePath)
            for targetName in targetNames {
                try xcodeHelpable.addDockerBuildPhase(toTarget: targetName, inProject: sourcePath)
            }
        }
        XcodeHelper.logger?.logWithNotification("Done updating packages")
        let output = outputs.joined(separator: "\n")
        let errorString = errors.joined(separator: "\n")
        let updateResult = ProcessResult(output: output.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 ? output : nil,
                                         error: errorString.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 ? errorString : nil,
                                         exitCode: errorString.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 ? EXIT_FAILURE : 0)
        guard updateResult.error == nil else { return updateResult }
        return updateResult
    }
    
    struct updateDockerPackages {
        static let command          = CliOption(keys: [Command.updateDockerPackages.cliName, Command.updateDockerPackages.envName],
                                                description: Command.updateDockerPackages.description,
                                                usage: "xchelper \(Command.updateDockerPackages.cliName) [OPTIONS]",
            requiresValue: false,
            defaultValue:nil)
        static let changeDirectory  = CliOption(keys:[changeDirectoryOption.short.rawValue, changeDirectoryOption.long.rawValue, "UPDATE_DOCKER_PACKAGES_\(changeDirectoryOption.envSuffix)"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
        static let imageName        = CliOption(keys:["-i", "--image-name", "UPDATE_DOCKER_PACKAGES_IMAGE_NAME"],
                                                description:"The Docker image name to run the commands in",
                                                usage: nil,
                                                requiresValue:true,
                                                defaultValue:"swift")
        // The combination of `swift package update` and persistentVolume caused "segmentation fault" and swift compiler crashes
        // For now, when we update packages in Docker we should delete all existing packages first. ie: don't persist Packges directory
        static let volumeName       = CliOption(keys:["-v", "--volume", "UPDATE_DOCKER_PACKAGES_PERSISTENT_VOLUME"],
                                                description:"Create a subdirectory in the .build directory. This separates the macOS build files from docker build files to make builds faster for each platform.",
                                                usage: "-v [PLATFORM_NAME] ie: -v android",
                                                requiresValue:true,
                                                defaultValue: "docker_volume")
    }
    public var updateDockerPackagesOption: CliOption {
        var updateOption = updateDockerPackages.command
        updateOption.optionalArguments = [updateDockerPackages.changeDirectory]
        updateOption.requiredArguments = [updateDockerPackages.imageName, updateDockerPackages.volumeName]
        updateOption.action = handleUpdateDockerPackages
        return updateOption
    }
    @discardableResult
    public func handleUpdateDockerPackages(option:CliOption) throws -> ProcessResult {
        XcodeHelper.logger = Logger(category: Command.updateDockerPackages.title)
        
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: updateMacOsPackages.changeDirectory.keys.first)
        XcodeHelper.logger?.logWithNotification("Updating %@", URL.init(fileURLWithPath: sourcePath).lastPathComponent)
        let imageName = argumentIndex[updateDockerPackages.imageName.keys.first!]?.first ?? updateDockerPackages.imageName.defaultValue!
        let volumeName = argumentIndex[updateDockerPackages.volumeName.keys.first!]?.first ?? updateDockerPackages.volumeName.defaultValue!
        let result = try xcodeHelpable.updateDockerPackages(at: sourcePath, inImage: imageName, withVolume: volumeName, shouldLog: true)
        
        XcodeHelper.logger?.logWithNotification("Packages updated.")
        return result
    }
    
    // MARK: DockerBuild
    struct dockerBuild {
        static let command              = CliOption(keys: [Command.dockerBuild.cliName, Command.dockerBuild.envName],
                                                    description: Command.dockerBuild.description,
                                                    usage: "xchelper \(Command.dockerBuild.cliName) [OPTIONS]",
            requiresValue: false,
            defaultValue: nil)
        static let buildOnSuccess       = CliOption(keys: ["-s", "--after-success", "DOCKER_BUILD_AFTER_SUCCESS"],
                                                    description: "Only build after a successful macOS build. This helps reduce duplicate errors in Xcode from multiple platforms.",
                                                    usage: "-s [PATH_TO_BUILD_DIR] ie: -s /project/path/.build",
                                                    requiresValue: true,
                                                    defaultValue: nil)
        static let removeWhenDone       = CliOption(keys: ["-r", "--rm", "DOCKER_REMOVE_WHEN_DONE"],
                                                    description: "Delete the container after building.",
                                                    usage: nil,
                                                    requiresValue: false,
                                                    defaultValue: nil)
        static let changeDirectory      = CliOption(keys:[changeDirectoryOption.short.rawValue, changeDirectoryOption.long.rawValue, "DOCKER_BUILD_\(changeDirectoryOption.envSuffix)"],
                                                    description:"Change the current working directory.",
                                                    usage: nil,
                                                    requiresValue: true,
                                                    defaultValue: nil)
        static let buildConfiguration   = CliOption(keys:["-c", "--build-configuration", "DOCKER_BUILD_CONFIGURATION"],
                                                    description:"debug or release mode",
                                                    usage: nil,
                                                    requiresValue: true,
                                                    defaultValue: "debug")
        static let imageName            = CliOption(keys:["-i", "--image-name", "DOCKER_BUILD_IMAGE_NAME"],
                                                    description:"The Docker image name to run the commands in",
                                                    usage: nil,
                                                    requiresValue: true,
                                                    defaultValue: "swift")
        static let containerName  = CliOption(keys:["-n", "--container-name", "DOCKER_BUILD_CONTAINER_NAME"],
                                              description:"The name of the container. Defaults to the same as the image name.",
                                              usage: "-n [CONTAINER_NAME] ie: -n android",
                                              requiresValue: true,
                                              defaultValue: "LinuxSwiftContainer")
        
        //TODO: make sure all volumeName options have the same keys
        static let volumeName  = CliOption(keys:["-v", "--volume", "DOCKER_BUILD_PERSISTENT_VOLUME"],
                                           description:"Create a subdirectory in the .build directory. This separates the macOS build files from docker build files to make builds faster for each platform.",
                                           usage: "-v [PLATFORM_NAME] ie: -v android",
                                           requiresValue: true,
                                           defaultValue: "docker_volume")
        
    }
    public var dockerBuildOption: CliOption {
        var dockerBuildOption = dockerBuild.command
        dockerBuildOption.optionalArguments = [dockerBuild.buildOnSuccess, dockerBuild.removeWhenDone, dockerBuild.changeDirectory, dockerBuild.containerName]
        dockerBuildOption.requiredArguments = [dockerBuild.buildConfiguration, dockerBuild.imageName, dockerBuild.volumeName]
        dockerBuildOption.action = handleDockerBuild
        return dockerBuildOption
    }
    @discardableResult
    public func handleDockerBuild(option:CliOption) throws -> ProcessResult {
        XcodeHelper.logger = Logger(category: Command.dockerBuild.title)
        
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: dockerBuild.changeDirectory.keys.first)
        var runOptions = [DockerRunOption]()
        XcodeHelper.logger?.logWithNotification("Building - %@", URL.init(fileURLWithPath: sourcePath).lastPathComponent)
        
        guard let buildConfigurationString = argumentIndex[dockerBuild.buildConfiguration.keys.first!]?.first else {
            throw XcodeHelperError.dockerBuild(message: "\(dockerBuild.buildConfiguration.keys) not provided.", exitCode: 1)
        }
        let buildConfiguration = BuildConfiguration(from:buildConfigurationString)
        guard let imageName = argumentIndex[dockerBuild.imageName.keys.first!]?.first else {
            throw XcodeHelperError.dockerBuild(message: "\(dockerBuild.imageName.keys) not provided.", exitCode: 1)
        }
        let persistentVolume = argumentIndex[dockerBuild.volumeName.keys.first!]?.first
        //        let customOptions = argumentIndex[dockerBuild.volumeName.keys.first!]
        
        if let containerName = argumentIndex[dockerBuild.containerName.keys.first!]?.first {
            runOptions.append(.container(name: containerName))
        }
        if argumentIndex.yamlBoolValue(forKey: dockerBuild.removeWhenDone.keys.first!) == true {
            runOptions.append(.removeWhenDone)
        }
        //        if let options = customOptions {
        //            options.forEach({ runOptions.append(.custom(option: $0)) })
        //        }
        
        if let buildDirectory = argumentIndex[dockerBuild.buildOnSuccess.keys.first!]?.first {
            if let buildURL = xcodeBuildLogDirectory(from: buildDirectory), try !lastBuildWasSuccess(at: buildURL) {
                return ProcessResult(output: "Last build failed. Skipped building in Docker", error: nil, exitCode: EXIT_FAILURE)
            }
        }
        
        let result = try xcodeHelpable.dockerBuild(sourcePath, with: runOptions, using: buildConfiguration, in: imageName, persistentVolumeName: persistentVolume, shouldLog: true)
        XcodeHelper.logger?.logWithNotification("Done building in docker")
        return result
    }
    //we have the func here instead of XcodeHelperKit because it requires use of ProcessInfo which is more likely to be available here
    //check BUILD_DIR/../../Logs/Build `ls -t` first item, it's gziped archive, last word in file is success or failed
    //if ls -t becomes a problem, Logs/Build/Cache.db is plist with most recent build in it with a highLevelStatus S or E, most recent build at top
    func lastBuildWasSuccess(at xcodeBuildLogDirectory: URL) throws -> Bool {
        guard let logURL = URLOfLastBuildLog(at: xcodeBuildLogDirectory) else {
            return false //no build log
        }
        guard let endOfFile = try decode(xcactivityLog: logURL) else { return false }
        return endOfFile.contains("succeeded")
    }
    func xcodeBuildLogDirectory(from xcodeBuildDir: String) -> URL? {
        let buildDirURL = URL(fileURLWithPath: xcodeBuildDir)// /target/Build/Products/../../Logs/Build
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Build", isDirectory: true)
        return buildDirURL
    }
    func URLOfLastBuildLog(at xcodeBuildDirURL: URL) -> URL? {
        //get a list of the files sorted DESC
        let result = ProcessRunner.synchronousRun("/bin/ls", arguments: ["-t1", xcodeBuildDirURL.path])
        //filter xcactivitylogs and get the first one
        guard let log = result.output?.components(separatedBy: "\n").compactMap({ $0.hasSuffix(".xcactivitylog") ? $0 : nil }).first else {
            return nil
        }
        return xcodeBuildDirURL.appendingPathComponent(log)
    }
    func decode(xcactivityLog: URL) throws -> String? {
        let result = ProcessRunner.synchronousRun("/usr/bin/gunzip", arguments: ["-cd", xcactivityLog.path], printOutput: false, outputPrefix: nil)
        guard let output = result.output, output.count > 0 else {
            throw XcodeHelperCliError.xcactivityLogDecode(message: result.error!)
        }
        let search = "Build succeeded"
        if let range = output.range(of: search, options: String.CompareOptions.backwards, range: nil, locale: nil),
            range.lowerBound.encodedOffset >= output.count - search.count - 10 {//it should be at the very end
            return String(output[range])
        }
        return nil
    }
    
    
    
    // MARK: Clean
    //    struct clean {
    //        static let command              = CliOption(keys: [Command.clean.rawValue, "CLEAN"],
    //                                                    description: "Run swift package --clean on your package.",
    //                                                    usage: "xchelper clean [OPTIONS]",
    //                                                    requiresValue: false,
    //                                                    defaultValue:nil)
    //        static let changeDirectory  = CliOption(keys:[changeDirectoryOption.short, changeDirectoryOption.long.rawValue, "CLEAN_\(changeDirectoryOption.envSuffix)"],
    //                                                description:"Change the current working directory.",
    //                                                usage:nil,
    //                                                requiresValue:true,
    //                                                defaultValue:nil)
    //    }
    //    public var cleanOption: CliOption {
    //        var cleanOption = clean.command
    //        cleanOption.optionalArguments = [clean.changeDirectory]
    //        cleanOption.action = handleClean
    //        return cleanOption
    //    }
    //    public func handleClean(option:CliOption) throws {
    //        let argumentIndex = option.argumentIndex
    //        let sourcePath = parseSourceCodePath(from: argumentIndex, with: clean.changeDirectory.keys.first)
    //        try xcodeHelpable.clean(sourcePath: sourcePath, shouldLog: true)
    //    }
    
    
    // MARK: SymlinkDependencies
    struct symlinkDependencies {
        static let command              = CliOption(keys: [Command.symlinkDependencies.cliName, Command.symlinkDependencies.envName],
                                                    description: Command.symlinkDependencies.description,
                                                    usage: "xchelper \(Command.symlinkDependencies.cliName) [OPTIONS]",
            requiresValue: false,
            defaultValue:nil)
        static let changeDirectory  = CliOption(keys:[changeDirectoryOption.short.rawValue, changeDirectoryOption.long.rawValue, "SYMLINK_DEPENDENCIES_\(changeDirectoryOption.envSuffix)"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
    }
    public var symlinkDependenciesOption: CliOption {
        var symlinkDependenciesOption = symlinkDependencies.command
        symlinkDependenciesOption.optionalArguments = [symlinkDependencies.changeDirectory];
        symlinkDependenciesOption.action = handleSymlinkDependencies
        return symlinkDependenciesOption
    }
    public func handleSymlinkDependencies(option:CliOption) throws {
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: symlinkDependencies.changeDirectory.keys.first)
        return try xcodeHelpable.symlinkDependencies(at: sourcePath, shouldLog: true)
    }
    
    
    // MARK: CreateArchive
    struct createArchive {
        static let command              = CliOption(keys: [Command.createArchive.cliName, Command.createArchive.envName],
                                                    description:Command.createArchive.description ,
                                                    usage: "xchelper \(Command.createArchive.cliName) ARCHIVE_PATH FILES [OPTIONS]. ARCHIVE_PATH the full path and filename for the archive to be created. FILES is a space separated list of full paths to the files you want to archive.",
            requiresValue: false,
            defaultValue: nil)
        static let flatList   = CliOption(keys:["-f", "--flat-list", "CREATE_ARCHIVE_FLAT_LIST"],
                                          description:"Put all the files in a flat list instead of maintaining directory structure",
                                          usage: nil,
                                          requiresValue:false,
                                          defaultValue:nil)
    }
    public var createArchiveOption: CliOption {
        var createArchiveOption = createArchive.command
        createArchiveOption.optionalArguments = [createArchive.flatList]
        createArchiveOption.action = handleCreateArchive
        return createArchiveOption
    }
    @discardableResult
    public func handleCreateArchive(option:CliOption) throws -> ProcessResult {
        XcodeHelper.logger = Logger(category: Command.createArchive.title)
        XcodeHelper.logger?.logWithNotification("Creating archive")
        let argumentIndex = option.argumentIndex
        guard let paths = argumentIndex[createArchive.command.keys.first!] else {
            throw XcodeHelperError.createArchive(message: "You didn't provide any paths.")
        }
        guard let archivePath = paths.first else {
            throw XcodeHelperError.createArchive(message: "You didn't provide the archive path.")
        }
        guard paths.count > 1 else {
            throw XcodeHelperError.createArchive(message: "You didn't provide any files to archive.")
        }
        var flatList = false
        if let _ = argumentIndex[createArchive.flatList.keys.first!]?.first {
            flatList = true
        }
        
        let filePaths = Array(paths[1..<paths.count])
        let result = try xcodeHelpable.createArchive(at: archivePath, with: filePaths, flatList: flatList, shouldLog: true)
        
        XcodeHelper.logger?.logWithNotification("Archive created")
        return result
    }
    
    
    // MARK: UploadArchive
    struct uploadArchive {
        static let command              = CliOption(keys: [Command.uploadArchive.cliName, Command.uploadArchive.envName],
                                                    description: Command.uploadArchive.description,
                                                    usage: "xchelper \(Command.uploadArchive.cliName) ARCHIVE_PATH [OPTIONS]. ARCHIVE_PATH the path of the archive that you want to upload to S3.",
            requiresValue: true,
            defaultValue:nil)
        static let bucket               = CliOption(keys:["-b", "--bucket", "UPLOAD_ARCHIVE_S3_BUCKET"],
                                                    description:"The bucket that you want to upload your archive to.",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:nil)
        static let region               = CliOption(keys:["-r", "--region", "UPLOAD_ARCHIVE_S3_REGION"],
                                                    description:"The bucket's region.",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:"us-east-1")
        static let key                  = CliOption(keys:["-k", "--key", "UPLOAD_ARCHIVE_S3_KEY"],
                                                    description:"The S3 key for the bucket.",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:nil)
        static let secret               = CliOption(keys:["-s", "--secret", "UPLOAD_ARCHIVE_S3_SECRET"],
                                                    description:"The secret for the key.",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:nil)
        static let credentialsFile      = CliOption(keys:["-c", "--credentials", "UPLOAD_ARCHIVE_CREDENTIALS"],
                                                    description:"If you don't want to provide the key and secret in a command, you can provide the path to a comma separated credentials file. \"$KEY,$SECRET\" ",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:nil)
    }
    public var uploadArchiveOption: CliOption {
        var uploadArchveOption = uploadArchive.command
        uploadArchveOption.requiredArguments = [uploadArchive.bucket, uploadArchive.region]//(key,secret) OR credentials check in handler
        uploadArchveOption.optionalArguments = [uploadArchive.key, uploadArchive.secret, uploadArchive.credentialsFile]
        uploadArchveOption.action = handleUploadArchive
        return uploadArchveOption
    }
    public func handleUploadArchive(option:CliOption) throws {
        XcodeHelper.logger = Logger(category: Command.uploadArchive.title)
        XcodeHelper.logger?.logWithNotification("Uploading archve")
        
        let argumentIndex = option.argumentIndex
        guard let archivePath = argumentIndex[uploadArchive.command.keys.first!]?.first else {
            throw XcodeHelperError.uploadArchive(message: "You didn't provide the path to the archive that you want to upload.")
        }
        guard let bucket = argumentIndex[uploadArchive.bucket.keys.first!]?.first else {
            throw XcodeHelperError.uploadArchive(message: "You didn't provide the S3 bucket to upload to.")
        }
        guard let region = argumentIndex[uploadArchive.region.keys.first!]?.first else {
            throw XcodeHelperError.uploadArchive(message: "You didn't provide the region for the bucket.")
        }
        
        if let key = argumentIndex[uploadArchive.key.keys.first!]?.first {
            guard let secret = argumentIndex[uploadArchive.secret.keys.first!]?.first else {
                throw XcodeHelperError.uploadArchive(message: "You didn't provide the secret for the key.")
            }
            try xcodeHelpable.uploadArchive(at: archivePath, to: bucket, in: region, key: key, secret: secret, shouldLog: true)
            
        } else if let file = argumentIndex[uploadArchive.credentialsFile.keys.first!]?.first {
            try xcodeHelpable.uploadArchive(at: archivePath, to: bucket, in: region, using: file, shouldLog: true)
            
        } else {
            throw XcodeHelperError.uploadArchive(message: "You must provide either a credentials file or a key and secret")
        }
        XcodeHelper.logger?.logWithNotification("Archive uploaded")
    }
    
    
    // MARK: GitTag
    struct gitTag {
        static let command              = CliOption(keys: [Command.gitTag.cliName, Command.gitTag.envName],
                                                    description: Command.gitTag.description,
                                                    usage: "xchelper \(Command.gitTag.cliName) [OPTIONS]",
            requiresValue: false,
            defaultValue: nil)
        static let changeDirectory      = CliOption(keys:[changeDirectoryOption.short.rawValue, changeDirectoryOption.long.rawValue, "GIT_TAG_\(changeDirectoryOption.envSuffix)"],
                                                    description:"Change the current working directory.",
                                                    usage:nil,
                                                    requiresValue:true,
                                                    defaultValue:nil)
        static let versionOption        = CliOption(keys: ["-v", "--version", "GIT_TAG_VERSION"],
                                                    description: "Specify exactly what the version should be.",
                                                    usage: nil,
                                                    requiresValue: true,
                                                    defaultValue: nil)
        static let incrementOption      = CliOption(keys: ["-i", "--increment", "GIT_TAG_INCREMENT"],
                                                    description: "Automatically increment a portion of the repo's tag. Valid values are [major, minor, patch]",
                                                    usage: nil,
                                                    requiresValue: true,
                                                    defaultValue: "patch")
        static let pushOption           = CliOption(keys: ["-p", "--push", "GIT_TAG_PUSH"],
                                                    description: "Push your tag with `git push && git push origin #.#.#`",
                                                    usage: nil,
                                                    requiresValue: false,
                                                    defaultValue: nil)
    }
    public var gitTagOption: CliOption {
        var gitTagOption = gitTag.command
        gitTagOption.optionalArguments = [gitTag.changeDirectory, gitTag.versionOption, gitTag.incrementOption, gitTag.pushOption]
        gitTagOption.action = handleGitTag
        return gitTagOption
    }
    @discardableResult
    public func handleGitTag(option:CliOption) throws -> ProcessResult {
        XcodeHelper.logger = Logger(category: Command.gitTag.title)
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: gitTag.changeDirectory.keys.first!)
        XcodeHelper.logger?.logWithNotification("Updating %@", URL.init(fileURLWithPath: sourcePath).lastPathComponent)
        var outputString: String?
        var processResult: ProcessResult?
        do {
            var versionString: String?
            
            //update from user input
            if let version = argumentIndex[gitTag.versionOption.keys.first!]?.first {
                processResult = try xcodeHelpable.gitTag(version, repo: sourcePath, shouldLog: true)
                versionString = version
                
            }else if let componentString = argumentIndex[gitTag.incrementOption.keys.first!]?.first,
                let component = GitTagComponent.init(stringValue: componentString) {
                versionString = try xcodeHelpable.incrementGitTag(component: component, at: sourcePath, shouldLog: true)
                
            }else{
                guard let componentString = argumentIndex[gitTag.incrementOption.keys.first!] else {
                    throw XcodeHelperError.gitTagParse(message: "You must provide either \(gitTag.versionOption.keys) OR \(gitTag.incrementOption.keys)")
                }
                let stringValue: String = componentString.first ?? GitTagComponent.patch.description
                guard let component = GitTagComponent(stringValue: stringValue) else {
                    throw XcodeHelperError.gitTagParse(message: "Unknown value \(componentString)")
                }
                versionString = try xcodeHelpable.incrementGitTag(component: component, at: sourcePath, shouldLog: true)
            }
            
            if let tag = versionString {
                outputString = tag
                if argumentIndex.yamlBoolValue(forKey: gitTag.pushOption.keys.first!) == true {
                    try xcodeHelpable.pushGitTag(tag: tag, at: sourcePath, shouldLog: true)
                }
            }
            
        } catch XcodeHelperError.gitTag(_) {
            //no current tag, just start it at 0.0.1
            outputString = "0.0.1"
            processResult = try xcodeHelpable.gitTag(outputString!, repo: sourcePath, shouldLog: true)
        }
        
        //if let str = outputString {
        //    print(str)
        //}
        let result = processResult ?? ProcessResult(output: nil, error: "Failed to execute", exitCode: EXIT_FAILURE)
        XcodeHelper.logger?.logWithNotification("Done updating Git Tag")
        return result
    }
    
    
    // MARK: CreateXcarchive
    struct createXcarchive {
        
        static let command              = CliOption(keys: [Command.createXcarchive.cliName, Command.createXcarchive.envName],
                                                    description: Command.createXcarchive.description,
                                                    usage: "xchelper \(Command.createXcarchive.cliName) XCARCHIVE_PATH [OPTIONS]. XCARCHIVE_PATH is the directory (.xcarchive) where you want the Info.plist created in. ",
            requiresValue: true,
            defaultValue: nil)
        //        static let nameOption          = CliOption(keys: ["-n", "--name", "CREATE_PLIST_APP_NAME"],
        //                                                   description: "The app name to include in the `Name` field of the Info.plist.",
        //                                                   usage: nil,
        //                                                   requiresValue: true,
        //                                                   defaultValue: nil)
        static let schemeOption          = CliOption(keys: ["-s", "--scheme", "CREATE_PLIST_SCHEME"],
                                                     description: "The scheme name to include in the `Scheme` field of the Info.plist.",
                                                     usage: nil,
                                                     requiresValue: true,
                                                     defaultValue: nil)
    }
    public var createXcarchiveOption: CliOption {
        var createXcarchiveOption = createXcarchive.command
        createXcarchiveOption.requiredArguments = [createXcarchive.schemeOption]//createXcarchive.nameOption,
        createXcarchiveOption.action = handleCreateXcarchive
        return createXcarchiveOption
    }
    //returns the path to the new xcarchive
    public func handleCreateXcarchive(option:CliOption) throws -> ProcessResult {
        XcodeHelper.logger = Logger(category: Command.createXcarchive.title)
        XcodeHelper.logger?.logWithNotification("Creating XCAchrive")
        let argumentIndex = option.argumentIndex
        guard var paths = argumentIndex[createXcarchive.command.keys.first!] else {
            throw XcodeHelperError.createXcarchive(message: "You didn't provide any paths.")
        }
        guard let archivePath = paths.first else {
            throw XcodeHelperError.createXcarchive(message: "You didn't provide the archive path.")
        }
        guard paths.count > 1 else {
            throw XcodeHelperError.createXcarchive(message: "You didn't provide the path to the binary which you want to archive.")
        }
        //        guard let name = argumentIndex[createXcarchive.nameOption.keys.first!]?.first else {
        //            throw XcodeHelperError.createXcarchive(message: "You didn't provide the name to include in the plist.")
        //        }
        guard let scheme = argumentIndex[createXcarchive.schemeOption.keys.first!]?.first else {
            throw XcodeHelperError.createXcarchive(message: "You didn't provide the scheme to include in the plist.")
        }
        paths.removeFirst()
        let result = try xcodeHelpable.createXcarchive(in: archivePath, with: paths.first!, from: scheme, shouldLog: true)
        //print(outputString)
        XcodeHelper.logger?.logWithNotification("Updating creating XCArchive")
        return result
    }
    
}
