import AppKit

final class FailureOverlayView: NSView {
    private let reloadHandler: () -> Void

    init(reloadHandler: @escaping () -> Void) {
        self.reloadHandler = reloadHandler
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configureInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureInterface() {
        let title = NSTextField(labelWithString: "Web content stopped unexpectedly.")
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)

        let detail = NSTextField(labelWithString: "CatalinaWeb kept your workspace URL. Reload only when you are ready.")
        detail.alignment = .center
        detail.textColor = .secondaryLabelColor

        let reloadButton = NSButton(title: "Reload Workspace", target: self, action: #selector(reloadPressed(_:)))
        reloadButton.bezelStyle = .rounded

        let stack = NSStackView(views: [title, detail, reloadButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    @objc private func reloadPressed(_ sender: Any?) {
        reloadHandler()
    }
}
