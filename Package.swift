import PackageDescription

/*
 Doesn't need to be built and tested in linux, it should only be ran from macOS
 */

let package = Package(
    name: "XcodeHelperCli",
    targets:[
        Target(name: "XcodeHelperCliKit"),
        Target(name: "xchelper", dependencies: ["XcodeHelperCliKit"]),
        ],
    dependencies: [
        .Package(url: "https://github.com/saltzmanjoelh/CliRunnable.git", versions: Version(0,0,0)..<Version(10,0,0)),
        .Package(url: "https://github.com/saltzmanjoelh/XcodeHelperKit.git", versions: Version(0,0,0)..<Version(10,0,0)),
        .Package(url: "https://github.com/behrang/YamlSwift.git", versions: Version(0,0,0)..<Version(10,0,0))
    ]
)
