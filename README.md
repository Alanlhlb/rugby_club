# Rugby Club Management App 17 🏉

一個專為橄欖球隊設計的全功能管理應用程式，旨在簡化球隊管理、球員追蹤和比賽記錄。

## 🌟 核心功能

### 1. 球隊與球季管理
- **多身份支援**：管理員、教練、球員不同權限視角
- **雙模式運作**：
  - **Demo 模式**：本地體驗所有功能，數據自動快取
  - **真實模式**：連接 Firebase 雲端，實時同步數據
- **球季切換**：輕鬆管理不同球季的球員名單與數據

### 2. 球員管理
- **FIFA 風格球員卡**：獨特的視覺化球員展示
- **詳細數據追蹤**：記錄達陣、轉換、罰球、紅黃牌等
- **位置與標籤**：自定義球員位置與特殊技能（Kicker、Lineout 跳躍手等）

### 3. 比賽引擎 (Match Engine) ⚡
- **實時比賽記錄**：計時器、比分、紅黃牌、換人
- **智能陣容填充**：根據位置自動建議先發名單
- **Lineout 檢查器**：自動驗證陣容是否符合規則（如前排專項位置）
- **歷史回顧**：查看過往比賽結果與詳細數據

### 4. 活動與出席
- **行事曆整合**：管理訓練、比賽、聚會
- **出席追蹤**：球員報名狀態即時更新
- **天氣預報**：整合香港天文台 API，顯示活動當日天氣

## 🛠️ 技術棧

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Auth, Storage)
- **State Management**: Provider
- **Local Storage**: SharedPreferences (Demo cache)
- **External APIs**: Hong Kong Observatory Open Data API

## 🚀 安裝與運行

1. **環境需求**
   - Flutter SDK (>=3.0.0)
   - Dart SDK

2. **設定 Firebase**
   - 本專案依賴 `firebase_options.dart` 配置
   - 需確保 `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) 已配置

3. **安裝依賴**
   ```bash
   flutter pub get
   ```

4. **運行 App**
   ```bash
   flutter run
   ```

 **運行 **
git clone https://github.com/Alanlhlb/rugby_club.git
cd rugby_club
flutter pub get
flutter run
