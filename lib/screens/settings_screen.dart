import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'license_screen.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final ValueNotifier<double>? fontSizeNotifier;

  const SettingsScreen({
    Key? key,
    required this.storageService,
    this.themeNotifier,
    this.fontSizeNotifier,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 18.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    // 如果有 themeNotifier，監聽其變化
    widget.themeNotifier?.addListener(_updateThemeFromNotifier);
    
    // 如果有 fontSizeNotifier，監聽其變化
    widget.fontSizeNotifier?.addListener(_updateFontSizeFromNotifier);
  }
  
  @override
  void dispose() {
    // 移除監聽器
    widget.themeNotifier?.removeListener(_updateThemeFromNotifier);
    widget.fontSizeNotifier?.removeListener(_updateFontSizeFromNotifier);
    super.dispose();
  }
  
  // 從 themeNotifier 更新主題
  void _updateThemeFromNotifier() {
    if (widget.themeNotifier != null && mounted) {
      setState(() {
        _themeMode = widget.themeNotifier!.value;
      });
    }
  }
  
  // 從 fontSizeNotifier 更新字體大小
  void _updateFontSizeFromNotifier() {
    if (widget.fontSizeNotifier != null && mounted) {
      setState(() {
        _fontSize = widget.fontSizeNotifier!.value;
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final themeMode = await widget.storageService.loadThemeMode();
      final fontSize = await widget.storageService.loadFontSize();

      setState(() {
        _themeMode = themeMode;
        _fontSize = fontSize;
        _isLoading = false;
      });
      
      // 更新 notifier 值
      if (widget.themeNotifier != null && widget.themeNotifier!.value != themeMode) {
        widget.themeNotifier!.value = themeMode;
      }
      
      if (widget.fontSizeNotifier != null && widget.fontSizeNotifier!.value != fontSize) {
        widget.fontSizeNotifier!.value = fontSize;
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showCustomSnackBar('載入設定失敗: $e');
    }
  }

  void showCustomSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _updateThemeMode(ThemeMode? themeMode) async {
    if (themeMode == null) return;

    setState(() {
      _isLoading = true;
      _themeMode = themeMode;
    });

    try {
      await widget.storageService.saveThemeMode(themeMode);
      // 同時更新 AppTheme 中的靜態主題模式
      AppTheme.setThemeMode(themeMode);
      
      // 更新 themeNotifier
      if (widget.themeNotifier != null) {
        widget.themeNotifier!.value = themeMode;
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showCustomSnackBar('更新主題失敗: $e');
    }
  }

  Future<void> _updateFontSize(double fontSize) async {
    setState(() {
      _isLoading = true;
      _fontSize = fontSize;
    });

    try {
      await widget.storageService.saveFontSize(fontSize);
      
      // 更新 fontSizeNotifier
      if (widget.fontSizeNotifier != null) {
        widget.fontSizeNotifier!.value = fontSize;
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showCustomSnackBar('更新字體大小失敗: $e');
    }
  }

  // 構建區塊標題
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  // 構建設定卡片
  Widget _buildSettingCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  // 構建設定項目
  Widget _buildSettingItem(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // 構建主題選項
  Widget _buildThemeOption(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: selected ? colorScheme.primary : null,
                          fontWeight: selected ? FontWeight.bold : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        centerTitle: true,
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: colorScheme.onPrimary,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // 外觀設定區塊
                _buildSectionHeader(context, '外觀設定', Icons.palette_outlined),
                
                // 主題設定
                _buildSettingCard(
                  context,
                  title: '外觀主題',
                  icon: Icons.brightness_6_outlined,
                  child: Column(
                    children: [
                      _buildThemeOption(
                        context,
                        title: '跟隨系統',
                        subtitle: '根據系統設定自動切換淺色或深色主題',
                        icon: Icons.brightness_auto,
                        selected: _themeMode == ThemeMode.system,
                        onTap: () => _updateThemeMode(ThemeMode.system),
                      ),
                      const Divider(),
                      _buildThemeOption(
                        context,
                        title: '淺色主題',
                        subtitle: '始終使用淺色主題',
                        icon: Icons.light_mode_outlined,
                        selected: _themeMode == ThemeMode.light,
                        onTap: () => _updateThemeMode(ThemeMode.light),
                      ),
                      const Divider(),
                      _buildThemeOption(
                        context,
                        title: '深色主題',
                        subtitle: '始終使用深色主題',
                        icon: Icons.dark_mode_outlined,
                        selected: _themeMode == ThemeMode.dark,
                        onTap: () => _updateThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),

                // 字體大小設定
                _buildSettingCard(
                  context,
                  title: '經文字體大小',
                  icon: Icons.format_size,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('A', 
                              style: TextStyle(
                                fontSize: 14, 
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _fontSize,
                                min: 14,
                                max: 30,
                                divisions: 8,
                                label: _fontSize.round().toString(),
                                onChanged: (value) {
                                  setState(() {
                                    _fontSize = value;
                                  });
                                },
                                onChangeEnd: (value) {
                                  _updateFontSize(value);
                                },
                              ),
                            ),
                            Text('A', 
                              style: TextStyle(
                                fontSize: 30, 
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                
                // 關於區塊
                _buildSectionHeader(context, '關於', Icons.info_outline),
                

                
                // Flutter 授權頁面
                _buildSettingItem(
                  context,
                  title: 'Flutter 授權資訊',
                  subtitle: '查看應用程式使用的開源套件授權',
                  icon: Icons.policy_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LicenseScreen(),
                      ),
                    );
                  },
                ),
                
                // 關於應用程式
                _buildSettingCard(
                  context,
                  title: '關於應用程式',
                  icon: Icons.app_shortcut,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('應用程式版本'),
                        subtitle: const Text('1.0.0'),
                        leading: Icon(Icons.new_releases_outlined, color: colorScheme.primary),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('開發者'),
                        subtitle: const Text('相信·聖經'),
                        leading: Icon(Icons.code, color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}