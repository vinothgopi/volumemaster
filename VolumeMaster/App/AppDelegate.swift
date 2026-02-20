import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Clean up any orphaned aggregate devices from previous sessions
        AggregateDeviceManager.shared.cleanupOrphanedAggregates()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop device monitoring
        DeviceMonitor.shared.stopMonitoring()

        // Revert default output if merge was active
        if AggregateDeviceManager.shared.isMergeActive {
            AggregateDeviceManager.shared.revertDefaultOutput()
        }

        // Destroy our aggregate device
        AggregateDeviceManager.shared.destroyActiveAggregate()
    }
}
