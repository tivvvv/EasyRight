import Cocoa

protocol ActionFeedbackPresenting: AnyObject {
    func presentSuccess(message: String)
    func presentFailure(message: String)
}

final class SystemActionFeedbackPresenter: ActionFeedbackPresenting {
    func presentSuccess(message: String) {
        let notification = NSUserNotification()
        notification.title = "EasyRight"
        notification.informativeText = message
        NSUserNotificationCenter.default.deliver(notification)
    }

    func presentFailure(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "EasyRight"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
