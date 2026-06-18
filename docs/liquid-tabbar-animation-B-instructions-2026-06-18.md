# 底部导航栏「液态滑动动画」方法 B 指令（给 Codex 执行）

> 背景：方法 A 失败。原因已确诊——药丸用 `if selectedTab == tab` 条件创建/销毁 + `matchedGeometryEffect` 移动，飞行过程不可见，视觉上像瞬移，叠加的拉伸/拖尾没有舞台。
> 方法 B 的核心：**把药丸改成一个常驻的、用真实坐标平滑移动的独立图层**，飞行过程真实可见，拉伸和拖尾才有效。
> **仍然只改动画与结构，不改外观**：药丸的填充/描边/颜色沿用现有 `LiquidGlassSelection` 外观，图标文字配色不变。

---

## 涉及文件
- `May/May/Components/AppComponents.swift` → `BottomTabBar` 及其私有子 view。

## 关键布局事实（简化实现的前提）
- tab 栏是 `HStack` 里 4 个等宽 tab（每个 `.frame(maxWidth: .infinity)`），均分整条可用宽度。
- 因此第 `i` 个 tab 的中心 x = `可用宽度 * (CGFloat(i) + 0.5) / 4`。
- `AppTab.bottomNavigationTabs` 顺序固定为 `[.home, .community, .builds, .profile]`（4 项）。

---

## 总体改造思路（务必照这个结构）

把当前"每个 tabButton 内部放一个条件药丸"的写法，改成：

```
ZStack(alignment: .leading) {
    // ① 常驻的液态药丸图层（绝对定位，用 offset 移动到选中 tab 的中心）
    LiquidPill(...)
        .frame(width: pillWidth)
        .offset(x: pillCenterX(for: selectedIndex) - pillWidth/2)

    // ② tabButton 们（HStack），不再各自包含药丸，只剩图标+文字
    HStack { ForEach(tabs) { tabButton($0) } }
}
```

- 药丸**只有一个**，永远存在，靠 `offset` 在 4 个等分中心间移动。
- 删除 tabButton 里的 `if selectedTab == tab { BottomTabLiquidSelection... }` 和 `matchedGeometryEffect`。
- 药丸宽度 `pillWidth` ≈ 单个 tab 宽度（用 GeometryReader 读整条宽度 ÷ 4，留点内边距）。

---

## 具体实现要点

### 1. 用 GeometryReader 拿整条宽度，算每个 tab 中心
```swift
GeometryReader { geo in
    let slotWidth = geo.size.width / CGFloat(tabs.count)
    let pillWidth = slotWidth - 8   // 比格子略窄，留缝
    func centerX(_ i: Int) -> CGFloat { slotWidth * (CGFloat(i) + 0.5) }
    ...
}
```
> 注意 `BottomTabBar.body` 现在有 `.padding(.horizontal, 8)`，把 GeometryReader 放在 padding **内侧**，让 `geo.size.width` 是实际放 tab 的宽度，否则中心会偏。

### 2. 药丸位置用 spring 动画驱动（这是"飞行可见"的关键）
```swift
@State private var selectedIndex: Int = 0   // 当前选中下标

// 药丸图层
LiquidGlassSelection(stretch: 0, direction: liquidDirection, cornerRadius: 28)
    .frame(width: pillWidth, height: 54)
    .scaleEffect(x: horizontalScale, y: verticalScale, anchor: stretchAnchor)
    .offset(x: centerX(selectedIndex) - pillWidth/2)
    .animation(.spring(response: 0.5, dampingFraction: 0.62), value: selectedIndex)
```
> `selectedIndex` 改变时，`.offset` 在 spring 驱动下**连续移动**——这就是肉眼可见的飞行过程，方法 A 缺的就是这个。

### 3. 飞行中拉伸（沿运动方向拉长）+ 拖尾残影
保留方法 A 写好的形变思路，但现在它有真实飞行过程可附着：
- `liquidStretch` 0→1→0：飞行中拉到 1，到位回 0。
- 飞行拉伸：`horizontalScale = 1 + progress * 0.45`，`verticalScale = 1 - progress * 0.15`，`anchor = direction > 0 ? .leading : .trailing`。
- 拖尾残影：在药丸图层**下方**再放一个 `Capsule().fill(白0.22)`，同样 offset 到 selectedIndex 位置，但额外 `offset(x: -direction * progress * 24)` 留在后方、`opacity(progress*0.6)`、`blur(progress*2.5)`、拉伸比主体更长(`1 + progress*0.8`)。

### 4. 时序（select 方法）
```swift
private func select(_ tab: AppTab) {
    guard tab != selectedTab else { return }
    let oldIndex = selectedIndex
    let newIndex = AppTab.bottomNavigationTabs.firstIndex(of: tab) ?? oldIndex
    liquidDirection = newIndex >= oldIndex ? 1 : -1

    withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
        selectedIndex = newIndex     // 驱动药丸飞行
        selectedTab = tab
        onSelect?(tab)
    }
    // 拉伸：飞行段冲到 1
    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { liquidStretch = 1 }
    // 回弹段：到位后拉伸收回，略低阻尼制造果冻过冲
    withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.16)) { liquidStretch = 0 }
}
```
> 初始化时 `selectedIndex` 要同步为 `selectedTab` 的下标（onAppear 或 init 里设一次），否则首屏药丸位置不对。

### 5. 图标/文字颜色
保持现状逻辑：`selectedTab == tab ? AppTheme.primaryText : AppTheme.secondaryText`。不改配色。
> 注意：药丸现在是独立图层、可能盖在图标下层或上层。确保 **tab 的图标文字在药丸之上**（HStack 放在 ZStack 后绘制），否则图标会被药丸遮住。

---

## 验收标准

1. iPhone 17 模拟器编译通过：
   ```bash
   cd /Users/may/Documents/AI装机
   xcodebuild -project May/May.xcodeproj -scheme May \
     -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
   ```
2. 连续点不同 tab，**肉眼必须能清楚看到药丸"飞"过去的过程**（不再是瞬移），且：
   - 飞行中药丸沿水平方向被拉长。
   - 身后有半透明拖尾残影，到位收回。
   - 到位有轻微果冻回弹。
   - 跨多个 tab（如从「我的」点回「首页」）飞得更远、过程更明显。
3. 首屏药丸停在当前选中 tab 上，位置准确（4 等分居中）。
4. 外观（颜色/玻璃质感/图标文字色）与改之前一致。
5. **连拍 4-6 张飞行中途的截图**（或录屏）给用户，必须能看出中间的拉伸飞行帧。

---

## 给 Codex 的一句话
> 方法 A 失败（药丸条件创建导致瞬移）。请按 `docs/liquid-tabbar-animation-B-instructions-2026-06-18.md` 把选中药丸改成常驻独立图层、用 offset+spring 在 4 等分位置间真实飞行，叠加拉伸和拖尾。不改任何颜色外观。改完用 iPhone 17 模拟器连拍飞行中途截图。
