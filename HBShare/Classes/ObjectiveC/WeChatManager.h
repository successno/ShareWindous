//
//  WeChatManager.h
//  HBShare
//

// WeChatManager.h
#import <Foundation/Foundation.h>
#import "WXApi.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef WeChatScene_h
#define WeChatScene_h

typedef NS_ENUM(NSInteger, WeChatScene) {
    WeChatSceneSession = 0,   // 微信好友
    WeChatSceneTimeline = 1   // 朋友圈
};

#endif /* WeChatScene_h */


/// 分享结果回调
typedef void (^WeChatShareCompletion)(BOOL success, NSString * _Nullable errorMessage);

@interface WeChatManager : NSObject <WXApiDelegate>

/// 单例
+ (instancetype)shared;

/// 初始化微信SDK
/// @param appId 微信AppID
/// @param universalLink Universal Link
- (BOOL)registerApp:(NSString *)appId universalLink:(NSString *)universalLink;

/// 分享网页到微信
/// @param title 标题
/// @param description 描述
/// @param url 链接
/// @param thumbnailImage 缩略图（UIImage 或 Image URL String）
/// @param scene 分享场景（好友/朋友圈）
/// @param completion 完成回调（可为 nil）
- (void)shareWebPageWithTitle:(NSString *)title
                  description:(NSString *)description
                          url:(NSString *)url
              thumbnailImage:(id)thumbnailImage
                       scene:(int32_t)scene
                  completion:(nullable WeChatShareCompletion)completion;

/// 分享图片到微信
/// @param image 要分享的图片（UIImage 或文件路径 NSString）
/// @param scene 分享场景（好友/朋友圈）
/// @param completion 完成回调（可为 nil）
- (void)shareImage:(id)image
              scene:(int32_t)scene
         completion:(nullable WeChatShareCompletion)completion;

/// 检查微信是否可用
- (BOOL)isWeChatInstalled;
- (BOOL)isWeChatSupported;

/// 处理 Universal Link 回调
- (BOOL)handleOpenUniversalLink:(NSUserActivity *)userActivity;

/// 处理 URL Scheme 回调
- (BOOL)handleOpenURL:(NSURL *)url;

/// 测试微信配置
- (void)testWeChatConfiguration;

/// 检查待处理的分享（应用进入前台时调用）
/// 如果从微信返回但没有收到回调，可能需要超时处理
- (void)checkPendingShareOnForeground;

@end

NS_ASSUME_NONNULL_END
