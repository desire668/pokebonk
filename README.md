# PokéBonk iOS 壳

把在线 3D 宝可梦幸存者游戏 [PokéBonk](https://pokebonk.app/zh-cn/) 包成一个 iOS App。

游戏自带移动端触屏操作，所以这里**只做壳，不注入任何东西**：整个屏幕就是一个 WKWebView，
不覆盖 UA、不拦截触摸、不注入脚本，游戏自己的触屏 UI 原样工作。

壳本身只负责：横屏全屏、隐藏状态栏与 Home 指示条、屏幕常亮、禁用页面滚动/缩放、
持久化存储（保住本地存档）、加载失败可重试，以及 GitHub Actions 产出**未签名 IPA**（签名你自己做）。

---

## 目录结构

```
project.yml                 XcodeGen 工程描述（不提交 xcodeproj）
Info.plist                  应用配置（首页地址、横屏、ATS…）
Sources/
  AppDelegate.swift         入口，强制横屏
  GameViewController.swift  WKWebView + 加载失败重试
Resources/Assets.xcassets/  AppIcon
tools/make_icon.py          生成应用图标（需要 Pillow）
.github/workflows/
  build-unsigned-ipa.yml    构建未签名 IPA
```

## 构建

推送到 GitHub 后 Actions 自动跑，也可以手动 `Run workflow`：

1. 安装 XcodeGen，生成 `PokeBonk.xcodeproj`
2. `xcodebuild archive`，全程关闭代码签名
3. 把 `*.app` 打进 `Payload/` 压缩成 `PokeBonk-unsigned.ipa`
4. 产物作为 Artifact 上传；打 `v*` tag 时额外挂到 Release

```bash
git tag v1.0.0 && git push origin v1.0.0
```

想换首页地址：`Run workflow` 里填 `home_url`，或直接改 `Info.plist` 的 `PokeBonkHomeURL`。

## 签名安装（你自己完成）

产物是**未签名**的，Apple 不允许直接装。任选一种：

| 方式 | 说明 |
| --- | --- |
| **Sideloadly** | 拖入 IPA，填 Apple ID，装到设备；免费证书 7 天过期 |
| **AltStore / SideStore** | 装 AltStore 后导入 IPA，到期自动续签 |
| **iOS App Signer + Xcode** | 用自己的证书与描述文件重签后安装 |
| **TrollStore**（仅支持的系统版本） | 直接安装，永久签名 |

> Bundle ID 是 `app.pokebonk.ios`，重签时可改成你自己的。

## 已知限制

- 需要联网，游戏没有离线包。
- WebGL 游戏在旧设备上可能发烫、掉帧。
- 存档存在 WKWebView 的持久化存储里；卸载 App 会丢，可用游戏内的「单机存档」导出备份。
