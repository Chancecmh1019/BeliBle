# BeliBle 開發者指南

本指南旨在幫助開發者理解 BeliBle 的代碼結構，並提供設置開發環境和貢獻代碼的說明。

## 目錄

- [開發環境設置](#開發環境設置)
- [項目結構](#項目結構)
- [核心組件](#核心組件)
- [開發工作流程](#開發工作流程)
- [測試](#測試)
- [構建和發布](#構建和發布)
- [代碼風格指南](#代碼風格指南)

## 開發環境設置

### 前提條件

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (建議使用最新穩定版)
- [Android Studio](https://developer.android.com/studio) 或 [Visual Studio Code](https://code.visualstudio.com/) 與 Flutter 插件
- [Git](https://git-scm.com/)

### 克隆倉庫

```bash
git clone https://github.com/yourusername/belible.git
cd belible
```

### 安裝依賴

```bash
flutter pub get
```

### 運行應用

```bash
flutter run
```

## 項目結構

```
belible/
├── android/            # Android 平台特定代碼
├── assets/             # 應用資源（聖經數據、圖像等）
├── ios/               # iOS 平台特定代碼
├── lib/               # Dart 源代碼
│   ├── main.dart      # 應用入口點
│   ├── models/        # 數據模型
│   ├── screens/       # UI 屏幕
│   ├── services/      # 業務邏輯和數據處理
│   ├── theme/         # 主題和樣式
│   └── widgets/       # 可重用 UI 組件
├── test/              # 測試代碼
└── pubspec.yaml       # 項目配置和依賴
```

## 核心組件

### 數據模型

- `lib/models/bible_models.dart`: 定義了聖經數據的結構，包括書卷、章節、經文等

### 服務

- `lib/services/bible_service.dart`: 處理聖經數據的加載和查詢
- `lib/services/storage_service.dart`: 管理本地存儲，包括設置、高亮和閱讀歷史

### 屏幕

- `lib/screens/`: 包含應用的主要屏幕，如閱讀視圖、搜索結果等

### 小部件

- `lib/widgets/verse_widget.dart`: 負責渲染單個經文，包括高亮處理

## 開發工作流程

### 分支策略

- `main`: 穩定版本分支
- `develop`: 開發分支，所有功能分支從這裡分出
- `feature/*`: 新功能分支
- `bugfix/*`: 錯誤修復分支

### 貢獻流程

1. 從最新的 `develop` 分支創建功能分支
2. 實現您的更改
3. 確保代碼通過所有測試
4. 提交拉取請求到 `develop` 分支

## 測試

### 運行測試

```bash
flutter test
```

### 編寫測試

- 單元測試放在 `test/` 目錄下
- 遵循 Flutter 的測試命名約定
- 確保為所有新功能和錯誤修復添加測試

## 構建和發布

### 構建 APK

```bash
flutter build apk --release
```

生成的 APK 將位於 `build/app/outputs/flutter-apk/app-release.apk`

### 發布流程

1. 更新 `pubspec.yaml` 中的版本號
2. 更新 `CHANGELOG.md`
3. 構建發布版本
4. 創建 GitHub 發布版本並上傳構建文件

## 代碼風格指南

- 遵循 [Dart 風格指南](https://dart.dev/guides/language/effective-dart/style)
- 使用有意義的變量和函數名稱
- 為所有公共 API 添加文檔注釋
- 保持代碼簡潔，遵循單一職責原則
- 使用 `flutter format .` 格式化代碼

## 資源

- [Flutter 文檔](https://flutter.dev/docs)
- [Dart 文檔](https://dart.dev/guides)
- [Flutter 社區](https://flutter.dev/community)