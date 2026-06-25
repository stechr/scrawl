import Foundation

/// A minimal HTTP/1.1 server bound to 127.0.0.1 only. It reads a JSON request
/// body, hands it to `handler` on the MAIN thread, and returns the handler's
/// JSON response. Intended purely as a local control channel for drawing
/// commands — it exposes no filesystem or system access, only the draw API.
final class ControlServer {
    private let port: UInt16
    private let handler: ([String: Any]) -> [String: Any]
    private var listenFD: Int32 = -1
    private let queue = DispatchQueue(label: "online.schristoph.scrawl.control")

    init(port: UInt16, handler: @escaping ([String: Any]) -> [String: Any]) {
        self.port = port
        self.handler = handler
    }

    func start() {
        signal(SIGPIPE, SIG_IGN) // never crash on writing to a closed socket

        listenFD = socket(AF_INET, SOCK_STREAM, 0)
        guard listenFD >= 0 else { NSLog("Scrawl: socket() failed"); return }

        var yes: Int32 = 1
        setsockopt(listenFD, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1") // loopback ONLY

        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(listenFD, 8) == 0 else {
            NSLog("Scrawl: control server failed to bind/listen on 127.0.0.1:\(port)")
            close(listenFD); listenFD = -1
            return
        }
        NSLog("Scrawl: control server listening on 127.0.0.1:\(port)")
        queue.async { [weak self] in self?.acceptLoop() }
    }

    func stop() {
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
    }

    private func acceptLoop() {
        while listenFD >= 0 {
            let client = accept(listenFD, nil, nil)
            if client < 0 { continue }
            handleClient(client)
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { close(fd) }

        var data = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        var headerEnd: Data.Index?
        var contentLength = 0

        while true {
            let n = read(fd, &buf, buf.count)
            if n <= 0 { break }
            data.append(contentsOf: buf[0..<n])

            if headerEnd == nil, let r = data.range(of: Data("\r\n\r\n".utf8)) {
                headerEnd = r.upperBound
                let headerData = data.subdata(in: data.startIndex..<r.lowerBound)
                if let headers = String(data: headerData, encoding: .utf8) {
                    for line in headers.split(separator: "\r\n") where line.lowercased().hasPrefix("content-length:") {
                        let parts = line.split(separator: ":", maxSplits: 1)
                        if parts.count == 2 {
                            contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                        }
                    }
                }
            }
            if let end = headerEnd {
                if contentLength == 0 { break }
                if data.count - end >= contentLength { break }
            }
        }

        var response: [String: Any] = ["ok": true]
        if let end = headerEnd, contentLength > 0, data.count - end >= contentLength {
            let body = data.subdata(in: end..<(end + contentLength))
            if let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
                response = DispatchQueue.main.sync { self.handler(json) }
            } else {
                response = ["ok": false, "error": "invalid JSON body"]
            }
        }

        let payload = (try? JSONSerialization.data(withJSONObject: response)) ?? Data("{\"ok\":true}".utf8)
        let head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(payload)
        out.withUnsafeBytes { _ = write(fd, $0.baseAddress, out.count) }
    }
}
