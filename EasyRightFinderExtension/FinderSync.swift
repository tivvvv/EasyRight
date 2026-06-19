import Cocoa
import FinderSync
import OSLog

import EasyRightCore

final class FinderSync: FIFinderSync {
    private let actionRegistry = ActionRegistry.standard
    private let logger = Logger(subsystem: "com.tiv.EasyRight.FinderExtension", category: "FinderSync")

    override init() {
        super.init()

        // 初始版本先监听用户主目录, 后续会通过设置页改成可配置的监听范围.
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: NSHomeDirectory()),
        ]
    }

    override func menu(for _: FIMenuKind) -> NSMenu? {
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        let selection = FileSelection(urls: selectedURLs)
        let availableActions = actionRegistry.availableActions(for: selection)

        let rootMenu = NSMenu(title: "EasyRight")
        let rootItem = NSMenuItem(title: "EasyRight", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "EasyRight")

        if availableActions.isEmpty {
            let item = NSMenuItem(title: "No Available Actions", action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        } else {
            availableActions.forEach { action in
                let item = NSMenuItem(
                    title: action.title,
                    action: #selector(handleAction(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = action.id.rawValue
                submenu.addItem(item)
            }
        }

        rootMenu.addItem(rootItem)
        rootMenu.setSubmenu(submenu, for: rootItem)
        return rootMenu
    }

    @objc private func handleAction(_ sender: NSMenuItem) {
        guard let rawActionID = sender.representedObject as? String else {
            logger.error("Missing action identifier.")
            return
        }

        // 这里先记录动作入口, 下一步会接入真正的执行器.
        logger.info("Selected EasyRight action: \(rawActionID, privacy: .public)")
    }
}
