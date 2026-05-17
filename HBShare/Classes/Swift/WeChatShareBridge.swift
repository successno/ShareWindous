// WeChatShareBridge.swift - 修正版
import UIKit

public final class WeChatShareBridge: NSObject {

    public static let shared = WeChatShareBridge()
    private let wechatManager = WeChatManager.shared()
    
    // Swift 端的场景枚举（与 OC 的 WeChatScene 对应）
    public enum ShareScene: Int {
        case session = 0   // 微信好友 (WeChatSceneSession)
        case timeline = 1  // 朋友圈 (WeChatSceneTimeline)
    }
    
    public func shareToWeChat(title: String,
                      description: String,
                      url: String,
                      thumbnailImageUrl: String? = nil,
                      toFriend: Bool = true) -> Bool {
        
        print("🌉 [WeChatShareBridge] 开始分享到微信")
        
        // 检查微信是否安装
        guard wechatManager.isWeChatInstalled() else {
            sendShareResult(success: false, message: "请先安装微信")
            return false
        }
        
        // 场景值
        let sceneValue: Int32 = toFriend ? 0 : 1
        
        // ✅ 安全处理缩略图
        var thumbnailImage: Any? = nil
        
        if let imageUrl = thumbnailImageUrl, !imageUrl.isEmpty {
            print("🖼️ 处理缩略图: \(imageUrl)")
            
            // 优先处理 data:image/...;base64,... 这种 Base64 图片
            if imageUrl.hasPrefix("data:image") {
                print("🧬 检测到 Base64 图片数据")
                // 按 "," 分割前缀和真正的 Base64 字符串
                if let commaIndex = imageUrl.firstIndex(of: ",") {
                    let base64String = String(imageUrl[imageUrl.index(after: commaIndex)...])
                    if let data = Data(base64Encoded: base64String),
                       let image = UIImage(data: data),
                       image.size.width > 0, image.size.height > 0 {
                        print("✅ Base64 图片解码成功，尺寸: \(image.size)")
                        performShare(
                            title: title,
                            description: description,
                            url: url,
                            thumbnailImage: image,
                            scene: sceneValue
                        )
                        return true
                    } else {
                        print("❌ Base64 图片解码失败，使用默认缩略图逻辑")
                    }
                } else {
                    print("⚠️ Base64 图片格式异常，缺少逗号分隔")
                }
            }
            
            // 判断是文件路径还是 URL
            if imageUrl.hasPrefix("/") || imageUrl.hasPrefix("file://") {
                // 文件路径，直接加载
                print("📁 检测到文件路径，直接加载")
                var filePath = imageUrl
                if imageUrl.hasPrefix("file://") {
                    if let fileURL = URL(string: imageUrl) {
                        filePath = fileURL.path
                    }
                }
                
                // 检查文件是否存在
                if FileManager.default.fileExists(atPath: filePath) {
                    // 验证文件可以加载（可选，因为 WeChatManager 会处理）
                    print("✅ 文件存在，使用文件路径: \(filePath)")
                    performShare(
                        title: title,
                        description: description,
                        url: url,
                        thumbnailImage: filePath as Any, // 传递文件路径给 WeChatManager
                        scene: sceneValue
                    )
                    return true
                } else {
                    print("❌ 文件不存在: \(filePath)")
                    // 文件不存在，使用默认图片继续分享
                    if let appIcon = HBShareConfig.fallbackThumbnailProvider() {
                        performShare(
                            title: title,
                            description: description,
                            url: url,
                            thumbnailImage: appIcon as Any,
                            scene: sceneValue
                        )
                        return true
                    } else {
                        // 没有默认图片，直接分享（不带缩略图）
                        performShare(
                            title: title,
                            description: description,
                            url: url,
                            thumbnailImage: nil,
                            scene: sceneValue
                        )
                        return true
                    }
                }
            } else {
                // URL 字符串，异步下载图片
                print("🌐 检测到 URL，开始下载")
                downloadImage(from: imageUrl) { [weak self] image in
                    // 使用下载的图片或默认图片
                    let finalImage = image ?? HBShareConfig.fallbackThumbnailProvider()
                    self?.performShare(
                        title: title,
                        description: description,
                        url: url,
                        thumbnailImage: finalImage as Any,
                        scene: sceneValue
                    )
                }
                
                return true // 异步下载中，先返回 true
            }
            
        } else {
            // 没有图片 URL，使用项目内的缩略图资源（优先使用“编组 921”，否则退回 AppIcon）
            if let thumb = HBShareConfig.fallbackThumbnailProvider() {
                thumbnailImage = thumb
                print("🖼️ 使用宿主 App 缩略图")
            } else {
                // 没有任何资源，传 nil
                thumbnailImage = nil
                print("ℹ️ 没有设置缩略图资源，将使用占位图")
            }
            
            performShare(
                title: title,
                description: description,
                url: url,
                thumbnailImage: thumbnailImage as Any,
                scene: sceneValue
            )
            
            return true
        }
    }
    
    private func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            print("❌ 图片URL无效: \(urlString)")
            completion(nil)
            return
        }
        
        DispatchQueue.global().async {
            do {
                let data = try Data(contentsOf: url)
                let image = UIImage(data: data)
                
                DispatchQueue.main.async {
                    if let image = image {
                        print("✅ 图片下载成功，尺寸: \(image.size)")
                        completion(image)
                    } else {
                        print("❌ 图片数据无法解析")
                        completion(nil)
                    }
                }
            } catch {
                print("❌ 图片下载失败: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    private func performShare(title: String,
                             description: String,
                             url: String,
                             thumbnailImage: Any?,
                             scene: Int32) {
        
        // ✅ 安全处理：确保 thumbnailImage 有效
        let safeThumbnailImage: Any
        if let image = thumbnailImage as? UIImage, image.size.width > 0, image.size.height > 0 {
            safeThumbnailImage = image
            print("✅ 使用有效的图片，尺寸: \(image.size)")
        } else {
            // 创建安全的占位图：优先使用“编组 921”，再退回 AppIcon，最后才用空图
            if let thumb = HBShareConfig.fallbackThumbnailProvider() {
                safeThumbnailImage = thumb
                print("⚠️ 原缩略图无效，改用宿主 App 占位图")
            } else {
                safeThumbnailImage = UIImage()
                print("⚠️ 使用空占位图（未找到资源图）")
            }
        }
        
        // 执行分享
        wechatManager.shareWebPage(withTitle: title,
                                  description: description,
                                  url: url,
                                  thumbnailImage: safeThumbnailImage,
                                  scene: scene) { success, error in
            
            print("📱 [WeChatShareBridge] 分享结果: \(success ? "成功" : "失败") - \(error ?? "")")
            
            self.sendShareResult(success: success,
                               message: error ?? (success ? "分享成功" : "分享失败"))
        }
    }
    
    private func sendShareResult(success: Bool, message: String) {
        NotificationCenter.default.post(
            name: HBShareNotification.weChatShareResult,
            object: nil,
            userInfo: ["success": success, "message": message]
        )
    }
    
    // MARK: - 图片分享
    
    /// 分享图片到微信
    /// - Parameters:
    ///   - image: 要分享的图片（UIImage 或文件路径 String）
    ///   - scene: 分享场景（好友/朋友圈）
    /// - Returns: 是否成功发起分享请求
    public func shareImageToWeChat(image: Any, scene: ShareScene) -> Bool {
        print("🌉 [WeChatShareBridge] 开始分享图片到微信")
        print("   📱 场景: \(scene == .session ? "好友" : "朋友圈")")
        
        // 检查微信是否安装
        guard wechatManager.isWeChatInstalled() else {
            sendShareResult(success: false, message: "请先安装微信")
            return false
        }
        
        // 场景值
        let sceneValue = Int32(scene.rawValue)
        
        // 调用 OC 的 WeChatManager 进行图片分享
        wechatManager.shareImage(image, scene: sceneValue) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                print("🌉 [WeChatShareBridge] 图片分享回调 - success: \(success), error: \(errorMessage ?? "")")
                
                // 发送结果通知
                self?.sendShareResult(success: success,
                                     message: errorMessage ?? (success ? "分享成功" : "分享失败"))
            }
        }
        
        return true
    }
}
