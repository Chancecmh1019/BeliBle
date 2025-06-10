import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../services/bible_service.dart';

class BookChapterSelector extends StatefulWidget {
  final BibleService bibleService;
  final ScriptureReference currentReference;
  final Function(ScriptureReference) onReferenceSelected;

  const BookChapterSelector({
    super.key,
    required this.bibleService,
    required this.currentReference,
    required this.onReferenceSelected,
  });

  @override
  State<BookChapterSelector> createState() => _BookChapterSelectorState();
}

class _BookChapterSelectorState extends State<BookChapterSelector> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Book _selectedBook;
  late int _selectedChapter;
  late List<Book> _oldTestamentBooks;
  late List<Book> _newTestamentBooks;
  
  // 緩存書卷分類，避免重複計算
  late Map<String, List<Book>> _oldTestamentCategories;
  late Map<String, List<Book>> _newTestamentCategories;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 初始化書籍列表
    _oldTestamentBooks = widget.bibleService.getOldTestamentBooks();
    _newTestamentBooks = widget.bibleService.getNewTestamentBooks();
    
    // 預先分類書卷，避免在構建UI時重複計算
    _initializeBookCategories();
    
    // 設置當前選中的書籍和章節
    _selectedBook = widget.bibleService.getBookById(widget.currentReference.bookId) ?? _oldTestamentBooks.first;
    _selectedChapter = widget.currentReference.chapter;
    
    // 設置初始標籤頁
    _tabController.index = _selectedBook.isOldTestament ? 0 : 1;
  }
  
  // 預先分類書卷
  void _initializeBookCategories() {
    // 舊約分類
    _oldTestamentCategories = {
      '摩西五經': _oldTestamentBooks.where((book) => int.parse(book.id) <= 5).toList(),
      '歷史書': _oldTestamentBooks.where((book) => int.parse(book.id) > 5 && int.parse(book.id) <= 17).toList(),
      '詩歌書': _oldTestamentBooks.where((book) => int.parse(book.id) > 17 && int.parse(book.id) <= 22).toList(),
      '大先知書': _oldTestamentBooks.where((book) => int.parse(book.id) > 22 && int.parse(book.id) <= 27).toList(),
      '小先知書': _oldTestamentBooks.where((book) => int.parse(book.id) > 27).toList(),
    };
    
    // 新約分類
    _newTestamentCategories = {
      '福音書': _newTestamentBooks.where((book) => int.parse(book.id) >= 101 && int.parse(book.id) <= 104).toList(),
      '使徒行傳': _newTestamentBooks.where((book) => int.parse(book.id) == 105).toList(),
      '保羅書信': _newTestamentBooks.where((book) => int.parse(book.id) >= 106 && int.parse(book.id) <= 118).toList(),
      '一般書信': _newTestamentBooks.where((book) => int.parse(book.id) >= 119 && int.parse(book.id) <= 126).toList(),
      '啟示錄': _newTestamentBooks.where((book) => int.parse(book.id) == 127).toList(),
    };
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // 獲取章節數量
  int _getChapterCount(String bookId) {
    return widget.bibleService.getBookChapterCount(bookId);
  }
  
  // 選擇書籍
  void _selectBook(Book book) {
    setState(() {
      _selectedBook = book;
      // 如果當前選中的章節超出了新書的章節數量，則重置為第一章
      final chapterCount = _getChapterCount(book.id);
      if (_selectedChapter > chapterCount) {
        _selectedChapter = 1;
      }
    });
  }
  
  // 選擇章節
  void _selectChapter(int chapter) {
    setState(() {
      _selectedChapter = chapter;
    });
    
    // 通知父組件選擇已更改
    widget.onReferenceSelected(ScriptureReference(
      bookId: _selectedBook.id,
      chapter: _selectedChapter,
      verse: widget.currentReference.verse, // 保留原來的經節信息
      endVerse: widget.currentReference.endVerse, // 同時保留結束經節信息
    ));
    
    // 關閉底部彈出窗口
    Navigator.pop(context);
  }
  
  // 構建書籍列表項 - 使用const構造函數優化性能
  Widget _buildBookItem(Book book) {
    final isSelected = book.id == _selectedBook.id;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          book.localName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
          ),
        ),
        subtitle: Text(
          book.name,
          style: TextStyle(
            fontSize: 12,
            color: isSelected 
                ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7) 
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.surfaceVariant,
          child: Text(
            book.shortName,
            style: TextStyle(
              color: isSelected 
                  ? Theme.of(context).colorScheme.onPrimary 
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        selected: isSelected,
        onTap: () => _selectBook(book),
      ),
    );
  }
  
  // 構建舊約書卷列表 - 使用緩存的分類
  Widget _buildOldTestament() {
    return ListView(
      // 防止滾動衝突
      physics: const ClampingScrollPhysics(),
      children: _oldTestamentCategories.entries.map((entry) {
        return _buildBookCategory(entry.key, entry.value);
      }).toList(),
    );
  }

  // 構建新約書卷列表 - 使用緩存的分類
  Widget _buildNewTestament() {
    return ListView(
      // 防止滾動衝突
      physics: const ClampingScrollPhysics(),
      children: _newTestamentCategories.entries.map((entry) {
        return _buildBookCategory(entry.key, entry.value);
      }).toList(),
    );
  }
  
  // 構建書卷分類 - 使用Column和List.generate優化性能
  Widget _buildBookCategory(String title, List<Book> books) {
    // 確保每個書卷只顯示一次
    final uniqueBooks = <String, Book>{};
    for (var book in books) {
      uniqueBooks[book.id] = book;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...uniqueBooks.values.map((book) => _buildBookItem(book)).toList(),
      ],
    );
  }
  
  // 構建章節網格 - 使用const構造函數和緩存優化性能
  Widget _buildChapterGrid() {
    final chapterCount = _getChapterCount(_selectedBook.id);
    
    // 根據螢幕寬度調整網格列數
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400; // 小螢幕設備
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        // 在小螢幕上減少列數，增加按鈕大小
        crossAxisCount: isSmallScreen ? 4 : 5,
        childAspectRatio: 1,
        crossAxisSpacing: isSmallScreen ? 8 : 12,
        mainAxisSpacing: isSmallScreen ? 8 : 12,
      ),
      itemCount: chapterCount,
      itemBuilder: (context, index) {
        final chapterNumber = index + 1;
        final isSelected = chapterNumber == _selectedChapter;
        
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _selectChapter(chapterNumber),
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                chapterNumber.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  // 增加字體大小
                  fontSize: isSmallScreen ? 18 : 16,
                  color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 頂部拖動條
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 標題和關閉按鈕
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  '選擇書卷和章節',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // 當前選中的書卷和章節
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  radius: 24,
                  child: Text(
                    _selectedBook.shortName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedBook.localName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedBook.name} • 第${_selectedChapter}章',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 標籤頁
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '舊約'),
                Tab(text: '新約'),
              ],
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(30),
              ),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
              padding: const EdgeInsets.all(4),
            ),
          ),
          
          // 內容區域
          Expanded(
            child: Row(
              children: [
                // 書卷列表
                Expanded(
                  flex: 2,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(), // 防止滑動切換，避免重複加載
                    children: [
                      _buildOldTestament(),
                      _buildNewTestament(),
                    ],
                  ),
                ),
                
                // 分隔線
                VerticalDivider(width: 1, thickness: 1, color: Theme.of(context).dividerColor),
                
                // 章節網格
                Expanded(
                  flex: 3,
                  child: _buildChapterGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}