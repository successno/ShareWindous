Pod::Spec.new do |s|
  s.name             = 'HBShare'
  s.version          = '0.1.0'
  s.summary          = 'iOS 分享面板与微信 SDK 封装（ShareView + WeChatManager）'
  s.description      = '可复用 CocoaPod：分享面板、微信 SDK 桥接、SwiftUI Host。'
  s.homepage         = 'https://github.com/successno/ShareWindous'
  s.license          = { :type => 'Proprietary', :file => 'LICENSE' }
  s.author           = { 'ShareWindous' => 'noreply@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/successno/ShareWindous.git', :tag => s.version.to_s }
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.0'

  s.source_files = 'HBShare/Classes/**/*.{swift,h,m}'
  s.public_header_files = 'HBShare/Classes/ObjectiveC/*.h'
  s.resources = 'HBShare/Assets/ShareIcon.xcassets'
  s.preserve_paths = 'HBShare/Vendor/libWeChatSDK.a'
  s.resource_bundles = { 'HBSharePrivacy' => ['HBShare/Classes/ObjectiveC/PrivacyInfo.xcprivacy'] }

  s.frameworks = 'UIKit', 'Foundation', 'WebKit'
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/HBShare/Classes/ObjectiveC"',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC -lc++',
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -force_load "${PODS_TARGET_SRCROOT}/HBShare/Vendor/libWeChatSDK.a"',
    'DEFINES_MODULE' => 'YES'
  }
end
