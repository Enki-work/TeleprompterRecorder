# TeleprompterRecorder（提词器相机）

> iOS 提词器 + 视频录制一体化应用，已在 App Store 上架发布。

**App Store 链接：**
https://apps.apple.com/jp/app/%E3%83%97%E3%83%AD%E3%83%B3%E3%83%97%E3%82%BF%E3%83%BC%E3%82%AB%E3%83%A1%E3%83%A9/id1608655385

---

## 功能概述

在拍摄视频的同时，屏幕上叠加显示提词器文字，让演讲、讲解、直播等场景更加流畅自然。支持高画质录制（最高 4K HDR），提词器样式可完全自定义。

---

## 主要功能

### 视频录制
- **多种分辨率支持**：4K、2.7K、全高清（1080p）、高清（720p）、标清
- **帧率显示**：支持各种帧率选择（24/30/60fps 等）
- **HDR 视频**：使用 HEVC 编码 + HLG BT.2020 色彩空间录制 HDR 内容
- **SDR 视频**：使用 H.264 编码 + P3/sRGB 色彩空间
- **前后镜头切换**：一键切换前置/后置摄像头
- **格式选择界面**：按分辨率分组展示，支持 HDR/SDR 切换筛选
- **自动保存**：录制完成后自动保存至系统相册

### 提词器
- **悬浮叠加显示**：提词器文字叠加在摄像头预览画面之上
- **模糊背景**：可调节毛玻璃模糊强度（0～100%），保持视频画面可见
- **渐变边缘**：顶部渐隐效果，视觉更自然
- **点击隐藏/显示**：点击提词器区域即可切换显示状态
- **文字编辑**：点击编辑按钮进入编辑模式，支持全文字输入
- **文字持久化**：编辑的提词内容自动保存，下次打开自动恢复

### 提词器外观自定义
- **背景颜色**：通过系统颜色选择器自由选择背景色
- **文字颜色**：通过系统颜色选择器自由选择文字颜色
- **字体大小**：滑块调节（12～60pt）
- **模糊强度**：滑块调节毛玻璃效果
- **实时预览**：调节时即时反映效果
- **重置功能**：一键恢复默认设置
- **设置持久化**：所有自定义设置自动保存

### 广告与变现
- **App Open 广告**：冷启动时展示，后台切回时展示（有 4 小时缓存限制）
- **激励视频广告**：提词器编辑功能有 24 小时使用限制，观看广告后解锁
- **ATT 授权**：符合 Apple App Tracking Transparency 规范

---

## 技术架构

### 架构模式
采用 **MVVM + RxSwift** 响应式架构：

```
ViewController（视图层）
    ↕ RxSwift 双向绑定
ViewModel（逻辑层）
    ↕
Manager / Service（功能层）
    ↕
Model / View（数据/组件层）
```

### 主要模块

| 模块 | 文件 | 说明 |
|------|------|------|
| 主录制界面 | `VideoRecorderViewController` | 摄像头预览、录制控制、提词器整合 |
| 录制逻辑 | `VideoRecorderViewModel` | 权限管理、录制状态、格式切换 |
| 相机管理 | `CaptureManager` | AVCaptureSession 管理、格式选择、帧输出 |
| 视频编码 | `CaptureEncoder` | AVAssetWriter 编码、HDR 色彩空间配置 |
| 提词器 UI | `CaptureButtonsView` | 提词器显示、编辑、设置应用 |
| 提词器设置 | `PrompterSettingsViewController` | 颜色/字体/模糊度自定义 |
| 格式列表 | `FormatListViewController` | 相机格式选择 UI |
| 激励广告 | `RewardedVideoManager` | AdMob 激励视频管理 |
| 侧边菜单 | `MenuViewController` | SideMenu 导航 |
| 联系我们 | `ContactMeViewController` | 多邮件客户端支持 |

### 录制流程

```
用户点击录制按钮
    → VideoRecorderViewModel 触发录制
    → CaptureManager.startRecording()
    → captureOutput() 回调 → CaptureEncoder 处理帧数据
    → AVAssetWriter 写入临时文件
    → 停止录制 → 保存至 PHPhotoLibrary
```

### 提词器设置流程

```
用户调整设置（颜色/字体/模糊）
    → UserDefaults 保存
    → NotificationCenter 发送 .prompterSettingsChanged
    → CaptureButtonsView 监听并实时应用
    → UIViewPropertyAnimator 动画过渡
```

---

## 技术要点

### HDR 支持
- 检测摄像头是否支持 HLG BT.2020 色彩空间
- HDR 模式使用 HEVC 编码器并配置完整色彩空间参数（色域、传输特性、色彩基元）
- SDR 模式使用 H.264 并适配 P3_D65 / sRGB

### 视频写入优化
- `AVAssetWriter.shouldOptimizeForNetworkUse = true`：将 moov atom 前置，避免相册播放开头卡顿
- 首帧处理：无论音频帧还是视频帧先到，均可正确开始写入会话

### 方向管理
- 录制开始时一次性设置 `videoOrientation`，避免录制中途更改导致管线中断
- 支持设备旋转的实时检测与同步

### 后台录制
- 使用 `UIApplication.beginBackgroundTask` 在进入后台时继续保存录制
- 后台结束时自动停止录制并保存

### 权限管理
- RxSwift Single 串联权限请求顺序：相机 → 麦克风 → 相册
- 权限拒绝时引导用户至系统设置

---

## 依赖框架

| 框架 | 用途 |
|------|------|
| RxSwift / RxCocoa | 响应式编程框架 |
| RxDataSources | TableView 数据源绑定 |
| Firebase Crashlytics | 崩溃监控 |
| Firebase Messaging | 推送通知（FCM） |
| GoogleMobileAds | AdMob 广告 |
| SideMenu | 侧边栏 UI 组件 |
| AppTrackingTransparency | iOS 广告追踪授权 |

---

## 环境要求

| 项目 | 要求 |
|------|------|
| iOS 版本 | iOS 17.0+ |
| 开发语言 | Swift |
| 架构 | MVVM + RxSwift |
| 编译工具 | Xcode 15+ |
| 包管理 | CocoaPods |

---

## 权限说明

| 权限 | 用途 |
|------|------|
| 相机 | 录制视频 |
| 麦克风 | 录制音频 |
| 相册写入 | 保存录制的视频 |
| 广告追踪（ATT） | 个性化广告展示 |

---

## 项目结构

```
TeleprompterRecorder/
├── AppDelegate.swift              # 应用初始化、Firebase、广告
├── SceneDelegate.swift            # 场景生命周期、ATT 授权
├── ViewController/
│   ├── VideoRecorderViewController.swift   # 主录制界面
│   ├── PrompterSettingsViewController.swift # 提词器设置
│   ├── MenuViewController.swift            # 侧边菜单
│   ├── FormatListViewController.swift      # 格式选择
│   └── ContactMeViewController.swift       # 联系我们
├── View/
│   ├── CameraPreview.swift        # 相机预览层
│   └── CaptureButtonsView.swift   # 录制控制 UI + 提词器
├── ViewModel/
│   ├── VideoRecorderViewModel.swift
│   ├── FormatListViewModel.swift
│   ├── ReposViewModel.swift
│   ├── Manager/
│   │   ├── CaptureManager.swift   # AVCaptureSession 管理
│   │   ├── CaptureEncoder.swift   # AVAssetWriter 编码
│   │   └── RewardedVideoManager.swift # 激励广告
│   └── Networking/
│       └── NetworkingApi.swift    # API 请求
├── Models/
│   ├── Repo.swift
│   ├── MySection.swift
│   └── LocalDeviceFormat.swift    # 格式偏好持久化
└── Utils/
    ├── Extension.swift            # 工具扩展（UserDefaults、UIKit）
    ├── RxExtension.swift          # RxSwift + AVFoundation 扩展
    ├── UIViewController+Rx.swift  # ViewController 生命周期 Rx 化
    ├── ViewModelType.swift        # MVVM 协议
    └── ActivityIndicator.swift    # 加载状态管理
```
