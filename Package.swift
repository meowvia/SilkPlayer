// swift-tools-version: 6.0
import PackageDescription

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
        .binaryTarget(
            name: "SilkCoreKit",
            path: "Packages/SilkCoreKit.xcframework"
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
        )
    ]
)
