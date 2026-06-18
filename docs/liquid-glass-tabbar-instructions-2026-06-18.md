# 底部导航栏液态玻璃质感改造指令（给 Codex 执行）

> 目标：把底部导航栏的"选中指示器"从当前的**浅色/白玻璃**改成参考视频里的**深色液态玻璃 + 彩色虹彩折射边 + 蓝色高亮图标**风格。
> 兼容策略：iOS 26+ 用系统原生 `.glassEffect()`，iOS 17–25 用手动模拟（深色半透明 + 模糊 + 彩色描边）。所有用户都能看到效果，新系统更丝滑。
> **保持 4 项导航不变（首页/社区/配置/我的），不加搜索圆。**

---

## 重要前提：滑动引擎已经存在，这是"换皮"不是"重写"

底部栏已经实现了液态玻璃**滑动动画**（弹性拉伸、方向感知、`matchedGeometryEffect` 滑动）。
**不要重写动画逻辑**，只改"外观/配色/材质"。涉及文件只有一个：

- `May/May/Components/AppComponents.swift`

涉及的三个结构（行号以当前代码为准，改前先确认）：
- `BottomTabBar`（约 463 行）—— 整条容器的背景/描边
- `BottomTabLiquidSelection`（约 534 行）—— 选中药丸的外层包装
- `LiquidGlassSelection`（约 659 行）—— 选中药丸的实际玻璃外观（**改动主要在这里**）

---

## 参考视频效果拆解（要还原的 4 个特征）

1. **容器**：深灰近黑的圆角胶囊条（不是白色）。
2. **选中药丸**：半透明深色玻璃，**能隐约透出底色**，不是实心白块。
3. **边缘虹彩**：药丸**边框泛蓝/绿/紫的彩色折射光**（这是"液态玻璃"最标志性的特征，务必做出来）。
4. **选中高亮**：被选中的图标 + 文字变成**蓝色**（参考视频是亮蓝 `#1E90FF` 左右），未选中是白/浅灰。

---

## 任务 1：容器背景改深色（BottomTabBar）

当前 `BottomTabBar.body`（约 477–485 行）是白玻璃：
```swift
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 33))
.background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 33))
.overlay(RoundedRectangle(cornerRadius: 33).stroke(Color.white.opacity(0.82), lineWidth: 1))
```
改为深色玻璃容器：
```swift
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 33))
.background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 33))
.overlay(
    RoundedRectangle(cornerRadius: 33)
        .stroke(Color.white.opacity(0.10), lineWidth: 1)   // 深色容器用淡白描边即可
)
.shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
```

---

## 任务 2：选中药丸改深色虹彩玻璃（LiquidGlassSelection）—— 核心

当前 `LiquidGlassSelection.body`（约 664–696 行）是白色填充。**整体重做它的外观**，保留入参 `stretch/direction/cornerRadius` 不变（动画靠这几个值，别动）。

新外观要点（按顺序叠层）：
1. **底层填充**：深色半透明，`Color.white.opacity(0.10)~0.16` 之类的浅色玻璃感叠在深容器上（让药丸比容器稍亮、有"玻璃片"感）。可配合 `.ultraThinMaterial` 增加真实模糊。
2. **虹彩描边（关键）**：用一圈 `AngularGradient`（角向渐变）描边模拟玻璃折射：
   ```swift
   Capsule()
       .strokeBorder(
           AngularGradient(
               colors: [
                   Color(red: 0.40, green: 0.80, blue: 1.0),   // 蓝
                   Color(red: 0.60, green: 1.0,  blue: 0.85),   // 青绿
                   Color(red: 0.75, green: 0.55, blue: 1.0),   // 紫
                   Color(red: 0.40, green: 0.80, blue: 1.0),    // 回到蓝(闭环)
               ],
               center: .center
           ),
           lineWidth: 1.5
       )
       .blur(radius: 0.5)
       .opacity(0.9)
   ```
3. **高光**：保留原有的顶部白色高光 shadow（`Color.white.opacity(...)` 那行），但把不透明度调低（深色背景下高光要收敛，0.72 → 0.25 左右），避免发灰。
4. 保留原有的 `.scaleEffect(x: 1 + stretch*0.13, ...)` 和移动的小圆点高光（那是滑动时的"液体甩动"效果，是亮点，别删）。

> 调参建议：先做出"深底 + 虹彩边"的大效果，再微调透明度。虹彩别太刺眼，`opacity` 0.7~0.9 之间，`lineWidth` 1~2。

---

## 任务 3：选中图标/文字改蓝色高亮（tabButton）

当前 `tabButton`（约 508 行）：
```swift
.foregroundStyle(selectedTab == tab ? AppTheme.primaryText : AppTheme.secondaryText)
```
现在容器变深色了，未选中文字也要改成浅色才看得见。改为：
```swift
.foregroundStyle(
    selectedTab == tab
        ? Color(red: 0.12, green: 0.56, blue: 1.0)   // 选中：亮蓝
        : Color.white.opacity(0.65)                  // 未选中：浅灰白
)
```
> 若 `AppTheme` 里已有合适的蓝色/品牌色常量，优先复用 AppTheme 的常量，不要硬编码颜色——先 grep 一下 `AppTheme` 有没有 `accent`/`primaryButton`/蓝色定义。

---

## 任务 4：iOS 26 原生玻璃降级（兼容层）

在选中药丸外层（`BottomTabLiquidSelection` 或 `LiquidGlassSelection` 的最外层）包一层条件编译/可用性判断：
```swift
if #available(iOS 26.0, *) {
    someView.glassEffect(.regular.tint(.blue.opacity(0.18)), in: .capsule)
} else {
    someView   // 上面任务 2 手写的虹彩玻璃版本
}
```
- iOS 26+：用系统 `.glassEffect()`，自动获得真实折射/景深。
- iOS 17–25：回退到任务 2 的手写版本。
- **注意**：`.glassEffect` 是 iOS 26 才有的 API，必须用 `#available` 包裹，否则低版本编译/运行会崩。先确认当前 Xcode SDK 是否支持该 API；若 SDK 太老导致 `glassEffect` 符号不存在，则本任务先跳过，只保留任务 2 的手写版（手写版已能覆盖全部用户），并在指令回执里说明。

---

## 验收标准

1. **iOS 17 模拟器**（iPhone 17，项目默认）编译通过并运行：
   ```bash
   cd /Users/may/Documents/AI装机
   xcodebuild -project May/May.xcodeproj -scheme May \
     -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
   ```
2. 视觉自检（截图确认）：
   - 容器是深色，不是白色。
   - 选中药丸边缘有彩色虹彩，半透明能透底。
   - 选中项图标+文字是蓝色，未选中是浅灰白、清晰可读。
   - 点不同 tab，药丸**带弹性滑动**过去（动画不能丢）。
3. **不要改动** `select(_:)` 里的 spring 动画参数和 `matchedGeometryEffect` 逻辑——滑动手感保持原样。
4. 改完只动 `AppComponents.swift` 一个文件（除非 AppTheme 需要加颜色常量）。

---

## 给 Codex 的一句话交代
> 按本文件改造 `AppComponents.swift` 的底部导航栏，把浅色玻璃改成深色虹彩液态玻璃 + 蓝色高亮，保留现有滑动动画，加 iOS 26 原生降级。改完用 iPhone 17 模拟器编译并截图自检。
