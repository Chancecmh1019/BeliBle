import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bible_models.dart';

class StorageService {
  // 單例模式
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  factory StorageService.withPrefs(SharedPreferences prefs) {
    _instance._prefs = prefs;
    return _instance;
  }
  StorageService._internal();
  
  // 檢查 _prefs 是否已初始化
  bool _prefsInitialized() {
    try {
      // 嘗試訪問 _prefs 的屬性，如果未初始化會拋出異常
      _prefs.toString();
      return true;
    } catch (e) {
      return false;
    }
  }

  // SharedPreferences 鍵
  // 書籤功能已移除
  // static const String _bookmarksKey = 'bookmarks';
  static const String _highlightsKey = 'highlights';
  static const String _readingHistoryKey = 'reading_history';
  static const String _lastReadKey = 'last_read';
  static const String _settingsKey = 'settings';
  // 筆記功能已移除
  // static const String _notesKey = 'notes'; // 新增筆記鍵

  // SharedPreferences 實例
  late SharedPreferences _prefs;
  
  // 數據存儲
  // 書籤功能已移除
  // List<Bookmark> _bookmarks = [];
  List<Highlight> _highlights = [];
  List<ReadingHistory> _readingHistory = [];
  ScriptureReference? _lastRead;
  Map<String, dynamic> _settings = {};
  // 筆記功能已移除
  // List<Note> _notes = []; // 新增筆記緩存

  // 初始化服務
  Future<void> initialize() async {
    try {
      // 如果 _prefs 未初始化，則獲取實例
      if (!_prefsInitialized()) {
        _prefs = await SharedPreferences.getInstance();
      }
      
      // 書籤功能已移除
      // await _loadBookmarks();
      await _loadHighlights();
      await _loadReadingHistory();
      await _loadLastRead();
      await _loadSettings();
      // 筆記功能已移除
      // await _loadNotes(); // 新增加載筆記
    } catch (e) {
      debugPrint('初始化存儲服務失敗: $e');
    }
  }
  
  // 主題模式相關方法
  Future<ThemeMode> loadThemeMode() async {
    await _loadSettings();
    final themeModeIndex = _settings['themeMode'] ?? 0;
    return ThemeMode.values[themeModeIndex];
  }
  
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    _settings['themeMode'] = themeMode.index;
    await _saveSettings();
  }
  
  // 字體大小相關方法
  Future<double> loadFontSize() async {
    await _loadSettings();
    return _settings['fontSize'] ?? 18.0;
  }
  
  Future<void> saveFontSize(double fontSize) async {
    _settings['fontSize'] = fontSize;
    await _saveSettings();
  }

  // 書籤相關方法已移除
  // List<Bookmark> getAllBookmarks() => _bookmarks;
  // 
  // Future<void> addBookmark(ScriptureReference reference) async {
  //   final bookmark = Bookmark(
  //     id: DateTime.now().millisecondsSinceEpoch.toString(),
  //     reference: reference,
  //     createdAt: DateTime.now(),
  //   );
  //   _bookmarks.add(bookmark);
  //   await _saveBookmarks();
  // }
  // 
  // Future<void> removeBookmark(String id) async {
  //   _bookmarks.removeWhere((bookmark) => bookmark.id == id);
  //   await _saveBookmarks();
  // }
  // 
  // Future<void> updateBookmark(String id) async {
  //   final index = _bookmarks.indexWhere((bookmark) => bookmark.id == id);
  //   if (index != -1) {
  //     final bookmark = _bookmarks[index];
  //     _bookmarks[index] = Bookmark(
  //       id: bookmark.id,
  //       reference: bookmark.reference,
  //       createdAt: bookmark.createdAt,
  //       updatedAt: DateTime.now(),
  //     );
  //     await _saveBookmarks();
  //   }
  // }

  // 筆記相關方法 - 已移除
  // List<Note> getAllNotes() => _notes;
  //
  // Future<Note?> getNoteById(String id) async {
  //   final index = _notes.indexWhere((note) => note.id == id);
  //   if (index != -1) {
  //     return _notes[index];
  //   }
  //   return null;
  // }
  //
  // Future<void> addNote(String title, String content, List<ScriptureReference> references) async {
  //   final note = Note(
  //     id: DateTime.now().millisecondsSinceEpoch.toString(),
  //     title: title,
  //     content: content,
  //     references: references,
  //     createdAt: DateTime.now(),
  //   );
  //
  //   _notes.add(note);
  //   await _saveNotes();
  // }
  //
  // Future<void> updateNote(String id, String title, String content, List<ScriptureReference> references) async {
  //   final index = _notes.indexWhere((note) => note.id == id);
  //   if (index != -1) {
  //     final note = _notes[index];
  //     _notes[index] = Note(
  //       id: note.id,
  //       title: title,
  //       content: content,
  //       references: references,
  //       createdAt: note.createdAt,
  //       updatedAt: DateTime.now(),
  //     );
  //     await _saveNotes();
  //   }
  // }
  //
  // Future<void> removeNote(String id) async {
  //   _notes.removeWhere((note) => note.id == id);
  //   await _saveNotes();
  // }

  // 高亮相關方法
  List<Highlight> getAllHighlights() => _highlights;

  Future<void> addHighlight(ScriptureReference reference, Color color) async {
    final highlight = Highlight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      reference: reference,
      color: color,
      createdAt: DateTime.now(),
    );

    _highlights.add(highlight);
    await _saveHighlights();
  }

  Future<void> removeHighlight(String id) async {
    _highlights.removeWhere((highlight) => highlight.id == id);
    await _saveHighlights();
  }

  // 閱讀歷史相關方法
  List<ReadingHistory> getReadingHistory() => _readingHistory;

  Future<void> addReadingHistory(ScriptureReference reference) async {
    final history = ReadingHistory(
      reference: reference,
      timestamp: DateTime.now(),
    );

    // 限制歷史記錄數量
    if (_readingHistory.length >= 100) {
      _readingHistory.removeLast();
    }

    _readingHistory.insert(0, history);
    await _saveReadingHistory();

    // 更新最後閱讀位置
    await setLastRead(reference);
  }

  Future<void> clearReadingHistory() async {
    _readingHistory.clear();
    await _saveReadingHistory();
  }

  // 最後閱讀位置相關方法
  ScriptureReference? getLastRead() => _lastRead;

  Future<void> setLastRead(ScriptureReference reference) async {
    _lastRead = reference;
    await _saveLastRead();
  }

  // 設置相關方法
  Map<String, dynamic> getAllSettings() => _settings;

  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settings[key] as T? ?? defaultValue;
  }

  Future<void> setSetting<T>(String key, T value) async {
    _settings[key] = value;
    await _saveSettings();
  }

  // 私有方法：加載書籤 - 已移除
  // Future<void> _loadBookmarks() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final String? bookmarksJson = prefs.getString(_bookmarksKey);
  //   
  //   if (bookmarksJson != null) {
  //     try {
  //       final List<dynamic> bookmarksList = jsonDecode(bookmarksJson);
  //       _bookmarks = bookmarksList.map((item) {
  //         return Bookmark(
  //           id: item['id'],
  //           reference: ScriptureReference(
  //             bookId: item['reference']['bookId'],
  //             chapter: item['reference']['chapter'],
  //             verse: item['reference']['verse'],
  //             endVerse: item['reference']['endVerse'],
  //           ),
  //           createdAt: DateTime.parse(item['createdAt']),
  //           updatedAt: item['updatedAt'] != null
  //               ? DateTime.parse(item['updatedAt'])
  //               : null,
  //         );
  //       }).toList();
  //     } catch (e) {
  //       debugPrint('解析書籤失敗: $e');
  //       _bookmarks = [];
  //     }
  //   }
  // }
  // 
  // // 私有方法：保存書籤
  // Future<void> _saveBookmarks() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final List<Map<String, dynamic>> bookmarksList = _bookmarks.map((bookmark) {
  //     return {
  //       'id': bookmark.id,
  //       'reference': {
  //         'bookId': bookmark.reference.bookId,
  //         'chapter': bookmark.reference.chapter,
  //         'verse': bookmark.reference.verse,
  //         'endVerse': bookmark.reference.endVerse,
  //       },
  //       'createdAt': bookmark.createdAt.toIso8601String(),
  //       'updatedAt': bookmark.updatedAt?.toIso8601String(),
  //     };
  //   }).toList();

  //   await prefs.setString(_bookmarksKey, jsonEncode(bookmarksList));
  // }

  // 私有方法：加載筆記 - 已移除
  // Future<void> _loadNotes() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final String? notesJson = prefs.getString(_notesKey);
  //
  //   if (notesJson != null) {
  //     try {
  //       final List<dynamic> notesList = jsonDecode(notesJson);
  //       _notes = notesList.map((item) {
  //         // 解析經文引用列表
  //         List<ScriptureReference> references = [];
  //         if (item['references'] != null) {
  //           references = (item['references'] as List).map((ref) {
  //             return ScriptureReference(
  //               bookId: ref['bookId'],
  //               chapter: ref['chapter'],
  //               verse: ref['verse'],
  //               endVerse: ref['endVerse'],
  //             );
  //           }).toList();
  //         }
  //         
  //         return Note(
  //           id: item['id'],
  //           title: item['title'],
  //           content: item['content'],
  //           references: references,
  //           createdAt: DateTime.parse(item['createdAt']),
  //           updatedAt: item['updatedAt'] != null
  //               ? DateTime.parse(item['updatedAt'])
  //               : null,
  //         );
  //       }).toList();
  //     } catch (e) {
  //       debugPrint('解析筆記失敗: $e');
  //       _notes = [];
  //     }
  //   }
  // }
  //
  // // 私有方法：保存筆記
  // Future<void> _saveNotes() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final List<Map<String, dynamic>> notesList = _notes.map((note) {
  //     // 將經文引用列表轉換為可序列化的格式
  //     final List<Map<String, dynamic>> referencesList = note.references.map((ref) {
  //       return {
  //         'bookId': ref.bookId,
  //         'chapter': ref.chapter,
  //         'verse': ref.verse,
  //         'endVerse': ref.endVerse,
  //       };
  //     }).toList();
  //     
  //     return {
  //       'id': note.id,
  //       'title': note.title,
  //       'content': note.content,
  //       'references': referencesList,
  //       'createdAt': note.createdAt.toIso8601String(),
  //       'updatedAt': note.updatedAt?.toIso8601String(),
  //     };
  //   }).toList();
  //
  //   await prefs.setString(_notesKey, jsonEncode(notesList));
  // }

  // 私有方法：加載高亮
  Future<void> _loadHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final String? highlightsJson = prefs.getString(_highlightsKey);

    if (highlightsJson != null) {
      try {
        final List<dynamic> highlightsList = jsonDecode(highlightsJson);
        _highlights = highlightsList.map((item) {
          // 確保顏色值是整數
          int colorValue = item['color'];
          // 如果顏色值沒有包含 alpha 通道，添加完全不透明的 alpha 通道
          if ((colorValue & 0xFF000000) == 0) {
            colorValue = colorValue | 0xFF000000;
          }
          
          return Highlight(
            id: item['id'],
            reference: ScriptureReference(
              bookId: item['reference']['bookId'],
              chapter: item['reference']['chapter'],
              verse: item['reference']['verse'],
              endVerse: item['reference']['endVerse'],
            ),
            color: Color(colorValue),
            createdAt: DateTime.parse(item['createdAt']),
          );
        }).toList();
      } catch (e) {
        debugPrint('解析高亮失敗: $e');
        _highlights = [];
      }
    }
  }

  // 私有方法：保存高亮
  Future<void> _saveHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> highlightsList = _highlights.map((highlight) {
      return {
        'id': highlight.id,
        'reference': {
          'bookId': highlight.reference.bookId,
          'chapter': highlight.reference.chapter,
          'verse': highlight.reference.verse,
          'endVerse': highlight.reference.endVerse,
        },
        'color': highlight.color.value,
        'createdAt': highlight.createdAt.toIso8601String(),
      };
    }).toList();

    await prefs.setString(_highlightsKey, jsonEncode(highlightsList));
  }

  // 私有方法：加載閱讀歷史
  Future<void> _loadReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_readingHistoryKey);

    if (historyJson != null) {
      try {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _readingHistory = historyList.map((item) {
          return ReadingHistory(
            reference: ScriptureReference(
              bookId: item['reference']['bookId'],
              chapter: item['reference']['chapter'],
              verse: item['reference']['verse'],
              endVerse: item['reference']['endVerse'],
            ),
            timestamp: DateTime.parse(item['timestamp']),
          );
        }).toList();
      } catch (e) {
        debugPrint('解析閱讀歷史失敗: $e');
        _readingHistory = [];
      }
    }
  }

  // 私有方法：保存閱讀歷史
  Future<void> _saveReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> historyList = _readingHistory.map((history) {
      return {
        'reference': {
          'bookId': history.reference.bookId,
          'chapter': history.reference.chapter,
          'verse': history.reference.verse,
          'endVerse': history.reference.endVerse,
        },
        'timestamp': history.timestamp.toIso8601String(),
      };
    }).toList();

    await prefs.setString(_readingHistoryKey, jsonEncode(historyList));
  }

  // 私有方法：加載最後閱讀位置
  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastReadJson = prefs.getString(_lastReadKey);

    if (lastReadJson != null) {
      try {
        final Map<String, dynamic> lastRead = jsonDecode(lastReadJson);
        _lastRead = ScriptureReference(
          bookId: lastRead['bookId'],
          chapter: lastRead['chapter'],
          verse: lastRead['verse'],
          endVerse: lastRead['endVerse'],
        );
      } catch (e) {
        debugPrint('解析最後閱讀位置失敗: $e');
        _lastRead = null;
      }
    }
  }

  // 私有方法：保存最後閱讀位置
  Future<void> _saveLastRead() async {
    if (_lastRead == null) return;

    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> lastRead = {
      'bookId': _lastRead!.bookId,
      'chapter': _lastRead!.chapter,
      'verse': _lastRead!.verse,
      'endVerse': _lastRead!.endVerse,
    };

    await prefs.setString(_lastReadKey, jsonEncode(lastRead));
  }

  // 私有方法：加載設置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      try {
        _settings = jsonDecode(settingsJson);
      } catch (e) {
        debugPrint('解析設置失敗: $e');
        _settings = {};
      }
    }
  }

  // 私有方法：保存設置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(_settings));
  }
}