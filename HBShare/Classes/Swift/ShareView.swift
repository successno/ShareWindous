import SwiftUI
import WebKit
import UIKit

public struct ShareView: View {
    public let shareOptions: [ShareIcon]

    public var currentWebView: WKWebView?
    public var shareUrl: String?
    public var shareTitle: String?
    public var shareInfo: String?
    public var shareImg: String?

    @State private var isSharing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var weChatResultObserver: NSObjectProtocol?

    public init(
        shareOptions: [ShareIcon] = [.wechat, .wechatTimeline, .copyLink],
        currentWebView: WKWebView? = nil,
        shareUrl: String? = nil,
        shareTitle: String? = nil,
        shareInfo: String? = nil,
        shareImg: String? = nil
    ) {
        self.shareOptions = shareOptions
        self.currentWebView = currentWebView
        self.shareUrl = shareUrl
        self.shareTitle = shareTitle
        self.shareInfo = shareInfo
        self.shareImg = shareImg
    }

    public var body: some View {
        let columnCount = max(1, min(shareOptions.count, 4))
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columnCount), spacing: 20) {
            ForEach(shareOptions, id: \.self) { option in
                option.makeButton {
                    handleButtonTap(for: option)
                }
                .disabled(isSharing)
            }
        }
        .padding()
        .overlay(
            isSharing ?
                ProgressView("處理中…".hbShareLocalized())
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.5))
                    .ignoresSafeArea()
                : nil
        )
        .alert("提示".hbShareLocalized(), isPresented: $showAlert) {
            Button("確定".hbShareLocalized()) { showAlert = false }
        } message: {
            Text(alertMessage.hbShareLocalized())
        }
        .onAppear { setupWeChatResultListener() }
        .onDisappear {
            if let observer = weChatResultObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private func setupWeChatResultListener() {
        weChatResultObserver = NotificationCenter.default.addObserver(
            forName: HBShareNotification.weChatShareResult,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let success = userInfo["success"] as? Bool,
               let message = userInfo["message"] as? String {
                isSharing = false
                alertMessage = message
                showAlert = true
                NotificationCenter.default.post(
                    name: HBShareNotification.shareComplete,
                    object: nil,
                    userInfo: ["success": success, "message": message]
                )
            }
        }
    }

    private func handleButtonTap(for option: ShareIcon) {
        isSharing = true
        switch option {
        case .wechat, .wechatTimeline:
            shareToWeChat(option: option)
        case .copyLink:
            copyLink()
        }
    }

    private func shareToWeChat(option: ShareIcon) {
        let title = shareTitle ?? HBShareConfig.defaultShareTitle.hbShareLocalized()
        let description = shareInfo ?? HBShareConfig.defaultShareDescription.hbShareLocalized()
        let url = shareUrl ?? currentWebView?.url?.absoluteString ?? ""
        let imageUrl = shareImg
        let toFriend = (option == .wechat)

        if (url.isEmpty || url == "about:blank"),
           let img = imageUrl,
           img.hasPrefix("data:image") {
            var decodedImage: UIImage?
            if let dataUrl = URL(string: img),
               let data = try? Data(contentsOf: dataUrl),
               let uiImage = UIImage(data: data),
               uiImage.size.width > 0, uiImage.size.height > 0 {
                decodedImage = uiImage
            } else if let commaIndex = img.firstIndex(of: ",") {
                let base64String = String(img[img.index(after: commaIndex)...])
                if let data = Data(base64Encoded: base64String),
                   let uiImage = UIImage(data: data),
                   uiImage.size.width > 0, uiImage.size.height > 0 {
                    decodedImage = uiImage
                }
            }

            guard let finalImage = decodedImage else {
                isSharing = false
                alertMessage = "無法解析分享圖片"
                showAlert = true
                return
            }

            let scene: WeChatShareBridge.ShareScene = toFriend ? .session : .timeline
            let success = WeChatShareBridge.shared.shareImageToWeChat(image: finalImage, scene: scene)
            if !success {
                isSharing = false
                alertMessage = "無法分享到微信"
                showAlert = true
            }
            return
        }

        let success = WeChatShareBridge.shared.shareToWeChat(
            title: title,
            description: description,
            url: url.isEmpty ? HBShareConfig.defaultShareURL : url,
            thumbnailImageUrl: nil,
            toFriend: toFriend
        )
        if !success {
            isSharing = false
            alertMessage = "無法分享到微信"
            showAlert = true
        }
    }

    private func copyLink() {
        guard let url = shareUrl ?? currentWebView?.url?.absoluteString else {
            alertMessage = "沒有可複製的鏈接"
            showAlert = true
            isSharing = false
            return
        }
        UIPasteboard.general.string = url
        alertMessage = "鏈接已複製到剪貼板"
        showAlert = true
        isSharing = false
    }
}

public enum ShareIcon: String, CaseIterable, Hashable {
    case wechat = "微信好友"
    case wechatTimeline = "朋友圈"
    case copyLink = "复制链接"

    public var imageName: String {
        switch self {
        case .wechat: return "微信好友"
        case .wechatTimeline: return "朋友圈"
        case .copyLink: return "复制链接"
        }
    }

    public var buttonTitle: String {
        rawValue.hbShareLocalized()
    }

    public func makeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(imageName, bundle: .hbShareResources)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)

                Text(buttonTitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 80, height: 80)
    }
}
