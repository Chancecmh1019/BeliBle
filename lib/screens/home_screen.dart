import 'package:flutter/material.dart';
import 'package:belible/screens/book_select_screen.dart';
// 移除筆記頁面的導入
// import 'package:belible/screens/notes_screen.dart';
import 'package:belible/screens/search_screen.dart';
import 'package:belible/screens/settings_screen.dart';
// 移除筆記編輯頁面的導入
// import 'package:belible/screens/note_edit_screen.dart';
import 'package:belible/services/bible_service.dart';
import 'package:belible/services/storage_service.dart';
import 'package:belible/models/bible_models.dart';

class HomeScreen extends StatefulWidget {
  final BibleService bibleService;
  final StorageService storageService;
  final ValueNotifier<ThemeMode> themeNotifier;
  final ValueNotifier<double> fontSizeNotifier;
  final String? initialBookId;
  final int? initialChapter;
  final int? initialVerse;

  const HomeScreen({
    super.key,
    required this.bibleService,
    required this.storageService,
    required this.themeNotifier,
    required this.fontSizeNotifier,
    this.initialBookId,
    this.initialChapter,
    this.initialVerse,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  bool _isLoading = true;
  String _errorMessage = '';

  // 使用 GlobalKey 來訪問 BookSelectScreen 的 State
  final GlobalKey<BookSelectScreenState> _bookSelectScreenKey = GlobalKey<BookSelectScreenState>();

  // 頁面列表
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    
    // 初始化服務
    _initializeServices().then((_) {
      // 如果提供了初始化經文參數，加載指定經文
      if (widget.initialBookId != null && widget.initialChapter != null) {
        _loadInitialScripture();
      }
    });
    
    // 添加頁面返回監聽器，用於處理從 DashboardScreen 返回時的標籤切換請求
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 設置頁面返回結果處理
      Navigator.of(context).popUntil((route) {
        if (route is MaterialPageRoute && route.settings.name == null) {
          final result = route.currentResult;
          if (result != null && result is int) {
            _onBottomNavTapped(result);
          }
        }
        return true;
      });
      
      // 處理路由參數
      _handleRouteArguments();
    });
  }
  
  // 處理路由參數 - 改為異步方法
  Future<void> _handleRouteArguments() async {
    final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      debugPrint('收到路由參數: $args');
      
      try {
        // 處理頁面索引
        if (args.containsKey('tabIndex')) {
          final int tabIndex = args['tabIndex'] as int;
          debugPrint('切換到頁面索引: $tabIndex');
          _onBottomNavTapped(tabIndex);
          
          // 等待頁面切換完成
          await Future.delayed(const Duration(milliseconds: 300));
        }
        
        // 處理經文參數 - 傳遞給 BookSelectScreen
        if (args.containsKey('book') && args.containsKey('chapter')) {
          debugPrint('準備加載經文: ${args['book']} ${args['chapter']}:${args['verse']}');
          
          // 使用 GlobalKey 獲取 BookSelectScreen 的 State
          final bookSelectScreenState = _bookSelectScreenKey.currentState;
          
          if (bookSelectScreenState != null) {
            final dynamic bookArg = args['book'];
            Book? book;
            
            // 處理不同類型的 book 參數
            if (bookArg is Book) {
              // 如果已經是 Book 對象，直接使用
              book = bookArg;
              debugPrint('取得 Book 對象: ${book.localName}');
            } else if (bookArg is String) {
              // 如果是 bookId 字符串，通過 BibleService 獲取 Book 對象
              book = widget.bibleService.getBookById(bookArg);
              debugPrint('通過 ID 取得 Book 對象: ${book?.localName ?? "null"}, ID: $bookArg');
              
              // 如果找不到書卷，記錄詳細信息
              if (book == null) {
                debugPrint('【錯誤】無法通過 ID $bookArg 找到書卷，這可能是導航問題的原因');
                // 嘗試列出所有有效的書卷ID
                final allBooks = widget.bibleService.getAllBooks();
                debugPrint('【調試】可用的書卷數量: ${allBooks.length}');
                if (allBooks.isNotEmpty) {
                  debugPrint('【調試】示例書卷: ${allBooks.first.id} - ${allBooks.first.localName}');
                }
              }
            } else {
              debugPrint('未知的 book 參數類型: ${bookArg.runtimeType}');
            }
            
            if (book != null) {
              final int chapter = args['chapter'] as int;
              final int? verse = args['verse'] as int?;
              
              // 加載指定經文
              debugPrint('呼叫 loadScripture: ${book.localName} $chapter${verse != null ? ":$verse" : ""}');
              bookSelectScreenState.loadScripture(book, chapter, verse);
              
              // 等待經文加載完成
              await Future.delayed(const Duration(milliseconds: 300));
              debugPrint('經文加載完成');
            } else {
              debugPrint('無法加載經文：無效的書卷參數 ${args['book']}');
            }
          } else {
            debugPrint('無法獲取 BookSelectScreen 狀態');
          }
        }
      } catch (e) {
        debugPrint('處理路由參數錯誤: $e');
      }
    }
  }

  // 初始化服務
  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 初始化聖經服務
      await widget.bibleService.initialize();
      // 初始化存儲服務
      await widget.storageService.initialize();

      // 初始化頁面 - 移除筆記頁面
      _pages = [
        BookSelectScreen(
          key: _bookSelectScreenKey,
          bibleService: widget.bibleService,
          storageService: widget.storageService,
          fontSizeNotifier: widget.fontSizeNotifier,
        ),
        // 移除筆記頁面
        // NotesScreen(
        //   bibleService: widget.bibleService,
        //   storageService: widget.storageService,
        //   fontSizeNotifier: widget.fontSizeNotifier,
        // ),
        SettingsScreen(
          storageService: widget.storageService,
          themeNotifier: widget.themeNotifier,
          fontSizeNotifier: widget.fontSizeNotifier,
        ),
      ];

      setState(() {
        _isLoading = false;
      });
      
      debugPrint('服務初始化完成');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化失敗: $e';
      });
      
      debugPrint('服務初始化失敗: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 切換頁面 - 添加更流暢的動畫
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // 切換底部導航欄 - 添加更流暢的動畫
  void _onBottomNavTapped(int index) {
    // 使用頁面控制器平滑切換頁面
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuint,
    );
  }

  // 加載初始經文
  void _loadInitialScripture() {
    // 確保已經初始化完成
    if (_isLoading) {
      debugPrint('服務尚未初始化完成，延遲加載初始經文');
      Future.delayed(const Duration(milliseconds: 500), _loadInitialScripture);
      return;
    }
    
    debugPrint('加載初始經文: ${widget.initialBookId} ${widget.initialChapter}:${widget.initialVerse}');
    
    // 獲取 BookSelectScreen 狀態
    final bookSelectScreenState = _bookSelectScreenKey.currentState;
    if (bookSelectScreenState == null) {
      debugPrint('無法獲取 BookSelectScreen 狀態');
      return;
    }
    
    // 通過 bookId 獲取 Book 對象
    final book = widget.bibleService.getBookById(widget.initialBookId!);
    if (book == null) {
      debugPrint('【錯誤】無法找到書卷: ${widget.initialBookId}');
      // 嘗試列出所有有效的書卷ID
      final allBooks = widget.bibleService.getAllBooks();
      debugPrint('【調試】可用的書卷數量: ${allBooks.length}');
      if (allBooks.isNotEmpty) {
        debugPrint('【調試】示例書卷: ${allBooks.first.id} - ${allBooks.first.localName}');
      }
      return;
    }
    
    debugPrint('【成功】找到書卷: ${book.id} - ${book.localName} (${book.name})');
    
    // 確保當前顯示的是聖經頁面（索引 0）
    if (_currentIndex != 0) {
      _onBottomNavTapped(0);
    }
    
    // 延遲一下再加載經文，確保頁面已經切換
    Future.delayed(const Duration(milliseconds: 300), () {
      // 加載指定經文
      bookSelectScreenState.loadScripture(book, widget.initialChapter!, widget.initialVerse);
      debugPrint('初始經文加載完成');
    });
  }

  // 創建新筆記 - 移除此方法
  // void _createNewNote() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => NoteEditScreen(
  //         bibleService: widget.bibleService,
  //         storageService: widget.storageService,
  //         fontSizeNotifier: widget.fontSizeNotifier,
  //       ),
  //     ),
  //   ).then((result) {
  //     // 如果返回 true，表示已保存筆記，需要刷新筆記列表
  //     if (result == true && _currentIndex == 1) {
  //       // 如果當前在筆記頁面，刷新筆記列表
  //       setState(() {
  //         // 重新構建頁面以刷新筆記列表
  //         _pages[1] = NotesScreen(
  //           bibleService: widget.bibleService,
  //           storageService: widget.storageService,
  //           fontSizeNotifier: widget.fontSizeNotifier,
  //         );
  //       });
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    // 顯示加載中
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('載入聖經中...', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    // 顯示錯誤
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
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
                onPressed: _initializeServices,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    // 主頁面
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const PageScrollPhysics(), // 允許滑動切換
        children: _pages.asMap().entries.map((entry) {
          // 為每個頁面添加淡入效果
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _currentIndex == entry.key
                ? FadeTransition(
                    opacity: AlwaysStoppedAnimation(1.0),
                    child: entry.value,
                  )
                : Opacity(
                    opacity: 0.3,
                    child: entry.value,
                  ),
          );
        }).toList(),
      ),
      // 移除浮動按鈕
      // floatingActionButton: _currentIndex == 1
      //     ? FloatingActionButton(
      //         onPressed: _createNewNote,
      //         tooltip: '新增筆記',
      //         child: const Icon(Icons.add),
      //       )
      //     : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onBottomNavTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '聖經',
          ),
          // 移除筆記選項
          // NavigationDestination(
          //   icon: Icon(Icons.note_alt_outlined),
          //   selectedIcon: Icon(Icons.note_alt),
          //   label: '筆記',
          // ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}