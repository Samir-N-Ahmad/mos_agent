import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var diagnosticsChannel: FlutterMethodChannel?
  private var logsWindow: NSWindow?
  private var logsText: NSTextView?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 480, height: 320)
    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "mos_agent/diagnostics",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    diagnosticsChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "open":
        self.openLogs(call.arguments as? String ?? "")
        result(self.logsWindow?.isVisible == true)
      case "update":
        self.updateLogs(call.arguments as? String ?? "")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    super.awakeFromNib()
  }

  private func openLogs(_ text: String) {
    if logsWindow == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false)
      window.title = "MOS Agent — Logs"
      window.isReleasedWhenClosed = false
      window.minSize = NSSize(width: 420, height: 280)
      window.appearance = NSAppearance(named: .darkAqua)
      let root = NSView()
      let caption = NSTextField(labelWithString:
        "Live session diagnostics • raw API responses • memory only • oldest entries expire")
      caption.textColor = .secondaryLabelColor
      caption.font = .systemFont(ofSize: 12)
      caption.translatesAutoresizingMaskIntoConstraints = false
      caption.lineBreakMode = .byWordWrapping
      caption.maximumNumberOfLines = 2
      let scroll = NSScrollView()
      scroll.translatesAutoresizingMaskIntoConstraints = false
      scroll.hasVerticalScroller = true
      scroll.autohidesScrollers = true
      let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 860, height: 540))
      view.isEditable = false
      view.isSelectable = true
      view.isRichText = false
      view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
      view.textColor = .labelColor
      view.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
      view.textContainerInset = NSSize(width: 16, height: 16)
      view.isVerticallyResizable = true
      view.isHorizontallyResizable = false
      view.autoresizingMask = [.width]
      view.textContainer?.widthTracksTextView = true
      view.textContainer?.containerSize = NSSize(width: 860, height: CGFloat.greatestFiniteMagnitude)
      scroll.documentView = view
      root.addSubview(caption)
      root.addSubview(scroll)
      NSLayoutConstraint.activate([
        caption.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
        caption.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
        caption.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
        scroll.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 12),
        scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
        scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor)
      ])
      window.contentView = root
      window.center()
      logsWindow = window
      logsText = view
    }
    updateLogs(text)
    logsWindow?.makeKeyAndOrderFront(nil)
  }

  private func updateLogs(_ text: String) {
    guard let view = logsText else { return }
    let visible = view.enclosingScrollView?.documentVisibleRect.maxY ?? 0
    let following = visible >= view.bounds.height - 40
    let selection = view.selectedRange()
    view.string = text.isEmpty ? "No diagnostics yet. Start inference to see API activity." : text
    if following {
      view.scrollToEndOfDocument(nil)
    } else {
      let length = (view.string as NSString).length
      if selection.location + selection.length <= length { view.setSelectedRange(selection) }
    }
  }
}
