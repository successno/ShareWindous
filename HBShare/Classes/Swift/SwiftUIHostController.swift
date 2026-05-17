import SwiftUI
import WebKit
import UIKit

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

// MARK: - Sheet 高度

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
    public static func estimatedHeight(optionCount: Int = 3) -> CGFloat {
        let count = max(1, optionCount)
        let columnCount = max(1, min(count, 4))
        let rows = Int(ceil(Double(count) / Double(columnCount)))
        let rowHeight: CGFloat = 80
        let gridVerticalPadding: CGFloat = 32
        let containerVerticalPadding: CGFloat = 40
        return CGFloat(rows) * rowHeight + gridVerticalPadding + containerVerticalPadding + sheetChromeHeight
    }

    /// SwiftUI `.sheet` 顶部拖拽条占位（overlay 模式不需要）
    public static let sheetChromeHeight: CGFloat = 20

    /// 贴底 overlay 面板高度（不含 sheet chrome）
    public static func overlayPanelHeight(optionCount: Int = 3) -> CGFloat {
        estimatedHeight(optionCount: optionCount) - sheetChromeHeight
    }
}

// MARK: - 分享面板内容（Sheet / Overlay 共用）

public struct SharePanelContent: View {
    public let title: String
    public let url: String
    public let text: String
    public let imageUrl: String
    public let webView: WKWebView?
    public var onShareComplete: (Bool, String) -> Void
    public var onDismiss: (() -> Void)?

    public init(
        title: String,
        url: String,
        text: String,
        imageUrl: String,
        webView: WKWebView?,
        onShareComplete: @escaping (Bool, String) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.url = url
        self.text = text
        self.imageUrl = imageUrl
        self.webView = webView
        self.onShareComplete = onShareComplete
        self.onDismiss = onDismiss
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
        .background(Color.white)
        .onReceive(NotificationCenter.default.publisher(for: HBShareNotification.shareComplete)) { notification in
            if let userInfo = notification.userInfo,
               let success = userInfo["success"] as? Bool,
               let message = userInfo["message"] as? String {
                onShareComplete(success, message)
                onDismiss?()
            }
        }
    }
}

// MARK: - SwiftUI `.sheet` 容器

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
        SharePanelContent(
            title: title,
            url: url,
            text: text,
            imageUrl: imageUrl,
            webView: webView,
            onShareComplete: onShareComplete,
            onDismiss: { dismiss() }
        )
        .background(
            GeometryReader { geometry in
                Color.clear.preference(key: ShareSheetHeightPreferenceKey.self, value: geometry.size.height)
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
    }
}

// MARK: - Overlay（UIKit / H5 用，与 SwiftUI sheet 视觉一致）

private struct ShareOverlayRootView: View {
    let panel: SharePanelContent
    let panelHeight: CGFloat
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            panel
                .frame(height: panelHeight)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.bottom, overlayBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea()
    }

    private var overlayBottomPadding: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
        return max(window?.safeAreaInsets.bottom ?? 0, 8)
    }
}

public enum ShareOverlayPresenter {
    private static weak var overlayContainerView: UIView?
    /// 强引用，避免未加入 VC 层级时被释放
    private static var overlayHostingController: UIViewController?

    private static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first(where: { $0.windowLevel == .normal })
    }

    private static func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// 仅挂载 view 到 window，不把 UIHostingController addChild 到 SwiftUI 页面（避免层级崩溃）
    public static func present(
        on viewController: UIViewController,
        title: String,
        url: String,
        text: String,
        imageUrl: String,
        webView: WKWebView?,
        optionCount: Int = 3,
        onShareComplete: @escaping (Bool, String) -> Void
    ) {
        runOnMain {
            _ = viewController
            tearDown(animated: false)

            guard let window = keyWindow else { return }

            let panelHeight = ShareSheetMetrics.overlayPanelHeight(optionCount: optionCount)
            let panel = SharePanelContent(
                title: title,
                url: url,
                text: text,
                imageUrl: imageUrl,
                webView: webView,
                onShareComplete: onShareComplete,
                onDismiss: { dismiss() }
            )
            let rootView = ShareOverlayRootView(
                panel: panel,
                panelHeight: panelHeight,
                onClose: { dismiss() }
            )

            let hosting = UIHostingController(rootView: rootView)
            hosting.view.backgroundColor = .clear
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            hosting.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            hosting.view.setContentHuggingPriority(.defaultLow, for: .vertical)
            hosting.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            hosting.view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.backgroundColor = .clear
            container.alpha = 0
            container.isUserInteractionEnabled = true

            window.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: window.topAnchor),
                container.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                container.bottomAnchor.constraint(equalTo: window.bottomAnchor)
            ])

            container.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])

            window.layoutIfNeeded()

            overlayContainerView = container
            overlayHostingController = hosting

            UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
                container.alpha = 1
            }
        }
    }

    public static func dismiss() {
        runOnMain {
            tearDown(animated: true)
        }
    }

    private static func tearDown(animated: Bool, completion: (() -> Void)? = nil) {
        guard let container = overlayContainerView else {
            completion?()
            return
        }

        let finish = {
            overlayHostingController?.view.removeFromSuperview()
            overlayHostingController = nil
            container.removeFromSuperview()
            overlayContainerView = nil
            completion?()
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
                container.alpha = 0
            } completion: { _ in
                finish()
            }
        } else {
            finish()
        }
    }
}
