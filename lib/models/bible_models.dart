import 'package:flutter/material.dart';

/// 聖經書卷模型
class Book {
  final String id;        // 書卷ID (例如: '001', '101')
  final String name;      // 書卷名稱 (例如: 'Genesis', 'Matthew')
  final String localName; // 本地化名稱 (例如: '創世紀', '馬太福音')
  final String shortName; // 縮寫 (例如: 'Ge', 'Mat')
  final bool isOldTestament; // 是否為舊約
  final Map<int, Chapter> chapters; // 章節映射表，鍵為章節號碼

  Book({
    required this.id,
    required this.name,
    required this.localName,
    required this.shortName,
    required this.isOldTestament,
    Map<int, Chapter>? chapters,
  }) : this.chapters = chapters ?? {};

  @override
  String toString() => '$id - $localName ($name)';
  
  // 重寫相等運算符，基於書卷ID進行比較
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book && other.id == id;
  }
  
  // 重寫哈希碼，基於書卷ID計算
  @override
  int get hashCode => id.hashCode;
}

/// 聖經章節模型
class Chapter {
  final int number;       // 章節號碼
  final List<Verse> verses; // 經文列表

  Chapter({
    required this.number,
    this.verses = const [],
  });

  @override
  String toString() => 'Chapter $number (${verses.length} verses)';
  
  // 重寫相等運算符，基於章節號碼進行比較
  // 注意：我們只比較章節號碼，不比較經文列表，因為經文列表可能很大
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chapter && other.number == number;
  }
  
  // 重寫哈希碼，基於章節號碼計算
  @override
  int get hashCode => number.hashCode;
}

/// 聖經經文模型
class Verse {
  final int number;    // 經文號碼
  final String text;   // 經文內容

  Verse({
    required this.number,
    required this.text,
  });

  // 獲取章節 (用於顯示)
  int get chapter => 0; // 這個應該由上下文提供，這裡只是一個佔位符

  @override
  String toString() => '$number: $text';
  
  // 重寫相等運算符，基於經文號碼和內容進行比較
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Verse &&
           other.number == number &&
           other.text == text;
  }
  
  // 重寫哈希碼，基於經文號碼和內容計算
  @override
  int get hashCode => Object.hash(number, text);
}

/// 聖經引用模型 (用於定位特定經文)
class ScriptureReference {
  final String bookId;  // 書卷ID
  final int chapter;    // 章節號碼
  final int? verse;     // 經文號碼 (可選)
  final int? endVerse;  // 結束經文號碼 (可選，用於表示一段經文)

  ScriptureReference({
    required this.bookId,
    required this.chapter,
    this.verse,
    this.endVerse,
  });
  
  // 重寫相等運算符，基於書卷ID、章節號、經文號和結束經文號進行比較
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScriptureReference &&
           other.bookId == bookId &&
           other.chapter == chapter &&
           other.verse == verse &&
           other.endVerse == endVerse;
  }
  
  // 重寫哈希碼，基於書卷ID、章節號、經文號和結束經文號計算
  @override
  int get hashCode => Object.hash(
    bookId,
    chapter,
    verse,
    endVerse,
  );

  // 獲取書卷名稱 (用於顯示)
  String get bookName {
    // 這裡只是返回書卷ID，實際應用中應該通過BibleService獲取真實名稱
    return bookId;
  }

  @override
  String toString() {
    if (verse != null && endVerse != null) {
      return '$bookId $chapter:$verse-$endVerse';
    } else if (verse != null) {
      return '$bookId $chapter:$verse';
    } else {
      return '$bookId $chapter';
    }
  }
}

/// 聖經閱讀歷史記錄
class ReadingHistory {
  final ScriptureReference reference;
  final DateTime timestamp;

  ReadingHistory({
    required this.reference,
    required this.timestamp,
  });

  // 獲取書卷名稱 (用於顯示)
  String get bookName => reference.bookName;
}

/// 聖經書籤 - 已棄用
// class Bookmark {
//   final String id;
//   final ScriptureReference reference;
//   final DateTime createdAt;
//   final DateTime? updatedAt;
//
//   Bookmark({
//     required this.id,
//     required this.reference,
//     required this.createdAt,
//     this.updatedAt,
//   });
// }


/// 聖經高亮
class Highlight {
  final String id;
  final ScriptureReference reference;
  final Color color;
  final DateTime createdAt;

  Highlight({
    required this.id,
    required this.reference,
    required this.color,
    required this.createdAt,
  });
}


/// 聖經筆記 - 已移除
// class Note {
//   final String id;
//   final String title;
//   final String content;
//   final List<ScriptureReference> references; // 筆記中包含的經文引用列表
//   final DateTime createdAt;
//   final DateTime? updatedAt;
//
//   Note({
//     required this.id,
//     required this.title,
//     required this.content,
//     this.references = const [],
//     required this.createdAt,
//     this.updatedAt,
//   });
// }