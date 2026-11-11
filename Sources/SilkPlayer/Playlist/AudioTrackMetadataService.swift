import Foundation
import AVFoundation
import CoreMedia
import AudioToolbox
import Observation
#if canImport(Libavformat) && canImport(Libavutil) && canImport(Libavcodec)
import Libavformat
import Libavutil
import Libavcodec
#endif

/// Structured metadata snapshot for an audio track, enriched asynchronously from file headers and tags.
public struct AudioTrackMetadata: Sendable, Equatable, Codable {
    public let path: String
    public var title: String
    public var artist: String
    public var album: String
    public var formatLabel: String
    public var sampleRateHz: Double?
    public var bitDepth: Int?
    public var duration: Double?
    public var modificationDate: Date?

    public init(
        path: String,
        title: String,
        artist: String = "",
        album: String = "",
        formatLabel: String = "",
        sampleRateHz: Double? = nil,
        bitDepth: Int? = nil,
        duration: Double? = nil,
        modificationDate: Date? = nil
    ) {
        self.path = path
        self.title = title
        self.artist = artist
        self.album = album
        self.formatLabel = formatLabel
        self.sampleRateHz = sampleRateHz
        self.bitDepth = bitDepth
        self.duration = duration
        self.modificationDate = modificationDate
    }

    /// Formatted audio stream specification badge for the Hero card (e.g. "FLAC · 44.1 kHz / 16-bit").
    public var heroSpecText: String {
        var components: [String] = []
        let fmt = formatLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fmt.isEmpty {
            components.append(fmt)
        }

        var rateParts: [String] = []
        if let sr = sampleRateHz, sr > 0 {
            let khz = sr / 1000.0
            if abs(khz.rounded() - khz) < 0.05 {
                rateParts.append(String(format: "%.0f kHz", khz.rounded()))
            } else {
                rateParts.append(String(format: "%.1f kHz", khz))
            }
        }
        if let bd = bitDepth, bd > 0 {
            rateParts.append("\(bd)-bit")
        }
        if !rateParts.isEmpty {
            components.append(rateParts.joined(separator: " / "))
        }
        return components.joined(separator: " · ")
    }

    /// Combined row display title ("Artist - Title" or cleaned filename).
    public var queueDisplayTitle: String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanArtist.isEmpty && !cleanTitle.isEmpty {
            return "\(cleanArtist) - \(cleanTitle)"
        }
        if !cleanTitle.isEmpty {
            return cleanTitle
        }
        return cleanArtist
    }
}

private struct AudioMetadataDiskStore: Codable, Sendable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    var entries: [String: AudioTrackMetadata]
}

/// Asynchronous metadata resolver and persistent cache for Music Mode Hero card, queue display, search, and sorting.
@MainActor
@Observable
public final class AudioTrackMetadataService {
    public static let shared = AudioTrackMetadataService(cacheURL: defaultDiskCacheURL())

    public private(set) var cache: [String: AudioTrackMetadata] = [:]

    private let cacheURL: URL?
    private var inFlightPaths: Set<String> = []
    private var queuedPaths: Set<String> = []
    private var attemptedExtractionPaths: Set<String> = []
    private var pendingQueue: [PlaylistItem] = []
    private var workerTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    private static let maxConcurrentExtractions = 4

    public init(cacheURL: URL? = nil) {
        self.cacheURL = cacheURL
        if let cacheURL {
            loadDiskCache(from: cacheURL)
        }
    }

    public nonisolated static func defaultDiskCacheURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("SilkPlayer", isDirectory: true)
            .appendingPathComponent("audio_metadata_cache_v2.json", isDirectory: false)
    }

    /// Returns cached metadata if available, otherwise synthesizes an instant filename/extension baseline
    /// and schedules background tag + format extraction.
    public func metadata(for item: PlaylistItem) -> AudioTrackMetadata {
        if let cached = cache[item.path] {
            return cached
        }
        return Self.fallbackMetadata(for: item)
    }

    /// Ensures metadata enrichment has been triggered for visible or queued audio items.
    /// Cached tracks with positive durations are served synchronously without disk I/O;
    /// uncached or incomplete entries are processed in a bounded worker queue.
    public func ensureLoaded(for items: [PlaylistItem], priorityPath: String? = nil) {
        var addedToQueue = false

        for item in items {
            let path = item.path
            if cache[path] == nil {
                // Populate synchronous fallback immediately so search/sort are responsive at cold launch
                cache[path] = Self.fallbackMetadata(for: item)
            }
            guard !path.contains("://") else { continue }

            let cached = cache[path]
            let hasValidDuration = (cached?.duration ?? 0) > 0
            let hasCompleteMetadata = hasValidDuration && cached?.sampleRateHz != nil
            let needsExtraction = !attemptedExtractionPaths.contains(path) && !hasCompleteMetadata

            guard needsExtraction else { continue }
            guard !inFlightPaths.contains(path), !queuedPaths.contains(path) else { continue }

            queuedPaths.insert(path)
            if path == priorityPath {
                pendingQueue.insert(item, at: 0)
            } else {
                pendingQueue.append(item)
            }
            addedToQueue = true
        }

        if let priorityPath, !priorityPath.contains("://") {
            if let existingIdx = pendingQueue.firstIndex(where: { $0.path == priorityPath }), existingIdx > 0 {
                let item = pendingQueue.remove(at: existingIdx)
                pendingQueue.insert(item, at: 0)
            }
        }

        if addedToQueue {
            startWorkerIfNeeded()
        }
    }

    /// Updates cached metadata with decoded stream properties from active playback.
    public func mergeLiveStreamInfo(
        path: String,
        rawTitle: String,
        codec: String?,
        sampleRateHz: Double?,
        bitDepth: Int?,
        duration: Double?,
        tags: [String: String]?
    ) {
        let dummy = PlaylistItem(path: path, title: rawTitle, duration: duration ?? 0)
        var base = cache[path] ?? Self.fallbackMetadata(for: dummy)

        if let codec, !codec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            base.formatLabel = Self.normalizeFormatLabel(codec: codec, path: path)
        }
        if let sr = sampleRateHz, sr > 0 {
            base.sampleRateHz = sr
        }
        if let bd = bitDepth, bd > 0 {
            base.bitDepth = bd
        }
        if let d = duration, d > 0 {
            base.duration = d
        }
        if let tags {
            for (k, v) in tags {
                let key = k.lowercased()
                let repaired = Self.repairMojibakeIfNeeded(v)
                guard !repaired.isEmpty, !Self.looksLikeCorruptLatinMojibake(repaired) else { continue }
                if key == "title" {
                    base.title = repaired
                } else if key == "artist" || (key == "album_artist" && base.artist.isEmpty) {
                    base.artist = repaired
                } else if key == "album" {
                    base.album = repaired
                }
            }
        }
        base.title = Self.repairMojibakeIfNeeded(base.title)
        base.artist = Self.repairMojibakeIfNeeded(base.artist)
        base.album = Self.repairMojibakeIfNeeded(base.album)
        cache[path] = base
        attemptedExtractionPaths.insert(path)
        scheduleDiskSave()
    }

    public func clearCache() {
        workerTask?.cancel()
        workerTask = nil
        saveTask?.cancel()
        saveTask = nil
        pendingQueue.removeAll()
        queuedPaths.removeAll()
        inFlightPaths.removeAll()
        attemptedExtractionPaths.removeAll()
        cache.removeAll()
        if let cacheURL {
            try? FileManager.default.removeItem(at: cacheURL)
        }
    }

    // MARK: - Bounded Extraction Queue & Persistence

    private func startWorkerIfNeeded() {
        guard workerTask == nil, !pendingQueue.isEmpty else { return }

        workerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let batchSize = min(Self.maxConcurrentExtractions, self.pendingQueue.count)
                guard batchSize > 0 else { break }

                let batch = Array(self.pendingQueue.prefix(batchSize))
                self.pendingQueue.removeFirst(batchSize)
                for item in batch {
                    self.queuedPaths.remove(item.path)
                    self.inFlightPaths.insert(item.path)
                }

                let results = await withTaskGroup(of: (String, AudioTrackMetadata).self) { group in
                    for item in batch {
                        group.addTask {
                            let extracted = await Self.extractMetadataFromDisk(item: item)
                            return (item.path, extracted)
                        }
                    }
                    var collected: [(String, AudioTrackMetadata)] = []
                    collected.reserveCapacity(batch.count)
                    for await pair in group {
                        collected.append(pair)
                    }
                    return collected
                }

                guard !Task.isCancelled else { break }

                for (path, extracted) in results {
                    if let current = self.cache[path] {
                        self.cache[path] = Self.merged(base: current, update: extracted)
                    } else {
                        self.cache[path] = extracted
                    }
                    self.inFlightPaths.remove(path)
                    self.attemptedExtractionPaths.insert(path)
                }

                self.scheduleDiskSave()
                await Task.yield()
            }
            if !Task.isCancelled {
                self.workerTask = nil
            }
        }
    }

    private func loadDiskCache(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(AudioMetadataDiskStore.self, from: data),
              store.schemaVersion == AudioMetadataDiskStore.currentSchemaVersion else {
            return
        }
        var sanitized: [String: AudioTrackMetadata] = [:]
        sanitized.reserveCapacity(store.entries.count)
        for (path, var meta) in store.entries {
            meta.title = Self.repairMojibakeIfNeeded(meta.title)
            meta.artist = Self.repairMojibakeIfNeeded(meta.artist)
            meta.album = Self.repairMojibakeIfNeeded(meta.album)
            sanitized[path] = meta
            if (meta.duration ?? 0) > 0 {
                attemptedExtractionPaths.insert(path)
            }
        }
        cache = sanitized
    }

    private func scheduleDiskSave() {
        guard let cacheURL else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self else { return }
            let snapshot = AudioMetadataDiskStore(
                schemaVersion: AudioMetadataDiskStore.currentSchemaVersion,
                entries: self.cache
            )
            Task.detached(priority: .utility) {
                let dir = cacheURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if let encoded = try? JSONEncoder().encode(snapshot) {
                    try? encoded.write(to: cacheURL, options: .atomic)
                }
            }
        }
    }

    // MARK: - Mojibake Detection & Legacy Encoding Recovery

    private nonisolated static let windows1252ReverseMap: [UnicodeScalar: UInt8] = {
        var map: [UnicodeScalar: UInt8] = [
            "\u{20AC}": 0x80, "\u{201A}": 0x82, "\u{0192}": 0x83, "\u{201E}": 0x84,
            "\u{2026}": 0x85, "\u{2020}": 0x86, "\u{2021}": 0x87, "\u{02C6}": 0x88,
            "\u{2030}": 0x89, "\u{0160}": 0x8A, "\u{2039}": 0x8B, "\u{0152}": 0x8C,
            "\u{017D}": 0x8E, "\u{2018}": 0x91, "\u{2019}": 0x92, "\u{201C}": 0x93,
            "\u{201D}": 0x94, "\u{2022}": 0x95, "\u{2013}": 0x96, "\u{2014}": 0x97,
            "\u{02DC}": 0x98, "\u{2122}": 0x99, "\u{0161}": 0x9A, "\u{203A}": 0x9B,
            "\u{0153}": 0x9C, "\u{017E}": 0x9E, "\u{0178}": 0x9F
        ]
        return map
    }()

    private nonisolated static let gb18030Encoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
    )
    private nonisolated static let big5Encoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5_HKSCS_1999.rawValue))
    )
    private nonisolated static let shiftJISEncoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue))
    )

    /// Repairs strings misdecoded as ISO-8859-1 / Windows-1252 when original bytes were UTF-8, GB18030 (GBK), Big5, or Shift-JIS.
    /// Leaves genuine accented European strings (e.g. "Beyoncé", "Café del Mar", "Tiësto") untouched.
    public nonisolated static func repairMojibakeIfNeeded(_ raw: String) -> String {
        let trimmed = raw
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var hasNonASCII = false
        for scalar in trimmed.unicodeScalars {
            if scalar.value >= 0x80 { hasNonASCII = true }
            if isEastAsianScriptScalar(scalar) {
                // Already contains genuine CJK / Kana / Hangul characters
                return trimmed
            }
        }
        guard hasNonASCII else { return trimmed }

        for useCP1252 in [true, false] {
            guard let bytes = extractSingleByteSequence(from: trimmed, useWindows1252: useCP1252),
                  hasAdjacentHighBytes(bytes) else {
                continue
            }

            if let utf8Decoded = String(data: bytes, encoding: .utf8),
               !utf8Decoded.contains("\u{FFFD}") {
                let cleaned = utf8Decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty, cleaned != trimmed {
                    return cleaned
                }
            }

            for enc in [gb18030Encoding, big5Encoding, shiftJISEncoding] {
                if let candidate = String(data: bytes, encoding: enc),
                   !candidate.contains("\u{FFFD}") {
                    let cleaned = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                    let eastAsianCount = cleaned.unicodeScalars.filter { isEastAsianScriptScalar($0) }.count
                    let hasControlChars = cleaned.unicodeScalars.contains { $0.value < 0x20 }
                    if eastAsianCount > 0 && !hasControlChars {
                        return cleaned
                    }
                }
            }
        }

        return trimmed
    }

    /// Decodes raw tag byte slices (ID3v1 / ID3v2 Latin-1 frames / APEv2 / RIFF INFO).
    public nonisolated static func decodeTagData(_ rawData: Data) -> String {
        let prefix: Data
        if let nulIndex = rawData.firstIndex(of: 0) {
            prefix = rawData.prefix(upTo: nulIndex)
        } else {
            prefix = rawData
        }
        guard !prefix.isEmpty else { return "" }

        // Trim trailing whitespace bytes cleanly before encoding detection
        var bytes = [UInt8](prefix)
        while let last = bytes.last, last == 0x20 || last == 0x09 || last == 0x0A || last == 0x0D {
            bytes.removeLast()
        }
        while let first = bytes.first, first == 0x20 || first == 0x09 || first == 0x0A || first == 0x0D {
            bytes.removeFirst()
        }
        guard !bytes.isEmpty else { return "" }
        let trimmedData = Data(bytes)

        // 1. Strict UTF-8
        if let utf8 = String(data: trimmedData, encoding: .utf8), !utf8.contains("\u{FFFD}") {
            return repairMojibakeIfNeeded(utf8)
        }

        // 2. East Asian 8-bit encodings when adjacent high bytes exist
        if hasAdjacentHighBytes(trimmedData) {
            for enc in [gb18030Encoding, big5Encoding, shiftJISEncoding] {
                if let decoded = String(data: trimmedData, encoding: enc),
                   !decoded.contains("\u{FFFD}"),
                   decoded.unicodeScalars.contains(where: { isEastAsianScriptScalar($0) }) {
                    return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // 3. Fallback single-byte Windows-1252 / Latin-1
        if let cp1252 = String(data: trimmedData, encoding: .windowsCP1252) {
            return cp1252.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let latin1 = String(data: trimmedData, encoding: .isoLatin1) {
            return latin1.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private nonisolated static func extractSingleByteSequence(from text: String, useWindows1252: Bool) -> Data? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            if scalar.value <= 0xFF {
                bytes.append(UInt8(scalar.value))
            } else if useWindows1252, let mapped = windows1252ReverseMap[scalar] {
                bytes.append(mapped)
            } else {
                return nil
            }
        }
        return Data(bytes)
    }

    private nonisolated static func hasAdjacentHighBytes(_ data: Data) -> Bool {
        var prevHigh = false
        for b in data {
            let isHigh = b >= 0x80
            if isHigh && prevHigh {
                return true
            }
            prevHigh = isHigh
        }
        return false
    }

    private nonisolated static func isEastAsianScriptScalar(_ scalar: UnicodeScalar) -> Bool {
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF)
            || (v >= 0x3400 && v <= 0x4DBF)
            || (v >= 0xF900 && v <= 0xFAFF)
            || (v >= 0x3040 && v <= 0x30FF)
            || (v >= 0xAC00 && v <= 0xD7AF)
    }

    private nonisolated static func looksLikeCorruptLatinMojibake(_ text: String) -> Bool {
        guard let bytes = extractSingleByteSequence(from: text, useWindows1252: true),
              hasAdjacentHighBytes(bytes) else {
            return false
        }
        return repairMojibakeIfNeeded(text) != text
    }

    // MARK: - Synchronous Fallback Builder

    public nonisolated static func fallbackMetadata(for item: PlaylistItem) -> AudioTrackMetadata {
        let url = item.url
        let ext = url.pathExtension.uppercased()
        let cleaned = MediaFilenameSanitizer.sanitize(repairMojibakeIfNeeded(item.title)).cleanTitle
        let fallbackName = cleaned.isEmpty
            ? MediaFilenameSanitizer.sanitize(url.deletingPathExtension().lastPathComponent).cleanTitle
            : cleaned
        let (parsedArtist, parsedTitle) = splitArtistAndTitle(from: fallbackName)
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        return AudioTrackMetadata(
            path: item.path,
            title: parsedTitle.isEmpty ? fallbackName : parsedTitle,
            artist: parsedArtist,
            album: "",
            formatLabel: ext.isEmpty ? "AUDIO" : ext,
            sampleRateHz: nil,
            bitDepth: nil,
            duration: item.duration > 0 ? item.duration : nil,
            modificationDate: modDate
        )
    }

    public nonisolated static func splitArtistAndTitle(from sanitizedName: String) -> (artist: String, title: String) {
        if let range = sanitizedName.range(of: " - ") {
            let left = String(sanitizedName[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(sanitizedName[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !left.isEmpty && !right.isEmpty {
                return (left, right)
            }
        }
        return ("", sanitizedName)
    }

    private nonisolated static func merged(base: AudioTrackMetadata, update: AudioTrackMetadata) -> AudioTrackMetadata {
        var result = base
        if !update.title.isEmpty {
            result.title = repairMojibakeIfNeeded(update.title)
        }
        if !update.artist.isEmpty {
            result.artist = repairMojibakeIfNeeded(update.artist)
        }
        if !update.album.isEmpty {
            result.album = repairMojibakeIfNeeded(update.album)
        }
        if !update.formatLabel.isEmpty {
            result.formatLabel = update.formatLabel
        }
        if let sr = update.sampleRateHz, sr > 0 {
            result.sampleRateHz = sr
        }
        if let bd = update.bitDepth, bd > 0 {
            result.bitDepth = bd
        }
        if let d = update.duration, d > 0 {
            result.duration = d
        }
        if let mod = update.modificationDate {
            result.modificationDate = mod
        }
        return result
    }

    // MARK: - Background Extraction Pipeline

    private nonisolated static func extractMetadataFromDisk(item: PlaylistItem) async -> AudioTrackMetadata {
        var meta = fallbackMetadata(for: item)
        let url = URL(fileURLWithPath: item.path)
        let ext = url.pathExtension.lowercased()
        var handledDirectly = false

        // 1. Parse container-specific headers & tags directly in pure Swift (avoids slow AVFoundation XPC overhead)
        switch ext {
        case "flac":
            let flacInfo = parseFLACHeader(url: url)
            apply(info: flacInfo, to: &meta)
            meta.formatLabel = "FLAC"
            handledDirectly = (meta.duration ?? 0) > 0 && (meta.sampleRateHz ?? 0) > 0

        case "wav", "wave":
            let wavInfo = parseWAVHeader(url: url)
            apply(info: wavInfo, to: &meta)
            meta.formatLabel = ext == "wave" ? "WAVE" : "WAV"
            handledDirectly = (meta.duration ?? 0) > 0 && (meta.sampleRateHz ?? 0) > 0

        case "ape":
            let apeInfo = parseAPEHeaderAndTags(url: url)
            apply(info: apeInfo, to: &meta)
            meta.formatLabel = "APE"
            handledDirectly = (meta.duration ?? 0) > 0 && (meta.sampleRateHz ?? 0) > 0

        case "mp3":
            let mp3Info = parseMP3HeaderAndTags(url: url)
            apply(info: mp3Info, to: &meta)
            meta.formatLabel = "MP3"
            handledDirectly = (meta.duration ?? 0) > 0 && (meta.sampleRateHz ?? 0) > 0

        default:
            break
        }

        // 2. AVURLAsset extraction for M4A / ALAC / AIFF / AAC / CAF or partial direct parses (skip APE/OGG/OPUS/WMA/DSF/DFF/WV/DTS)
        let avFoundationUnsupported: Set<String> = ["ape", "ogg", "opus", "wma", "dsf", "dff", "dsd", "wv", "tak", "mpc", "dts", "dtshd", "ac3", "eac3"]
        if !handledDirectly && !avFoundationUnsupported.contains(ext) {
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
            if let common = try? await asset.load(.commonMetadata) {
                for itemTag in common {
                    guard let key = itemTag.commonKey else { continue }
                    let rawVal = (try? await itemTag.load(.stringValue)) ?? ""
                    let value = repairMojibakeIfNeeded(rawVal)
                    guard !value.isEmpty else { continue }
                    switch key {
                    case .commonKeyTitle:
                        if meta.title.isEmpty || ext != "mp3" { meta.title = value }
                    case .commonKeyArtist:
                        if meta.artist.isEmpty || ext != "mp3" { meta.artist = value }
                    case .commonKeyAlbumName:
                        if meta.album.isEmpty || ext != "mp3" { meta.album = value }
                    default:
                        break
                    }
                }
            }

            if (meta.duration ?? 0) <= 0 {
                if let cmDur = try? await asset.load(.duration) {
                    let sec = CMTimeGetSeconds(cmDur)
                    if sec.isFinite && sec > 0 {
                        meta.duration = sec
                    }
                }
            }

            if (meta.sampleRateHz ?? 0) <= 0 || meta.formatLabel == ext.uppercased() {
                if let tracks = try? await asset.loadTracks(withMediaType: .audio), let firstTrack = tracks.first {
                    if let formatDescs = try? await firstTrack.load(.formatDescriptions), let desc = formatDescs.first {
                        let audioDesc = desc as CMAudioFormatDescription
                        if let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(audioDesc) {
                            let asbd = asbdPtr.pointee
                            if (meta.sampleRateHz ?? 0) <= 0 && asbd.mSampleRate > 0 {
                                meta.sampleRateHz = asbd.mSampleRate
                            }
                            if (meta.bitDepth ?? 0) <= 0 && asbd.mBitsPerChannel > 0 {
                                meta.bitDepth = Int(asbd.mBitsPerChannel)
                            }
                            meta.formatLabel = formatLabel(fromFourCC: asbd.mFormatID, pathExtension: ext)
                        }
                    }
                }
            }
        }

        // 3. Universal Libavformat fallback if duration or sampleRate is still unresolved
        #if canImport(Libavformat) && canImport(Libavutil) && canImport(Libavcodec)
        if (meta.duration ?? 0) <= 0 || (meta.sampleRateHz ?? 0) <= 0 {
            let ffInfo = probeWithLibavformat(url: url, ext: ext)
            apply(info: ffInfo, to: &meta)
            if meta.formatLabel.isEmpty, let fmt = ffInfo.formatLabel {
                meta.formatLabel = fmt
            }
        }
        #endif

        return meta
    }

    private nonisolated static func apply(info: ContainerHeaderInfo, to meta: inout AudioTrackMetadata) {
        if let t = info.title, !t.isEmpty { meta.title = repairMojibakeIfNeeded(t) }
        if let a = info.artist, !a.isEmpty { meta.artist = repairMojibakeIfNeeded(a) }
        if let al = info.album, !al.isEmpty { meta.album = repairMojibakeIfNeeded(al) }
        if let fmt = info.formatLabel, !fmt.isEmpty { meta.formatLabel = fmt }
        if let sr = info.sampleRate, sr > 0 { meta.sampleRateHz = sr }
        if let bd = info.bitDepth, bd > 0 { meta.bitDepth = bd }
        if let dur = info.duration, dur > 0 { meta.duration = dur }
    }

    private nonisolated static func normalizeFormatLabel(codec: String, path: String) -> String {
        let lower = codec.lowercased()
        let ext = URL(fileURLWithPath: path).pathExtension.uppercased()
        if lower.contains("alac") { return "ALAC" }
        if lower.contains("flac") { return "FLAC" }
        if lower.contains("aac") { return "AAC" }
        if lower.contains("mp3") || lower.contains("mp3float") { return "MP3" }
        if lower.contains("opus") { return "OPUS" }
        if lower.contains("vorbis") { return "OGG" }
        if lower.contains("ape") || lower.contains("monkey") { return "APE" }
        if lower.contains("dsd") || ext == "DSF" || ext == "DFF" { return "DSD" }
        if lower.contains("wma") { return "WMA" }
        if lower.contains("wavpack") || ext == "WV" { return "WV" }
        if lower.contains("pcm") {
            if ext == "WAV" || ext == "WAVE" || ext == "AIFF" || ext == "AIF" {
                return ext
            }
            return "PCM"
        }
        return ext.isEmpty ? codec.uppercased() : ext
    }

    private nonisolated static func formatLabel(fromFourCC formatID: AudioFormatID, pathExtension ext: String) -> String {
        switch formatID {
        case kAudioFormatAppleLossless: return "ALAC"
        case kAudioFormatFLAC: return "FLAC"
        case kAudioFormatMPEGLayer3: return "MP3"
        case kAudioFormatMPEG4AAC, kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_LD: return "AAC"
        case kAudioFormatOpus: return "OPUS"
        case kAudioFormatLinearPCM:
            return ext.isEmpty ? "PCM" : ext.uppercased()
        default:
            return ext.isEmpty ? "AUDIO" : ext.uppercased()
        }
    }

    // MARK: - Lightweight Binary Container Parsers

    private struct ContainerHeaderInfo {
        var title: String?
        var artist: String?
        var album: String?
        var formatLabel: String?
        var sampleRate: Double?
        var bitDepth: Int?
        var duration: Double?
    }

    private nonisolated static func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private nonisolated static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private nonisolated static func readUInt32BE(_ data: Data, at offset: Int) -> UInt32 {
        (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    // MARK: FLAC

    private nonisolated static func parseFLACHeader(url: URL) -> ContainerHeaderInfo {
        var info = ContainerHeaderInfo()
        guard let handle = try? FileHandle(forReadingFrom: url) else { return info }
        defer { try? handle.close() }

        guard let headerData = try? handle.read(upToCount: 4),
              headerData.count == 4,
              String(data: headerData, encoding: .ascii) == "fLaC" else {
            return info
        }

        var isLastBlock = false
        var blockCount = 0
        while !isLastBlock && blockCount < 64 {
            blockCount += 1
            guard let blockHeader = try? handle.read(upToCount: 4), blockHeader.count == 4 else { break }
            isLastBlock = (blockHeader[0] & 0x80) != 0
            let blockType = blockHeader[0] & 0x7F
            let blockLen = (Int(blockHeader[1]) << 16) | (Int(blockHeader[2]) << 8) | Int(blockHeader[3])
            guard blockLen >= 0 else { break }

            if blockType == 0 && blockLen >= 18 {
                guard let payload = try? handle.read(upToCount: blockLen), payload.count >= 18 else { break }
                let sr = (Int(payload[10]) << 12) | (Int(payload[11]) << 4) | ((Int(payload[12]) & 0xF0) >> 4)
                let bps = (((Int(payload[12]) & 0x01) << 4) | ((Int(payload[13]) & 0xF0) >> 4)) + 1
                let totalSamples: UInt64 =
                    (UInt64(payload[13] & 0x0F) << 32) |
                    (UInt64(payload[14]) << 24) |
                    (UInt64(payload[15]) << 16) |
                    (UInt64(payload[16]) << 8) |
                    UInt64(payload[17])
                if sr > 0 {
                    info.sampleRate = Double(sr)
                    if totalSamples > 0 {
                        info.duration = Double(totalSamples) / Double(sr)
                    }
                }
                if bps > 0 && bps <= 64 {
                    info.bitDepth = bps
                }
            } else if blockType == 4 && blockLen <= 262_144 {
                guard let payload = try? handle.read(upToCount: blockLen), payload.count == blockLen else { break }
                parseVorbisComments(data: payload, into: &info)
            } else {
                do {
                    let currentOffset = try handle.offset()
                    try handle.seek(toOffset: currentOffset + UInt64(blockLen))
                } catch {
                    break
                }
            }
        }
        return info
    }

    private nonisolated static func parseVorbisComments(data: Data, into info: inout ContainerHeaderInfo) {
        var offset = 0
        func nextUInt32LE() -> UInt32? {
            guard offset + 4 <= data.count else { return nil }
            let val = readUInt32LE(data, at: offset)
            offset += 4
            return val
        }

        guard let vendorLen = nextUInt32LE() else { return }
        let vendorAdvance = Int(vendorLen)
        guard vendorAdvance >= 0, offset + vendorAdvance <= data.count else { return }
        offset += vendorAdvance

        guard let commentCount = nextUInt32LE() else { return }
        let safeCount = min(commentCount, 256)
        for _ in 0..<safeCount {
            guard let len = nextUInt32LE() else { break }
            let strLen = Int(len)
            guard strLen >= 0, offset + strLen <= data.count else { break }
            let sub = data.subdata(in: offset..<(offset + strLen))
            offset += strLen
            let comment = decodeTagData(sub)
            guard let eqIdx = comment.firstIndex(of: "=") else { continue }
            let key = String(comment[..<eqIdx]).uppercased()
            let val = repairMojibakeIfNeeded(String(comment[comment.index(after: eqIdx)...]))
            guard !val.isEmpty else { continue }
            switch key {
            case "TITLE":
                if info.title == nil { info.title = val }
            case "ARTIST":
                if info.artist == nil { info.artist = val }
            case "ALBUMARTIST", "ALBUM ARTIST":
                if info.artist == nil { info.artist = val }
            case "ALBUM":
                if info.album == nil { info.album = val }
            default:
                break
            }
        }
    }

    // MARK: WAV / RIFF

    private nonisolated static func parseWAVHeader(url: URL) -> ContainerHeaderInfo {
        var info = ContainerHeaderInfo()
        guard let handle = try? FileHandle(forReadingFrom: url) else { return info }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        guard fileSize >= 36 else { return info }
        try? handle.seek(toOffset: 0)

        guard let riffHeader = try? handle.read(upToCount: 12), riffHeader.count == 12 else { return info }
        let riff = String(data: riffHeader[0..<4], encoding: .ascii)
        let wave = String(data: riffHeader[8..<12], encoding: .ascii)
        guard riff == "RIFF", wave == "WAVE" else { return info }

        var byteRate: UInt32 = 0
        var dataChunkSize: UInt32 = 0
        var offset: UInt64 = 12
        var chunkCount = 0

        while offset + 8 <= fileSize && chunkCount < 32 {
            chunkCount += 1
            do {
                try handle.seek(toOffset: offset)
                guard let chunkHeader = try handle.read(upToCount: 8), chunkHeader.count == 8 else { break }
                let chunkID = String(data: chunkHeader[0..<4], encoding: .ascii) ?? ""
                let chunkSize = UInt64(readUInt32LE(chunkHeader, at: 4))
                let paddedSize = chunkSize + (chunkSize & 1)

                if chunkID == "fmt " && chunkSize >= 16 {
                    let readLen = Int(min(chunkSize, 64))
                    if let fmt = try? handle.read(upToCount: readLen), fmt.count >= 16 {
                        let sr = readUInt32LE(fmt, at: 4)
                        byteRate = readUInt32LE(fmt, at: 8)
                        let bps = readUInt16LE(fmt, at: 14)
                        if sr > 0 { info.sampleRate = Double(sr) }
                        if bps > 0 && bps <= 64 { info.bitDepth = Int(bps) }
                    }
                } else if chunkID == "data" && chunkSize > 0 {
                    dataChunkSize = UInt32(min(chunkSize, UInt64(UInt32.max)))
                } else if chunkID == "LIST" && chunkSize >= 4 && chunkSize <= 65_536 {
                    if let listData = try? handle.read(upToCount: Int(chunkSize)), listData.count >= 4,
                       String(data: listData[0..<4], encoding: .ascii) == "INFO" {
                        parseRIFFInfoList(data: Data(listData[4...]), into: &info)
                    }
                }

                offset += 8 + paddedSize
                if byteRate > 0 && dataChunkSize > 0 {
                    // Continue scanning only if small metadata chunks remain near EOF? Wait: audio data chunk in WAV can be tens of MB, so stop if we already checked LIST or moved past data when near end
                    if offset >= fileSize { break }
                }
            } catch {
                break
            }
        }

        if byteRate > 0 {
            let effectiveBytes: UInt64 = dataChunkSize > 0 ? UInt64(dataChunkSize) : (fileSize > 44 ? fileSize - 44 : 0)
            if effectiveBytes > 0 {
                info.duration = Double(effectiveBytes) / Double(byteRate)
            }
        }
        return info
    }

    private nonisolated static func parseRIFFInfoList(data: Data, into info: inout ContainerHeaderInfo) {
        var pos = 0
        while pos + 8 <= data.count {
            let id = String(data: data[pos..<(pos + 4)], encoding: .ascii) ?? ""
            let sz = Int(readUInt32LE(data, at: pos + 4))
            pos += 8
            guard sz >= 0, pos + sz <= data.count else { break }
            let val = decodeTagData(data.subdata(in: pos..<(pos + sz)))
            if !val.isEmpty {
                switch id {
                case "INAM": if info.title == nil { info.title = val }
                case "IART": if info.artist == nil { info.artist = val }
                case "IPRD": if info.album == nil { info.album = val }
                default: break
                }
            }
            pos += sz + (sz & 1)
        }
    }

    // MARK: Monkey's Audio (.ape) + APEv2 Tags

    private nonisolated static func parseAPEHeaderAndTags(url: URL) -> ContainerHeaderInfo {
        var info = ContainerHeaderInfo()
        guard let handle = try? FileHandle(forReadingFrom: url) else { return info }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        guard fileSize >= 32 else { return info }
        try? handle.seek(toOffset: 0)

        guard let header = try? handle.read(upToCount: 160), header.count >= 32,
              String(data: header[0..<4], encoding: .ascii) == "MAC " else {
            return info
        }

        let version = readUInt16LE(header, at: 4)
        if version >= 3980 {
            // New descriptor + header format (>= 3.98)
            let descriptorBytes = Int(readUInt32LE(header, at: 8))
            let hdrOffset = max(32, descriptorBytes)
            if hdrOffset + 24 <= header.count {
                let blocksPerFrame = UInt64(readUInt32LE(header, at: hdrOffset + 4))
                let finalFrameBlocks = UInt64(readUInt32LE(header, at: hdrOffset + 8))
                let totalFrames = UInt64(readUInt32LE(header, at: hdrOffset + 12))
                let bps = Int(readUInt16LE(header, at: hdrOffset + 16))
                let sr = UInt32(readUInt32LE(header, at: hdrOffset + 20))
                if sr > 0 { info.sampleRate = Double(sr) }
                if bps > 0 && bps <= 64 { info.bitDepth = bps }
                if totalFrames > 0 && sr > 0 && blocksPerFrame > 0 {
                    let totalSamples = (totalFrames - 1) * blocksPerFrame + finalFrameBlocks
                    info.duration = Double(totalSamples) / Double(sr)
                }
            }
        } else {
            // Legacy APE header (<= 3.97)
            let comp = readUInt16LE(header, at: 6)
            let flags = readUInt16LE(header, at: 8)
            let sr = readUInt32LE(header, at: 12)
            let wavHeaderBytes = Int(readUInt32LE(header, at: 16))
            let totalFrames = UInt64(readUInt32LE(header, at: 24))
            let finalFrameBlocks = UInt64(readUInt32LE(header, at: 28))

            let blocksPerFrame: UInt64
            if version >= 3950 {
                blocksPerFrame = 73_728 * 4
            } else if version >= 3900 || (version >= 3800 && comp == 4000) {
                blocksPerFrame = 73_728
            } else {
                blocksPerFrame = 9_216
            }

            if sr > 0 { info.sampleRate = Double(sr) }
            // Infer bit depth from flags or embedded WAV header (starts at offset 40 when WAV header is present)
            var bps = (flags & 0x01) != 0 ? 8 : ((flags & 0x08) != 0 ? 24 : 16)
            if (flags & 0x20) == 0 && wavHeaderBytes >= 36 && 40 + 36 <= header.count {
                if String(data: header[40..<44], encoding: .ascii) == "RIFF" {
                    let wavBps = Int(readUInt16LE(header, at: 40 + 34))
                    if wavBps > 0 && wavBps <= 64 { bps = wavBps }
                }
            }
            info.bitDepth = bps

            if totalFrames > 0 && sr > 0 {
                let totalSamples = (totalFrames - 1) * blocksPerFrame + finalFrameBlocks
                info.duration = Double(totalSamples) / Double(sr)
            }
        }

        info.formatLabel = "APE"
        parseAPEv2Tags(handle: handle, fileSize: fileSize, into: &info)
        return info
    }

    private nonisolated static func parseAPEv2Tags(handle: FileHandle, fileSize: UInt64, into info: inout ContainerHeaderInfo) {
        // APEv2 footer may sit either at EOF - 32 or right before a 128-byte ID3v1 TAG at EOF - 160
        let candidateFooterOffsets: [UInt64] = [32, 160]
        for tailDist in candidateFooterOffsets {
            guard fileSize >= tailDist else { continue }
            let footerOffset = fileSize - tailDist
            do {
                try handle.seek(toOffset: footerOffset)
                guard let footer = try? handle.read(upToCount: 32), footer.count == 32,
                      String(data: footer[0..<8], encoding: .ascii) == "APETAGEX" else {
                    continue
                }
                let tagSizeIncludingFooter = UInt64(readUInt32LE(footer, at: 12))
                let itemCount = min(readUInt32LE(footer, at: 16), 256)
                guard tagSizeIncludingFooter >= 32,
                      tagSizeIncludingFooter <= 524_288,
                      tagSizeIncludingFooter - 32 <= footerOffset else {
                    continue
                }
                let itemsByteCount = Int(tagSizeIncludingFooter - 32)
                let itemsOffset = footerOffset - UInt64(itemsByteCount)
                try handle.seek(toOffset: itemsOffset)
                guard let payload = try? handle.read(upToCount: itemsByteCount), payload.count == itemsByteCount else {
                    continue
                }

                var pos = 0
                for _ in 0..<itemCount {
                    guard pos + 8 <= payload.count else { break }
                    let valLen = Int(readUInt32LE(payload, at: pos))
                    let flags = readUInt32LE(payload, at: pos + 4)
                    pos += 8
                    guard let nulIdx = payload[pos...].firstIndex(of: 0) else { break }
                    let key = String(data: payload[pos..<nulIdx], encoding: .ascii)?.uppercased() ?? ""
                    pos = nulIdx + 1
                    guard valLen >= 0, pos + valLen <= payload.count else { break }
                    let valueData = payload.subdata(in: pos..<(pos + valLen))
                    pos += valLen

                    // Skip binary items (flags bits 2..1 == 1 => binary cover art, etc.)
                    let itemType = (flags >> 1) & 0x03
                    guard itemType == 0 || itemType == 2 else { continue }

                    let val = decodeTagData(valueData)
                    guard !val.isEmpty else { continue }
                    switch key {
                    case "TITLE":
                        if info.title == nil { info.title = val }
                    case "ARTIST":
                        if info.artist == nil { info.artist = val }
                    case "ALBUMARTIST", "ALBUM ARTIST":
                        if info.artist == nil { info.artist = val }
                    case "ALBUM":
                        if info.album == nil { info.album = val }
                    default:
                        break
                    }
                }
                return
            } catch {
                continue
            }
        }
    }

    // MARK: MP3 (ID3v2 + ID3v1 + APEv2 + Xing/VBRI/CBR Frame Duration)

    private nonisolated static func parseMP3HeaderAndTags(url: URL) -> ContainerHeaderInfo {
        var info = ContainerHeaderInfo()
        guard let handle = try? FileHandle(forReadingFrom: url) else { return info }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        guard fileSize >= 128 else { return info }
        try? handle.seek(toOffset: 0)

        var audioStartOffset: UInt64 = 0
        var id3v2Info = ContainerHeaderInfo()

        if let head = try? handle.read(upToCount: 10), head.count == 10,
           String(data: head[0..<3], encoding: .ascii) == "ID3" {
            let majorVer = head[3]
            let flags = head[5]
            let tagSize = (UInt64(head[6] & 0x7F) << 21)
                | (UInt64(head[7] & 0x7F) << 14)
                | (UInt64(head[8] & 0x7F) << 7)
                | UInt64(head[9] & 0x7F)
            let hasFooter = (majorVer == 4) && ((flags & 0x10) != 0)
            audioStartOffset = min(fileSize, 10 + tagSize + (hasFooter ? 10 : 0))
            parseID3v2Frames(handle: handle, majorVersion: majorVer, flags: flags, tagEndOffset: 10 + tagSize, into: &id3v2Info)
        }

        // Parse APEv2 & ID3v1 at EOF (priority: ID3v2 > APEv2 > ID3v1)
        var apeInfo = ContainerHeaderInfo()
        parseAPEv2Tags(handle: handle, fileSize: fileSize, into: &apeInfo)

        var id3v1Info = ContainerHeaderInfo()
        var tailTagBytes: UInt64 = 0
        do {
            try handle.seek(toOffset: fileSize - 128)
            if let v1 = try? handle.read(upToCount: 128), v1.count == 128,
               String(data: v1[0..<3], encoding: .ascii) == "TAG" {
                tailTagBytes = 128
                let title = decodeTagData(v1.subdata(in: 3..<33))
                let artist = decodeTagData(v1.subdata(in: 33..<63))
                let album = decodeTagData(v1.subdata(in: 63..<93))
                if !title.isEmpty { id3v1Info.title = title }
                if !artist.isEmpty { id3v1Info.artist = artist }
                if !album.isEmpty { id3v1Info.album = album }
            }
        } catch {}

        info.title = id3v2Info.title ?? apeInfo.title ?? id3v1Info.title
        info.artist = id3v2Info.artist ?? apeInfo.artist ?? id3v1Info.artist
        info.album = id3v2Info.album ?? apeInfo.album ?? id3v1Info.album
        info.formatLabel = "MP3"

        // Parse MPEG Audio Header + Xing / Info / VBRI or CBR bitrate at audioStartOffset
        if audioStartOffset < fileSize {
            parseMP3AudioFrameDuration(
                handle: handle,
                startOffset: audioStartOffset,
                fileSize: fileSize,
                tailTagBytes: tailTagBytes,
                into: &info
            )
        }
        return info
    }

    private nonisolated static func parseID3v2Frames(
        handle: FileHandle,
        majorVersion: UInt8,
        flags: UInt8,
        tagEndOffset: UInt64,
        into info: inout ContainerHeaderInfo
    ) {
        guard majorVersion >= 2 && majorVersion <= 4 else { return }
        var offset: UInt64 = 10
        let hasExtHeader = (majorVersion >= 3) && ((flags & 0x40) != 0)
        if hasExtHeader {
            try? handle.seek(toOffset: offset)
            if let extHdr = try? handle.read(upToCount: 4), extHdr.count == 4 {
                if majorVersion == 4 {
                    let sz = (UInt64(extHdr[0] & 0x7F) << 21) | (UInt64(extHdr[1] & 0x7F) << 14) | (UInt64(extHdr[2] & 0x7F) << 7) | UInt64(extHdr[3] & 0x7F)
                    offset += max(6, sz)
                } else {
                    let sz = UInt64(readUInt32BE(extHdr, at: 0))
                    offset += 4 + sz
                }
            }
        }

        let headerLen: UInt64 = (majorVersion == 2) ? 6 : 10
        var frameCount = 0
        while offset + headerLen <= tagEndOffset && frameCount < 256 {
            frameCount += 1
            do {
                try handle.seek(toOffset: offset)
                guard let fh = try? handle.read(upToCount: Int(headerLen)), fh.count == Int(headerLen) else { break }
                if fh[0] == 0 { break } // ID3 padding reached

                let frameID: String
                let frameSize: UInt64
                if majorVersion == 2 {
                    frameID = String(data: fh[0..<3], encoding: .ascii) ?? ""
                    frameSize = (UInt64(fh[3]) << 16) | (UInt64(fh[4]) << 8) | UInt64(fh[5])
                } else {
                    frameID = String(data: fh[0..<4], encoding: .ascii) ?? ""
                    if majorVersion == 4 {
                        frameSize = (UInt64(fh[4] & 0x7F) << 21)
                            | (UInt64(fh[5] & 0x7F) << 14)
                            | (UInt64(fh[6] & 0x7F) << 7)
                            | UInt64(fh[7] & 0x7F)
                    } else {
                        frameSize = UInt64(readUInt32BE(fh, at: 4))
                    }
                }

                offset += headerLen
                guard frameSize > 0, offset + frameSize <= tagEndOffset else { break }

                let isDesired = (frameID == "TIT2" || frameID == "TT2" || frameID == "TPE1" || frameID == "TP1" || frameID == "TALB" || frameID == "TAL")
                if isDesired && frameSize <= 65_536 {
                    if let payload = try? handle.read(upToCount: Int(frameSize)), !payload.isEmpty {
                        let decoded = decodeID3v2TextPayload(payload)
                        if !decoded.isEmpty {
                            if (frameID == "TIT2" || frameID == "TT2") && info.title == nil {
                                info.title = decoded
                            } else if (frameID == "TPE1" || frameID == "TP1") && info.artist == nil {
                                info.artist = decoded
                            } else if (frameID == "TALB" || frameID == "TAL") && info.album == nil {
                                info.album = decoded
                            }
                        }
                    }
                }
                offset += frameSize
                if info.title != nil && info.artist != nil && info.album != nil {
                    break
                }
            } catch {
                break
            }
        }
    }

    private nonisolated static func decodeID3v2TextPayload(_ payload: Data) -> String {
        guard payload.count >= 2 else { return "" }
        let encByte = payload[0]
        let textData = Data(payload[1...])
        switch encByte {
        case 0: // ISO-8859-1 (often misused for GBK/Big5/Shift-JIS)
            return decodeTagData(textData)
        case 1: // UTF-16 with BOM
            let raw = String(data: textData, encoding: .utf16) ?? ""
            return repairMojibakeIfNeeded(raw)
        case 2: // UTF-16BE without BOM
            let raw = String(data: textData, encoding: .utf16BigEndian) ?? ""
            return repairMojibakeIfNeeded(raw)
        case 3: // UTF-8
            return decodeTagData(textData)
        default:
            return decodeTagData(textData)
        }
    }

    private nonisolated static let mpeg1Layer3Bitrates = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
    private nonisolated static let mpeg2Layer3Bitrates = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
    private nonisolated static let mpeg1SampleRates = [44_100, 48_000, 32_000, 0]

    private nonisolated static func parseMP3AudioFrameDuration(
        handle: FileHandle,
        startOffset: UInt64,
        fileSize: UInt64,
        tailTagBytes: UInt64,
        into info: inout ContainerHeaderInfo
    ) {
        do {
            try handle.seek(toOffset: startOffset)
            let scanCap = Int(min(16_384, fileSize - startOffset))
            guard scanCap >= 4, let buf = try? handle.read(upToCount: scanCap), buf.count >= 4 else { return }

            for i in 0..<(buf.count - 4) {
                guard buf[i] == 0xFF && (buf[i + 1] & 0xE0) == 0xE0 else { continue }
                let b1 = buf[i + 1]
                let b2 = buf[i + 2]
                let b3 = buf[i + 3]

                let versionBits = Int((b1 >> 3) & 0x03) // 3 = MPEG 1, 2 = MPEG 2, 0 = MPEG 2.5
                let layerBits = Int((b1 >> 1) & 0x03)   // 1 = Layer III
                let bitrateIdx = Int((b2 >> 4) & 0x0F)
                let srIdx = Int((b2 >> 2) & 0x03)
                let padding = Int((b2 >> 1) & 0x01)
                let channelMode = Int((b3 >> 6) & 0x03) // 3 = Mono

                guard versionBits != 1, layerBits == 1, bitrateIdx > 0, bitrateIdx < 15, srIdx < 3 else { continue }

                let baseSR = mpeg1SampleRates[srIdx]
                let sampleRate: Int = {
                    switch versionBits {
                    case 3: return baseSR
                    case 2: return baseSR / 2
                    case 0: return baseSR / 4
                    default: return 0
                    }
                }()
                let kbps = (versionBits == 3) ? mpeg1Layer3Bitrates[bitrateIdx] : mpeg2Layer3Bitrates[bitrateIdx]
                guard sampleRate > 0, kbps > 0 else { continue }

                let samplesPerFrame = (versionBits == 3) ? 1152 : 576
                let frameLength = (samplesPerFrame / 8 * (kbps * 1000)) / sampleRate + padding
                guard frameLength >= 24 else { continue }

                // Check for Xing / Info VBR header inside this first frame
                let sideInfoLen: Int = {
                    if versionBits == 3 {
                        return (channelMode == 3) ? 17 : 32
                    } else {
                        return (channelMode == 3) ? 9 : 17
                    }
                }()
                let xingOffset = i + 4 + sideInfoLen
                if xingOffset + 12 <= buf.count {
                    let xingID = String(data: buf[xingOffset..<(xingOffset + 4)], encoding: .ascii)
                    if xingID == "Xing" || xingID == "Info" {
                        let xingFlags = readUInt32BE(buf, at: xingOffset + 4)
                        if (xingFlags & 0x01) != 0 {
                            let totalFrames = readUInt32BE(buf, at: xingOffset + 8)
                            if totalFrames > 0 {
                                info.sampleRate = Double(sampleRate)
                                info.duration = Double(UInt64(totalFrames) * UInt64(samplesPerFrame)) / Double(sampleRate)
                                return
                            }
                        }
                    }
                }

                // Check for VBRI header (fixed offset +36 bytes from frame start)
                let vbriOffset = i + 36
                if vbriOffset + 18 <= buf.count,
                   String(data: buf[vbriOffset..<(vbriOffset + 4)], encoding: .ascii) == "VBRI" {
                    let totalFrames = readUInt32BE(buf, at: vbriOffset + 14)
                    if totalFrames > 0 {
                        info.sampleRate = Double(sampleRate)
                        info.duration = Double(UInt64(totalFrames) * UInt64(samplesPerFrame)) / Double(sampleRate)
                        return
                    }
                }

                // Validate second MPEG sync at frame boundary before trusting CBR bitrate estimate
                let nextFrameIdx = i + frameLength
                let hasSecondSync: Bool = {
                    guard nextFrameIdx + 2 <= buf.count else { return false }
                    return buf[nextFrameIdx] == 0xFF && (buf[nextFrameIdx + 1] & 0xE0) == 0xE0
                }()
                guard hasSecondSync else { continue }

                info.sampleRate = Double(sampleRate)
                let frameStartAbsolute = startOffset + UInt64(i)
                if fileSize > frameStartAbsolute + tailTagBytes {
                    let audioBytes = fileSize - frameStartAbsolute - tailTagBytes
                    info.duration = Double(audioBytes * 8) / Double(kbps * 1000)
                }
                return
            }
        } catch {}
    }

    // MARK: Universal FFmpeg Fallback

    #if canImport(Libavformat) && canImport(Libavutil) && canImport(Libavcodec)
    private nonisolated static func probeWithLibavformat(url: URL, ext: String) -> ContainerHeaderInfo {
        var info = ContainerHeaderInfo()
        var ctx: UnsafeMutablePointer<AVFormatContext>? = nil
        guard avformat_open_input(&ctx, url.path, nil, nil) >= 0, let fmtCtx = ctx else {
            return info
        }
        defer {
            avformat_close_input(&ctx)
        }

        _ = avformat_find_stream_info(fmtCtx, nil)

        let rawDuration = fmtCtx.pointee.duration
        if rawDuration > 0 && rawDuration != Int64.min {
            info.duration = Double(rawDuration) / 1_000_000.0
        }

        let streamCount = Int(fmtCtx.pointee.nb_streams)
        if let streamsPtr = fmtCtx.pointee.streams {
            for idx in 0..<streamCount {
                guard let stream = streamsPtr[idx],
                      let codecpar = stream.pointee.codecpar,
                      codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO else {
                    continue
                }
                if codecpar.pointee.sample_rate > 0 {
                    info.sampleRate = Double(codecpar.pointee.sample_rate)
                }
                let rawBits = Int(codecpar.pointee.bits_per_raw_sample)
                let codedBits = Int(codecpar.pointee.bits_per_coded_sample)
                if rawBits > 0 {
                    info.bitDepth = rawBits
                } else if codedBits > 0 && codedBits <= 64 {
                    info.bitDepth = codedBits
                }
                if let cNamePtr = avcodec_get_name(codecpar.pointee.codec_id) {
                    let codecName = String(cString: cNamePtr)
                    info.formatLabel = normalizeFormatLabel(codec: codecName, path: url.path)
                }
                break
            }
        }

        if let dict = fmtCtx.pointee.metadata {
            var entry: UnsafePointer<AVDictionaryEntry>? = nil
            while let next = av_dict_get(dict, "", entry, AV_DICT_IGNORE_SUFFIX) {
                entry = UnsafePointer(next)
                guard let kPtr = next.pointee.key, let vPtr = next.pointee.value else { continue }
                let k = String(cString: kPtr).lowercased()
                let v = repairMojibakeIfNeeded(String(cString: vPtr))
                guard !v.isEmpty else { continue }
                if k == "title" && info.title == nil {
                    info.title = v
                } else if (k == "artist" || k == "album_artist") && info.artist == nil {
                    info.artist = v
                } else if k == "album" && info.album == nil {
                    info.album = v
                }
            }
        }

        if info.formatLabel == nil && !ext.isEmpty {
            info.formatLabel = ext.uppercased()
        }
        return info
    }
    #endif
}
