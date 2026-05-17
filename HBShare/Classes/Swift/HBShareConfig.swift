import UIKit

/// HBShare 模块配置（由宿主 App 在启动时注入）
public enum HBShareConfig {
    /// 简繁本地化，默认原样返回
    public static var localize: (String) -> String = { $0 }

    /// 由宿主 App 在启动时赋值；Pod 内不提供业务默认文案
    public static var defaultShareTitle: String = ""
    public static var defaultShareDescription: String = ""
    public static var defaultShareURL: String = ""

    /// 链接分享默认缩略图（主工程 AppIcon 等）
    public static var fallbackThumbnailProvider: () -> UIImage? = {
        UIImage(named: "AppIcon")
    }
}

public enum HBShareNotification {
    public static let weChatShareResult = Notification.Name("WeChatShareResult")
    public static let shareComplete = Notification.Name("ShareComplete")
}

private final class HBShareBundleToken: NSObject {}

public extension Bundle {
    static var hbShareResources: Bundle {
        Bundle(for: HBShareBundleToken.self)
    }
}

extension String {
    func hbShareLocalized() -> String {
        HBShareConfig.localize(self)
    }
}
