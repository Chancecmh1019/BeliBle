# BeliBle 聖經應用程式

<p align="center">
  <img src="assets/icon/app_icon.png" alt="BeliBle Logo" width="200"/>
</p>

## 簡介

BeliBle 是一款現代化的聖經應用程式，採用 Flutter 框架開發，提供人性化且易於操作的經節選擇功能，並採用最新的 Material 3 設計。應用程式支援新舊約聖經閱讀，提供直觀的經文導航、搜尋、高亮和個人化設定。

## 功能特色

- **直觀的經節選擇**：輕鬆瀏覽新舊約、經卷、篇章
- **現代化 UI**：採用 Material 3 設計，提供美觀且一致的使用者體驗
- **搜尋功能**：快速搜尋聖經中的經文
- **高亮功能**：標記重要經文並以不同顏色區分
- **閱讀歷史**：自動記錄閱讀歷史，方便繼續閱讀
- **個人化設定**：調整字體大小、選擇淺色/深色主題

## 截圖

<p align="center">
  <img src="screenshots/home_screen.png" alt="首頁" width="200"/>
  <img src="screenshots/reading_screen.png" alt="閱讀頁面" width="200"/>
  <img src="screenshots/search_screen.png" alt="搜尋頁面" width="200"/>
  <img src="screenshots/settings_screen.png" alt="設定頁面" width="200"/>
</p>

## 安裝與執行

### 系統需求

- Flutter 3.0 或更高版本
- Dart 2.17 或更高版本

### 安裝步驟

1. 複製專案到本地：
   ```
   git clone https://github.com/Chancecmh1019/BeliBle.git
   ```

2. 進入專案目錄：
   ```
   cd belible
   ```

3. 安裝依賴：
   ```
   flutter pub get
   ```

4. 執行應用程式：
   ```
   flutter run
   ```

### 下載 APK

您可以在 [Releases](https://github.com/Chancecmh1019/BeliBle/releases) 頁面下載最新版本的 APK。

## 專案結構

```
lib/
├── main.dart                 # 應用程式入口點
├── models/                   # 數據模型
│   └── bible_models.dart     # 聖經相關數據模型
├── screens/                  # 頁面
│   ├── book_select_screen.dart    # 書卷選擇頁面
│   ├── bookmarks_screen.dart      # 書籤頁面
│   ├── chapter_select_screen.dart # 章節選擇頁面
│   ├── home_screen.dart           # 主頁面
│   ├── reading_screen.dart        # 閱讀頁面
│   ├── search_screen.dart         # 搜尋頁面
│   └── settings_screen.dart       # 設定頁面
├── services/                 # 服務
│   ├── bible_service.dart    # 聖經數據服務
│   └── storage_service.dart  # 本地儲存服務
├── theme/                    # 主題
│   └── app_theme.dart        # 應用程式主題設定
└── widgets/                  # 元件
    └── verse_widget.dart     # 經文顯示元件
```

## 聖經數據

應用程式使用純文本格式的聖經數據，位於 `BIBLE/` 目錄下，每個書卷對應一個文本檔案。

## 技術細節

- **狀態管理**：使用 ValueNotifier 和 Provider 進行狀態管理
- **本地儲存**：使用 SharedPreferences 儲存用戶設定和閱讀歷史
- **UI 框架**：採用 Material 3 設計語言
- **資源管理**：使用 Flutter 資源管理系統載入聖經文本

## 貢獻

歡迎提交 Pull Request 或開 Issue 來改進這個專案。詳細資訊請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 更新日誌

查看 [CHANGELOG.md](CHANGELOG.md) 了解各版本的更新內容。

## 授權

本專案採用 MIT 授權。詳細資訊請參閱 [LICENSE](LICENSE) 文件。
