import Foundation

extension VideoPlayerView {
    func fetchHLSQualities(from url: URL, completion: @escaping ([[String: String]]) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let playlist = String(data: data, encoding: .utf8)
            else {
                completion([])
                return
            }

            var qualities: [[String: String]] = []
            let lines = playlist.components(separatedBy: "\n")
            var lastResolution = ""

            for line in lines {
                if line.contains("#EXT-X-STREAM-INF") {
                    if let resMatch = line.range(of: "RESOLUTION=\\d+x\\d+", options: .regularExpression) {
                        lastResolution = String(line[resMatch]).replacingOccurrences(of: "RESOLUTION=", with: "")
                    }
                } else if line.hasSuffix(".m3u8") {
                    qualities.append(["label": lastResolution, "url": line])
                }
            }

            completion(qualities)
        }
        .resume()
    }
}