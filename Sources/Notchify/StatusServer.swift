import Foundation
import Darwin
import AppKit

/// Listens on a Unix domain socket and updates StatusManager when commands arrive.
/// Protocol: plain text commands terminated by newline or connection close.
/// Valid commands: "working", "waiting", "done", "error", "idle"
final class StatusServer {
    static let socketPath = "/tmp/notchify.sock"

    private var serverFd: Int32 = -1
    private var isRunning = false

    func start() {
        // Remove stale socket file
        unlink(StatusServer.socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            print("[StatusServer] Failed to create socket: \(String(cString: strerror(errno)))")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        StatusServer.socketPath.withCString { cStr in
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                UnsafeMutableRawPointer(ptr).copyMemory(from: cStr, byteCount: strlen(cStr) + 1)
            }
        }

        let bindResult = withUnsafePointer(to: addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            print("[StatusServer] bind failed: \(String(cString: strerror(errno)))")
            close(fd)
            return
        }

        guard listen(fd, 5) == 0 else {
            print("[StatusServer] listen failed: \(String(cString: strerror(errno)))")
            close(fd)
            return
        }

        serverFd = fd
        isRunning = true

        Thread.detachNewThread { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        isRunning = false
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }
        unlink(StatusServer.socketPath)
    }

    private func acceptLoop() {
        while isRunning {
            let clientFd = accept(serverFd, nil, nil)
            guard clientFd >= 0 else { continue }

            var buffer = [UInt8](repeating: 0, count: 128)
            let bytesRead = read(clientFd, &buffer, 127)
            close(clientFd)

            guard bytesRead > 0 else { continue }

            let message = String(bytes: buffer.prefix(bytesRead), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if message == "quit" {
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            } else if let status = ClaudeStatus(rawValue: message) {
                StatusManager.shared.update(status)
            }
        }
    }
}
