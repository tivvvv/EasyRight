import Cocoa
import FinderSync
import OSLog

import EasyRightCore

final class FinderSync: FIFinderSync {
    private let actionRegistry = ActionRegistry.standard
    private let actionExecutor = ActionExecutor()
    private let feedbackPresenter: ActionFeedbackPresenting = SystemActionFeedbackPresenter()
    private let logger = Logger(subsystem: "com.tiv.EasyRight.FinderExtension", category: "FinderSync")

    override init() {
        super.init()

        // 初始版本先监听用户主目录, 后续会通过设置页改成可配置的监听范围.
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: NSHomeDirectory()),
        ]
    }

    override func menu(for _: FIMenuKind) -> NSMenu? {
        let availableActions = actionRegistry
            .availableActions(for: currentSelection)
            .filter(actionExecutor.canExecute)

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
            feedbackPresenter.presentFailure(message: "This action could not be identified.")
            return
        }

        let actionID = ActionIdentifier(rawValue: rawActionID)

        guard let action = actionRegistry.action(with: actionID) else {
            logger.error("Unknown action identifier: \(rawActionID, privacy: .public)")
            feedbackPresenter.presentFailure(message: "This action is not supported yet.")
            return
        }

        let context = ActionExecutionContext(selection: currentSelection)

        do {
            let result = try actionExecutor.execute(action, context: context)
            logger.info("EasyRight action completed: \(result.message, privacy: .public)")
            feedbackPresenter.presentSuccess(message: result.message)
        } catch {
            if error.easyRightShouldSuppressUserFeedback {
                logger.info("EasyRight action cancelled.")
                return
            }

            let message = error.easyRightUserFeedbackMessage
            logger.error("EasyRight action failed: \(message, privacy: .public)")
            feedbackPresenter.presentFailure(message: message)
        }
    }

    private var currentSelection: FileSelection {
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        return FileSelection(urls: selectedURLs)
    }
}
