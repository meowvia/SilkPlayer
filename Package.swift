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
        (ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true")
            ? .target(
                name: "SilkCoreKit",
                path: "Sources/SilkCoreKitMock",
                swiftSettings: [
                    .swiftLanguageMode(.v6)
                ]
            )
            : (
                FileManager.default.fileExists(atPath: "Packages/SilkCoreKit.xcframework")
                    ? .binaryTarget(
                        name: "SilkCoreKit",
                        path: "Packages/SilkCoreKit.xcframework"
                    )
                    : .binaryTarget(
                        name: "SilkCoreKit",
                        url: "https://github.com/meowvia/SilkPlayer/releases/download/1.1.0/SilkCoreKit.xcframework.zip",
                        checksum: "a147747afec895a49028f60072def754c316a2086a546fc60ab513370bd39018"
                    )
            ),
        .executableTarget(
            name: "SilkPlayer",
            dependencies: [
                "Libavcodec",
                "Libavformat",
                "Libavutil",
                "Libswresample",
                "Libswscale",
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
