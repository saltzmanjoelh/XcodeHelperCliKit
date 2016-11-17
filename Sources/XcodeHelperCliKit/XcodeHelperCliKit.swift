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

//TODO: add currentDirectory to handle action?

// MARK: Cli Options
extension XcodeHelper: CliRunnable {
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
    
    
    public var cliOptionGroups: [CliOptionGroup] {
        get {
            var fetchPackagesOption = FetchPackages.command
            fetchPackagesOption.optionalArguments = [FetchPackages.changeDirectory, FetchPackages.linuxPackages, FetchPackages.imageName]
            fetchPackagesOption.action = handleFetchPackages
            
            var updatePackagesOption = UpdatePackages.command
            updatePackagesOption.optionalArguments = [UpdatePackages.changeDirectory, UpdatePackages.linuxPackages, UpdatePackages.imageName]
            updatePackagesOption.action = handleUpdatePackages
            
            var buildOption = Build.command
            buildOption.optionalArguments = [Build.changeDirectory, Build.buildConfiguration, Build.imageName]
            buildOption.action = handleBuild
            
            var cleanOption = Clean.command
            cleanOption.optionalArguments = [Clean.changeDirectory]
            cleanOption.action = handleClean
            
            var symLinkDependenciesOption = SymlinkDependencies.command
            symLinkDependenciesOption.optionalArguments = [SymlinkDependencies.changeDirectory];
            symLinkDependenciesOption.action = handleSymlinkDependencies
            
            var createArchiveOption = CreateArchive.command
            createArchiveOption.optionalArguments = [CreateArchive.flatList]
            createArchiveOption.action = handleCreateArchive
            
            var uploadArchve = UploadArchive.command
            uploadArchve.requiredArguments = [UploadArchive.bucket, UploadArchive.region]//(key,secret) OR credentials check in handler
            
            var gitTagOption = GitTag.command
            gitTagOption.optionalArguments = [GitTag.changeDirectory, GitTag.versionOption, GitTag.incrementOption]
            gitTagOption.action = handleGitTag
            
            var createPlistOption = CreateXcarchive.command
            createPlistOption.requiredArguments = [CreateXcarchive.nameOption, CreateXcarchive.schemeOption]
            createPlistOption.action = handleCreateArchive
            
            return [CliOptionGroup(description:"Commands:",
                                   options:[fetchPackagesOption, updatePackagesOption, buildOption, cleanOption, symLinkDependenciesOption, createArchiveOption, uploadArchve, gitTagOption, createPlistOption])]
        }
    }
    
    // MARK: FetchPackages
    struct FetchPackages {
        static let command          = CliOption(keys: ["fetch-packages", "FETCH_PACKAGES"],
                                                description: "Fetch the package dependencies via 'swift package fetch'.",
                                                usage: "xchelper fetch-packages [OPTIONS]",
                                                requiresValue: false,
                                                defaultValue:nil)
        static let changeDirectory  = CliOption(keys:["-C", "--chdir", "XCHELPER_CHDIR"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
        static let linuxPackages    = CliOption(keys:["-l", "--linux-packages", "FETCH_PACKAGES_LINUX_PACKAGES"],
                                                description:"Fetch the Linux version of the packages. Some packages have Linux specific dependencies which may not be compatible with the macOS dependencies. `swift build --clean` is performed before they are fetched.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:"false")
        static let imageName        = CliOption(keys:["-i", "--image-name", "FETCH_PACKAGES_DOCKER_IMAGE_NAME"],
                                                description:"The Docker image name to run the commands in.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:"saltzmanjoelh/swiftubuntu")
    }
    public func handleFetchPackages(option:CliOption) throws {
        let index = option.argumentIndex
        var sourcePath: String?
        if let customDirectory = index[FetchPackages.changeDirectory.keys.first!]?.first {
            sourcePath = customDirectory
        }else{
            sourcePath = FileManager.default.currentDirectoryPath
        }
        guard let forLinux = index[FetchPackages.linuxPackages.keys.first!]?.first else {
            throw XcodeHelperError.fetch(message: "\(FetchPackages.linuxPackages.keys) keys were not provided.")
        }
        
        guard let imageName = index[FetchPackages.imageName.keys.first!]?.first else {
            throw XcodeHelperError.fetch(message: "\(FetchPackages.imageName.keys) keys were not provided.")
        }
        try fetchPackages(at:sourcePath!, forLinux:(forLinux as NSString).boolValue, inDockerImage: imageName)
    }
    
    // MARK: UpdatePackages
    struct UpdatePackages {
        static let command          = CliOption(keys: ["update-packages", "UPDATE_PACKAGES"],
                                                description: "Update the package dependencies via 'swift package update' without breaking your file references in Xcode.",
                                                usage: "xchelper update-packages [OPTIONS]",
                                                requiresValue: false,
                                                defaultValue:nil)
        static let changeDirectory  = CliOption(keys:["-C", "--chdir", "XCHELPER_CHDIR"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
        static let linuxPackages    = CliOption(keys:["-l", "--linux-packages", "UPDATE_PACKAGES_LINUX_PACKAGES"],
                                                description:"Some packages have Linux specific dependencies. Use this option to update the Linux version of the packages. Linux packages may not be compatible with the macOS dependencies. `swift build --clean` is performed before they are updated",
                                                usage: nil,
                                                requiresValue:true,
                                                defaultValue:"false")
        static let imageName        = CliOption(keys:["-i", "--image-name", "UPDATE_PACKAGES_DOCKER_IMAGE_NAME"],
                                                description:"The Docker image name to run the commands in",
                                                usage: nil,
                                                requiresValue:true,
                                                defaultValue:"saltzmanjoelh/swiftubuntu")
    }
    public func handleUpdatePackages(option:CliOption) throws {
        let index = option.argumentIndex
        var sourcePath: String?
        if let customDirectory = index[UpdatePackages.changeDirectory.keys.first!]?.first {
            sourcePath = customDirectory
        }else{
            sourcePath = FileManager.default.currentDirectoryPath
        }
        guard let forLinux = index[UpdatePackages.linuxPackages.keys.first!]?.first else {
            throw XcodeHelperError.update(message: "\(UpdatePackages.linuxPackages.keys) keys were not provided.")
        }
        
        guard let imageName = index[UpdatePackages.imageName.keys.first!]?.first else {
            throw XcodeHelperError.update(message: "\(UpdatePackages.imageName.keys) keys were not provided.")
        }
        try updatePackages(at:sourcePath!, forLinux:(forLinux as NSString).boolValue, inDockerImage: imageName)
    }
    
    // MARK: Build
    struct Build {
        static let command              = CliOption(keys: ["build", "BUILD"],
                                                    description: "Build a Swift package in Linux and have the build errors appear in Xcode.",
                                                    usage: "xchelper build [OPTIONS]",
                                                    requiresValue: false,
                                                    defaultValue:nil)
        static let changeDirectory      = CliOption(keys:["-C", "--chdir", "XCHELPER_CHDIR"],
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
        let index = option.argumentIndex
        var sourcePath: String?
        if let customDirectory = index[Build.changeDirectory.keys.first!]?.first {
            sourcePath = customDirectory
        }else{
            sourcePath = FileManager.default.currentDirectoryPath
        }
        guard let buildConfigurationString = index[Build.buildConfiguration.keys.first!]?.first else {
            throw XcodeHelperError.build(message: "\(Build.buildConfiguration.keys) not provided.", exitCode: 1)
        }
        let buildConfiguration = BuildConfiguration(from:buildConfigurationString)
        
        guard let imageName = index[Build.imageName.keys.first!]?.first else {
            throw XcodeHelperError.build(message: "\(Build.imageName.keys) not provided.", exitCode: 1)
        }
        try build(source: sourcePath!, usingConfiguration: buildConfiguration, inDockerImage: imageName)
    }
    
    // MARK: Clean
    struct Clean {
        static let command              = CliOption(keys: ["clean", "CLEAN"],
                                                    description: "Run swift build --clean on your package.",
                                                    usage: "xchelper clean [OPTIONS]",
                                                    requiresValue: false,
                                                    defaultValue:nil)
        static let changeDirectory  = CliOption(keys:["-C", "--chdir", "XCHELPER_CHDIR"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
    }
    public func handleClean(option:CliOption) throws {
        let index = option.argumentIndex
        var sourcePath: String?
        if let customDirectory = index[Clean.changeDirectory.keys.first!]?.first {
            sourcePath = customDirectory
        }else{
            sourcePath = FileManager.default.currentDirectoryPath
        }
        try clean(source: sourcePath!)
    }
    
    // MARK: SymlinkDependencies
    struct SymlinkDependencies {
        static let command              = CliOption(keys: ["symlink-dependencies", "SYMLINK_DEPENDENCIES"],
                                                    description: "Create symbolic links for Xcode 'Dependencies' after `swift package update` so you don't have to generate a new xcode project.",
                                                    usage: "xchelper symlink-dependencies [OPTIONS]",
                                                    requiresValue: false,
                                                    defaultValue:nil)
        static let changeDirectory  = CliOption(keys:["-C", "--chdir", "XCHELPER_CHDIR"],
                                                description:"Change the current working directory.",
                                                usage:nil,
                                                requiresValue:true,
                                                defaultValue:nil)
    }
    public func handleSymlinkDependencies(option:CliOption) throws {
        let index = option.argumentIndex
        var sourcePath: String?
        if let customDirectory = index[SymlinkDependencies.changeDirectory.keys.first!]?.first {
            sourcePath = customDirectory
        }else{
            sourcePath = FileManager.default.currentDirectoryPath
        }
        try symLinkDependencies(sourcePath: sourcePath!)
    }
    
    // MARK: CreateArchive
    struct CreateArchive {
        static let command              = CliOption(keys: ["create-archive", "CREATE_ARCHIVE"],
                                                    description: "Archive files with tar.",
                                                    usage: "xchelper create-archive ARCHIVE_PATH FILES [OPTIONS]. ARCHIVE_PATH the full path and filename for the archive to be created. FILES is a space separated list of full paths to the files you want to archive.",
                                                    requiresValue: false,
                                                    defaultValue: nil)
        static let flatList   = CliOption(keys:["-f", "--flat-list", "CREATE_ARCHIVE_FLAT_LIST"],
                                          description:"Put all the files in a flat list instead of maintaining directory structure",
                                          usage: nil,
                                          requiresValue:true,
                                          defaultValue:"true")
    }
    public func handleCreateArchive(option:CliOption) throws {
        let index = option.argumentIndex
        guard let paths = index[CreateArchive.command.keys.first!] else {
            throw XcodeHelperError.createArchive(message: "You didn't provide any paths.")
        }
        guard let archivePath = paths.first else {
            throw XcodeHelperError.createArchive(message: "You didn't provide the archive path.")
        }
        guard paths.count > 1 else {
            throw XcodeHelperError.createArchive(message: "You didn't provide any files to archive.")
        }
        let filePaths = Array(paths[1..<paths.count])
        try createArchive(at: archivePath, with: filePaths)
    }
    
    // MARK: UploadArchive
    struct UploadArchive {
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
        static let credentialsFile      = CliOption(keys:["-c", "--credentials", "UPLOAD_ARCHIVE_CREDENTIALS"],
                                                    description:"The secret for the key.",
                                                    usage: nil,
                                                    requiresValue:true,
                                                    defaultValue:nil)
    }
    public func handleUploadArchive(option:CliOption) throws {
        let index = option.argumentIndex
        guard let archivePath = index[UploadArchive.command.keys.first!]?.first else {
            throw XcodeHelperError.uploadArchive(message: "You didn't prove the path to the archive that you want to upload.")
        }
        guard let bucket = index[UploadArchive.bucket.keys.first!]?.first else {
            throw XcodeHelperError.uploadArchive(message: "You didn't provide the S3 bucket to upload to.")
        }
        guard let region = index[UploadArchive.region.keys.first!]?.first else {
            throw XcodeHelperError.uploadArchive(message: "You didn't provide the region for the bucket.")
        }
        
        if index[UploadArchive.key.keys.first!]?.first != nil {
            if let key = index[UploadArchive.key.keys.first!]?.first {
                guard let secret = index[UploadArchive.secret.keys.first!]?.first else {
                    throw XcodeHelperError.uploadArchive(message: "You didn't provide the secret for the key.")
                }
                try uploadArchive(at: archivePath, to: bucket, in: region, key: key, secret: secret)
            }
            
        } else if index[UploadArchive.credentialsFile.keys.first!]?.first != nil {
            if let file = index[UploadArchive.credentialsFile.keys.first!]?.first {
                try uploadArchive(at: archivePath, to: bucket, in: region, using: file)
            }
            
        } else {
            throw XcodeHelperError.uploadArchive(message: "You must provide either a credentials file or a key and secret")
        }
    }
    
    // MARK: GitTag
    struct GitTag {
        //TODO: how do I set a default flag here?
        static let command              = CliOption(keys: ["git-tag", "GIT_TAG"],
                                                    description: "Update your package's git repo's semantic versioned tag",
                                                    usage: "xchelper git-tag [OPTIONS]",
                                                    requiresValue: false,
                                                    defaultValue: nil)
        static let changeDirectory      = CliOption(keys:["-C", "--chdir", "XCHELPER_CHDIR"],
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
    }
    public func handleGitTag(option:CliOption) throws {
        let index = option.argumentIndex
        var sourcePath: String?
        if let customDirectory = index[GitTag.changeDirectory.keys.first!]?.first {
            sourcePath = customDirectory
        }else{
            sourcePath = FileManager.default.currentDirectoryPath
        }
        do {
            
            //update from user input
            if let version = index[GitTag.versionOption.keys.first!]?.first {
                try gitTag(tag: version, at: sourcePath!)
                
            }else if let componentString = index[GitTag.incrementOption.keys.first!]?.first {
                guard let component = GitTagComponent(rawValue: componentString) else {
                    throw XcodeHelperError.gitTagParse(message: "Unknown value \(componentString)")
                }
                try incrementGitTag(components: [component], at: sourcePath!)
            }else{
                throw XcodeHelperError.gitTagParse(message: "You must provide either \(GitTag.versionOption.keys) OR \(GitTag.incrementOption.keys)")
            }
            
        } catch XcodeHelperError.gitTag(_) {
            //no current tag, just start it at 0.0.1
            try gitTag(tag: "0.0.1" , at: sourcePath!)
        }
        
        
    }
    
    // MARK: CreateXcarchive
    struct CreateXcarchive {
        
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
        let index = option.argumentIndex
        guard let archivePath = index[CreateXcarchive.command.keys.first!]?.first else {
            throw XcodeHelperError.createArchive(message: "You didn't prove the path to the xcarchive.")
        }
        guard let name = index[CreateXcarchive.nameOption.keys.first!]?.first else {
            throw XcodeHelperError.createArchive(message: "You didn't prove the name to include in the plist.")
        }
        guard let scheme = index[CreateXcarchive.schemeOption.keys.first!]?.first else {
            throw XcodeHelperError.createArchive(message: "You didn't prove the scheme to include in the plist.")
        }
        return try createXcarchive(in: archivePath, with: name, from: scheme)
    }

}
