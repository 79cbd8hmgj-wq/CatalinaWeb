import AppKit

final class AppMenuBuilder {
    func makeMainMenu(target: MainWindowController) -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu")

        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "CatalinaWeb")
        applicationMenu.addItem(menuItem(
            title: "Quit CatalinaWeb",
            action: #selector(NSApplication.terminate(_:)),
            key: "q",
            target: nil
        ))
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(menuItem(
            title: "Close",
            action: #selector(NSWindow.performClose(_:)),
            key: "w",
            target: nil
        ))
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let navigateItem = NSMenuItem()
        let navigateMenu = NSMenu(title: "Navigate")
        navigateMenu.addItem(menuItem(
            title: "ChatGPT",
            action: #selector(MainWindowController.switchToChatGPT(_:)),
            key: "1",
            target: target
        ))
        navigateMenu.addItem(menuItem(
            title: "GitHub",
            action: #selector(MainWindowController.switchToGitHub(_:)),
            key: "2",
            target: target
        ))
        navigateMenu.addItem(.separator())
        navigateMenu.addItem(menuItem(
            title: "Back",
            action: #selector(MainWindowController.goBack(_:)),
            key: "[",
            target: target
        ))
        navigateMenu.addItem(menuItem(
            title: "Forward",
            action: #selector(MainWindowController.goForward(_:)),
            key: "]",
            target: target
        ))
        navigateMenu.addItem(menuItem(
            title: "Reload",
            action: #selector(MainWindowController.reload(_:)),
            key: "r",
            target: target
        ))
        navigateItem.submenu = navigateMenu
        mainMenu.addItem(navigateItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(menuItem(
            title: "Diagnostics",
            action: #selector(MainWindowController.showDiagnostics(_:)),
            key: "",
            target: target
        ))
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        return mainMenu
    }

    private func menuItem(
        title: String,
        action: Selector?,
        key: String,
        target: AnyObject?
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = [.command]
        item.target = target
        return item
    }
}
