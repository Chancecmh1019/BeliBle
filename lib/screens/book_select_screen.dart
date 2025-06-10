import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bible_models.dart';
import '../services/bible_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/verse_widget.dart';
import '../widgets/book_chapter_selector.dart';
import 'search_screen.dart';

class BookSelectScreen extends StatefulWidget {
  final BibleService bibleService;
  final StorageService? storageService;
  final ValueNotifier<double>? fontSizeNotifier;

  const BookSelectScreen({
    super.key,
    required this.bibleService,
    this.storageService,
    this.fontSizeNotifier,
  });
  
  @override
  BookSelectScreenState createState() => BookSelectScreenState();
}

class BookSelectScreenState extends State<BookSelectScreen> {
  late BibleService _bibleService;
  StorageService? _storageService;
  ValueNotifier<double>? _fontSizeNotifier;
  
  // 添加 ScrollController 來控制經文列表的滾動
  final ScrollController _scrollController = ScrollController();
  
  // 添加閱讀器所需的狀態變量
  late ScriptureReference _currentReference;
  Book? _currentBook;
  Chapter? _currentChapter;
  bool _isLoading = true;
  String _errorMessage = '';
  double _fontSize = 18.0;
  bool _isBookmarked = false;
  bool _isScriptureLoaded = false; // 標記是否已經通過 loadScripture 方法加載了經文
  // 移除滾動至該經節功能
  
  // 存儲當前章節的高亮信息，key為經文號，value為高亮顏色
  Map<int, Color> _highlightColors = {};
  
  // 多選經文相關變量
  bool _isMultiSelectMode = false; // 是否處於多選模式
  Set<int> _selectedVerses = {}; // 已選擇的經文號集合
  
  // 檢查 StorageService 是否可用
  bool get _hasStorageService => _storageService != null;
  
  // 檢查 FontSizeNotifier 是否可用
  bool get _hasFontSizeNotifier => _fontSizeNotifier != null;
  
  // 提供給外部調用的方法，用於加載特定經文
  void loadScripture(Book? book, int chapter, int? verse) {
    // 檢查傳入的書卷是否為空
    if (book == null) {
      debugPrint('【新加載邏輯】loadScripture 錯誤: book 參數為空');
      return;
    }
    
    debugPrint('【新加載邏輯】loadScripture 被調用: ${book.localName} $chapter${verse != null ? ':$verse' : ''}');
    debugPrint('【詳細資訊】Book ID: ${book.id}, Name: ${book.name}, LocalName: ${book.localName}');
    
    // 清除加載狀態，準備重新加載
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _highlightColors = {};
      // 移除滾動至該經節功能
    });
    
    try {
      // 設置當前引用和書卷
      _currentReference = ScriptureReference(
        bookId: book.id,
        chapter: chapter,
        verse: verse,
      );
      _currentBook = book;
      _isScriptureLoaded = true; // 標記已經加載了經文
      
      // 儲存當前閱讀狀態
      if (_hasStorageService) {
        _storageService!.addReadingHistory(_currentReference);
        _storageService!.setLastRead(_currentReference);
        debugPrint('【新加載邏輯】已保存閱讀位置: ${book.localName} $chapter${verse != null ? ':$verse' : ''}');
      }
      
      // 直接加載章節，不通過 _initializeReading
      _bibleService.getChapter(book.id, chapter).then((chapter) {
        if (chapter == null) {
          throw Exception('找不到章節: ${book.id} $chapter');
        }
        
        // 成功加載章節
        _currentChapter = chapter;
        
        // 檢查是否已收藏
        _checkIfBookmarked();
        
        // 加載高亮信息
        _loadHighlights();
        
        // 更新UI
        setState(() {
          _isLoading = false;
        });
        
        debugPrint('【新加載邏輯】經文加載完成: ${book.localName} $chapter');
        
        // 移除滾動至該經節功能
      }).catchError((error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
        debugPrint('【新加載邏輯】經文加載錯誤: $error');
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      debugPrint('【新加載邏輯】處理經文加載參數錯誤: $e');
    }
  }
  
  @override
  void initState() {
    super.initState();
    debugPrint('【新邏輯】BookSelectScreen - initState 被調用');
    _bibleService = widget.bibleService;
    _storageService = widget.storageService;
    _fontSizeNotifier = widget.fontSizeNotifier;
    _isScriptureLoaded = false; // 初始化時設置為 false
    
    // 初始化字體大小
    if (_hasFontSizeNotifier) {
      _fontSize = _fontSizeNotifier!.value;
      // 監聽字體大小變化
      _fontSizeNotifier!.addListener(() {
        if (mounted) {
          setState(() {
            _fontSize = _fontSizeNotifier!.value;
          });
        }
      });
    }
    
    // 初始化閱讀位置 - 僅在未通過 loadScripture 加載時執行
    debugPrint('【新邏輯】BookSelectScreen - 準備初始化閱讀位置');
    _initializeReading();
  }
  
  // 初始化閱讀
  Future<void> _initializeReading() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      // 清空高亮信息
      _highlightColors = {};
    });

    try {
      // 只有在未通過 loadScripture 方法加載經文時才使用最後閱讀位置或默認位置
      if (!_isScriptureLoaded) {
        debugPrint('使用保存的或默認的閱讀位置');
        // 優先使用最後閱讀位置或默認位置
        if (_hasStorageService) {
          final lastRead = _storageService!.getLastRead();
          if (lastRead != null) {
            _currentReference = lastRead;
            debugPrint('從存儲服務獲取最後閱讀位置: ${_currentReference.bookId} ${_currentReference.chapter}${_currentReference.verse != null ? ':${_currentReference.verse}' : ''}');
          } else {
            // 默認從創世紀第一章開始
            _currentReference = ScriptureReference(bookId: '001', chapter: 1);
            debugPrint('使用默認位置: 創世紀第一章');
          }
        } else {
          // 如果存儲服務不可用，則使用默認位置
          _currentReference = ScriptureReference(bookId: '001', chapter: 1);
          debugPrint('存儲服務不可用，使用默認位置: 創世紀第一章');
        }

        // 加載當前書卷
        _currentBook = _bibleService.getBookById(_currentReference.bookId);
        if (_currentBook == null) {
          throw Exception('找不到書卷: ${_currentReference.bookId}');
        }
      } else {
        debugPrint('使用由 loadScripture 指定的閱讀位置: ${_currentBook?.localName} ${_currentReference.chapter}${_currentReference.verse != null ? ':${_currentReference.verse}' : ''}');
      }
      
      // 確認當前書卷是否正確加載
      if (_currentBook == null) {
        debugPrint('警告：當前書卷為空，嘗試從當前引用中獲取');
        _currentBook = _bibleService.getBookById(_currentReference.bookId);
        if (_currentBook == null) {
          throw Exception('找不到書卷: ${_currentReference.bookId}');
        }
      }
      
      debugPrint('正在加載章節：${_currentBook!.id} (${_currentBook!.localName}) 第 ${_currentReference.chapter} 章');

      // 加載當前章節
      _currentChapter = await _bibleService.getChapter(
        _currentReference.bookId,
        _currentReference.chapter,
      );
      if (_currentChapter == null) {
        throw Exception('找不到章節: ${_currentReference.bookId} ${_currentReference.chapter}');
      }

      // 檢查是否已收藏
      _checkIfBookmarked();
      
      // 加載高亮信息
      _loadHighlights();

      // 添加到閱讀歷史並保存最後閱讀位置（如果存儲服務可用且不是通過 loadScripture 加載的）
      if (_hasStorageService && !_isScriptureLoaded) {
        debugPrint('將當前位置添加到閱讀歷史中');
        await _storageService!.addReadingHistory(_currentReference);
        // 注意：addReadingHistory 方法已經包含了保存最後閱讀位置的功能
      } else if (_isScriptureLoaded) {
        debugPrint('由於是通過 loadScripture 加載的，跳過添加到閱讀歷史');
      }

      setState(() {
        _isLoading = false;
      });
      
      debugPrint('經文加載完成: ${_currentBook?.localName} ${_currentReference.chapter}');
      
      // 移除滾動至該經節功能
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      debugPrint('經文加載錯誤: $e');
    }
  }
  
  // 檢查是否已收藏
  void _checkIfBookmarked() {
    // 此方法已被移除，書籤功能不再支持
    _isBookmarked = false;
  }
  
  // 加載高亮信息
  void _loadHighlights() {
    // 如果存儲服務不可用，則不執行任何操作
    if (!_hasStorageService) {
      _highlightColors = {};
      return;
    }
    
    final highlights = _storageService!.getAllHighlights();
    
    // 清空當前高亮信息
    _highlightColors = {};
    
    // 篩選當前章節的高亮
    for (final highlight in highlights) {
      if (highlight.reference.bookId == _currentReference.bookId &&
          highlight.reference.chapter == _currentReference.chapter &&
          highlight.reference.verse != null) {
        _highlightColors[highlight.reference.verse!] = highlight.color;
      }
    }
  }

  // 切換收藏狀態
  Future<void> _toggleBookmark() async {
    // 此方法已被移除，書籤功能不再支持
    showCustomSnackBar(
      context,
      '書籤功能已被移除',
      icon: Icons.info_outline,
      backgroundColor: Colors.grey,
    );
    return;
  }
  

  
  // 顯示顏色選擇器對話框
  void _showColorPickerDialog(int verseNumber) {
    // 預設顏色選項 - 柔和淺色系，確保在深淺模式下都能看清但不刺眼
    final colors = [
      // 柔和淺色系，增加不透明度至DD (約87%)
      const Color(0xDDFFFF99), // 淺黃色
      const Color(0xDDFFD699), // 淺橙色
      const Color(0xDDFFB6D9), // 淺粉色
      const Color(0xDD99FFFF), // 淺青色
      const Color(0xDDC6FF99), // 淺綠色
      const Color(0xDDD9B3FF), // 淺紫色
      const Color(0xDDFF9999), // 淺紅色
      const Color(0xDD99CCFF), // 淺藍色
      const Color(0xDDFFD699), // 淺橙色
      const Color(0xDDB3FFB3), // 淺綠色
      const Color(0xDDFFB6D9), // 淺粉色
      const Color(0xDD99FFFF), // 淺青色
    ];
    
    // 獲取當前主題亮度
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('選擇高亮顏色'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((color) => GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _addHighlight(verseNumber, color);
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                // 使用圓角矩形而非圓形
                borderRadius: BorderRadius.circular(12),
                // 在深色模式下使用較深的邊框以增強可見度
                border: Border.all(
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                  width: 1.5,
                ),
                // 添加陰影增強視覺效果
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              // 添加顏色示例文字，以便用戶預覽文字在該顏色上的效果
              child: Center(
                child: Text(
                  'Aa',
                  style: TextStyle(
                    color: isDarkMode ? Colors.black87 : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
  
  // 添加高亮
  Future<void> _addHighlight(int verseNumber, Color color) async {
    // 如果存儲服務不可用，則不執行任何操作
    if (!_hasStorageService) {
      showCustomSnackBar(
        context,
        '無法添加高亮：存儲服務不可用',
        icon: Icons.error_outline,
        backgroundColor: Colors.red,
      );
      return;
    }

    // 添加高亮
    await _storageService!.addHighlight(
      ScriptureReference(
        bookId: _currentReference.bookId,
        chapter: _currentReference.chapter,
        verse: verseNumber,
      ),
      color,
    );

    // 重新加載高亮並使用 setState 更新 UI
    setState(() {
      _loadHighlights();
    });

    // 不顯示提示，直接返回
  }
  
  // 移除高亮
  Future<void> _removeHighlight(int verseNumber) async {
    // 如果存儲服務不可用，則不執行任何操作
    if (!_hasStorageService) {
      showCustomSnackBar(
        context,
        '無法移除高亮：存儲服務不可用',
        icon: Icons.error_outline,
        backgroundColor: Colors.red,
      );
      return;
    }
    
    // 獲取本章所有高亮
    final highlights = _storageService!.getAllHighlights().where(
      (highlight) =>
          highlight.reference.bookId == _currentReference.bookId &&
          highlight.reference.chapter == _currentReference.chapter,
    ).toList();
    
    // 如果沒有高亮，顯示提示
    if (highlights.isEmpty) {
      showCustomSnackBar(
        context,
        '本章沒有高亮',
        icon: Icons.info_outline,
      );
      return;
    }
    
    // 查找指定經節的高亮
    final highlight = highlights.firstWhere(
      (h) => h.reference.verse == verseNumber,
      orElse: () => Highlight(id: '', reference: ScriptureReference(bookId: '', chapter: 0), color: Colors.transparent, createdAt: DateTime.now()),
    );
    
    // 如果找不到高亮，顯示提示
    if (highlight.id.isEmpty) {
      showCustomSnackBar(
        context,
        '該經節沒有高亮',
        icon: Icons.info_outline,
      );
      return;
    }
    
    // 移除高亮
    await _storageService!.removeHighlight(highlight.id);
    
    // 重新加載高亮並使用 setState 更新 UI
    setState(() {
      _loadHighlights();
    });
    
    // 不顯示提示，直接返回
  }
  
  // 這裡已經有另一個 _loadHighlights 方法的定義，所以刪除這個重複的定義
  

  

  
  // 顯示本章高亮
  void _showChapterHighlights() {
    // 如果存儲服務不可用，則不執行任何操作
    if (!_hasStorageService) {
      showCustomSnackBar(
        context,
        '無法顯示高亮：存儲服務不可用',
        icon: Icons.error_outline,
        backgroundColor: Colors.red,
      );
      return;
    }
    
    // 獲取本章所有高亮
    final highlights = _storageService!.getAllHighlights().where(
      (highlight) =>
          highlight.reference.bookId == _currentReference.bookId &&
          highlight.reference.chapter == _currentReference.chapter,
    ).toList();
    
    // 如果沒有高亮，顯示提示
    if (highlights.isEmpty) {
      showCustomSnackBar(
        context,
        '本章暫無高亮',
        icon: Icons.format_color_text,
      );
      return;
    }
    
    // 显示高亮列表
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_currentBook?.localName} ${_currentReference.chapter}章高亮'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: highlights.length,
            itemBuilder: (context, index) {
              final highlight = highlights[index];
              return ListTile(
                title: Text('${_currentReference.chapter}:${highlight.reference.verse}'),
                leading: CircleAvatar(
                  backgroundColor: highlight.color,
                  radius: 12,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    _storageService!.removeHighlight(highlight.id);
                    setState(() {
                      _loadHighlights();
                    });
                    Navigator.pop(context);
                    showCustomSnackBar(
                      context,
                      '高亮已刪除',
                      icon: Icons.format_color_reset,
                    );
                  },
                ),
                onTap: () {
                  // 移除滾動至該經節功能
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 分享經文
  Future<void> _shareScripture() async {
    if (_currentBook == null || _currentChapter == null) return;

    // 構建分享文本
    final StringBuffer shareText = StringBuffer();
    shareText.writeln('${_currentBook!.localName} ${_currentChapter!.number}章');
    shareText.writeln();

    for (final verse in _currentChapter!.verses) {
      shareText.writeln('${_currentChapter!.number}:${verse.number} ${verse.text}');
    }

    // 分享
    await Share.share(shareText.toString());
  }

  // 複製經文
  Future<void> _copyScripture() async {
    if (_currentBook == null || _currentChapter == null) return;

    // 構建複製文本
    final StringBuffer copyText = StringBuffer();
    copyText.writeln('${_currentBook!.localName} ${_currentChapter!.number}章');
    copyText.writeln();

    for (final verse in _currentChapter!.verses) {
      copyText.writeln('${_currentChapter!.number}:${verse.number} ${verse.text}');
    }

    // 複製到剪貼板
    await Clipboard.setData(ClipboardData(text: copyText.toString()));

    // 顯示提示
    if (mounted) {
      showCustomSnackBar(
        context, 
        '已複製到剪貼板',
        icon: Icons.content_copy,
      );
    }
  }

  // 調整字體大小
  void _adjustFontSize(double delta) {
    final newFontSize = (_fontSize + delta).clamp(12.0, 32.0);
    
    // 更新 ValueNotifier
    if (_hasFontSizeNotifier) {
      _fontSizeNotifier!.value = newFontSize;
    }
    
    // 保存到存儲服務
    if (_hasStorageService) {
      _storageService!.saveFontSize(newFontSize);
    }
    
    // 更新本地狀態
    setState(() {
      _fontSize = newFontSize;
    });
  }

  // 顯示書籍章節選擇器
  void _showBookChapterSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookChapterSelector(
        bibleService: _bibleService,
        currentReference: _currentReference,
        onReferenceSelected: (reference) {
          debugPrint('收到新的引用選擇: bookId=${reference.bookId}, chapter=${reference.chapter}, verse=${reference.verse}');
          
          // 獲取新選擇的書卷
          final Book? selectedBook = _bibleService.getBookById(reference.bookId);
          if (selectedBook == null) {
            debugPrint('錯誤：無法找到書卷 ID ${reference.bookId}');
            return;
          }
          
          debugPrint('找到書卷: ${selectedBook.id} - ${selectedBook.localName}');
          
          // 使用 loadScripture 方法加載新的經文
          loadScripture(selectedBook, reference.chapter, reference.verse);
          
          // 保存最後閱讀位置
          if (_hasStorageService) {
            _storageService!.setLastRead(reference);
            debugPrint('已保存最後閱讀位置');
          }
        },
      ),
    );
  }
  
  // 滾動到指定經節
  // 移除滾動至該經節功能
  
  @override
  void dispose() {
    // 釋放 ScrollController
    _scrollController.dispose();
    
    // 如果有字體大小監聽器，移除監聽
    if (_hasFontSizeNotifier) {
      _fontSizeNotifier!.removeListener(() {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 顯示加載中
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('${_currentBook?.localName ?? '聖經'} - 第${_currentReference?.chapter ?? 1}章')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 顯示錯誤
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('聖經')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('發生錯誤', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_errorMessage, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeReading,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    // 主閱讀界面
    return Scaffold(
      appBar: AppBar(
        // 將標題改為可點擊的按鈕
        title: InkWell(
          onTap: _showBookChapterSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book, size: 18),
                const SizedBox(width: 8),
                // 顯示當前書卷和章節
                Text(
                  '${_currentBook?.localName ?? '聖經'} - 第${_currentReference.chapter}章',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          // 搜索圖標
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜尋經文',
            onPressed: () async {
              // 打開搜索頁面並等待結果
              // 檢查必要的服務是否可用
              if (widget.storageService == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('無法開啟搜尋頁面：儲存服務不可用'))
                );
                return;
              }
              
              // 檢查fontSizeNotifier是否為空
              ValueNotifier<double> fontSizeNotifier = widget.fontSizeNotifier ?? ValueNotifier<double>(18.0);
              
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    bibleService: widget.bibleService,
                    storageService: widget.storageService!,
                    fontSizeNotifier: fontSizeNotifier,
                  ),
                ),
              );
              
              // 如果我們創建了一個新的ValueNotifier，需要釋放它
              if (widget.fontSizeNotifier == null) {
                fontSizeNotifier.dispose();
              }
              
              // 處理搜索結果
              if (result != null && result is Map<String, dynamic>) {
                debugPrint('收到搜索結果: $result');
                
                // 加載指定經文，並滾動到特定經節
                final book = result['book'] as Book;
                final chapter = result['chapter'] as int;
                // 獲取經節並使用它進行滾動
                final verse = result['verse'] as int;
                
                debugPrint('從搜索結果加載經文: ${book.localName} $chapter:$verse');
                loadScripture(book, chapter, verse);
              }
            },
          ),
          // 更多選項
          PopupMenuButton<String>(
            tooltip: '顯示選單', // 添加中文提示
            // 自定義動畫效果，類似 Chrome
            position: PopupMenuPosition.under,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            offset: const Offset(0, 8), // 調整彈出位置
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _shareScripture();
                  break;
                case 'copy':
                  _copyScripture();
                  break;
                case 'font_increase':
                  _adjustFontSize(2.0);
                  break;
                case 'font_decrease':
                  _adjustFontSize(-2.0);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('分享'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.content_copy),
                    SizedBox(width: 8),
                    Text('複製'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'font_increase',
                child: Row(
                  children: [
                    Icon(Icons.text_increase),
                    SizedBox(width: 8),
                    Text('增大字體'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'font_decrease',
                child: Row(
                  children: [
                    Icon(Icons.text_decrease),
                    SizedBox(width: 8),
                    Text('減小字體'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 添加頂部安全區域，避免與狀態列重疊
          const SizedBox(height: 8),
          // 經文內容
          Expanded(
            child: _currentChapter != null
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _currentChapter!.verses.length,
                    controller: _scrollController, // 添加 ScrollController
                    itemBuilder: (context, index) {
                      final verse = _currentChapter!.verses[index];
                      final bool isSelected = _selectedVerses.contains(verse.number);
                      
                      return Stack(
                        children: [
                          VerseWidget(
                            verse: verse,
                            fontSize: _fontSize,
                            // 傳遞高亮顏色
                            highlightColor: _highlightColors[verse.number],
                            onLongPress: () {
                              // 檢查經節是否已經有高亮
                              if (_highlightColors[verse.number] != null) {
                                // 如果已有高亮，顯示底部操作表
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (context) => Container(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 4,
                                          margin: const EdgeInsets.only(bottom: 20),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        Text(
                                          '第 ${verse.number} 節',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          verse.text,
                                          style: const TextStyle(fontSize: 16),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildActionButton(
                                              icon: Icons.content_copy,
                                              label: '複製',
                                              onTap: () {
                                                Navigator.pop(context);
                                                Clipboard.setData(ClipboardData(text: '${_currentReference.chapter}:${verse.number} ${verse.text}'));
                                                showCustomSnackBar(
                                                  context,
                                                  '已複製經文到剪貼板',
                                                  icon: Icons.content_copy,
                                                );
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.share,
                                              label: '分享',
                                              onTap: () {
                                                Navigator.pop(context);
                                                Share.share('${_currentBook?.localName} ${_currentReference.chapter}:${verse.number} ${verse.text}');
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.highlight_remove,
                                              label: '移除高亮',
                                              onTap: () {
                                                Navigator.pop(context);
                                                _removeHighlight(verse.number);
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.palette,
                                              label: '更換顏色',
                                              onTap: () {
                                                Navigator.pop(context);
                                                // 將單個經文添加到選擇列表
                                                setState(() {
                                                  _selectedVerses.clear();
                                                  _selectedVerses.add(verse.number);
                                                });
                                                _showColorPickerForSelectedVerses();
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                // 如果沒有高亮，顯示底部操作表
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (context) => Container(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 4,
                                          margin: const EdgeInsets.only(bottom: 20),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        Text(
                                          '第 ${verse.number} 節',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          verse.text,
                                          style: const TextStyle(fontSize: 16),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildActionButton(
                                              icon: Icons.content_copy,
                                              label: '複製',
                                              onTap: () {
                                                Navigator.pop(context);
                                                Clipboard.setData(ClipboardData(text: '${_currentReference.chapter}:${verse.number} ${verse.text}'));
                                                showCustomSnackBar(
                                                  context,
                                                  '已複製經文到剪貼板',
                                                  icon: Icons.content_copy,
                                                );
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.share,
                                              label: '分享',
                                              onTap: () {
                                                Navigator.pop(context);
                                                Share.share('${_currentBook?.localName} ${_currentReference.chapter}:${verse.number} ${verse.text}');
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.highlight,
                                              label: '高亮',
                                              onTap: () {
                                                Navigator.pop(context);
                                                // 將單個經文添加到選擇列表
                                                setState(() {
                                                  _selectedVerses.clear();
                                                  _selectedVerses.add(verse.number);
                                                });
                                                _showColorPickerForSelectedVerses();
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.library_add_check,
                                              label: '多選',
                                              onTap: () {
                                                Navigator.pop(context);
                                                // 進入多選模式
                                                setState(() {
                                                  _isMultiSelectMode = true;
                                                  _selectedVerses.add(verse.number);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                            onTap: _isMultiSelectMode ? () {
                              // 在多選模式下點擊經文，切換選擇狀態
                              setState(() {
                                if (isSelected) {
                                  _selectedVerses.remove(verse.number);
                                  // 如果沒有選中的經文，退出多選模式
                                  if (_selectedVerses.isEmpty) {
                                    _isMultiSelectMode = false;
                                  }
                                } else {
                                  _selectedVerses.add(verse.number);
                                }
                              });
                            } : null,
                          ),
                          // 在多選模式下顯示選擇狀態
                          if (_isMultiSelectMode)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : const SizedBox(width: 16, height: 16),
                              ),
                            ),
                        ],
                      );
                    },
                  )
                : const Center(child: Text('無法加載經文')),
          ),
          
          // 多選模式下顯示底部操作欄
          if (_isMultiSelectMode)
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('已選擇 ${_selectedVerses.length} 節經文'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.content_copy),
                        tooltip: '複製所選經文',
                        onPressed: () => _copySelectedVerses(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: '分享所選經文',
                        onPressed: () => _shareSelectedVerses(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.highlight),
                        tooltip: '高亮所選經文',
                        onPressed: () => _showColorPickerForSelectedVerses(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: '取消選擇',
                        onPressed: () {
                          setState(() {
                            _isMultiSelectMode = false;
                            _selectedVerses.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      // 移除浮動按鈕，保留 Scaffold 的其他部分
      );
    }
    
    // 複製所選經文的方法
    
    // 複製所選經文
    void _copySelectedVerses() {
      if (_selectedVerses.isEmpty || _currentChapter == null) return;
      
      // 按經文號排序
      final sortedVerses = _selectedVerses.toList()..sort();
      
      // 構建複製文本
      final StringBuffer buffer = StringBuffer();
      for (final verseNumber in sortedVerses) {
        final verse = _currentChapter!.verses.firstWhere(
          (v) => v.number == verseNumber,
          orElse: () => Verse(number: verseNumber, text: ''),
        );
        buffer.writeln('${_currentReference.chapter}:$verseNumber ${verse.text}');
      }
      
      // 複製到剪貼板
      Clipboard.setData(ClipboardData(text: buffer.toString()));
      showCustomSnackBar(
        context,
        '已複製 ${_selectedVerses.length} 節經文到剪貼板',
        icon: Icons.content_copy,
      );
      
      // 退出多選模式
      setState(() {
        _isMultiSelectMode = false;
        _selectedVerses.clear();
      });
    }
    
    // 分享所選經文
    void _shareSelectedVerses() {
      if (_selectedVerses.isEmpty || _currentChapter == null) return;
      
      // 按經文號排序
      final sortedVerses = _selectedVerses.toList()..sort();
      
      // 構建分享文本
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('${_currentBook?.localName} ${_currentReference.chapter}章');
      buffer.writeln();
      
      for (final verseNumber in sortedVerses) {
        final verse = _currentChapter!.verses.firstWhere(
          (v) => v.number == verseNumber,
          orElse: () => Verse(number: verseNumber, text: ''),
        );
        buffer.writeln('${_currentReference.chapter}:$verseNumber ${verse.text}');
      }
      
      // 分享
      Share.share(buffer.toString());
      
      // 退出多選模式
      setState(() {
        _isMultiSelectMode = false;
        _selectedVerses.clear();
      });
    }
    
    // 為所選經文顯示顏色選擇器
    void _showColorPickerForSelectedVerses() {
      if (_selectedVerses.isEmpty) return;
      
      // 預設顏色選項 - 明亮螢光色系，確保在深淺模式下都能看清
      final colors = [
      // 柔和淺色系，增加不透明度至DD (約87%)
      const Color(0xDDFFFF99), // 淺黃色
      const Color(0xDDFFD699), // 淺橙色
      const Color(0xDDFFB6D9), // 淺粉色
      const Color(0xDD99FFFF), // 淺青色
      const Color(0xDDC6FF99), // 淺綠色
      const Color(0xDDD9B3FF), // 淺紫色
      const Color(0xDDFF9999), // 淺紅色
      const Color(0xDD99CCFF), // 淺藍色
      const Color(0xDDFFD699), // 淺橙色
      const Color(0xDDB3FFB3), // 淺綠色
      const Color(0xDDFFB6D9), // 淺粉色
      const Color(0xDD99FFFF), // 淺青色
    ];
      
      // 獲取當前主題亮度
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      
      // 使用現有的顏色選擇器對話框，但修改為應用於多個經文
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('選擇高亮顏色 (${_selectedVerses.length} 節經文)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: colors.map((color) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        // 為所有選中的經文添加高亮
                        for (final verseNumber in _selectedVerses) {
                          _addHighlight(verseNumber, color);
                        }
                        // 退出多選模式
                        setState(() {
                          _isMultiSelectMode = false;
                          _selectedVerses.clear();
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          // 使用圓角矩形而非圓形
                          borderRadius: BorderRadius.circular(12),
                          // 在深色模式下使用較深的邊框以增強可見度
                          border: Border.all(
                            color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                            width: 1.5,
                          ),
                          // 添加陰影增強視覺效果
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        // 添加顏色示例文字，以便用戶預覽文字在該顏色上的效果
                        child: Center(
                          child: Text(
                            'Aa',
                            style: TextStyle(
                              color: isDarkMode ? Colors.black87 : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    }

    // 創建一個自定義的 SnackBar 顯示函數，用於統一提示詞的顯示樣式
    void showCustomSnackBar(BuildContext context, String message, {IconData? icon, Color? backgroundColor}) {
      final snackBar = SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 12)],
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
    
    // 構建操作按鈕
    Widget _buildActionButton({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
}