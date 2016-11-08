XcodeHelperCli keeps you in Xcode and off the command line. It's build from [XcodeHelperKit](https://www.github.com/saltzmanjoelh/XcodeHelperKit). You can:

- [Build and run tests on Linux through Docker](#build-and-run-tests-on-linux-through-docker)
- [Keep your "Dependencies" group in Xcode referencing the correct paths](#keep-your-dependencies-group-in-xcode-referencing-the-correct-paths)
- [Tar and upload you Linux binary to AWS S3 buckets.](#tar-and-upload-you-linux-binary-to-aws-s3-buckets)

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


##Keep your "Dependencies" group in Xcode referencing the correct paths
When you need to update your package dependencies, you have to call `swift package update`. This breaks your project and now you have to call `swift package generate-xcodeproj` again or update your references in your project. There are 2 commands (`update-packages` and `sym-link-dependencies`) that help with this process.<br/>

------
The `update-packages` command will download any updates to your dependencies via `swift package update`

```
xchelper update-packages SOURCE_CODE_PATH [OPTIONS]
```
`SOURCE_CODE_PATH` is the root of your package to call `swift package update` in.

Option  | Description
------------- | ------------- 
`-l`, `----linux-packages` or env var `UPDATE_PACKAGES_LINUX_PACKAGES`| Some packages have Linux specific dependencies. Use this option to update the Linux version of the packages. Linux packages may not be compatible with the macOS dependencies. `swift build --clean` is performed before they are updated. Defaults to: false    
`-i`, `--image-name` or env var `UPDATE_PACKAGES_DOCKER_IMAGE_NAME`| The Docker image name to run the commands in. Defaults to saltzmanjoelh/swiftubuntu.    


------

`sym-link-dependencies` create symbolic links to your dependencies and it will update your Xcode Project to use those sym links instead of the directories with version number suffixes.

```
xchelper sym-link-dependencies SOURCE_CODE_PATH
```
`SOURCE_CODE_PATH` is the root of your package to call `swift package update` in. There are no options for this command.


------

Here is an example of updating your packages, creating/updating your sym links to those packages and having Xcode updated to use those sym links. 

<img src="https://cloud.githubusercontent.com/assets/1833492/20121590/496c331c-a5c7-11e6-8401-9fe6e055de73.png" width="600"><br/>

Please note the use of `xcrun`. You can use this if you get any errors like `cannot load underlying module for 'Darwin'` or `did you forget to set an SDK using -sdk or SDKROOT?`<br/>




##Tar and upload you Linux binary to AWS S3 buckets.

There are 2 commands (`create-archive` and `upload-archive`) to help get your files to an S3 bucket. You might use this if you are using CodeDeploy or something similar to monitor an S3 bucket for continuous integration.




