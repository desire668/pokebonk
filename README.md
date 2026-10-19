# PokéBonk iOS 壳

把在线 3D 宝可梦幸存者游戏 [PokéBonk](https://pokebonk.app/zh-cn/) 包成 iOS App，并补上移动端操作：

- **左侧浮动虚拟摇杆** → 映射为 WASD 移动
- **右侧区域拖动** → 调整视角（模拟鼠标位移 / 指针锁定）
- **右下角动作键** → 大招 `R`、互动 `E`、跳跃 `空格`、滑行 `Shift`
- 横屏全屏、隐藏状态栏与 Home 指示条、屏幕常亮
- GitHub Actions 直接产出**未签名 IPA**，签名交给你自己完成

---

## 目录结构

```
project.yml                 XcodeGen 工程描述（不提交 xcodeproj）
Info.plist                  应用配置（首页地址、横屏、ATS…）
InputBridge.js              注入到 WKWebView 的输入桥（键盘 / 视角 / 指针锁定垫片）
Sources/
  AppDelegate.swift         入口，强制横屏
  GameViewController.swift  WKWebView + 触控层 + 输入下发
  JoystickView.swift        浮动虚拟摇杆
  LookPadView.swift         右侧视角触控区
  ActionButton.swift        按住型动作键
  SettingsViewController.swift  灵敏度 / 反转 Y / 视角方案
.github/workflows/
  build-unsigned-ipa.yml    构建未签名 IPA
```

## 构建

推送到 GitHub 后，Actions 会自动跑（也可以手动 `Run workflow`）：

1. 安装 XcodeGen，生成 `PokeBonk.xcodeproj`
2. `xcodebuild archive`，全程关闭代码签名
3. 把 `*.app` 打进 `Payload/` 压缩成 `PokeBonk-unsigned.ipa`
4. 产物上传到 Artifact；打 `v*` tag 时额外挂到 Release

打 tag 触发 Release：

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
| **iOS App Signer + Xcode** | 选自己的证书与描述文件重签，再用 `devicectl` / Xcode 安装 |
| **TrollStore**（仅支持的系统版本） | 直接安装，永久签名 |

> 未签名 IPA 的 Bundle ID 是 `app.pokebonk.ios`，重签时可自行改成你自己的。

## 操作

| 控件 | 行为 |
| --- | --- |
| 左半屏下方任意位置按下 | 浮动摇杆出现，拖动即移动；松手回中 |
| 右半屏拖动 | 转视角 |
| 右下四键 | 大招 / 互动 / 跳跃 / 滑行 |
| 左上角 `⌾` | 临时隐藏全部触控层（点游戏里的菜单、按钮时用），再点恢复 |
| 左上角 `⚙` | 灵敏度、反转 Y、视角方案、重新加载 |

`视角方案` 默认是 `鼠标模拟`。如果转不动视角，切到 `触屏拖拽` 再试。

## 实现要点

游戏主 bundle 的输入逻辑是：

- 键盘：`keydown / keyup` 读 `e.code`（`KeyW/KeyA/KeyS/KeyD/Space/ShiftLeft/KeyR/KeyE`）
- 视角：`mousemove` 读 `e.movementX / e.movementY`
  - 拿到 pointer lock 时无条件累加；
  - 否则只有 `dragLook` 为真、`e.target` 是锁定目标元素、且 `buttons & 1` 才累加。

iOS 上没有真正的 pointer lock，所以 `InputBridge.js` 里对 `Element.prototype.requestPointerLock`
做了一层垫片：调用即进入「已锁定」状态并派发 `pointerlockchange`。游戏自己想锁（`requestLock()`）时
垫片会让它锁上；若游戏此刻并不想锁，它会立刻 `exitPointerLock`，桥接会退避几秒后重试，
等玩家真正进入对局再锁。视角输入同时带上 `buttons: 1` 与 `movementX/Y`，两条分支都能命中。

## 已知限制

- 需要联网，游戏本身没有离线包。
- WebGL 游戏在旧设备上可能发烫、掉帧。
- 键盘是数字输入，摇杆只能给到 8 方向，无法像手柄那样线性控制走路速度。
- 若游戏后续改了输入实现，需要同步更新 `InputBridge.js`。
