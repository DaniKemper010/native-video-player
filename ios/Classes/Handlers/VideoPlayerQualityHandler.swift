import Foundation
import AVFoundation

class VideoPlayerQualityHandler {
    static func fetchHLSQualities(from url: URL, completion: @escaping ([VideoPlayer.QualityLevel]) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let playlist = String(data: data, encoding: .utf8)
            else {
                completion([])
                return
            }

            var qualities: [VideoPlayer.QualityLevel] = []
            let lines = playlist.components(separatedBy: "\n")
            var lastBitrate: Int?
            var lastResolution: String?
            
            for line in lines {
                if line.contains("#EXT-X-STREAM-INF") {
                    // Extract resolution
                    if let resMatch = line.range(of: "RESOLUTION=\\d+x\\d+", options: .regularExpression) {
                        lastResolution = String(line[resMatch]).replacingOccurrences(of: "RESOLUTION=", with: "")
                    }
                    
                    // Extract bitrate
                    if let bitrateMatch = line.range(of: "BANDWIDTH=\\d+", options: .regularExpression) {
                        let bitrateStr = String(line[bitrateMatch]).replacingOccurrences(of: "BANDWIDTH=", with: "")
                        lastBitrate = Int(bitrateStr)
                    }
                } else if line.hasSuffix(".m3u8") {
                    // Resolve relative URLs against the base URL
                    let qualityUrl: String
                    if line.hasPrefix("http://") || line.hasPrefix("https://") {
                        qualityUrl = line
                    } else {
                        let baseUrl = url.deletingLastPathComponent()
                        if let resolvedUrl = URL(string: line, relativeTo: baseUrl)?.absoluteString {
                            qualityUrl = resolvedUrl
                        } else {
                            qualityUrl = line
                        }
                    }
                    
                    if let resolution = lastResolution {
                        let components = resolution.components(separatedBy: "x")
                        if components.count == 2,
                           let width = Int(components[0]),
                           let height = Int(components[1]) {
                            qualities.append(VideoPlayer.QualityLevel(
                                url: qualityUrl,
                                label: resolution,
                                bitrate: lastBitrate ?? 0,
                                resolution: CGSize(width: width, height: height)
                            ))
                        }
                    }
                }
            }
            
            // Sort qualities by resolution height (ascending)
            let sortedQualities = qualities.sorted { $0.resolution.height < $1.resolution.height }
            completion(sortedQualities)
        }.resume()
    }
}