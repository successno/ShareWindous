import SwiftUI
import WebKit

public class SwiftUIHostController<Content: View>: UIHostingController<Content> {
    public var shareCompletion: ((Bool, String) -> Void)?

    public init(rootView: Content, shareCompletion: ((Bool, String) -> Void)? = nil) {
        self.shareCompletion = shareCompletion
        super.init(rootView: rootView)
        view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public struct ShareSheetContainer: View {
    @Environment(\.dismiss) private var dismiss

    public let title: String
    public let url: String
    public let text: String
    public let imageUrl: String
    public let webView: WKWebView?
    public var onShareComplete: (Bool, String) -> Void

    public init(
        title: String,
        url: String,
        text: String,
        imageUrl: String,
        webView: WKWebView?,
        onShareComplete: @escaping (Bool, String) -> Void
    ) {
        self.title = title
        self.url = url
        self.text = text
        self.imageUrl = imageUrl
        self.webView = webView
        self.onShareComplete = onShareComplete
    }

    public var body: some View {
        VStack {
            ShareView(
                shareOptions: [.wechat, .wechatTimeline, .copyLink],
                currentWebView: webView,
                shareUrl: url.isEmpty ? nil : url,
                shareTitle: title.isEmpty ? nil : title,
                shareInfo: text.isEmpty ? nil : text,
                shareImg: imageUrl.isEmpty ? nil : imageUrl
            )
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .cornerRadius(35)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .onReceive(NotificationCenter.default.publisher(for: HBShareNotification.shareComplete)) { notification in
            if let userInfo = notification.userInfo,
               let success = userInfo["success"] as? Bool,
               let message = userInfo["message"] as? String {
                onShareComplete(success, message)
                dismiss()
            }
        }
    }
}
