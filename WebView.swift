import SwiftUI
import WebKit

// Shows the OmniStaq page and passes print requests from the page to the printer.
struct WebView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "omniPrinter")

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let web = WKWebView(frame: .zero, configuration: config)
        web.uiDelegate = context.coordinator
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.web = web

        if #available(iOS 16.4, *) {
            web.isInspectable = true   // lets you debug from Safari on a Mac
        }

        // The page is stored inside the app, so it works with no internet
        if let page = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate {

        weak var web: WKWebView?
        private let printer = PrinterManager()

        // MARK: Messages from the page

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let id = body["id"] as? String,
                  let action = body["action"] as? String else {
                return
            }

            switch action {
            case "connect":
                printer.connect { result in
                    self.reply(id, result)
                }

            case "print":
                guard let text = body["data"] as? String,
                      let bytes = Data(base64Encoded: text) else {
                    reply(id, .failure(PrinterError.badData))
                    return
                }
                printer.printData(bytes) { result in
                    self.reply(id, result)
                }

            default:
                reply(id, .failure(PrinterError.badData))
            }
        }

        // Sends the answer back to the page (omniNativeResult in index.html)
        private func reply(_ id: String, _ result: Result<String, Error>) {
            var good = true
            var text = ""

            switch result {
            case .success(let message):
                text = message
            case .failure(let error):
                good = false
                text = error.localizedDescription
            }

            let js = "omniNativeResult(\(quote(id)), \(good), \(quote(text)));"
            web?.evaluateJavaScript(js)
        }

        // Turns a Swift string into a safe JavaScript string, quotes included
        private func quote(_ text: String) -> String {
            guard let data = try? JSONEncoder().encode(text),
                  let result = String(data: data, encoding: .utf8) else {
                return "\"\""
            }
            return result
        }

        // MARK: alert() and confirm() from the page (WKWebView ignores them otherwise)

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            let box = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            box.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })
            show(box)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            let box = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            box.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false)
            })
            box.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })
            show(box)
        }

        private func show(_ box: UIAlertController) {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let window = scene?.windows.first(where: { $0.isKeyWindow })
            window?.rootViewController?.present(box, animated: true)
        }
    }
}
