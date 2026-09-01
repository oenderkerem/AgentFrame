import AppKit
import Darwin

final class WindowFocusManager {

    static func focus(agent: AgentInfo) {
        // Best case: known terminal session IDs allow precise tab focus
        if let id = agent.itermSessionId, !id.isEmpty {
            if runAppleScript(iterm: id) { return }
        }
        if let id = agent.termSessionId, !id.isEmpty {
            if runAppleScript(terminal: id) { return }
        }
        // Fallback: walk process tree from PPID to find the owning GUI app
        if let ppid = agent.ppid {
            activateOwningApp(ppid: ppid)
        }
    }

    static func canFocus(_ agent: AgentInfo) -> Bool {
        agent.ppid != nil ||
        (agent.termSessionId != nil && !agent.termSessionId!.isEmpty) ||
        (agent.itermSessionId != nil && !agent.itermSessionId!.isEmpty)
    }

    // MARK: - Process tree

    private static func activateOwningApp(ppid: pid_t) {
        var current = ppid
        for _ in 0..<20 {
            guard current > 1 else { break }
            if let app = NSRunningApplication(processIdentifier: current),
               app.activationPolicy == .regular {
                app.activate(options: .activateIgnoringOtherApps)
                return
            }
            current = parentPID(of: current)
        }
    }

    private static func parentPID(of pid: pid_t) -> pid_t {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        sysctl(&mib, 4, &info, &size, nil, 0)
        return info.kp_eproc.e_ppid
    }

    // MARK: - AppleScript (precise tab focus)

    @discardableResult
    private static func runAppleScript(iterm sessionId: String) -> Bool {
        let src = """
        tell application "iTerm2"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique id of s is "\(sessionId)" then
                            select s
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        return err == nil
    }

    @discardableResult
    private static func runAppleScript(terminal sessionId: String) -> Bool {
        let src = """
        tell application "Terminal"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    if id of t is "\(sessionId)" then
                        set selected tab of w to t
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        return err == nil
    }
}
