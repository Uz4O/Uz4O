# 底部导航栏「液态滑动动画」增强指令（方法 A，给 Codex 执行）

> 目标：只增强底部导航栏切换 tab 时选中药丸的**滑动动画**，做出参考视频里的"液态甩动"感——飞行中沿运动方向被拉长成水银长条 + 拖尾残影，到位时挤压回弹。
> **只改动画，不改外观**：颜色、材质、玻璃质感全部保持现状不动。
> 参考帧见 `docs/reference-liquid-glass/`（reference-sliding.png 是飞行拉伸态）。

---

## 涉及文件（只动这一个）
- `May/May/Components/AppComponents.swift`
  - `BottomTabBar.select(_:)`（约 517 行）—— 驱动动画的时序
  - `BottomTabLiquidSelection`（约 529 行）—— 药丸的形变 + 拖尾
  - 形变计算 `horizontalScale` / `verticalScale`（约 558–564 行）

> **不要碰** `LiquidGlassSelection` 的填充/描边/颜色（那是外观），也不要动 `tabButton` 的图标文字配色。

---

## 当前问题诊断（为什么现在没有甩动感）

1. **形变方向反了**：当前 `horizontalScale = 1 - progress * 0.12`，滑动时药丸是**横向缩短、纵向拉长**（立起来）。而视频里飞行时应是**沿水平运动方向拉长**（躺平拉长）。方向是矛盾的。
2. **形变量太小**：只有 12%，几乎看不见。视频里飞行段拉伸约 **+40%**。
3. **完全没有拖尾残影**：当前只有一个药丸整体缩放，缺少跟在身后的"液体尾巴"。

---

## 视频动画的运动学（百分百还原的依据，已逐帧量化）

切换分两个相位，必须都做出来：

| 相位 | 时间 | 形变 | 体感 |
|------|------|------|------|
| **飞行/加速段** | 动画前 ~60% | 沿水平方向**大幅拉长**(scaleX ≈ 1.4)，纵向略压扁(scaleY ≈ 0.9)，身后拖出半透明残影 | 被甩出的水银长条 |
| **到位/减速回弹段** | 动画后 ~40% | 反向**挤压**(scaleX ≈ 0.9 过冲)再 spring 弹回 1.0，拖尾收回 | 果冻落地回弹 |

方向：`liquidDirection`（+1 向右 / -1 向左）已存在，复用它决定拉伸和拖尾朝向。

---

## 具体改法

### 1. 形变方向翻转 + 放大（horizontalScale / verticalScale）
把：
```swift
private var horizontalScale: CGFloat { 1 - progress * 0.12 }
private var verticalScale: CGFloat { 1 / horizontalScale }
```
改为**沿水平方向拉长**（飞行时变扁长）：
```swift
private var horizontalScale: CGFloat { 1 + progress * 0.40 }   // 飞行时横向拉长 40%
private var verticalScale: CGFloat { 1 - progress * 0.14 }     // 纵向略压扁，体积守恒感
```
> `progress` 仍是 0→1→0：飞行中冲到 1（最大拉伸），到位回 0（恢复）。

### 2. 拉伸锚点改为"沿运动方向"
当前 `scaleEffect(... anchor: .center)`。飞行时锚点应偏向**运动来的方向**，让药丸"头先到、尾巴还黏在后面"：
```swift
.scaleEffect(
    x: horizontalScale,
    y: verticalScale,
    anchor: direction > 0 ? .leading : .trailing   // 向右飞→锚定左侧(尾巴在左)
)
```

### 3. 加拖尾残影（这是"液体甩动"的灵魂）
在 `BottomTabLiquidSelection` 的 ZStack 里，药丸**主体下层**加一个半透明残影，跟在运动后方、随 stretch 拉伸淡出：
```swift
// 拖尾残影：飞行时在身后拉出一截，到位收回
Capsule()
    .fill(Color.white.opacity(0.22))        // 残影用现有玻璃色系的淡版，别引入新颜色
    .scaleEffect(
        x: 1 + progress * 0.75,             // 残影拉得比主体更长
        y: 1 - progress * 0.10,
        anchor: direction > 0 ? .leading : .trailing
    )
    .offset(x: -direction * progress * 18)  // 残影留在运动后方
    .opacity(Double(progress) * 0.6)        // 只在飞行中出现，静止时消失
    .blur(radius: progress * 2)             // 拖尾带轻微模糊，更像液体
```
> 残影放在主体药丸**之下/之后**绘制（ZStack 里靠前的位置），别盖住图标。

### 4. 时序与弹簧手感（select 方法）
当前两段 spring 时序基本可用，调整为更"Q弹"、相位更分明：
```swift
liquidDirection = newIndex >= oldIndex ? 1 : -1
// 飞行段：快速拉伸 + 位移
withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
    liquidStretch = 1
    selectedTab = tab
    onSelect?(tab)
}
// 回弹段：略低阻尼，制造到位过冲回弹（果冻感）
withAnimation(.spring(response: 0.62, dampingFraction: 0.52).delay(0.12)) {
    liquidStretch = 0
}
```

---

## 验收标准

1. iPhone 17 模拟器编译通过：
   ```bash
   cd /Users/may/Documents/AI装机
   xcodebuild -project May/May.xcodeproj -scheme May \
     -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
   ```
2. 在模拟器里**连续点不同 tab**，肉眼应能看到：
   - 药丸飞行时**沿水平方向被拉长**成扁长形（不是立起来）。
   - 身后**拖一截半透明残影**，到位后收回消失。
   - 到位时有轻微**挤压回弹**（过冲一下再稳定）。
   - 向左点和向右点，拉伸/拖尾方向都正确（跟着运动方向）。
3. **外观零变化**：颜色、玻璃质感、图标文字配色跟改之前完全一样，只有动起来时不同。
4. 录一段模拟器屏幕或连拍几张滑动中的截图给用户确认。

---

## 给 Codex 的一句话
> 按 `docs/liquid-tabbar-animation-instructions-2026-06-18.md` 只增强底部导航栏选中药丸的滑动动画（沿运动方向拉长+拖尾残影+到位回弹），不要改任何颜色和外观。改完用 iPhone 17 模拟器编译并连拍滑动截图。

---

## 备注（给用户和 Codex）
本方案是「方法 A」：在现有 `matchedGeometryEffect` 位移基础上叠加拉伸+拖尾，视觉接近视频八九成。若用户看后觉得"拖尾还不够像水银长条横跨两个 tab"，再升级到方法 B（放弃 matchedGeometryEffect，用 GeometryReader 算坐标 + keyframeAnimator 手动驱动 + Canvas 连续拖尾）。**方法 B 不在本次范围内，先做 A。**
