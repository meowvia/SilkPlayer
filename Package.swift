// swift-tools-version: 6.0
import PackageDescription
import Foundation

let package = Package(
    name: "SilkPlayer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SilkPlayer", targets: ["SilkPlayer"])
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "Libavcodec",
            path: "Packages/Libavcodec.xcframework"
        ),
        .binaryTarget(
            name: "Libavformat",
            path: "Packages/Libavformat.xcframework"
        ),
        .binaryTarget(
            name: "Libavutil",
            path: "Packages/Libavutil.xcframework"
        ),
        .binaryTarget(
            name: "Libswresample",
            path: "Packages/Libswresample.xcframework"
        ),
        .binaryTarget(
            name: "Libswscale",
            path: "Packages/Libswscale.xcframework"
        ),
        (ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != "true"
            && FileManager.default.fileExists(atPath: "Packages/SilkCoreKit.xcframework"))
            ? .binaryTarget(
                name: "SilkCoreKit",
                path: "Packages/SilkCoreKit.xcframework"
            )
            : .target(
                name: "SilkCoreKit",
                path: "Sources/SilkCoreKitMock",
                swiftSettings: [
                    .swiftLanguageMode(.v6)
                ]
            ),
        .executableTarget(
            name: "SilkPlayer",
            dependencies: (ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != "true"
                && FileManager.default.fileExists(atPath: "Packages/SilkCoreKit.xcframework"))
                ? [
                    "Libavcodec",
                    "Libavformat",
                    "Libavutil",
                    "Libswresample",
                    "Libswscale",
                    "SilkCoreKit"
                ]
                : [
                    "SilkCoreKit"
                ],
            path: "Sources/SilkPlayer",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Cocoa"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Security"),
                .linkedFramework("IOKit"),
                .linkedFramework("NetFS"),
                .linkedFramework("Network"),
                .linkedLibrary("sqlite3"),
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
                .linkedLibrary("iconv")
            ]
        ),
        .testTarget(
            name: "SilkPlayerTests",
            dependencies: ["SilkPlayer"],
            path: "Tests/SilkPlayerTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
