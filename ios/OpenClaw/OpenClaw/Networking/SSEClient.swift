import Foundation

final class SSEClient: @unchecked Sendable {
    private let baseURL: URL
    private var task: Task<Void, Never>?
    private let decoder = JSONDecoder()

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func stream() -> AsyncStream<LogEntry> {
        AsyncStream { continuation in
            task = Task {
                while !Task.isCancelled {
                    do {
                        let url = baseURL.appendingPathComponent("events")
                        let (bytes, response) = try await URLSession.shared.bytes(from: url)

                        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                            throw SSEError.badStatus
                        }

                        for try await line in bytes.lines {
                            if Task.isCancelled { break }

                            guard line.hasPrefix("data: ") else { continue }
                            let jsonStr = String(line.dropFirst(6))
                            guard let data = jsonStr.data(using: .utf8) else { continue }

                            if let entry = try? decoder.decode(LogEntry.self, from: data) {
                                continuation.yield(entry)
                            }
                        }
                    } catch {
                        if Task.isCancelled { break }
                    }

                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
                continuation.finish()
            }

            continuation.onTermination = { [weak self] _ in
                self?.stop()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

enum SSEError: Error {
    case badStatus
}
