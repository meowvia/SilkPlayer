import Foundation
import AVFoundation
import CoreMedia
import AudioToolbox
import Observation

/// Structured metadata snapshot for an audio track, enriched asynchronously from file headers and tags.
public struct AudioTrackMetadata: Sendable, Equatable {
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

/// Asynchronous metadata resolver and cache for Music Mode Hero card, queue display, search, and sorting.
@MainActor
@Observable
public final class AudioTrackMetadataService {
    public static let shared = AudioTrackMetadataService()

    public private(set) var cache: [String: AudioTrackMetadata] = [:]
    private var inFlightPaths: Set<String> = []

    public init() {}

    /// Returns cached metadata if available, otherwise synthesizes an instant filename/extension baseline
    /// and schedules background tag + format extraction.
    public func metadata(for item: PlaylistItem) -> AudioTrackMetadata {
        if let cached = cache[item.path] {
            return cached
        }
        return Self.fallbackMetadata(for: item)
    }

    /// Ensures metadata enrichment has been triggered for visible or queued audio items.
    public func ensureLoaded(for items: [PlaylistItem]) {
        for item in items {
            let path = item.path
            if cache[path] != nil || inFlightPaths.contains(path) {
                continue
            }
            // Populate synchronous fallback immediately so sorting/search are ready right away
            cache[path] = Self.fallbackMetadata(for: item)
            guard !path.contains("://") else { continue }
            inFlightPaths.insert(path)

            Task.detached(priority: .utility) {
                let extracted = await Self.extractMetadataFromDisk(item: item)
                await MainActor.run {
                    if let current = self.cache[path] {
                        self.cache[path] = Self.merged(base: current, update: extracted)
                    } else {
                        self.cache[path] = extracted
                    }
                    self.inFlightPaths.remove(path)
                }
            }
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

        if let codec = codec, !codec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        if let tags = tags {
            for (k, v) in tags {
                let key = k.lowercased()
                let val = v.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !val.isEmpty else { continue }
                if key == "title" {
                    base.title = val
                } else if key == "artist" || key == "album_artist" && base.artist.isEmpty {
                    base.artist = val
                } else if key == "album" {
                    base.album = val
                }
            }
        }
        cache[path] = base
    }

    public func clearCache() {
        cache.removeAll()
        inFlightPaths.removeAll()
    }

    // MARK: - Synchronous Fallback Builder

    public nonisolated static func fallbackMetadata(for item: PlaylistItem) -> AudioTrackMetadata {
        let url = item.url
        let ext = url.pathExtension.uppercased()
        let cleaned = MediaFilenameSanitizer.sanitize(item.title).cleanTitle
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
            result.title = update.title
        }
        if !update.artist.isEmpty {
            result.artist = update.artist
        }
        if !update.album.isEmpty {
            result.album = update.album
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

        // 1. Parse container-specific binary tags where fast and exact (FLAC / WAV)
        if ext == "flac" {
            let flacInfo = parseFLACHeader(url: url)
            if let t = flacInfo.title, !t.isEmpty { meta.title = t }
            if let a = flacInfo.artist, !a.isEmpty { meta.artist = a }
            if let al = flacInfo.album, !al.isEmpty { meta.album = al }
            if let sr = flacInfo.sampleRate, sr > 0 { meta.sampleRateHz = sr }
            if let bd = flacInfo.bitDepth, bd > 0 { meta.bitDepth = bd }
            if let dur = flacInfo.duration, dur > 0 { meta.duration = dur }
        } else if ext == "wav" || ext == "wave" {
            let wavInfo = parseWAVHeader(url: url)
            if let sr = wavInfo.sampleRate, sr > 0 { meta.sampleRateHz = sr }
            if let bd = wavInfo.bitDepth, bd > 0 { meta.bitDepth = bd }
            if let dur = wavInfo.duration, dur > 0 { meta.duration = dur }
        }

        // 2. AVURLAsset extraction for M4A / ALAC / MP3 / AIFF / AAC / CAF / FLAC common tags
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        if let common = try? await asset.load(.commonMetadata) {
            for itemTag in common {
                guard let key = itemTag.commonKey else { continue }
                let value = (try? await itemTag.load(.stringValue))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !value.isEmpty else { continue }
                switch key {
                case .commonKeyTitle:
                    meta.title = value
                case .commonKeyArtist:
                    meta.artist = value
                case .commonKeyAlbumName:
                    meta.album = value
                default:
                    break
                }
            }
        }

        if meta.duration == nil || (meta.duration ?? 0) <= 0 {
            if let cmDur = try? await asset.load(.duration) {
                let sec = CMTimeGetSeconds(cmDur)
                if sec.isFinite && sec > 0 {
                    meta.duration = sec
                }
            }
        }

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

        return meta
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
        var sampleRate: Double?
        var bitDepth: Int?
        var duration: Double?
    }

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
                // STREAMINFO block
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
                // VORBIS_COMMENT block (cap at 256 KB)
                guard let payload = try? handle.read(upToCount: blockLen), payload.count == blockLen else { break }
                parseVorbisComments(data: payload, into: &info)
            } else {
                // Skip oversized or unrelated metadata blocks
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
        func readUInt32LE() -> UInt32? {
            guard offset + 4 <= data.count else { return nil }
            let val = UInt32(data[offset])
                | (UInt32(data[offset + 1]) << 8)
                | (UInt32(data[offset + 2]) << 16)
                | (UInt32(data[offset + 3]) << 24)
            offset += 4
            return val
        }

        guard let vendorLen = readUInt32LE() else { return }
        let vendorAdvance = Int(vendorLen)
        guard vendorAdvance >= 0, offset + vendorAdvance <= data.count else { return }
        offset += vendorAdvance

        guard let commentCount = readUInt32LE() else { return }
        let safeCount = min(commentCount, 256)
        for _ in 0..<safeCount {
            guard let len = readUInt32LE() else { break }
            let strLen = Int(len)
            guard strLen >= 0, offset + strLen <= data.count else { break }
            let sub = data.subdata(in: offset..<(offset + strLen))
            offset += strLen
            guard let comment = String(data: sub, encoding: .utf8),
                  let eqIdx = comment.firstIndex(of: "=") else { continue }
            let key = String(comment[..<eqIdx]).uppercased()
            let val = String(comment[comment.index(after: eqIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
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

    private nonisolated static func parseWAVHeader(url: URL) -> ContainerHeaderInfo {
        var info = ContainerHeaderInfo()
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.read(upToCount: 44),
              data.count >= 36 else {
            return info
        }
        try? handle.close()

        let riff = String(data: data[0..<4], encoding: .ascii)
        let wave = String(data: data[8..<12], encoding: .ascii)
        guard riff == "RIFF", wave == "WAVE" else { return info }

        let sr = UInt32(data[24]) | (UInt32(data[25]) << 8) | (UInt32(data[26]) << 16) | (UInt32(data[27]) << 24)
        let byteRate = UInt32(data[28]) | (UInt32(data[29]) << 8) | (UInt32(data[30]) << 16) | (UInt32(data[31]) << 24)
        let bps = UInt16(data[34]) | (UInt16(data[35]) << 8)

        if sr > 0 { info.sampleRate = Double(sr) }
        if bps > 0 && bps <= 64 { info.bitDepth = Int(bps) }
        if byteRate > 0,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? UInt64, fileSize > 44 {
            info.duration = Double(fileSize - 44) / Double(byteRate)
        }
        return info
    }
}
