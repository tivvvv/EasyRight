import Cocoa
import FinderSync
import OSLog

import EasyRightCore

final class FinderSync: FIFinderSync {
    private let actionMenuProvider = ActionMenuProvider.standard
    private let actionExecutor = ActionExecutor()
    private let preferencesStore = ActionPreferencesStore.shared
    private let scopePreferencesStore = FinderScopePreferencesStore.shared
    private let feedbackPresenter: ActionFeedbackPresenting = SystemActionFeedbackPresenter()
    private let logger = Logger(subsystem: "com.tiv.EasyRight.FinderExtension", category: "FinderSync")
    private var appliedDirectoryURLs = Set<URL>()

    override init() {
        super.init()

        refreshDirectoryScope()
        observeDirectoryScopeChanges()
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(
                FinderScopePreferencesStore.didChangeDarwinNotificationName as CFString
            ),
            nil
        )
    }

    override func menu(for _: FIMenuKind) -> NSMenu? {
        refreshDirectoryScope()

        let actionPreferences = preferencesStore.preferences(for: actionMenuProvider.registry)
        let availableActions = actionMenuProvider.actions(
            for: currentSelection,
            preferences: actionPreferences
        )

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

        guard let action = actionMenuProvider.registry.action(with: actionID) else {
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

    private func refreshDirectoryScope() {
        let directoryURLs = Set(scopePreferencesStore.preferences().directoryURLs)
        guard directoryURLs != appliedDirectoryURLs else {
            return
        }

        appliedDirectoryURLs = directoryURLs
        FIFinderSyncController.default().directoryURLs = directoryURLs
        logger.info("Updated Finder scope with \(directoryURLs.count, privacy: .public) directories.")
    }

    private func observeDirectoryScopeChanges() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else {
                    return
                }

                let observerAddress = UInt(bitPattern: observer)
                DispatchQueue.main.async {
                    guard let observer = UnsafeRawPointer(bitPattern: observerAddress) else {
                        return
                    }

                    let finderSync = Unmanaged<FinderSync>
                        .fromOpaque(observer)
                        .takeUnretainedValue()
                    finderSync.refreshDirectoryScope()
                }
            },
            FinderScopePreferencesStore.didChangeDarwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }
}
