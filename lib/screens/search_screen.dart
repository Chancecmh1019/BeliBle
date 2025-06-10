import 'package:flutter/material.dart';
import '../services/bible_service.dart';
import '../services/storage_service.dart';
import '../widgets/verse_widget.dart';
import '../models/bible_models.dart';
import '../screens/home_screen.dart';
import '../screens/book_select_screen.dart';

class SearchScreen extends StatefulWidget {
  final BibleService bibleService;
  final StorageService storageService;
  final ValueNotifier<double> fontSizeNotifier;

  const SearchScreen({
    super.key, 
    required this.bibleService,
    required this.storageService,
    required this.fontSizeNotifier,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  String _errorMessage = '';
  double _searchProgress = 0.0; // 搜尋進度 (0.0 - 1.0)
  bool _searchLimitReached = false; // 是否達到搜尋結果上限
  
  // 搜尋過濾選項
  String? _testamentFilter; // 新約/舊約過濾
  String? _bookIdFilter; // 書卷過濾
  bool _exactMatch = false; // 精確匹配
  
  // 書卷列表
  late List<Book> _allBooks;
  late List<Book> _oldTestamentBooks;
  late List<Book> _newTestamentBooks;

  @override
  void initState() {
    super.initState();
    _initializeBooks();
  }
  
  // 初始化書卷列表
  void _initializeBooks() {
    _allBooks = widget.bibleService.getAllBooks();
    _oldTestamentBooks = widget.bibleService.getOldTestamentBooks();
    _newTestamentBooks = widget.bibleService.getNewTestamentBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 執行搜尋 - 性能優化版本
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchProgress = 0.0; // 重置進度
      _errorMessage = '';
    });

    try {
      // 設置最大結果數量限制，避免返回過多結果導致性能問題
      const int maxResults = 100;
      
      final results = await widget.bibleService.searchScripture(
        query,
        testamentFilter: _testamentFilter,
        bookIdFilter: _bookIdFilter,
        exactMatch: _exactMatch,
        maxResults: maxResults,
      );
      
      // 使用 toSet().toList() 去除重複的搜索結果
      final uniqueResults = results.toSet().toList();
      
      setState(() {
        _searchResults = uniqueResults;
        _isSearching = false;
        _searchProgress = 1.0; // 完成進度
        
        // 如果結果達到上限，顯示提示訊息
        if (uniqueResults.length >= maxResults) {
          _searchLimitReached = true;
        } else {
          _searchLimitReached = false;
        }
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchProgress = 0.0;
        _errorMessage = '搜尋時發生錯誤: $e';
      });
    }
  }
  
  // 顯示過濾選項對話框
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('搜尋過濾選項'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 約過濾
                  const Text('聖經約別', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: _testamentFilter,
                    hint: const Text('全部'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('全部'),
                      ),
                      const DropdownMenuItem<String?>(
                        value: 'old',
                        child: Text('舊約'),
                      ),
                      const DropdownMenuItem<String?>(
                        value: 'new',
                        child: Text('新約'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _testamentFilter = value;
                        // 重置書卷過濾
                        _bookIdFilter = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 書卷過濾
                  const Text('書卷', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: _bookIdFilter,
                    hint: const Text('全部'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('全部'),
                      ),
                      // 使用 Set 確保書卷 ID 不重複
                      ...(_testamentFilter == 'old' ? _oldTestamentBooks :
                         _testamentFilter == 'new' ? _newTestamentBooks :
                         _allBooks)
                         // 使用 toSet().toList() 去除可能的重複項
                         .toSet().toList()
                         .map((book) => DropdownMenuItem<String?>(
                        value: book.id,
                        child: Text('${book.localName} (${book.name})'),
                      )).toList(),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _bookIdFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 精確匹配
                  Row(
                    children: [
                      Checkbox(
                        value: _exactMatch,
                        onChanged: (value) {
                          setDialogState(() {
                            _exactMatch = value ?? false;
                          });
                        },
                      ),
                      const Text('精確匹配'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 如果有搜尋關鍵字，重新執行搜尋
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(_searchController.text);
                  }
                },
                child: const Text('套用'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜尋經文'),
        centerTitle: true,
        actions: [
          // 過濾按鈕
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: '搜尋過濾選項',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋區域
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 搜尋輸入框
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '輸入關鍵字搜尋經文',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      _performSearch(value);
                    },
                  ),
                ),
                // 搜尋按鈕
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    _performSearch(_searchController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('搜尋'),
                ),
              ],
            ),
          ),
          
          // 搜尋進度指示器
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _searchProgress,
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '正在搜尋中...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          
          // 搜尋結果或錯誤訊息
          Expanded(
            child: _isSearching
                ? const Center(
                    child: SizedBox(), // 使用空容器，因為上方已經有進度指示器
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty
                                      ? '請輸入關鍵字搜尋經文'
                                      : '沒有找到符合的結果',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // 如果達到搜尋結果上限，顯示提示訊息
                              if (_searchLimitReached)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '搜尋結果過多，僅顯示前100筆結果。請使用更精確的關鍵字或過濾選項縮小搜尋範圍。',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _searchResults.length,
                                  padding: const EdgeInsets.all(16),
                                  itemBuilder: (context, index) {
                                    final result = _searchResults[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          // 記錄選擇的經文信息
                                          debugPrint('【導航到聖經頁面】選擇搜尋結果: ${result.book.localName} ${result.reference.chapter}:${result.verse.number}');
                                          
                                          // 獲取書卷和章節信息
                                          final book = result.book;
                                          final chapter = result.reference.chapter;
                                          final verse = result.verse.number;
                                          
                                          debugPrint('【導航】準備導航到聖經頁面: book=${book.id}, chapter=$chapter, verse=$verse');
                                          
                                          // 使用 Navigator.pop 返回上一頁
                                          Navigator.pop(context, {
                                            'book': book,
                                            'chapter': chapter,
                                            'verse': verse,
                                          });
                                          
                                          // 注意：這裡不再使用 Navigator.pushReplacement，而是返回結果給調用頁面
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.primaryContainer,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '${result.book.localName}',
                                                      style: TextStyle(
                                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${result.reference.chapter}:${result.verse.number}',
                                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              ValueListenableBuilder<double>(
                                                valueListenable: widget.fontSizeNotifier,
                                                builder: (context, fontSize, child) {
                                                  return VerseWidget(
                                                    verse: result.verse,
                                                    fontSize: fontSize,
                                                    highlightStart: result.highlightStart,
                                                    highlightLength: result.highlightLength,
                                                    highlightRanges: result.highlightRanges,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
