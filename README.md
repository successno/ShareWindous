# ShareWindous (HBShare)

iOS 分享模块 CocoaPod：ShareView 分享面板、WeChatManager 微信 SDK 封装、SwiftUI Host。

## 安装

在宿主 App 的 `Podfile` 中引用你的私有仓库（将 URL 与 tag 换成实际值）：

```ruby
pod 'HBShare', :git => '<YOUR_PRIVATE_REPO_GIT_URL>', :tag => '0.1.4'
```

## 主工程接入

```swift
import HBShare

// App 启动时注入本地化、默认文案与缩略图（勿在 Pod 内写死业务域名）
HBShareConfig.localize = { key in /* 返回本地化文案 */ }
HBShareConfig.defaultShareTitle = "你的分享标题"
HBShareConfig.defaultShareDescription = "你的分享描述"
HBShareConfig.defaultShareURL = "https://your-app.example.com"
HBShareConfig.fallbackThumbnailProvider = { UIImage(named: "AppIcon") }
```

微信 AppID、Universal Link 请在宿主 App 的 `AppDelegate` 中调用 `WeChatManager.registerApp(_:universalLink:)` 配置。

## 要求

- iOS 16.0+
- Swift 5.0+
- 真机微信分享需配置 Universal Link 与 URL Scheme
