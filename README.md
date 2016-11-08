XcodeHelperCli keeps you in Xcode and off the command line. It's build from [XcodeHelperKit](https://www.github.com/saltzmanjoelh/XcodeHelperKit). You can:

- [Build and run tests on Linux through Docker](#build)
- [Fetch/Update Swift packages](#fetch)
- [Keep your "Dependencies" group in Xcode referencing the correct paths](#symlink)
- [Tar and upload you Linux binary to AWS S3 buckets.](#archive)

Combining all these features gives Xcode and Xcode Server the ability to handle the continuous integration and delivery for both macOS and Linux (via Docker) so that we don't have to use an intermediary build server like Jenkins. 

There is an [example project](https://www.github.com/saltzmanjoelh/XcodeHelperExample) available to see the full configuration.

Building and testing your Swift code in Xcode on the macOS is one thing. But, then you have to fire up Docker and make sure that there aren't any library differences or unimplemented language features on the Linux side of things. It's kind of a pain. XcodeHelper eases these pains with the Linux side of cross-platform Swift development.

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


Create a new External Build target in Xcode.<br/>
<img src="https://cloud.githubusercontent.com/assets/1833492/20109936/1fd5bb8e-a597-11e6-9542-5ea82bc56534.png" height="400"><br/>
<img src="https://cloud.githubusercontent.com/assets/1833492/20109938/1fd6e202-a597-11e6-9f30-028d490aeb29.png" height="400"><br/>


Arguments are `/path/to/xchelper build $(PROJECT_DIR)`<br/>
<img src="https://cloud.githubusercontent.com/assets/1833492/20109937/1fd5d286-a597-11e6-9eab-fdb38f4bb47f.png" width="600"><br/>


------
Here is an example of all of the `build` options
<img src="https://cloud.githubusercontent.com/assets/1833492/20109939/1fd6f4a4-a597-11e6-9d73-eb205120e620.png" width="600">

------


##Fetch/Update Swift packages
Instead of going to the command line to update dependencies

##Keep your "Dependencies" group in Xcode referencing the correct paths

##Tar and upload you Linux binary to AWS S3 buckets.

You can also have xchelper archive your built linux binary into a tar file and upload to S3. 


