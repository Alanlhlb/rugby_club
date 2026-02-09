# AI 實作差異報告

## 問題根源
AI 建立了新檔案但**未整合到現有程式碼**中。

---

## 已修復清單 ✅

### Widgets (3 個)

| 檔案 | 整合位置 | 修復狀態 |
|------|-----------|----------|
| `demo_mode_banner.dart` | `home_screen.dart` AppBar | ✅ 已修復 |
| `lineout_checker.dart` | `match_engine_screen.dart` 選單 | ✅ 已修復 |
| `season_selector.dart` | `settings_screen.dart` 球季設定區 | ✅ 已修復 |

### Services (5 個)

| 檔案 | 整合位置 | 修復狀態 |
|------|-----------|----------|
| `auto_fill_service.dart` | `match_engine_screen.dart` 有內聯版 `_autoFillLineup()`，service 待整合 | ⚠️ 未使用 service |
| `share_service.dart` | 未整合（TODO stub） | ⚠️ 未使用 |
| `notification_service.dart` | `settings_screen.dart` | ⏳ 待整合 |
| `offline_cache_service.dart` | Providers | ⏳ 待整合 |
| `pdf_export_service.dart` | 被 share_service 引用（share_service 本身未使用） | ⚠️ 間接未使用 |

> **注意**: 原報告引用的 `lineup_screen.dart` 不存在。相關功能在 `match_engine_screen.dart` 中。

---

## 新增功能入口

### match_engine_screen.dart 選單
- 🧠 **智能填充** - 內聯 `_autoFillLineup()` 已實作
- ✅ **檢查陣容** - 透過 `lineout_checker.dart`
- 📤 **分享陣容** - 待整合 `share_service.dart`

### home_screen.dart
- 👤 **訪客模式標籤** - AppBar 顯示 DemoModeChip

### settings_screen.dart
- 📅 **賽季選擇器** - 快速切換賽季

---

## 代碼審查修復記錄 (2026-02-08)

| 問題 | 修復 |
|------|------|
| `pdf_export_service.dart` Hooker 翻譯不當 (`妓`) | 改為 `鈎球員` |
| `event_detail_screen.dart` 刪除活動只 pop 沒移除 | 返回 `'deleted'` 結果，呼叫方處理移除 |
| `event_detail_screen.dart` `_sortAsc` 永遠 `true` | 改為 mutable + 加排序方向切換按鈕 |
| `AttendanceStatus` enum 定義衝突 | 統一到 `attendance.dart`，screen 改用 import |
| `AppColors` 6 個未使用 alias | 刪除 `background`, `surfaceDark`, `going`, `maybe`, `trainingGreen`, `teamBuildingYellow` |
| Demo events 在 home/events 各自生成不同步 | 抽成共用 `DemoData` 類 (`core/constants/demo_data.dart`) |

---

## 預防措施

建議 AI 在建立新檔案時：
1. **同時修改使用該檔案的 screen**
2. **加入 import 語句**
3. **建立 UI 入口點**（按鈕/選單）
4. **驗證功能可被觸發**
