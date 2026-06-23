# M.2 Heatsink Width and DIMM Clearance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Narrow the M.2 heatsink and move the complete M.2 installation area left so it no longer intersects the DIMM latch geometry.

**Architecture:** Keep the adjustment inside the Blender motherboard generator. Preserve all exported node names so the existing SceneKit lookup, dynamic install anchor, highlight, and heatsink animation continue to follow the regenerated model without Swift coordinate changes.

**Tech Stack:** Blender Python, USD export, SceneKit, Xcode iOS Simulator

---

### Task 1: Constrain the motherboard geometry

**Files:**
- Modify: `outputs/blender-motherboard/create_motherboard_mobile.py:506-548`

- [ ] **Step 1: Add a failing source-geometry assertion**

Run a Python assertion that expects the heatsink Y span to be `1.16`, every active M.2 X coordinate to be shifted by `-0.70`, and the M.2 back wall maximum X to remain left of the first DIMM latch minimum X.

- [ ] **Step 2: Verify the assertion fails**

Run: `python3 /tmp/check_m2_clearance.py`

Expected: FAIL because the heatsink Y span is currently `1.28` and the connector remains at its original X position.

- [ ] **Step 3: Apply the minimum geometry change**

Change the active heatsink outer Y limits from `-0.99...0.29` to `-0.93...0.23`, adjust its inset face proportionally, and subtract `0.70` from the X positions of the M.2 recess, guide, connector parts, contacts, key, pegs, heatsink, and inset face. Keep dimensions, materials, Z positions, and node names unchanged.

- [ ] **Step 4: Verify geometry and syntax**

Run: `python3 -m py_compile outputs/blender-motherboard/create_motherboard_mobile.py && python3 /tmp/check_m2_clearance.py`

Expected: PASS with positive DIMM clearance and heatsink width greater than SSD width.

### Task 2: Export and synchronize the iOS model

**Files:**
- Modify generated asset: `May/May/Models3D/modern-atx-motherboard-mobile.usdc`

- [ ] **Step 1: Export through Blender MCP**

Execute `outputs/blender-motherboard/create_motherboard_mobile.py` through the Blender MCP socket at `127.0.0.1:9876`.

Expected: Blender reports the updated `.blend`, `.glb`, and `.usdc` output paths.

- [ ] **Step 2: Run focused rules and the iOS build**

Run: `swiftc May/May/Models/GuideFlow.swift May/MayTests/GuideFlowRulesTests.swift -o /tmp/GuideFlowRulesTests && /tmp/GuideFlowRulesTests`

Run: `xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,id=E98EA16E-2ADD-42CA-B08D-A4B70C14C2ED' -configuration Debug build`

Expected: rules print `GuideFlowRulesTests passed`; Xcode prints `BUILD SUCCEEDED`.

- [ ] **Step 3: Install and launch**

Install the Debug app with `xcrun simctl install` and launch bundle `chasinghost.May` on simulator `E98EA16E-2ADD-42CA-B08D-A4B70C14C2ED`.

Expected: `simctl launch` returns a process identifier.
