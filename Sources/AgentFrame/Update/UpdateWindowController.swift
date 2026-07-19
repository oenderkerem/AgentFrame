import AppKit
import SwiftUI

final class UpdateWindowController: NSWindowController {
    private let settings: AppSettings
    private let updateChecker: UpdateChecker

    init(settings: AppSettings, updateChecker: UpdateChecker) {
        self.settings      = settings
        self.updateChecker = updateChecker

        let w = NSWindow()
        w.title                      = ""
        w.styleMask                  = [.titled, .closable]
        w.setContentSize(NSSize(width: 460, height: 380))
        w.center()
        w.isReleasedWhenClosed       = false
        w.titlebarAppearsTransparent = true
        w.titleVisibility            = .hidden

        super.init(window: w)

        w.contentViewController = NSHostingController(rootView: UpdateView(
            settings:     settings,
            updateChecker: updateChecker,
            onClose:    { [weak self] in self?.window?.close() },
            onDownload: { [weak self] in
                updateChecker.openReleasesPage()
                self?.window?.close()
            }
        ))
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - View

private struct UpdateView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var updateChecker: UpdateChecker
    let onClose: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Divider()

            notesSection
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            Divider()

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 460)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                Text(settings.t("update.title"))
                    .font(.title3).bold()

                if let v = updateChecker.availableVersion {
                    Text(String(format: settings.t("update.new_version"), v))
                        .font(.subheadline)
                }

                Text(String(format: settings.t("update.current_version"), installedVersion))
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }

            Spacer()
        }
    }

    // MARK: Release notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.t("update.release_notes"))
                .font(.headline)

            ScrollView {
                Group {
                    if let notes = updateChecker.releaseNotes {
                        Text(attributedNotes(notes))
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(settings.t("update.release_notes_none"))
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: 180)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button(settings.t("update.later"), action: onClose)
                .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button(settings.t("update.download"), action: onDownload)
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: Helpers

    private var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private func attributedNotes(_ raw: String) -> AttributedString {
        (try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(raw)
    }
}
