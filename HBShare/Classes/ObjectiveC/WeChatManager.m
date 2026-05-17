//
//  WeChatManager.m
//  HBShare
//

// WeChatManager.m
#import "WeChatManager.h"
#import <TargetConditionals.h>

#if TARGET_OS_SIMULATOR

@interface WeChatManager ()
@property (nonatomic, strong) NSMutableDictionary *shareCompletions;
@property (nonatomic, copy) NSString *currentAppId;
@end

@implementation WeChatManager

+ (instancetype)shared {
    static WeChatManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WeChatManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _shareCompletions = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)registerApp:(NSString *)appId universalLink:(NSString *)universalLink {
    (void)appId;
    (void)universalLink;
    NSLog(@"[WeChatManager] 模拟器：跳过微信 SDK（无 libWeChatSDK.a）");
    return NO;
}

- (void)shareWebPageWithTitle:(NSString *)title
                  description:(NSString *)description
                          url:(NSString *)url
              thumbnailImage:(id)thumbnailImage
                       scene:(int32_t)scene
                  completion:(nullable WeChatShareCompletion)completion {
    (void)title;
    (void)description;
    (void)url;
    (void)thumbnailImage;
    (void)scene;
    if (completion) {
        completion(NO, @"模拟器不支持微信 SDK");
    }
}

- (void)shareImage:(id)image
              scene:(int32_t)scene
         completion:(nullable WeChatShareCompletion)completion {
    (void)image;
    (void)scene;
    if (completion) {
        completion(NO, @"模拟器不支持微信 SDK");
    }
}

- (BOOL)isWeChatInstalled {
    return NO;
}

- (BOOL)isWeChatSupported {
    return NO;
}

- (BOOL)handleOpenUniversalLink:(NSUserActivity *)userActivity {
    (void)userActivity;
    return NO;
}

- (BOOL)handleOpenURL:(NSURL *)url {
    (void)url;
    return NO;
}

- (void)testWeChatConfiguration {
    NSLog(@"[WeChatManager] 模拟器：跳过微信配置测试");
}

- (void)checkPendingShareOnForeground {
}

@end

#else

@interface WeChatManager ()
@property (nonatomic, strong) NSMutableDictionary *shareCompletions;
@property (nonatomic, copy) NSString *currentAppId;
@end

@implementation WeChatManager

+ (instancetype)shared {
    static WeChatManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WeChatManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _shareCompletions = [NSMutableDictionary dictionary];
        [self setupLogging];
    }
    return self;
}

- (void)setupLogging {
    // 开启详细日志（仅在调试模式）
#ifdef DEBUG
    [WXApi startLogByLevel:WXLogLevelDetail logBlock:^(NSString *log) {
        NSLog(@"📱 WeChatSDK Log: %@", log);
    }];
#endif
}

#pragma mark - 注册与检查

- (BOOL)registerApp:(NSString *)appId universalLink:(NSString *)universalLink {
    NSLog(@"📱 注册微信SDK - AppID: %@, UniversalLink: %@", appId, universalLink);
    self.currentAppId = appId;
    
    BOOL success = [WXApi registerApp:appId universalLink:universalLink];
    
    if (success) {
        NSLog(@"✅ 微信SDK注册成功");
#ifdef DEBUG
        // 可选：调用自检函数
      //  [self checkUniversalLink];
#endif
    } else {
        NSLog(@"❌ 微信SDK注册失败");
    }
    
    return success;
}

- (void)checkUniversalLink {
#ifdef DEBUG
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [WXApi checkUniversalLinkReady:^(WXULCheckStep step, WXCheckULStepResult* result) {
            NSLog(@"🔍 WeChat Universal Link 检查 - Step: %@, Success: %@, Error: %@, Suggestion: %@", 
                  @(step), 
                  @(result.success), 
                  result.errorInfo ?: @"", 
                  result.suggestion ?: @"");
        }];
    });
#endif
}

- (BOOL)isWeChatInstalled {
    return [WXApi isWXAppInstalled];
}

- (BOOL)isWeChatSupported {
    return [WXApi isWXAppSupportApi];
}

#pragma mark - 分享功能

- (void)shareWebPageWithTitle:(NSString *)title
                  description:(NSString *)description
                          url:(NSString *)url
              thumbnailImage:(id)thumbnailImage
                       scene:(int32_t)scene
                  completion:(nullable WeChatShareCompletion)completion {
    
    NSLog(@"📤 [WeChatManager] 开始微信分享");
    NSLog(@"   📝 标题: %@", title);
    NSLog(@"   📝 描述: %@", description);
    NSLog(@"   🔗 URL: %@", url);
    NSLog(@"   📱 场景: %@", scene == 0 ? @"好友" : @"朋友圈");
    
    // 1. 检查微信是否可用
    if (![self isWeChatInstalled]) {
        NSLog(@"❌ [WeChatManager] 微信未安装");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @"请先安装微信");
            });
        }
        return;
    }
    
    if (![self isWeChatSupported]) {
        NSLog(@"❌ [WeChatManager] 微信版本不支持");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @"微信版本过低，请升级微信");
            });
        }
        return;
    }
    
    NSLog(@"✅ [WeChatManager] 微信检查通过，开始构建分享内容");
    
    // 2. 创建分享请求
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.scene = (int32_t)scene;
    
    // 3. 创建媒体消息
    WXMediaMessage *message = [WXMediaMessage message];
    message.title = title;
    message.description = description;
    
    // 4. 设置缩略图
    if (thumbnailImage) {
        UIImage *thumbImage = nil;
        
        if ([thumbnailImage isKindOfClass:[UIImage class]]) {
            thumbImage = thumbnailImage;
            NSLog(@"📷 [WeChatManager] 使用 UIImage 作为缩略图");
        } else if ([thumbnailImage isKindOfClass:[NSString class]]) {
            NSString *imageString = (NSString *)thumbnailImage;
            NSLog(@"ℹ️ [WeChatManager] 图片路径/URL: %@", imageString);
            
            // 判断是文件路径还是 URL
            if ([imageString hasPrefix:@"/"] || [imageString hasPrefix:@"file://"]) {
                // 文件路径
                NSString *filePath = imageString;
                if ([imageString hasPrefix:@"file://"]) {
                    NSURL *fileURL = [NSURL URLWithString:imageString];
                    filePath = fileURL.path;
                }
                
                // 检查文件是否存在
                if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                    thumbImage = [UIImage imageWithContentsOfFile:filePath];
                    if (thumbImage) {
                        NSLog(@"✅ [WeChatManager] 从文件路径加载图片成功: %@", filePath);
                    } else {
                        NSLog(@"❌ [WeChatManager] 从文件路径加载图片失败: %@", filePath);
                    }
                } else {
                    NSLog(@"❌ [WeChatManager] 文件不存在: %@", filePath);
                }
            } else {
                // URL 字符串，使用 NSURLSession 下载图片
                NSURL *imageUrl = [NSURL URLWithString:imageString];
                if (imageUrl) {
                    NSLog(@"📥 [WeChatManager] 开始下载图片: %@", imageString);
                    // 使用 NSURLSession 同步下载图片（因为已经在异步线程）
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                    __block UIImage *downloadedImage = nil;
                    
                    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:imageUrl completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                        if (data && !error) {
                            downloadedImage = [UIImage imageWithData:data];
                            if (downloadedImage) {
                                NSLog(@"✅ [WeChatManager] 图片下载成功，尺寸: %@", NSStringFromCGSize(downloadedImage.size));
                            } else {
                                NSLog(@"❌ [WeChatManager] 图片数据无法解析");
                            }
                        } else {
                            NSLog(@"❌ [WeChatManager] 图片下载失败: %@", error.localizedDescription);
                        }
                        dispatch_semaphore_signal(semaphore);
                    }];
                    
                    [task resume];
                    
                    // 等待下载完成（最多等待 5 秒）
                    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC);
                    if (dispatch_semaphore_wait(semaphore, timeout) == 0) {
                        thumbImage = downloadedImage;
                    } else {
                        NSLog(@"⏰ [WeChatManager] 图片下载超时");
                    }
                }
            }
            
            // 如果加载失败，使用默认图片
            if (!thumbImage) {
                thumbImage = [UIImage imageNamed:@"AppIcon"];
                if (!thumbImage) {
                    // 如果 AppIcon 不存在，创建一个占位图
                    thumbImage = [UIImage new];
                }
                NSLog(@"⚠️ [WeChatManager] 使用默认图片作为缩略图");
            }
        }
        
        if (thumbImage) {
            // 压缩缩略图（确保小于32KB）
            UIImage *compressedThumb = [self compressImageForWeChat:thumbImage];
            [message setThumbImage:compressedThumb];
            NSLog(@"📷 [WeChatManager] 设置缩略图，原始尺寸: %@, 压缩后尺寸: %@", 
                  NSStringFromCGSize(thumbImage.size), 
                  NSStringFromCGSize(compressedThumb.size));
        }
    } else {
        NSLog(@"ℹ️ [WeChatManager] 未设置缩略图");
    }
    
    // 5. 创建网页对象
    WXWebpageObject *webpageObject = [WXWebpageObject object];
    webpageObject.webpageUrl = url;
    message.mediaObject = webpageObject;
    
    req.message = message;
    
    NSLog(@"✅ [WeChatManager] 分享内容构建完成，准备发送请求");
    
    // 6. 存储回调
    NSString *requestId = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
    if (completion) {
        self.shareCompletions[requestId] = completion;
        NSLog(@"📝 [WeChatManager] 已存储回调，requestId: %@", requestId);
    }
    
    // 7. 发送请求
    NSLog(@"📤 [WeChatManager] 调用 WXApi.sendReq，准备跳转到微信...");
    NSLog(@"   📦 请求内容: title=%@, url=%@, scene=%d", title, url, scene);
    
    // 注意：sendReq:completion: 返回 void，不是 BOOL
    // 是否成功通过 completion 回调来判断
    [WXApi sendReq:req completion:^(BOOL success) {
        NSLog(@"📱 [WeChatManager] 微信SDK发送请求 completion 回调: %@", success ? @"✅ 成功" : @"❌ 失败");
        if (!success) {
            NSLog(@"❌ [WeChatManager] 无法打开微信，立即回调失败");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @"无法打开微信");
                });
            }
            [self.shareCompletions removeObjectForKey:requestId];
        } else {
            NSLog(@"✅ [WeChatManager] 已跳转到微信，等待用户操作...");
            NSLog(@"   ⚠️ 注意：如果用户取消分享或立即返回，onResp 回调会被触发");
            NSLog(@"   ⚠️ 注意：如果 30 秒内没有收到 onResp，可能是用户取消了分享");
            
            // 设置超时保护：如果 30 秒内没有收到 onResp 回调，自动清理
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.shareCompletions[requestId]) {
                    NSLog(@"⏰ [WeChatManager] 超时：30秒内未收到 onResp 回调，可能用户取消了分享");
                    WeChatShareCompletion timeoutCompletion = self.shareCompletions[requestId];
                    if (timeoutCompletion) {
                        timeoutCompletion(NO, @"分享超时，可能已取消");
                    }
                    [self.shareCompletions removeObjectForKey:requestId];
                }
            });
        }
    }];
    
    NSLog(@"📱 [WeChatManager] sendReq 调用完成，等待 completion 回调...");
}

#pragma mark - 图片分享

- (void)shareImage:(id)image
              scene:(int32_t)scene
         completion:(nullable WeChatShareCompletion)completion {
    
    NSLog(@"📤 [WeChatManager] 开始分享图片到微信");
    NSLog(@"   📱 场景: %@", scene == 0 ? @"好友" : @"朋友圈");
    
    // 1. 检查微信是否可用
    if (![self isWeChatInstalled]) {
        NSLog(@"❌ [WeChatManager] 微信未安装");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @"请先安装微信");
            });
        }
        return;
    }
    
    if (![self isWeChatSupported]) {
        NSLog(@"❌ [WeChatManager] 微信版本不支持");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @"微信版本过低，请升级微信");
            });
        }
        return;
    }
    
    // 2. 获取 UIImage 对象
    UIImage *shareImage = nil;
    
    if ([image isKindOfClass:[UIImage class]]) {
        shareImage = (UIImage *)image;
        NSLog(@"📷 [WeChatManager] 使用 UIImage 对象");
    } else if ([image isKindOfClass:[NSString class]]) {
        NSString *imageString = (NSString *)image;
        NSLog(@"📁 [WeChatManager] 图片路径: %@", imageString);
        
        // 判断是文件路径还是 URL
        if ([imageString hasPrefix:@"/"] || [imageString hasPrefix:@"file://"]) {
            // 文件路径
            NSString *filePath = imageString;
            if ([imageString hasPrefix:@"file://"]) {
                NSURL *fileURL = [NSURL URLWithString:imageString];
                filePath = fileURL.path;
            }
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                shareImage = [UIImage imageWithContentsOfFile:filePath];
                if (shareImage) {
                    NSLog(@"✅ [WeChatManager] 从文件路径加载图片成功");
                } else {
                    NSLog(@"❌ [WeChatManager] 从文件路径加载图片失败");
                }
            } else {
                NSLog(@"❌ [WeChatManager] 文件不存在: %@", filePath);
            }
        } else {
            // URL，需要下载
            NSURL *imageUrl = [NSURL URLWithString:imageString];
            if (imageUrl) {
                NSLog(@"📥 [WeChatManager] 开始下载图片: %@", imageString);
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                __block UIImage *downloadedImage = nil;
                
                NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:imageUrl completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    if (data && !error) {
                        downloadedImage = [UIImage imageWithData:data];
                        if (downloadedImage) {
                            NSLog(@"✅ [WeChatManager] 图片下载成功");
                        }
                    } else {
                        NSLog(@"❌ [WeChatManager] 图片下载失败: %@", error.localizedDescription);
                    }
                    dispatch_semaphore_signal(semaphore);
                }];
                
                [task resume];
                dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC);
                if (dispatch_semaphore_wait(semaphore, timeout) == 0) {
                    shareImage = downloadedImage;
                } else {
                    NSLog(@"⏰ [WeChatManager] 图片下载超时");
                }
            }
        }
    }
    
    if (!shareImage) {
        NSLog(@"❌ [WeChatManager] 无法获取图片");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @"无法加载图片");
            });
        }
        return;
    }
    
    // 3. 创建图片分享请求
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.scene = scene;
    
    // 4. 创建图片对象
    WXImageObject *imageObject = [WXImageObject object];
    
    // 将 UIImage 转换为 NSData（JPEG 格式）
    NSData *imageData = UIImageJPEGRepresentation(shareImage, 0.9);
    if (!imageData) {
        NSLog(@"❌ [WeChatManager] 图片转换失败");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @"图片格式错误");
            });
        }
        return;
    }
    
    imageObject.imageData = imageData;
    
    // 5. 创建媒体消息
    WXMediaMessage *message = [WXMediaMessage message];
    message.mediaObject = imageObject;
    
    // 设置缩略图（微信要求，必须小于 32KB）
    UIImage *thumbImage = [self compressImageForWeChat:shareImage];
    [message setThumbImage:thumbImage];
    
    req.message = message;
    
    NSLog(@"✅ [WeChatManager] 图片分享内容构建完成，准备发送请求");
    NSLog(@"   📦 图片大小: %.2f KB", imageData.length / 1024.0);
    NSLog(@"   📦 缩略图大小: %.2f KB", thumbImage ? (UIImageJPEGRepresentation(thumbImage, 0.9).length / 1024.0) : 0);
    
    // 6. 存储回调
    NSString *requestId = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
    if (completion) {
        self.shareCompletions[requestId] = completion;
        NSLog(@"📝 [WeChatManager] 已存储回调，requestId: %@", requestId);
        
        // 设置超时保护
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.shareCompletions[requestId]) {
                NSLog(@"⏰ [WeChatManager] 超时：15秒内未收到 onResp 回调");
                WeChatShareCompletion timeoutCompletion = self.shareCompletions[requestId];
                if (timeoutCompletion) {
                    timeoutCompletion(NO, @"分享超时，可能已取消");
                }
                [self.shareCompletions removeObjectForKey:requestId];
            }
        });
    }
    
    // 7. 发送请求
    NSLog(@"📤 [WeChatManager] 调用 WXApi.sendReq 分享图片...");
    [WXApi sendReq:req completion:^(BOOL success) {
        NSLog(@"📱 [WeChatManager] 微信SDK发送请求 completion 回调: %@", success ? @"✅ 成功" : @"❌ 失败");
        if (!success) {
            NSLog(@"❌ [WeChatManager] 无法打开微信，立即回调失败");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @"无法打开微信");
                });
            }
            [self.shareCompletions removeObjectForKey:requestId];
        } else {
            NSLog(@"✅ [WeChatManager] 已跳转到微信，等待用户操作...");
        }
    }];
}

#pragma mark - 图片处理

- (UIImage *)compressImageForWeChat:(UIImage *)image {
    // ✅ 安全检查：确保图片尺寸有效
    if (!image || image.size.width <= 0 || image.size.height <= 0 || isnan(image.size.width) || isnan(image.size.height)) {
        NSLog(@"❌ [WeChatManager] 图片尺寸无效: %@", NSStringFromCGSize(image.size));
        
        // 创建一个安全的默认图片
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(120, 120), YES, 1.0);
        [[UIColor lightGrayColor] setFill];
        UIRectFill(CGRectMake(0, 0, 120, 120));
        UIImage *safeImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return safeImage ?: image;
    }
    
    NSLog(@"✅ [WeChatManager] 图片尺寸有效: %@", NSStringFromCGSize(image.size));
    
    // 目标尺寸：120x120（微信推荐）
    CGFloat maxSize = 120.0;
    CGSize targetSize = CGSizeZero;
    
    if (image.size.width > image.size.height) {
        targetSize = CGSizeMake(maxSize, maxSize * image.size.height / image.size.width);
    } else {
        targetSize = CGSizeMake(maxSize * image.size.width / image.size.height, maxSize);
    }
    
    // ✅ 再次检查目标尺寸
    if (targetSize.width <= 0 || targetSize.height <= 0 || isnan(targetSize.width) || isnan(targetSize.height)) {
        targetSize = CGSizeMake(120, 120);
        NSLog(@"⚠️ [WeChatManager] 目标尺寸无效，使用默认: %@", NSStringFromCGSize(targetSize));
    }
    
    NSLog(@"🔧 [WeChatManager] 压缩图片: %@ -> %@",
          NSStringFromCGSize(image.size),
          NSStringFromCGSize(targetSize));
    
    // 调整尺寸
    UIGraphicsBeginImageContextWithOptions(targetSize, YES, 1.0);
    @try {
        [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
        UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (!resizedImage) {
            NSLog(@"❌ [WeChatManager] 图片重绘失败");
            return image;
        }
        
        // 压缩质量，确保小于32KB
        NSData *imageData = nil;
        CGFloat compression = 0.9;
        
        for (int i = 0; i < 6; i++) { // 最多尝试6次
            imageData = UIImageJPEGRepresentation(resizedImage, compression);
            NSLog(@"🔧 [WeChatManager] 图片压缩尝试 %d: 质量 %.1f, 大小 %.2fKB",
                  i + 1, compression, imageData.length / 1024.0);
            
            if (imageData.length <= 28 * 1024) { // 28KB留有余量
                break;
            }
            compression -= 0.15;
            if (compression < 0.1) compression = 0.1;
        }
        
        if (imageData && imageData.length > 0) {
            UIImage *finalImage = [UIImage imageWithData:imageData];
            NSLog(@"✅ [WeChatManager] 图片压缩完成: %.2fKB", imageData.length / 1024.0);
            return finalImage ?: image;
        }
        
        return resizedImage;
    } @catch (NSException *exception) {
        NSLog(@"❌ [WeChatManager] 图片处理异常: %@", exception);
        UIGraphicsEndImageContext();
        return image;
    }
}

#pragma mark - WXApiDelegate

- (void)onReq:(BaseReq *)req {
    NSLog(@"📱 收到微信请求: %@", req);
}

- (void)onResp:(BaseResp *)resp {
    NSLog(@"📱 [WeChatManager] ========== 收到微信响应 ==========");
    NSLog(@"   📦 响应类型: %@", NSStringFromClass([resp class]));
    NSLog(@"   📦 响应对象: %@", resp);
    
    if ([resp isKindOfClass:[SendMessageToWXResp class]]) {
        SendMessageToWXResp *shareResp = (SendMessageToWXResp *)resp;
        BOOL success = (shareResp.errCode == 0);
        NSString *errorMsg = shareResp.errStr ?: @"";
        
        NSLog(@"🔄 [WeChatManager] 微信分享响应详情:");
        NSLog(@"   errCode: %d", shareResp.errCode);
        NSLog(@"   errStr: %@", errorMsg);
        NSLog(@"   结果: %@", success ? @"✅ 成功" : @"❌ 失败");
        
        // 解释 errCode 的含义
        NSString *errCodeDescription = @"";
        switch (shareResp.errCode) {
            case 0:
                errCodeDescription = @"用户同意/分享成功";
                break;
            case -2:
                errCodeDescription = @"用户取消";
                break;
            case -3:
                errCodeDescription = @"发送失败";
                break;
            case -4:
                errCodeDescription = @"授权失败";
                break;
            case -5:
                errCodeDescription = @"微信不支持";
                break;
            default:
                errCodeDescription = [NSString stringWithFormat:@"未知错误码: %d", shareResp.errCode];
                break;
        }
        NSLog(@"   errCode 说明: %@", errCodeDescription);
        
        // 执行所有等待的回调
        NSArray *allKeys = [self.shareCompletions allKeys];
        NSLog(@"📝 [WeChatManager] 待处理的回调数量: %lu", (unsigned long)allKeys.count);
        
        if (allKeys.count == 0) {
            NSLog(@"⚠️ [WeChatManager] 警告：没有待处理的回调，可能已被清理或超时");
            NSLog(@"   ⚠️ 这可能导致 UI 一直显示加载状态");
        }
        
        for (NSString *key in allKeys) {
            WeChatShareCompletion completion = self.shareCompletions[key];
            if (completion) {
                NSLog(@"📤 [WeChatManager] 执行回调，requestId: %@", key);
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 根据 errCode 生成更友好的错误消息
                    NSString *finalMessage = nil;
                    if (!success) {
                        if (shareResp.errCode == -2) {
                            finalMessage = @"用户取消了分享";
                        } else if (errorMsg.length > 0) {
                            finalMessage = errorMsg;
                        } else {
                            finalMessage = @"分享失败";
                        }
                    }
                    completion(success, finalMessage);
                });
            }
            [self.shareCompletions removeObjectForKey:key];
        }
        
        NSLog(@"✅ [WeChatManager] 所有回调已处理完成");
        NSLog(@"📱 [WeChatManager] ========================================");
    } else {
        NSLog(@"ℹ️ [WeChatManager] 收到其他类型的响应: %@", NSStringFromClass([resp class]));
        NSLog(@"   ℹ️ 这不是分享响应，忽略处理");
    }
}

#pragma mark - URL 处理

- (BOOL)handleOpenUniversalLink:(NSUserActivity *)userActivity {
    NSURL *url = userActivity.webpageURL;
    NSLog(@"🔗 [WeChatManager] ========== 处理 Universal Link ==========");
    NSLog(@"   📦 URL: %@", url);
    NSLog(@"   📦 Activity Type: %@", userActivity.activityType);
    
    BOOL result = [WXApi handleOpenUniversalLink:userActivity delegate:self];
    NSLog(@"   ✅ 处理结果: %@", result ? @"成功" : @"失败");
    NSLog(@"🔗 [WeChatManager] ========================================");
    return result;
}

- (BOOL)handleOpenURL:(NSURL *)url {
    NSLog(@"🔗 [WeChatManager] ========== 处理 URL Scheme ==========");
    NSLog(@"   📦 URL: %@", url);
    NSLog(@"   📦 Scheme: %@", url.scheme);
    
    BOOL result = [WXApi handleOpenURL:url delegate:self];
    NSLog(@"   ✅ 处理结果: %@", result ? @"成功" : @"失败");
    NSLog(@"🔗 [WeChatManager] ========================================");
    return result;
}

#pragma mark - 应用生命周期处理

- (void)checkPendingShareOnForeground {
    NSArray *allKeys = [self.shareCompletions allKeys];
    if (allKeys.count > 0) {
        NSLog(@"📱 [WeChatManager] 应用进入前台，发现 %lu 个待处理的分享回调", (unsigned long)allKeys.count);
        NSLog(@"   ⚠️ 如果用户从微信返回但没有完成分享，onResp 应该会被触发");
        NSLog(@"   ⚠️ 如果 15 秒内仍未收到回调，超时机制会自动清理");
    } else {
        NSLog(@"📱 [WeChatManager] 应用进入前台，没有待处理的分享回调");
    }
}

#pragma mark - 测试方法

- (void)testWeChatConfiguration {
    NSLog(@"=== 微信配置测试开始 ===");
    
    // 1. 检查微信安装
    NSLog(@"微信已安装: %@", [self isWeChatInstalled] ? @"✅" : @"❌");
    
    // 2. 检查微信支持
    NSLog(@"微信版本支持: %@", [self isWeChatSupported] ? @"✅" : @"❌");
    
    // 3. 测试分享
    [self shareWebPageWithTitle:@"测试分享"
                    description:@"这是一个配置测试"
                            url:@"https://www.baidu.com"
                 thumbnailImage:nil
                          scene:WeChatSceneSession
                     completion:^(BOOL success, NSString *errorMessage) {
        NSLog(@"测试分享结果: %@ - %@", success ? @"✅ 成功" : @"❌ 失败", errorMessage ?: @"");
    }];
    
    NSLog(@"=== 微信配置测试结束 ===");
}

@end

#endif
