#XcodeHelperCli

[![Build Status][image-1]][1] [![Swift Version][image-2]][2]

XcodeHelperCli keeps you in Xcode and off the command line. It's built from [XcodeHelperKit](https://www.github.com/saltzmanjoelh/XcodeHelperKit). 

- [Build and run tests on Linux through Docker](#build-and-run-tests-on-linux-through-docker)
- [Keep your "Dependencies" group in Xcode referencing the correct paths](#keep-your-dependencies-group-in-xcode-referencing-the-correct-paths)
- [Tar and upload your binary to AWS S3 buckets.](#tar-and-upload-you-linux-binary-to-aws-s3-buckets)

Combining all these features gives Xcode and Xcode Server the ability to handle the continuous integration and delivery for both macOS and Linux (via Docker) so that we don't have to use an intermediary build server like Jenkins.

##Commands

- [build](#build)
- [update-packages](#update-packages)
- [symlink-dependencies](#symlink-dependencies)
- [create-archive](#create-archive)
- [upload-archive](#upload-archive)



##build

Build a Swift package in Linux and have the build errors appear in Xcode.

Building and testing your Swift code in Xcode on the macOS is one thing. But, then you have to fire up Docker and make sure that there aren't any library differences or unimplemented language features on the Linux side of things. It's kind of a pain. XcodeHelper eases these pains with the Linux side of cross-platform Swift development.

```
xchelper build SOURCE_CODE_PATH [OPTIONS]
```

Option  | Description
------------- | ------------- 
`build` or env var `BUILD_CONFIGURATION`| Build a Swift package in Linux and have the build errors appear in Xcode. *SOURCE\_CODE\_PATH* is the root of your package to call 'swift build' in.
`-c`, `--build-configuration` or env var `BUILD_CONFIGURATION`| debug or release mode    
`-i`, `--image-name` or env var `BUILD_DOCKER_IMAGE_NAME`| The Docker image name to run the commands in. Defaults to saltzmanjoelh/swiftubuntu                


#####You can add a new Run Script Build Phase to your target<br/>
<img src="https://cloud.githubusercontent.com/assets/1833492/20236478/4fc99776-a86b-11e6-9b80-81e876b8f6f4.png" height="400"><br/>

#####Or add a separate External Build target and manually switch between macOS build and Linux build

1. Create a new External Build target in Xcode.<br/>
<img src="https://cloud.githubusercontent.com/assets/1833492/20109936/1fd5bb8e-a597-11e6-9542-5ea82bc56534.png" height="400"><br/>
<img src="https://cloud.githubusercontent.com/assets/1833492/20109938/1fd6e202-a597-11e6-9f30-028d490aeb29.png" height="400"><br/>


2. Arguments are `/path/to/xchelper build $(PROJECT_DIR)`<br/>
<img src="https://cloud.githubusercontent.com/assets/1833492/20236500/c77192f6-a86b-11e6-8298-1ebf00810d29.png" width="600"><br/>


##update-packages

```
xchelper update-packages SOURCE_CODE_PATH [OPTIONS]
```


Option  | Description
------------- | ------------- 
`update-packages`, or env var `UPDATE_PACKAGES` | Update the package dependencies via `swift package update`. *SOURCE\_CODE\_PATH* is the root of your package to call `swift package update` in.
`-l`, `----linux-packages` or env var `UPDATE_PACKAGES_LINUX_PACKAGES`| Some packages have Linux specific dependencies. Use this option to update the Linux version of the packages. Linux packages may not be compatible with the macOS dependencies. `swift build --clean` is performed before they are updated. Defaults to: false    
`-i`, `--image-name` or env var `UPDATE_PACKAGES_DOCKER_IMAGE_NAME`| The Docker image name to run the commands in. Defaults to saltzmanjoelh/swiftubuntu.    


##symlink-dependencies
```
xchelper symlink-dependencies SOURCE_CODE_PATH
```

Option  | Description
------------- | ------------- 
`symlink-dependencies`, or env var `SYMLINK_DEPENDENCIES` | Create symbolic links to your dependencies and it will update your Xcode Project to use those symlinks instead of the directories with version number suffixes.


##create-archive


```
xchelper create-archive ARCHIVE_PATH FILES [OPTIONS]
```

Option  | Description
------------- | ------------- 
`create-archive`, or env var `CREATE_ARCHIVE` | Archive files with tar. `ARCHIVE_PATH` the full path and filename for the archive to be created. FILES is a space separated list of full paths to the files you want to archive. 
`-f`, `--flat-list`, or env var `CREATE_ARCHIVE_FLAT_LIST` | Put all the files in a flat list instead of maintaining directory structure. Defaults to: true. 

##upload-archive

```
xchelper upload-archive SOURCE_CODE_PATH [OPTIONS]
```
The `upload-archive` command will download any updates to your dependencies via `swift package update`
`SOURCE_CODE_PATH` is the root of your package to call `swift package update` in.

Option  | Description
------------- | ------------- 
`-l`, `----linux-packages` or env var `UPDATE_PACKAGES_LINUX_PACKAGES`| Some packages have Linux specific dependencies. Use this option to update the Linux version of the packages. Linux packages may not be compatible with the macOS dependencies. `swift build --clean` is performed before they are updated. Defaults to: false    
`-i`, `--image-name` or env var `UPDATE_PACKAGES_DOCKER_IMAGE_NAME`| The Docker image name to run the commands in. Defaults to saltzmanjoelh/swiftubuntu.    



#Examples

There is an [example project](https://www.github.com/saltzmanjoelh/XcodeHelperExample) available to see the full configuration.



## Build and run tests on Linux through Docker

Here is an example of all of the `xchelper build` options
<img src="https://cloud.githubusercontent.com/assets/1833492/20236466/f9aec168-a86a-11e6-9923-20d1c772b396.png" width="600">

------


##Keep your "Dependencies" group in Xcode referencing the correct paths
When you need to update your package dependencies, you have to call `swift package update`. This breaks your project and now you have to call `swift package generate-xcodeproj` again or update your references in your project. Use `update-packages` and `symlink-dependencies` to help with this process.<br/>


Here is an example of updating your packages, creating/updating your symlinks to those packages and having Xcode updated to use those symlinks. 

<img src="https://cloud.githubusercontent.com/assets/1833492/20236541/1ded3c42-a86d-11e6-8690-b743bb938164.png" width="600"><br/>

Please note the use of `xcrun`. You can use this if you get any errors like `cannot load underlying module for 'Darwin'` or `did you forget to set an SDK using -sdk or SDKROOT?`<br/>




##Tar and upload your binary to AWS S3 buckets.

Use `create-archive` and `upload-archive` to help get your files to an S3 bucket. You might use this if you are using CodeDeploy or something similar to monitor an S3 bucket for continuous integration.


[1]:	https://travis-ci.org/saltzmanjoelh/XcodeHelperCli
[2]:	https://swift.org "Swift"

[image-1]:	https://travis-ci.org/saltzmanjoelh/XcodeHelperCli.svg?branch=master
[image-2]:	https://img.shields.io/badge/swift-version%204-blue.svg