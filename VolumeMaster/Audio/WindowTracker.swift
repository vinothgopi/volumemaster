import Cocoa

final class WindowTracker {
    var onPositionChanged: ((CGFloat) -> Void)?

    private var timer: Timer?
    private var lastNormalizedX: CGFloat = 0.5
    private let changeThreshold: CGFloat = 0.01

    func start() {
        stop()
        lastNormalizedX = 0.5

        // Poll immediately, then every 0.5s
        pollFrontmostWindowPosition()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollFrontmostWindowPosition()
        }

        // Also react to app activation
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appDidActivate(_ notification: Notification) {
        pollFrontmostWindowPosition()
    }

    private func pollFrontmostWindowPosition() {
        guard let windowBounds = frontmostWindowBounds() else { return }

        let midX = windowBounds.midX
        let normalizedX = normalizeX(midX)

        if abs(normalizedX - lastNormalizedX) > changeThreshold {
            lastNormalizedX = normalizedX
            onPositionChanged?(normalizedX)
        }
    }

    private func frontmostWindowBounds() -> CGRect? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Find the frontmost on-screen window belonging to the active app
        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0, // normal windows only
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                continue
            }

            // Skip tiny windows (tooltips, HUDs)
            if bounds.width > 50 && bounds.height > 50 {
                return bounds
            }
        }

        return nil
    }

    private func normalizeX(_ x: CGFloat) -> CGFloat {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return 0.5 }

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude

        for screen in screens {
            let frame = screen.frame
            minX = min(minX, frame.minX)
            maxX = max(maxX, frame.maxX)
        }

        let span = maxX - minX
        guard span > 0 else { return 0.5 }

        return max(0, min(1, (x - minX) / span))
    }
}
