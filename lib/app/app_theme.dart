import 'package:dashboard/app/config_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme with ChangeNotifier {
  AppTheme() {
    changeThemeMode(ConfigHelper.getThemeMode());
    changeThemeColor(ConfigHelper.getAppTheme());
  }

  static Map<String, ThemeMode> themeModes = {
    "跟随系统": ThemeMode.system,
    "开启": ThemeMode.dark,
    "关闭": ThemeMode.light,
  };

  static Map<String, Color> themeColors = {
    "胖次蓝": Colors.blue,
    "姨妈红": Colors.red,
    "咸蛋黄": Colors.yellow,
    "早苗绿": Colors.green,
    "少女粉": Colors.pink,
    "基佬紫": Colors.purple,
    "朴素灰": Colors.blueGrey,
  };

  ThemeMode? _themeMode;
  String? _themeModeName;

  ThemeMode get themeMode => _themeMode ?? ThemeMode.system;

  String get themeModeName => _themeModeName ?? '跟随系统';

  void changeThemeMode(int index) {
    _themeMode = AppTheme.themeModes.values.toList()[index];
    _themeModeName = AppTheme.themeModes.keys.toList()[index];
    notifyListeners();
    ConfigHelper.setThemeMode(index);
  }

  void showThemeModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('夜间模式'),
          children: _createThemeModeWidget(context),
        );
      },
    );
  }

  List<Widget> _createThemeModeWidget(BuildContext context) {
    return [
      RadioGroup<String>(
        groupValue: _themeModeName,
        onChanged: (value) {
          if (value == null) return;
          changeThemeMode(AppTheme.themeModes.keys.toList().indexOf(value));
          Navigator.of(context).pop();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in AppTheme.themeModes.keys)
              RadioListTile<String>(value: item, title: Text(item)),
          ],
        ),
      ),
    ];
  }

  Color? _themeColor;
  String? _themeColorName;

  Color get themeColor => _themeColor ?? Colors.blue;

  String get themeColorName => _themeColorName ?? '胖次蓝';

  ThemeData themeFor(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: themeColor,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;
    final surface = isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1A1D23);
    final scaffold = isLight
        ? const Color(0xFFF7F8FA)
        : const Color(0xFF111318);
    final divider = scheme.outlineVariant;
    final statusBarIcons = scheme.onPrimary.computeLuminance() > 0.5
        ? Brightness.light
        : Brightness.dark;
    final statusBarBackground = scheme.primary.computeLuminance() > 0.5
        ? Brightness.light
        : Brightness.dark;
    final navigationBarIcons = surface.computeLuminance() > 0.5
        ? Brightness.dark
        : Brightness.light;

    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scaffold,
      cardColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: scheme.primary,
          statusBarIconBrightness: statusBarIcons,
          statusBarBrightness: statusBarBackground,
          systemNavigationBarColor: surface,
          systemNavigationBarIconBrightness: navigationBarIcons,
          systemNavigationBarDividerColor: divider,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
    );
  }

  void changeThemeColor(int index) {
    _themeColor = AppTheme.themeColors.values.toList()[index];
    _themeColorName = AppTheme.themeColors.keys.toList()[index];
    notifyListeners();
    ConfigHelper.setAppTheme(index);
  }

  void showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('切换主题'),
          children: _createThemeWidget(context),
        );
      },
    );
  }

  List<Widget> _createThemeWidget(BuildContext context) {
    return [
      RadioGroup<String>(
        groupValue: _themeColorName,
        onChanged: (value) {
          if (value == null) return;
          changeThemeColor(AppTheme.themeColors.keys.toList().indexOf(value));
          Navigator.of(context).pop();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in AppTheme.themeColors.keys)
              RadioListTile<String>(
                value: item,
                title: Text(
                  item,
                  style: TextStyle(color: AppTheme.themeColors[item]),
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
