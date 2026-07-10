import AppKit

let app = NSApplication.shared  // must be called before anything accesses NSApp
let delegate = AppDelegate()
app.delegate = delegate
app.run()
