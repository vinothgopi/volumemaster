import AppKit
import SwiftUI

final class VolumeHUD {
    static let shared = VolumeHUD()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<VolumeHUDView>?
    private var hideTimer: Timer?

    private init() {}

    func show(volume: Float, muted: Bool = false) {
        DispatchQueue.main.async { [self] in
            let hudView = VolumeHUDView(volume: volume, muted: muted)

            if panel == nil {
                let p = NSPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
                    styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered,
                    defer: false
                )
                p.level = .floating
                p.backgroundColor = .clear
                p.isOpaque = false
                p.hasShadow = true
                p.collectionBehavior = [.canJoinAllSpaces, .stationary]
                p.ignoresMouseEvents = true
                panel = p
            }

            if let existing = hostingView {
                existing.rootView = hudView
            } else {
                let hv = NSHostingView(rootView: hudView)
                panel!.contentView = hv
                hostingView = hv
            }

            if let screen = NSScreen.main {
                let frame = screen.frame
                let x = frame.midX - 100
                let y = frame.minY + 100
                panel!.setFrameOrigin(NSPoint(x: x, y: y))
            }

            panel!.alphaValue = 1.0
            panel!.orderFront(nil)

            hideTimer?.invalidate()
            hideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    self?.panel?.animator().alphaValue = 0
                } completionHandler: {
                    self?.panel?.orderOut(nil)
                }
            }
        }
    }
}

private struct VolumeHUDView: View {
    let volume: Float
    let muted: Bool

    private var iconName: String {
        if muted || volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 24)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white)
                        .frame(width: geo.size.width * CGFloat(muted ? 0 : volume))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 200, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }
}
