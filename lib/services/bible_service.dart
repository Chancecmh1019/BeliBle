import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../models/bible_models.dart';

class BibleService {
  // static const String _bibleDirectoryPath = 'BIBLE'; // 未使用的字段
  static String? _validBiblePath; // 存儲找到的有效聖經目錄路徑
  
  // 單例模式
  static final BibleService _instance = BibleService._internal();
  factory BibleService() => _instance;
  BibleService._internal();

  // 私有變量
  final List<Book> _books = [];
  bool _isInitialized = false; // 標記服務是否已初始化
  // String? _validBiblePath; // 已在靜態變量中聲明

  // 公共方法：初始化
  Future<void> initialize() async {
    try {
      debugPrint('開始初始化聖經服務...');
      await _loadBooks();
      _isInitialized = true; // 標記初始化完成
      debugPrint('聖經服務初始化完成！');
    } catch (e) {
      debugPrint('初始化聖經服務失敗: $e');
      rethrow;
    }
  }

  // 獲取所有書卷
  List<Book> getAllBooks() {
    if (!_isInitialized) {
      throw Exception('聖經服務尚未初始化');
    }
    return _books;
  }
  
  // 獲取所有書卷 (別名，用於兼容)
  Future<List<Book>> getBooks() async {
    return getAllBooks();
  }

  // 獲取舊約書卷
  List<Book> getOldTestamentBooks() {
    return getAllBooks().where((book) => book.isOldTestament).toList();
  }

  // 獲取新約書卷
  List<Book> getNewTestamentBooks() {
    return getAllBooks().where((book) => !book.isOldTestament).toList();
  }

  // 根據ID獲取書卷
  Book? getBookById(String id) {
    try {
      return getAllBooks().firstWhere((book) => book.id == id);
    } catch (e) {
      return null;
    }
  }

  // 根據名稱獲取書卷
  Book? getBookByName(String name) {
    try {
      return getAllBooks().firstWhere(
        (book) => book.name.toLowerCase() == name.toLowerCase() || 
                  book.localName.toLowerCase() == name.toLowerCase() ||
                  book.shortName.toLowerCase() == name.toLowerCase()
      );
    } catch (e) {
      return null;
    }
  }

  // 獲取特定書卷的章節
  Future<Chapter?> getChapter(String bookId, int chapterNumber) async {
    Book? book = getBookById(bookId);
    if (book == null) return null;

    // 如果章節已經加載，直接返回
    if (book.chapters.containsKey(chapterNumber)) {
      return book.chapters[chapterNumber];
    } else {
      // 章節尚未加載，嘗試加載
      return await _loadChapter(book, chapterNumber);
    }
  }
  
  // 獲取特定書卷的所有章節
  Future<List<Chapter>> getChapters(String bookId) async {
    Book? book = getBookById(bookId);
    if (book == null) return [];
    
    List<Chapter> chapters = [];
    int chapterCount = getBookChapterCount(bookId);
    
    for (int i = 1; i <= chapterCount; i++) {
      Chapter? chapter = await getChapter(bookId, i);
      if (chapter != null) {
        chapters.add(chapter);
      }
    }
    
    return chapters;
  }

  // 獲取特定經文
  Future<Verse?> getVerse(String bookId, int chapterNumber, int verseNumber) async {
    Chapter? chapter = await getChapter(bookId, chapterNumber);
    if (chapter == null) return null;

    try {
      return chapter.verses.firstWhere((verse) => verse.number == verseNumber);
    } catch (e) {
      return null;
    }
  }

  // 獲取一段經文
  Future<List<Verse>> getVerseRange(String bookId, int chapterNumber, int startVerse, int endVerse) async {
    Chapter? chapter = await getChapter(bookId, chapterNumber);
    if (chapter == null) return [];

    return chapter.verses.where(
      (verse) => verse.number >= startVerse && verse.number <= endVerse
    ).toList();
  }

  // 根據引用獲取經文
  Future<List<Verse>> getVersesByReference(ScriptureReference reference) async {
    if (reference.verse != null && reference.endVerse != null) {
      return await getVerseRange(
        reference.bookId, 
        reference.chapter, 
        reference.verse!, 
        reference.endVerse!
      );
    } else if (reference.verse != null) {
      Verse? verse = await getVerse(
        reference.bookId, 
        reference.chapter, 
        reference.verse!
      );
      return verse != null ? [verse] : [];
    } else {
      Chapter? chapter = await getChapter(reference.bookId, reference.chapter);
      return chapter?.verses ?? [];
    }
  }

  // 搜索經文 - 性能優化版本
  Future<List<SearchResult>> searchScripture(String query, {String? testamentFilter, String? bookIdFilter, bool exactMatch = false, int maxResults = 100}) async {
    if (!_isInitialized) {
      throw Exception('聖經服務尚未初始化');
    }

    List<SearchResult> results = [];
    String normalizedQuery = query.toLowerCase().trim();
    
    // 如果查詢為空，直接返回空結果
    if (normalizedQuery.isEmpty) {
      return results;
    }
    
    // 將查詢分解為單詞（用於分詞搜尋）
    List<String> queryWords = normalizedQuery.split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    // 過濾書卷
    List<Book> filteredBooks = _books;
    
    // 按約過濾
    if (testamentFilter != null) {
      bool isOldTestament = testamentFilter.toLowerCase() == 'old';
      filteredBooks = filteredBooks.where((book) => book.isOldTestament == isOldTestament).toList();
    }
    
    // 按書卷ID過濾
    if (bookIdFilter != null) {
      filteredBooks = filteredBooks.where((book) => book.id == bookIdFilter).toList();
    }

    // 使用序列處理而非並行處理，避免創建過多的 Future
    for (Book book in filteredBooks) {
      // 檢查是否已達到最大結果數
      if (results.length >= maxResults) break;
      
      // 在單本書卷中搜索
      List<SearchResult> bookResults = await _searchInBook(
        book, 
        normalizedQuery, 
        queryWords, 
        exactMatch, 
        maxResults - results.length
      );
      
      results.addAll(bookResults);
    }

    return results;
  }
  
  // 在單本書卷中搜索 - 優化版本
  Future<List<SearchResult>> _searchInBook(Book book, String normalizedQuery, List<String> queryWords, bool exactMatch, int maxResults) async {
    List<SearchResult> results = [];
    
    // 使用序列處理而非並行處理
    for (int i = 1; i <= _getBookChapterCount(book.id); i++) {
      // 檢查是否已達到最大結果數
      if (results.length >= maxResults) break;
      
      // 在單個章節中搜索
      List<SearchResult> chapterResults = await _searchInChapter(
        book, 
        i, 
        normalizedQuery, 
        queryWords, 
        exactMatch, 
        maxResults - results.length
      );
      
      results.addAll(chapterResults);
    }
    
    return results;
  }
  
  // 在單個章節中搜索 - 優化版本
  Future<List<SearchResult>> _searchInChapter(Book book, int chapterNumber, String normalizedQuery, List<String> queryWords, bool exactMatch, int maxResults) async {
    List<SearchResult> results = [];
    
    Chapter? chapter = await getChapter(book.id, chapterNumber);
    if (chapter == null) return results;
    
    // 預先計算一些常用值，避免重複計算
    bool isMultiWordQuery = queryWords.length > 1;
    bool isShortQuery = queryWords.length <= 3;
    
    for (Verse verse in chapter.verses) {
      // 檢查是否已達到最大結果數
      if (results.length >= maxResults) break;
      
      // 將經文文本轉為小寫，只做一次
      String verseTextLower = verse.text.toLowerCase();
      bool matches = false;
      
      if (exactMatch) {
        // 精確匹配 - 簡化邏輯
        matches = verseTextLower == normalizedQuery || 
                 verseTextLower.split(RegExp(r'\s+')).contains(normalizedQuery);
      } else {
        // 模糊匹配 - 先檢查完整查詢字符串
        if (verseTextLower.contains(normalizedQuery)) {
          matches = true;
        } else if (isMultiWordQuery) {
          // 分詞搜尋 - 必須包含所有查詢單詞
          matches = true;
          for (String word in queryWords) {
            // 只匹配長度>=2的詞，或者是用戶明確輸入的單個字符
            if ((word.length >= 2 || isShortQuery) && !verseTextLower.contains(word)) {
              matches = false;
              break;
            }
          }
        }
      }
      
      if (matches) {
        // 創建帶有高亮信息的搜尋結果 - 優化高亮處理邏輯
        int? startIndex;
        int? highlightLength;
        String matchedText = normalizedQuery;
        List<Map<String, int>> highlightRanges = [];
        
        // 嘗試找到完整查詢字符串的匹配
        startIndex = verseTextLower.indexOf(normalizedQuery);
        if (startIndex >= 0) {
          // 找到完整查詢字符串
          highlightLength = normalizedQuery.length;
          highlightRanges.add({
            'start': startIndex,
            'length': highlightLength,
          });
        } else if (isMultiWordQuery) {
          // 如果找不到完整匹配，但有多個關鍵詞，找出所有匹配的關鍵詞
          bool foundFirstWord = false;
          
          // 對於每個關鍵詞，查找所有匹配位置並高亮
          for (String word in queryWords) {
            // 只處理有效的關鍵詞（長度>=2或者是用戶明確輸入的短詞）
            if (word.length >= 2 || isShortQuery) {
              // 查找所有匹配的位置 - 限制最多找5個匹配位置，避免過多處理
              int wordIndex = 0;
              int matchCount = 0;
              final int maxMatchesPerWord = 5;
              
              while (matchCount < maxMatchesPerWord) {
                int index = verseTextLower.indexOf(word, wordIndex);
                if (index == -1) break; // 沒有更多匹配
                
                // 添加到高亮範圍
                highlightRanges.add({
                  'start': index,
                  'length': word.length,
                });
                
                // 如果這是第一個找到的單詞，也設置舊版兼容的高亮
                if (!foundFirstWord) {
                  startIndex = index;
                  highlightLength = word.length;
                  matchedText = word;
                  foundFirstWord = true;
                }
                
                // 移動到下一個可能的匹配位置
                wordIndex = index + word.length;
                matchCount++;
              }
            }
          }
        }
        
        results.add(SearchResult(
          reference: ScriptureReference(
            bookId: book.id,
            chapter: chapter.number,
            verse: verse.number,
          ),
          verse: verse,
          book: book,
          highlightStart: startIndex,
          highlightLength: highlightLength,
          matchedQuery: matchedText,
          highlightRanges: highlightRanges,
        ));
      }
    }
    
    return results;
  }

  // 私有方法：加載所有書卷
  Future<void> _loadBooks() async {
    debugPrint('開始加載聖經書卷...');
    _books.clear();
    _validBiblePath = null;
    
    try {
      // 使用 Flutter 的資源系統加載聖經文件
      debugPrint('正在加載資源清單...');
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      debugPrint('資源清單加載完成，開始尋找聖經文件...');
      
      // 過濾出 BIBLE 目錄下的 .txt 文件
      final bibleFiles = manifestMap.keys.where((String key) => 
        key.startsWith('BIBLE/') && 
        key.endsWith('.txt')
      ).toList();
      
      if (bibleFiles.isEmpty) {
        debugPrint('找不到聖經文件，請確保 BIBLE 目錄已添加到 pubspec.yaml 的 assets 中');
        throw Exception('找不到聖經文件');
      }
      
      // 設置有效的聖經路徑
      _validBiblePath = 'BIBLE';
      debugPrint('找到 ${bibleFiles.length} 個聖經文件，開始解析...');
      
      // 排序文件
      bibleFiles.sort();
      debugPrint('文件已排序，開始處理每個文件...');
      
      // 使用 Set 來追蹤已處理的書卷 ID，防止重複
      final Set<String> processedBookIds = {};
      
      // 處理每個文件
      int processedFiles = 0;
      for (String filePath in bibleFiles) {
        try {
          debugPrint('正在處理文件 (${processedFiles+1}/${bibleFiles.length}): $filePath');
          // 從文件名中提取書卷 ID
          String fileName = path.basename(filePath);
          RegExp idRegex = RegExp(r'(\d+)_');
          Match? idMatch = idRegex.firstMatch(fileName);
          String fileId = idMatch?.group(1) ?? '';
          
          if (fileId.isEmpty) {
            // 嘗試其他格式
            idRegex = RegExp(r'(\d+)\.');
            idMatch = idRegex.firstMatch(fileName);
            fileId = idMatch?.group(1) ?? '';
          }
          
          if (fileId.isEmpty) {
            debugPrint('無法從文件名中提取書卷 ID: $fileName');
            continue;
          }
          
          // 檢查是否已經處理過該書卷 ID
          if (processedBookIds.contains(fileId)) {
            debugPrint('書卷 ID $fileId 已經處理過，跳過重複加載');
            continue;
          }
          
          // 加載文件內容
          debugPrint('正在加載文件內容: $filePath');
          // 使用ByteData加載文件，然後手動處理編碼
          final ByteData data = await rootBundle.load(filePath);
          final String content = _decodeText(data);
          final List<String> lines = content.split('\n');
          debugPrint('文件編碼解析成功');
          debugPrint('文件內容已加載，行數: ${lines.length}');
          
          if (lines.isEmpty) {
            debugPrint('文件為空: $filePath');
            continue;
          }
          processedFiles++;
          
          // 解析第一行獲取書卷信息
          // 格式: =001 Genesis - 創世紀
          String firstLine = lines[0].trim();
          RegExp regex = RegExp(r'=(\d+)\s+([\w]+)\s+-\s+([^\s]+)');
          Match? match = regex.firstMatch(firstLine);
          
          if (match != null && match.groupCount >= 3) {
            String id = match.group(1) ?? '';
            String name = match.group(2) ?? '';
            String localName = match.group(3) ?? '';
            
            // 確保 ID 一致
            if (id != fileId) {
              debugPrint('警告：文件名中的 ID ($fileId) 與內容中的 ID ($id) 不一致，使用內容中的 ID');
            }
            
            // 檢查是否已經處理過該書卷 ID
            if (processedBookIds.contains(id)) {
              debugPrint('書卷 ID $id 已經處理過，跳過重複加載');
              continue;
            }
            
            // 從第二行獲取縮寫
            String shortName = '';
            if (lines.length > 1) {
              // 使用更寬鬆的正則表達式
              RegExp shortNameRegex = RegExp(r'^([A-Za-z]+)');
              Match? shortNameMatch = shortNameRegex.firstMatch(lines[1]);
              if (shortNameMatch != null) {
                shortName = shortNameMatch.group(1) ?? '';
              }
            }
            
            // 如果沒有找到縮寫，使用 ID
            if (shortName.isEmpty) {
              shortName = id;
            }
            
            // 判斷是舊約還是新約
            bool isOldTestament = int.parse(id) < 100;
            
            _books.add(Book(
              id: id,
              name: name,
              localName: localName,
              shortName: shortName,
              isOldTestament: isOldTestament,
            ));
            
            // 將 ID 添加到已處理集合中
            processedBookIds.add(id);
            
            debugPrint('已載入書卷: $id - $localName ($name)');
          } else {
            debugPrint('無法解析書卷信息: $firstLine');
          }
        } catch (e) {
          debugPrint('解析檔案 $filePath 時發生錯誤: $e');
          // 繼續處理下一個檔案
        }
      }
      
      if (_books.isEmpty) {
        debugPrint('沒有成功載入任何書卷，請檢查檔案格式');
        throw Exception('無法載入任何聖經書卷，請檢查檔案格式是否正確');
      }
      
      debugPrint('成功載入 ${_books.length} 本書卷');
      // 列出已載入的書卷
      for (int i = 0; i < _books.length; i++) {
        Book book = _books[i];
        debugPrint('  ${i+1}. ${book.id} - ${book.localName} (${book.name})');
      }
      debugPrint('書卷載入完成！');
    } catch (e) {
      debugPrint('載入聖經書卷時發生錯誤: $e');
      rethrow;
    }
  }

  // 私有方法：加載特定章節
  Future<Chapter?> _loadChapter(Book book, int chapter) async {
    try {
      if (_validBiblePath == null) {
        debugPrint('無效的聖經目錄路徑');
        return null;
      }

      // 使用 Flutter 的資源系統加載章節文件
      // 嘗試多種可能的文件名格式
      List<String> possibleFileNames = [
        'BIBLE/${book.id}_${book.name}.txt',
        'BIBLE/${book.id}_${book.localName}.txt',
        'BIBLE/${book.id}.txt',
      ];
      
      String? fileContent;
      String? foundFilePath;
      
      // 嘗試從資源中加載文件
      for (String filePath in possibleFileNames) {
        try {
          // 使用ByteData加載文件，然後手動處理編碼
          final ByteData data = await rootBundle.load(filePath);
          // 使用改進的解碼方法
          fileContent = _decodeText(data);
          foundFilePath = filePath;
          debugPrint('找到章節檔案: $filePath');
          debugPrint('章節文件編碼解析成功');
          break;
        } catch (e) {
          // 繼續嘗試下一個可能的文件名
          debugPrint('無法加載資源: $filePath - $e');
        }
      }
      
      // 如果無法找到文件，嘗試查找以書卷ID開頭的文件
      if (fileContent == null) {
        final manifestContent = await rootBundle.loadString('AssetManifest.json');
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        
        final bibleFiles = manifestMap.keys.where((String key) => 
          key.startsWith('BIBLE/') && 
          key.endsWith('.txt') && 
          (key.contains('${book.id}_') || key.startsWith('BIBLE/${book.id}.'))
        ).toList();
        
        if (bibleFiles.isNotEmpty) {
          foundFilePath = bibleFiles.first;
          // 使用ByteData加載文件，然後手動處理編碼
          final ByteData data = await rootBundle.load(foundFilePath);
          fileContent = _decodeText(data);
          debugPrint('通過目錄搜索找到章節檔案: $foundFilePath');
          debugPrint('通過目錄搜索的章節文件編碼解析成功');
        }
      }
      
      if (fileContent == null) {
        debugPrint('找不到章節檔案: ${book.id} ${book.name} 第 $chapter 章');
        return null;
      }

      // 解析文件內容
      List<String> lines = fileContent.split('\n');
      
      // 解析經文
      List<Verse> verses = [];
      int versesLoaded = 0;
      
      // 正則表達式匹配經文格式: "Ge 1:1 創世紀 1:1 起初　神創造天地。"
      RegExp regex = RegExp(r'[A-Za-z]+\s+(\d+):(\d+)\s+[^\d]+\s+\d+:\d+\s+(.+)');
      
      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('=')) continue;
        
        Match? match = regex.firstMatch(line);
        if (match != null && match.groupCount >= 3) {
          int chapterNumber = int.tryParse(match.group(1) ?? '') ?? 0;
          int verseNumber = int.tryParse(match.group(2) ?? '') ?? 0;
          String text = match.group(3) ?? '';
          
          // 只處理指定章節的經文
          if (chapterNumber == chapter) {
            verses.add(Verse(number: verseNumber, text: text));
            versesLoaded++;
          }
        }
      }
      
      if (verses.isEmpty) {
        debugPrint('找不到第 $chapter 章的經文');
        return null;
      }
      
      // 按照經文編號排序
      verses.sort((a, b) => a.number.compareTo(b.number));
      
      // 創建章節對象
      Chapter newChapter = Chapter(number: chapter, verses: verses);
      
      // 更新書卷對象
      book.chapters[chapter] = newChapter;
      
      debugPrint('已載入 ${book.localName} 第 $chapter 章，共 $versesLoaded 節經文');
      
      return newChapter;
    } catch (e) {
      debugPrint('載入章節時發生錯誤: $e');
      return null;
    }
  }

  // 私有方法：獲取書卷的章節數量
  int _getBookChapterCount(String bookId) {
    // 這裡使用預定義的章節數量
    // 實際應用中可以從文件中解析或使用配置
    Map<String, int> chapterCounts = {
      '001': 50,  // Genesis
      '002': 40,  // Exodus
      '003': 27,  // Leviticus
      '004': 36,  // Numbers
      '005': 34,  // Deuteronomy
      '006': 24,  // Joshua
      '007': 21,  // Judges
      '008': 4,   // Ruth
      '009': 31,  // 1 Samuel
      '010': 24,  // 2 Samuel
      '011': 22,  // 1 Kings
      '012': 25,  // 2 Kings
      '013': 29,  // 1 Chronicles
      '014': 36,  // 2 Chronicles
      '015': 10,  // Ezra
      '016': 13,  // Nehemiah
      '017': 10,  // Esther
      '018': 42,  // Job
      '019': 150, // Psalms
      '020': 31,  // Proverbs
      '021': 12,  // Ecclesiastes
      '022': 8,   // Song of Solomon
      '023': 66,  // Isaiah
      '024': 52,  // Jeremiah
      '025': 5,   // Lamentations
      '026': 48,  // Ezekiel
      '027': 12,  // Daniel
      '028': 14,  // Hosea
      '029': 3,   // Joel
      '030': 9,   // Amos
      '031': 1,   // Obadiah
      '032': 4,   // Jonah
      '033': 7,   // Micah
      '034': 3,   // Nahum
      '035': 3,   // Habakkuk
      '036': 3,   // Zephaniah
      '037': 2,   // Haggai
      '038': 14,  // Zechariah
      '039': 4,   // Malachi
      '101': 28,  // Matthew
      '102': 16,  // Mark
      '103': 24,  // Luke
      '104': 21,  // John
      '105': 28,  // Acts
      '106': 16,  // Romans
      '107': 16,  // 1 Corinthians
      '108': 13,  // 2 Corinthians
      '109': 6,   // Galatians
      '110': 6,   // Ephesians
      '111': 4,   // Philippians
      '112': 4,   // Colossians
      '113': 5,   // 1 Thessalonians
      '114': 3,   // 2 Thessalonians
      '115': 6,   // 1 Timothy
      '116': 4,   // 2 Timothy
      '117': 3,   // Titus
      '118': 1,   // Philemon
      '119': 13,  // Hebrews
      '120': 5,   // James
      '121': 5,   // 1 Peter
      '122': 3,   // 2 Peter
      '123': 5,   // 1 John
      '124': 1,   // 2 John
      '125': 1,   // 3 John
      '126': 1,   // Jude
      '127': 22,  // Revelation
    };

    return chapterCounts[bookId] ?? 0;
  }
  
  // 公共方法：獲取書卷的章節數量
  int getBookChapterCount(String bookId) {
    return _getBookChapterCount(bookId);
  }
  
  // 嘗試使用不同編碼解碼文本
  String _decodeText(ByteData data) {
    final bytes = data.buffer.asUint8List();
    
    // 首先嘗試UTF-8
    try {
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('UTF-8解碼失敗，嘗試其他編碼: $e');
    }
    
    // 如果UTF-8失敗，嘗試使用Latin1（ISO-8859-1）
    try {
      return latin1.decode(bytes);
    } catch (e) {
      debugPrint('Latin1解碼失敗: $e');
    }
    
    // 如果所有嘗試都失敗，返回原始UTF-8解碼結果，但忽略錯誤
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('UTF-8解碼（允許錯誤）失敗: $e');
      // 最後的嘗試：將無法解碼的字節替換為問號
      return String.fromCharCodes(bytes.map((byte) => byte < 128 ? byte : 63)); // 63 是 '?' 的 ASCII 碼
    }
  }
  
  // 添加獲取隨機經節的方法
  Future<Map<String, String>> getRandomVerse() async {
    if (!_isInitialized) {
      throw Exception('聖經服務尚未初始化');
    }

    // 隨機選擇一本書
    final books = getAllBooks();
    final random = DateTime.now().millisecondsSinceEpoch % books.length;
    final book = books[random];

    // 獲取該書的章節數
    final chapterCount = _getBookChapterCount(book.id);
    if (chapterCount <= 0) return {'text': '', 'reference': ''};

    // 隨機選擇一章
    final chapterRandom = DateTime.now().microsecondsSinceEpoch % chapterCount + 1;
    final chapter = await getChapter(book.id, chapterRandom);
    if (chapter == null || chapter.verses.isEmpty) return {'text': '', 'reference': ''};

    // 隨機選擇一節
    final verseRandom = DateTime.now().microsecondsSinceEpoch % chapter.verses.length;
    final verse = chapter.verses[verseRandom];

    return {
      'text': verse.text,
      'reference': '${book.localName} ${chapter.number}:${verse.number}'
    };
  }
}

/// 搜索結果模型
class SearchResult {
  final ScriptureReference reference;
  final Verse verse;
  final Book book;
  final int? highlightStart; // 高亮開始位置 (舊版兼容)
  final int? highlightLength; // 高亮長度 (舊版兼容)
  final String matchedQuery; // 匹配的查詢字符串
  final List<Map<String, int>> highlightRanges; // 多個高亮區域 [{"start": 開始位置, "length": 長度}]

  SearchResult({
    required this.reference,
    required this.verse,
    required this.book,
    this.highlightStart,
    this.highlightLength,
    required this.matchedQuery,
    this.highlightRanges = const [],
  });
  
  // 獲取高亮文本
  String? get highlightedText {
    if (highlightStart != null && highlightLength != null && 
        highlightStart! >= 0 && highlightStart! + highlightLength! <= verse.text.length) {
      return verse.text.substring(highlightStart!, highlightStart! + highlightLength!);
    }
    return null;
  }
  
  // 重寫相等運算符，基於書卷ID、章節號和經文號進行比較
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResult &&
           other.reference.bookId == reference.bookId &&
           other.reference.chapter == reference.chapter &&
           other.reference.verse == reference.verse;
  }
  
  // 重寫哈希碼，基於書卷ID、章節號和經文號計算
  @override
  int get hashCode => Object.hash(
    reference.bookId,
    reference.chapter,
    reference.verse,
  );
}