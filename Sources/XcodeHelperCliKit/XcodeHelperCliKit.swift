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

public struct XCHelper : CliRunnable {
    
    public var xcodeHelpable: XcodeHelpable
    
    public init(xcodeHelpable:XcodeHelpable) {
        self.xcodeHelpable = xcodeHelpable
    }
    
    public var appName: String {
        get {
            return "xchelper"
        }
    }
    public var description: String? {
        get {
            return "xchelper keeps in Xcode and off the command line. You can build and run tests on Linux through Docker, fetch Swift packages, keep your \"Dependencies\" group in Xcode referencing the correct paths and tar and upload you Linux binary to AWS S3 buckets."
        }
    }
    public var appUsage: String? {
        return "xchelper COMMAND [OPTIONS]"
    }
    
    public func parseSourceCodePath(from argumentIndex: [String:[String]], with optionKey: String?) -> String {
        if let key = optionKey, let customDirectory = argumentIndex[key]?.first {
            return customDirectory
        }
        return FileManager.default.currentDirectoryPath
    }
    
    
    public var cliOptionGroups: [CliOptionGroup] {
        get {
            return [CliOptionGroup(description:"Commands:",
                                   options:[updatePackagesOption, buildOption, cleanOption, symlinkDependenciesOption, createArchiveOption, uploadArchiveOption, gitTagOption, createXcarchiveOption])]
        }
    }
    
    // MARK: UpdatePackages
    struct updatePackages {
        static let command          = CliOption(keys: ["update-packages", "UPDATE_PACKAGES"],
                                                description: "Update the package dependencies via 'swift package update' without breaking your file references in Xcode.",
                                                usage: "xchelper update-packages [OPTIONS]",
                                                requiresValue: false,
                                                defaultValue:nil)
        static let changeDirectory  = CliOption(keys:["-d", "--chdir", "XCHELPER_CHDIR"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
        static let linuxPackages    = CliOption(keys:["-l", "--linux-packages", "UPDATE_PACKAGES_LINUX_PACKAGES"],
                                                description:"Some packages have Linux specific dependencies. Use this option to update the Linux version of the packages. Linux packages may not be compatible with the macOS dependencies. `swift build --clean` is performed before they are updated",
                                                usage: "Just provide the one of the keys, no bool value required.",
                                                requiresValue:false,
                                                defaultValue: nil)
        static let symlink          = CliOption(keys:["-s", "--symlink", "UPDATE_PACKAGES_SYMLINK"],
                                                description:"Create symbolic links for the dependency 'Packages' after `swift package update` so you don't have to generate a new xcode project.",
                                                usage: nil,
                                                requiresValue:false,
                                                defaultValue: nil)
        static let imageName        = CliOption(keys:["-i", "--image-name", "UPDATE_PACKAGES_DOCKER_IMAGE_NAME"],
                                                description:"The Docker image name to run the commands in",
                                                usage: nil,
                                                requiresValue:true,
                                                defaultValue:"saltzmanjoelh/swiftubuntu")
    }
    public func handleUpdatePackages(option:CliOption) throws {
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: updatePackages.changeDirectory.keys.first)
        
        var forLinux = false
        if let forLinuxString = argumentIndex[updatePackages.linuxPackages.keys.first!]?.first {
            forLinux = (forLinuxString as NSString).boolValue
        }
        guard let imageName = argumentIndex[updatePackages.imageName.keys.first!]?.first else {
            throw XcodeHelperError.update(message: "\(updatePackages.imageName.keys) keys were not provided.")
        }
        
        try xcodeHelpable.updatePackages(at:sourcePath, forLinux:forLinux, inDockerImage: imageName)
        if argumentIndex[updatePackages.symlink.keys.first!] != nil {
            try xcodeHelpable.symlinkDependencies(sourcePath: sourcePath)
        }
    }
    public var updatePackagesOption: CliOption {
        var updatePackagesOption = updatePackages.command
        updatePackagesOption.optionalArguments = [updatePackages.changeDirectory, updatePackages.linuxPackages, updatePackages.symlink, updatePackages.imageName]
        updatePackagesOption.action = handleUpdatePackages
        return updatePackagesOption
    }
    
    // MARK: Build
    struct build {
        static let command              = CliOption(keys: ["build", "BUILD"],
                                                    description: "Build a Swift package in Linux and have the build errors appear in Xcode.",
                                                    usage: "xchelper build [OPTIONS]",
                                                    requiresValue: false,
                                                    defaultValue:nil)
        static let changeDirectory      = CliOption(keys:["-d", "--chdir", "XCHELPER_CHDIR"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
        static let buildConfiguration   = CliOption(keys:["-c", "--build-configuration", "BUILD_CONFIGURATION"],
                                                    description:"debug or release mode",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:"debug")
        static let imageName            = CliOption(keys:["-i", "--image-name", "BUILD_DOCKER_IMAGE_NAME"],
                                                    description:"The Docker image name to run the commands in",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:"saltzmanjoelh/swiftubuntu")
    }
    public func handleBuild(option:CliOption) throws {
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: build.changeDirectory.keys.first)
        
        guard let buildConfigurationString = argumentIndex[build.buildConfiguration.keys.first!]?.first else {
            throw XcodeHelperError.build(message: "\(build.buildConfiguration.keys) not provided.", exitCode: 1)
        }
        let buildConfiguration = BuildConfiguration(from:buildConfigurationString)
        guard let imageName = argumentIndex[build.imageName.keys.first!]?.first else {
            throw XcodeHelperError.build(message: "\(build.imageName.keys) not provided.", exitCode: 1)
        }
        try xcodeHelpable.build(source: sourcePath, usingConfiguration: buildConfiguration, inDockerImage: imageName, removeWhenDone: true)
    }
    public var buildOption: CliOption {
        var buildOption = build.command
        buildOption.optionalArguments = [build.changeDirectory, build.buildConfiguration, build.imageName]
        buildOption.action = handleBuild
        return buildOption
    }
    
    // MARK: Clean
    struct clean {
        static let command              = CliOption(keys: ["clean", "CLEAN"],
                                                    description: "Run swift build --clean on your package.",
                                                    usage: "xchelper clean [OPTIONS]",
                                                    requiresValue: false,
                                                    defaultValue:nil)
        static let changeDirectory  = CliOption(keys:["-d", "--chdir", "XCHELPER_CHDIR"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
    }
    public func handleClean(option:CliOption) throws {
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: clean.changeDirectory.keys.first)
        try xcodeHelpable.clean(sourcePath: sourcePath)
    }
    public var cleanOption: CliOption {
        var cleanOption = clean.command
        cleanOption.optionalArguments = [clean.changeDirectory]
        cleanOption.action = handleClean
        return cleanOption
    }
    
    // MARK: SymlinkDependencies
    struct symlinkDependencies {
        static let command              = CliOption(keys: ["symlink-dependencies", "SYMLINK_DEPENDENCIES"],
                                                    description: "Create symbolic links for the dependency 'Packages' after `swift package update` so you don't have to generate a new xcode project.",
                                                    usage: "xchelper symlink-dependencies [OPTIONS]",
                                                    requiresValue: false,
                                                    defaultValue:nil)
        static let changeDirectory  = CliOption(keys:["-d", "--chdir", "XCHELPER_CHDIR"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
    }
    public func handleSymlinkDependencies(option:CliOption) throws {
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: symlinkDependencies.changeDirectory.keys.first)
        try xcodeHelpable.symlinkDependencies(sourcePath: sourcePath)
    }
    public var symlinkDependenciesOption: CliOption {
        var symlinkDependenciesOption = symlinkDependencies.command
        symlinkDependenciesOption.optionalArguments = [symlinkDependencies.changeDirectory];
        symlinkDependenciesOption.action = handleSymlinkDependencies
        return symlinkDependenciesOption
    }
    
    // MARK: CreateArchive
    struct createArchive {
        static let command              = CliOption(keys: ["create-archive", "CREATE_ARCHIVE"],
                                                    description: "Archive files with tar.",
                                                    usage: "xchelper create-archive ARCHIVE_PATH FILES [OPTIONS]. ARCHIVE_PATH the full path and filename for the archive to be created. FILES is a space separated list of full paths to the files you want to archive.",
                                                    requiresValue: false,
                                                    defaultValue: nil)
        static let flatList   = CliOption(keys:["-f", "--flat-list", "CREATE_ARCHIVE_FLAT_LIST"],
                                          description:"Put all the files in a flat list instead of maintaining directory structure",
                                          usage: nil,
                                          requiresValue:false,
                                          defaultValue:nil)
    }
    public func handleCreateArchive(option:CliOption) throws {
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
        try xcodeHelpable.createArchive(at: archivePath, with: filePaths, flatList: flatList)
    }
    public var createArchiveOption: CliOption {
        var createArchiveOption = createArchive.command
        createArchiveOption.optionalArguments = [createArchive.flatList]
        createArchiveOption.action = handleCreateArchive
        return createArchiveOption
    }
    
    // MARK: UploadArchive
    struct uploadArchive {
        static let command              = CliOption(keys: ["upload-archive", "UPLOAD_ARCHIVE"],
                                                    description: "Upload an archive to S3",
                                                    usage: "xchelper upload-archive ARCHIVE_PATH [OPTIONS]. ARCHIVE_PATH the path of the archive that you want to upload to S3.",
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
        static let credentialsFile      = CliOption(keys:["-d", "--credentials", "UPLOAD_ARCHIVE_CREDENTIALS"],
                                                    description:"The secret for the key.",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:nil)
    }
    public func handleUploadArchive(option:CliOption) throws {
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
            try xcodeHelpable.uploadArchive(at: archivePath, to: bucket, in: region, key: key, secret: secret)
            
        } else if let file = argumentIndex[uploadArchive.credentialsFile.keys.first!]?.first {
                try xcodeHelpable.uploadArchive(at: archivePath, to: bucket, in: region, using: file)
            
        } else {
            throw XcodeHelperError.uploadArchive(message: "You must provide either a credentials file or a key and secret")
        }
    }
    public var uploadArchiveOption: CliOption {
        var uploadArchveOption = uploadArchive.command
        uploadArchveOption.requiredArguments = [uploadArchive.bucket, uploadArchive.region]//(key,secret) OR credentials check in handler
        return uploadArchveOption
    }
    
    // MARK: GitTag
    struct gitTag {
        static let command              = CliOption(keys: ["git-tag", "GIT_TAG"],
                                                    description: "Update your package's git repo's semantic versioned tag",
                                                    usage: "xchelper git-tag [OPTIONS]",
                                                    requiresValue: false,
                                                    defaultValue: nil)
        static let changeDirectory      = CliOption(keys:["-d", "--chdir", "XCHELPER_CHDIR"],
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
    
    public func handleGitTag(option:CliOption) throws {
        let argumentIndex = option.argumentIndex
        let sourcePath = parseSourceCodePath(from: argumentIndex, with: gitTag.changeDirectory.keys.first!)
        var outputString: String?
        do {
            var versionString: String?

            //update from user input
            if let version = argumentIndex[gitTag.versionOption.keys.first!]?.first {
                try xcodeHelpable.gitTag(tag: version, at: sourcePath)
                versionString = version
                
            }else{
                guard let componentString = argumentIndex[gitTag.incrementOption.keys.first!]?.first else {
                    throw XcodeHelperError.gitTagParse(message: "You must provide either \(gitTag.versionOption.keys) OR \(gitTag.incrementOption.keys)")
                }
                guard let component = GitTagComponent(rawValue: componentString) else {
                    throw XcodeHelperError.gitTagParse(message: "Unknown value \(componentString)")
                }
                versionString = try xcodeHelpable.incrementGitTag(components: [component], at: sourcePath)
            }

            if let tag = versionString, argumentIndex[gitTag.pushOption.keys.first!] != nil {
                outputString = tag
                try xcodeHelpable.pushGitTag(tag: tag, at: sourcePath)
            }

        } catch XcodeHelperError.gitTag(_) {
            //no current tag, just start it at 0.0.1
            outputString = "0.0.1"
            try xcodeHelpable.gitTag(tag: outputString! , at: sourcePath)
        }
        
        if let str = outputString {
            print(str)
        }
    }
    public var gitTagOption: CliOption {
        var gitTagOption = gitTag.command
        gitTagOption.optionalArguments = [gitTag.changeDirectory, gitTag.versionOption, gitTag.incrementOption, gitTag.pushOption]
        gitTagOption.action = handleGitTag
        return gitTagOption
    }
    
    // MARK: CreateXcarchive
    struct createXcarchive {
        
        static let command              = CliOption(keys: ["create-xcarchive", "CREATE_XCARCHIVE"],
                                                    description: "Store your built binary in an xcarchive where Xcode's Organizer can keep track",
                                                    usage: "xchelper create-xcarchive-plist XCARCHIVE_PATH [OPTIONS]. XCARCHIVE_PATH is the directory (.xcarchive) where you want the Info.plist created in. ",
                                                    requiresValue: true,
                                                    defaultValue: nil)
        static let nameOption          = CliOption(keys: ["-n", "--name", "CREATE_PLIST_APP_NAME"],
                                                   description: "The app name to include in the `Name` field of the Info.plist.",
                                                   usage: nil,
                                                   requiresValue: true,
                                                   defaultValue: nil)
        static let schemeOption          = CliOption(keys: ["-s", "--scheme", "CREATE_PLIST_SCHEME"],
                                                     description: "The scheme name to include in the `Scheme` field of the Info.plist.",
                                                     usage: nil,
                                                     requiresValue: true,
                                                     defaultValue: nil)
    }
    //returns the path to the new xcarchive
    public func handleCreateXcarchive(option:CliOption) throws -> String {
        let argumentIndex = option.argumentIndex
        guard let archivePath = argumentIndex[createXcarchive.command.keys.first!]?.first else {
            throw XcodeHelperError.createArchive(message: "You didn't prove the path to the xcarchive.")
        }
        guard let name = argumentIndex[createXcarchive.nameOption.keys.first!]?.first else {
            throw XcodeHelperError.createArchive(message: "You didn't prove the name to include in the plist.")
        }
        guard let scheme = argumentIndex[createXcarchive.schemeOption.keys.first!]?.first else {
            throw XcodeHelperError.createArchive(message: "You didn't prove the scheme to include in the plist.")
        }
        return try xcodeHelpable.createXcarchive(in: archivePath, with: name, from: scheme)
    }
    public var createXcarchiveOption: CliOption {
        var createXcarchiveOption = createXcarchive.command
        createXcarchiveOption.requiredArguments = [createXcarchive.nameOption, createXcarchive.schemeOption]
        createXcarchiveOption.action = handleCreateArchive
        return createXcarchiveOption
    }
}
