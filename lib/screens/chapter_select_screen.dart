import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../services/bible_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class ChapterSelectScreen extends StatelessWidget {
  final Book book;
  final BibleService bibleService;
  final StorageService? storageService;
  final ValueNotifier<double>? fontSizeNotifier;

  const ChapterSelectScreen({
    super.key, 
    required this.book,
    required this.bibleService,
    this.storageService,
    this.fontSizeNotifier,
  });

  // 獲取章節數量
  int _getChapterCount() {
    // 使用預定義的章節數量
    final Map<String, int> chapterCounts = {
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

    return chapterCounts[book.id] ?? 0;
  }

  // 導航到主頁並顯示選定的章節
  void _navigateToReading(BuildContext context, int chapterNumber) {
    // 導航回主頁並切換到聖經頁面
    Navigator.popUntil(context, ModalRoute.withName('/'));
    Navigator.pushReplacementNamed(
      context,
      '/',
      arguments: {
        'tabIndex': 0, // 切換到聖經頁面
        'book': book,
        'chapter': chapterNumber,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int chapterCount = _getChapterCount();

    return Scaffold(
      appBar: AppBar(
        title: Text(book.localName),
      ),
      body: Column(
        children: [
          // 書卷信息
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                // 書卷圖標
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      book.shortName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 書卷詳情
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.localName,
                        style: AppTheme.bookTitleStyle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${book.name} • $chapterCount章',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 章節網格
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                // 根據螢幕寬度調整網格列數
                crossAxisCount: MediaQuery.of(context).size.width < 400 ? 4 : 5,
                childAspectRatio: 1,
                crossAxisSpacing: MediaQuery.of(context).size.width < 400 ? 10 : 8,
                mainAxisSpacing: MediaQuery.of(context).size.width < 400 ? 10 : 8,
              ),
              itemCount: chapterCount,
              itemBuilder: (context, index) {
                final chapterNumber = index + 1;
                final isSmallScreen = MediaQuery.of(context).size.width < 400;
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => _navigateToReading(context, chapterNumber),
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Text(
                        chapterNumber.toString(),
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          // 在小螢幕上增加字體大小
                          fontSize: isSmallScreen ? 22 : 20,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}