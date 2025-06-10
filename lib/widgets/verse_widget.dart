import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../theme/app_theme.dart';

class VerseWidget extends StatelessWidget {
  final Verse verse;
  final double fontSize;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap; // 添加點擊事件回調
  final Color? highlightColor; // 高亮顏色
  final int? highlightStart; // 高亮開始位置 (舊版兼容)
  final int? highlightLength; // 高亮長度 (舊版兼容)
  final List<Map<String, int>>? highlightRanges; // 多個高亮區域 [{"start": 開始位置, "length": 長度}]

  const VerseWidget({
    super.key,
    required this.verse,
    this.fontSize = 18.0,
    this.onLongPress,
    this.onTap, // 添加點擊事件參數
    this.highlightColor,
    this.highlightStart,
    this.highlightLength,
    this.highlightRanges,
  });

  @override
  Widget build(BuildContext context) {
    // 獲取當前主題亮度
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap, // 添加點擊事件處理
        borderRadius: BorderRadius.circular(12), // 增加圓角半徑
        child: Container(
          padding: const EdgeInsets.all(6), // 增加內邊距
          decoration: BoxDecoration(
            // 直接使用高亮顏色，不調整透明度
            color: highlightColor,
            borderRadius: BorderRadius.circular(12), // 增加圓角半徑
            // 添加更明顯的邊框以增強可見度
            border: highlightColor != null ? Border.all(
              color: isDarkMode 
                ? Colors.white70 
                : Colors.grey.shade800,
              width: 1.5, // 減少邊框寬度
            ) : null,
            // 添加陰影效果增強視覺效果
            boxShadow: highlightColor != null ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3,
                spreadRadius: 1,
              ),
            ] : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 經文號
              SizedBox(
                width: 32,
                child: Text(
                  '${verse.number}',
                  style: AppTheme.verseNumberStyle(context).copyWith(
                    fontSize: fontSize - 2,
                    // 確保經文號在高亮背景上清晰可見
                  color: highlightColor != null 
                    ? Colors.black
                    : Theme.of(context).colorScheme.primary,
                  fontWeight: highlightColor != null ? FontWeight.w900 : FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              // 經文內容
              Expanded(
                child: _buildVerseText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 構建經文文本，支持高亮顯示
  Widget _buildVerseText(BuildContext context) {
    // 獲取當前主題亮度
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 如果沒有高亮，直接顯示完整文本
    if ((highlightStart == null || highlightLength == null || highlightStart! < 0 || highlightStart! + highlightLength! > verse.text.length) && 
        (highlightRanges == null || highlightRanges!.isEmpty)) {
      return Text(
        verse.text,
        style: AppTheme.verseTextStyle(context).copyWith(
          fontSize: fontSize,
          // 根據主題調整文字顏色，確保在高亮背景上清晰可見
          color: highlightColor != null 
            ? Colors.black // 統一使用黑色文字以增強對比度
            : null,
          fontWeight: highlightColor != null ? FontWeight.w600 : null,
          backgroundColor: null, // 移除文本背景色，因为已经有Container背景色
        ),
      );
    }

    // 有高亮，使用 RichText 顯示
    final TextStyle baseStyle = AppTheme.verseTextStyle(context).copyWith(
      fontSize: fontSize,
      // 保持原始文字顏色
      color: null,
    );
    
    // 高亮樣式 - 根據主題模式調整文字顏色
    final TextStyle highlightStyle = baseStyle.copyWith(
      backgroundColor: highlightColor, // 使用与Container相同的颜色
      fontWeight: FontWeight.bold,
      // 根據主題模式調整文字顏色
      color: isDarkMode ? Colors.white : Colors.black, // 深色模式下使用白色，淺色模式下使用黑色
      letterSpacing: 0.6, // 增加字間距
      height: 1.6, // 增加行高
    );

    // 使用新的 highlightRanges 屬性
    if (highlightRanges != null && highlightRanges!.isNotEmpty) {
      // 按照開始位置排序高亮區域
      final sortedRanges = List<Map<String, int>>.from(highlightRanges!)
        ..sort((a, b) => a['start']! - b['start']!);
      
      // 創建 TextSpan 列表
      List<TextSpan> spans = [];
      int currentPos = 0;
      
      for (var range in sortedRanges) {
        final start = range['start']!;
        final length = range['length']!;
        
        // 確保範圍有效
        if (start < 0 || start + length > verse.text.length) continue;
        
        // 添加高亮前的文本
        if (start > currentPos) {
          spans.add(TextSpan(
            text: verse.text.substring(currentPos, start),
            style: baseStyle,
          ));
        }
        
        // 添加高亮文本
        spans.add(TextSpan(
          text: verse.text.substring(start, start + length),
          style: highlightStyle,
        ));
        
        currentPos = start + length;
      }
      
      // 添加最後一段文本
      if (currentPos < verse.text.length) {
        spans.add(TextSpan(
          text: verse.text.substring(currentPos),
          style: baseStyle,
        ));
      }
      
      return RichText(text: TextSpan(children: spans));
    }
    
    // 舊版兼容：使用單一高亮區域
    return RichText(
      text: TextSpan(
        children: [
          // 高亮前的文本
          if (highlightStart! > 0)
            TextSpan(
              text: verse.text.substring(0, highlightStart!),
              style: baseStyle,
            ),
          // 高亮的文本
          TextSpan(
            text: verse.text.substring(highlightStart!, highlightStart! + highlightLength!),
            style: highlightStyle,
          ),
          // 高亮後的文本
          if (highlightStart! + highlightLength! < verse.text.length)
            TextSpan(
              text: verse.text.substring(highlightStart! + highlightLength!),
              style: baseStyle,
            ),
        ],
      ),
    );
  }
}