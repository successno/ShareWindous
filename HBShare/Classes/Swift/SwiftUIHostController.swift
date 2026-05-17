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

// MARK: - Sheet 高度（与内容白底区域对齐）

private struct ShareSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ShareSheetPresentationModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(16)
                .presentationBackground(Color.white)
        } else {
            content
                .presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
        }
    }
}

public enum ShareSheetMetrics {
    /// 分享渠道数量，用于估算 Sheet 高度（默认 3：微信好友 / 朋友圈 / 复制链接）
    public static func estimatedHeight(optionCount: Int = 3) -> CGFloat {
        let count = max(1, optionCount)
        let columnCount = max(1, min(count, 4))
        let rows = Int(ceil(Double(count) / Double(columnCount)))
        let rowHeight: CGFloat = 80
        let gridVerticalPadding: CGFloat = 32
        let containerVerticalPadding: CGFloat = 40
        return CGFloat(rows) * rowHeight + gridVerticalPadding + containerVerticalPadding + sheetChromeHeight
    }

    /// 系统 Sheet 顶部拖拽条等占位
    public static let sheetChromeHeight: CGFloat = 20
}

public struct ShareSheetContainer: View {
    @Environment(\.dismiss) private var dismiss

    public let title: String
    public let url: String
    public let text: String
    public let imageUrl: String
    public let webView: WKWebView?
    public var onShareComplete: (Bool, String) -> Void

    private let optionCount: Int

    @State private var contentHeight: CGFloat = ShareSheetMetrics.estimatedHeight(optionCount: 3)

    public init(
        title: String,
        url: String,
        text: String,
        imageUrl: String,
        webView: WKWebView?,
        onShareComplete: @escaping (Bool, String) -> Void,
        optionCount: Int = 3
    ) {
        self.title = title
        self.url = url
        self.text = text
        self.imageUrl = imageUrl
        self.webView = webView
        self.onShareComplete = onShareComplete
        self.optionCount = max(1, optionCount)
        _contentHeight = State(initialValue: ShareSheetMetrics.estimatedHeight(optionCount: max(1, optionCount)))
    }

    private var sheetDetentHeight: CGFloat {
        max(contentHeight, ShareSheetMetrics.estimatedHeight(optionCount: optionCount))
    }

    public var body: some View {
        VStack(spacing: 0) {
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
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geometry in
                Color.white
                    .preference(key: ShareSheetHeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(ShareSheetHeightPreferenceKey.self) { measured in
            guard measured > 0 else { return }
            let total = measured + ShareSheetMetrics.sheetChromeHeight
            if abs(contentHeight - total) > 0.5 {
                contentHeight = total
            }
        }
        .modifier(ShareSheetPresentationModifier(height: sheetDetentHeight))
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
