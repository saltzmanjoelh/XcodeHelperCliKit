XcodeHelper keeps you in Xcode and off the command line. You can:

* [Build and run tests on Linux through Docker](#build)
* [Fetch/Update Swift packages](#fetch)
* [Keep your "Dependencies" group in Xcode referencing the correct paths](#symlink)
* [Tar and upload you Linux binary to AWS S3 buckets.](#archive)

Combining all these features gives Xcode and Xcode Server the ability to handle the continuous integration and delivery for both macOS and Linux (via Docker) so that we don't have to use an intermediary build server like Jenkins. 

There is a sample project available to see the full configuration.

## Build and run tests on Linux through Docker
Build a Swift package in Linux and have the build errors appear in Xcode.
```
xchelper build SOURCE_CODE_PATH [OPTIONS]
```
`SOURCE_CODE_PATH` is the root of your package to call `swift build` in.

Option  | Description
------------- | ------------- 
`-c`, `--build-configuration` or env var `BUILD_CONFIGURATION`| debug or release mode    
`-i`, `--image-name` or env var `BUILD_DOCKER_IMAGE_NAME`| The Docker image name to run the commands in. Defaults to saltzmanjoelh/swiftubuntu                

Building and testing your Swift code in Xcode on the macOS is one thing. But, you then have to fire up Docker and make sure that there aren't any language differences or library differences on the Linux side of things. It's kind of a pain. This helps with the Linux side of cross-platform Swift.

You can use the xchelper as a binary. Then, create a new External Build target in Xcode. Now, when you are building your project, you can see the Linux errors right in Xcode. 

![Create External Build Target](https://raw.githubusercontent.com/saltzmanjoelh/XcodeHelper/assets/build1.png)
![Build Tool is /usr/bin/env](https://raw.githubusercontent.com/saltzmanjoelh/XcodeHelper/assets/build2.png)
![Arguments are /path/to/xchelper build $\(PROJECT_DIR\)](https://raw.githubusercontent.com/saltzmanjoelh/XcodeHelper/assets/build2.png)



##Fetch/Update Swift packages
Instead of going to the command line to update dependencies

##Keep your "Dependencies" group in Xcode referencing the correct paths

##Tar and upload you Linux binary to AWS S3 buckets.

You can also have xchelper archive your project into a tar file and upload to S3. 

