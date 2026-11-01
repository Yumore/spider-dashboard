import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _buildArguments = <String, List<String>>{
  'android': ['build', 'apk', '--release'],
  'ios': ['build', 'ipa', '--release'],
  'macos': ['build', 'macos', '--release'],
  'windows': ['build', 'windows', '--release'],
  'linux': ['build', 'linux', '--release'],
  'web': ['build', 'web', '--release', '--no-wasm-dry-run'],
  'ohos': ['build', 'hap', '--release'],
};

Future<void> main(List<String> arguments) async {
  exitCode = await PlatformPackager(arguments).run();
}

class PlatformPackager {
  PlatformPackager(this.arguments);

  final List<String> arguments;

  Future<int> run() async {
    if (arguments.isEmpty ||
        arguments.contains('--help') ||
        arguments.contains('-h')) {
      _printUsage();
      return arguments.isEmpty ? 64 : 0;
    }

    final target = arguments.first.toLowerCase() == 'harmony'
        ? 'ohos'
        : arguments.first.toLowerCase();
    final dryRun = arguments.skip(1).contains('--dry-run');
    final unexpected = arguments
        .skip(1)
        .where((argument) => argument != '--dry-run')
        .toList();
    if (unexpected.isNotEmpty) {
      stderr.writeln('不支持的参数：${unexpected.join(' ')}');
      _printUsage();
      return 64;
    }

    if (target == 'setup-ohos') {
      return _setupOhos(dryRun: dryRun);
    }
    final buildArguments = _buildArguments[target];
    if (buildArguments == null) {
      stderr.writeln('不支持的平台：$target');
      _printUsage();
      return 64;
    }

    try {
      _requireProjectRoot();
      if (!dryRun) {
        _requireBuildHost(target);
        await _checkFlutterSdk(target);
        if (target == 'ohos') _requireOhosProject();
      }

      final flutter = _flutterExecutable(target, allowMissingOhos: dryRun);
      stdout.writeln('执行：${_formatCommand(flutter, buildArguments)}');
      if (dryRun) {
        stdout.writeln('模拟模式：未启动构建，也未检查本机工具链。');
        return 0;
      }

      final process = await Process.start(
        flutter,
        buildArguments,
        mode: ProcessStartMode.inheritStdio,
        runInShell: Platform.isWindows,
      );
      final result = await process.exitCode;
      if (result != 0) {
        stderr.writeln('Flutter 构建失败，退出码：$result');
        return result;
      }

      final artifacts = await _findArtifacts(target);
      if (artifacts.isEmpty) {
        stderr.writeln('构建命令成功，但未找到预期的 $target 产物。');
        return 1;
      }
      stdout.writeln('打包完成：');
      for (final artifact in artifacts) {
        stdout.writeln('  $artifact');
      }
      return 0;
    } on Object catch (error) {
      stderr.writeln(error);
      return 2;
    }
  }

  Future<int> _setupOhos({required bool dryRun}) async {
    try {
      _requireProjectRoot();
      final flutter = _flutterExecutable('ohos', allowMissingOhos: dryRun);
      if (!dryRun) await _checkFlutterSdk('ohos');
      if (Directory('ohos').existsSync()) {
        stdout.writeln('已存在 ohos/ 工程目录，未覆盖现有文件。');
        return 0;
      }

      const arguments = ['create', '--platforms=ohos', '.'];
      stdout.writeln('执行：${_formatCommand(flutter, arguments)}');
      if (dryRun) {
        stdout.writeln('模拟模式：未生成 OHOS 工程文件。');
        return 0;
      }
      final process = await Process.start(
        flutter,
        arguments,
        mode: ProcessStartMode.inheritStdio,
        runInShell: Platform.isWindows,
      );
      final result = await process.exitCode;
      if (result == 0) {
        stdout.writeln('OHOS 工程已生成；检查插件适配和签名配置后再打 HAP。');
      }
      return result;
    } on Object catch (error) {
      stderr.writeln(error);
      return 2;
    }
  }

  void _requireProjectRoot() {
    if (!File('pubspec.yaml').existsSync()) {
      throw StateError('请从 Flutter 工程根目录运行此脚本。');
    }
  }

  void _requireBuildHost(String target) {
    final requiredHost = switch (target) {
      'ios' || 'macos' => 'macOS',
      'windows' => 'Windows',
      'linux' => 'Linux',
      _ => null,
    };
    if (requiredHost == null) return;

    final isCorrectHost = switch (requiredHost) {
      'macOS' => Platform.isMacOS,
      'Windows' => Platform.isWindows,
      'Linux' => Platform.isLinux,
      _ => false,
    };
    if (!isCorrectHost) {
      throw StateError('$target 发布构建必须在 $requiredHost 主机上运行。');
    }
  }

  Future<void> _checkFlutterSdk(String target) async {
    final flutter = _flutterExecutable(target);
    final versionResult = await _runVersionCommand(flutter);
    if (versionResult.exitCode != 0) {
      throw StateError('无法读取 Flutter SDK 版本：${versionResult.stderr}');
    }

    final versionInfo = jsonDecode(versionResult.stdout);
    if (versionInfo is! Map<String, dynamic>) {
      throw const FormatException('Flutter --version --machine 返回了无效数据。');
    }
    final flutterVersion = versionInfo['frameworkVersion']?.toString() ?? '';
    final dartVersion = versionInfo['dartSdkVersion']?.toString() ?? '';
    if (!_meetsMinimumVersion(flutterVersion, 3, 32, 0) ||
        !_meetsMinimumVersion(dartVersion, 3, 8, 0)) {
      throw StateError(
        '本工程需要 Flutter >=3.32.0 / Dart >=3.8.0；'
        '当前为 Flutter $flutterVersion / Dart $dartVersion。',
      );
    }
  }

  Future<({int exitCode, String stdout, String stderr})> _runVersionCommand(
    String flutter,
  ) async {
    final process = await Process.start(flutter, [
      '--version',
      '--machine',
    ], runInShell: Platform.isWindows);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCodeFuture = process.exitCode;
    try {
      final exitCode = await exitCodeFuture.timeout(
        const Duration(seconds: 25),
      );
      return (
        exitCode: exitCode,
        stdout: await stdoutFuture,
        stderr: await stderrFuture,
      );
    } on TimeoutException {
      process.kill();
      await exitCodeFuture;
      await stdoutFuture;
      await stderrFuture;
      rethrow;
    }
  }

  bool _meetsMinimumVersion(String value, int major, int minor, int patch) {
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(value);
    if (match == null) return false;
    final version = [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
    final minimum = [major, minor, patch];
    for (var index = 0; index < minimum.length; index++) {
      if (version[index] != minimum[index]) {
        return version[index] > minimum[index];
      }
    }
    return true;
  }

  String _flutterExecutable(String target, {bool allowMissingOhos = false}) {
    if (target == 'ohos') {
      final executable = Platform.environment['OHOS_FLUTTER_BIN'];
      if (executable == null || executable.trim().isEmpty) {
        if (allowMissingOhos) return 'OHOS_FLUTTER_BIN';
        throw StateError(
          '鸿蒙构建需要 OpenHarmony 适配版 Flutter。'
          '请设置 OHOS_FLUTTER_BIN 指向该 SDK 的 flutter 可执行文件。',
        );
      }
      return executable;
    }
    return Platform.environment['FLUTTER_BIN'] ?? 'flutter';
  }

  void _requireOhosProject() {
    if (!Directory('ohos').existsSync()) {
      throw StateError(
        '工程缺少 ohos/ 平台壳。配置满足版本要求的 OHOS Flutter 后，'
        '运行 `dart tool/package.dart setup-ohos` 初始化，再重新打包。',
      );
    }
  }

  Future<List<String>> _findArtifacts(String target) async {
    switch (target) {
      case 'android':
        const path = 'build/app/outputs/flutter-apk/app-release.apk';
        return File(path).existsSync() ? [path] : const [];
      case 'web':
        const path = 'build/web';
        return File('$path/index.html').existsSync() ? [path] : const [];
      case 'ios':
        return _findFiles(Directory('build/ios/ipa'), '.ipa');
      case 'macos':
        return _findDirectories(
          Directory('build/macos/Build/Products/Release'),
          '.app',
        );
      case 'windows':
        final executables = await _findFiles(
          Directory('build/windows'),
          '.exe',
        );
        return executables
            .where((path) => path.toLowerCase().contains('release'))
            .map((path) => File(path).parent.path)
            .toSet()
            .toList();
      case 'linux':
        return _findDirectories(Directory('build/linux'), 'bundle');
      case 'ohos':
        return _findFiles(
          Directory('ohos/entry/build/default/outputs'),
          '.hap',
        );
      default:
        return const [];
    }
  }

  Future<List<String>> _findFiles(Directory root, String extension) async {
    if (!root.existsSync()) return const [];
    final matches = <String>[];
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (entry is File && entry.path.toLowerCase().endsWith(extension)) {
        matches.add(entry.path);
      }
    }
    matches.sort();
    return matches;
  }

  Future<List<String>> _findDirectories(Directory root, String suffix) async {
    if (!root.existsSync()) return const [];
    final matches = <String>[];
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (entry is Directory && entry.path.toLowerCase().endsWith(suffix)) {
        matches.add(entry.path);
      }
    }
    matches.sort();
    return matches;
  }

  String _formatCommand(String executable, List<String> arguments) =>
      [executable, ...arguments]
          .map((argument) => argument.contains(' ') ? '"$argument"' : argument)
          .join(' ');

  void _printUsage() {
    stdout.writeln('''
Flutter 发布打包：
  dart tool/package.dart <android|ios|macos|windows|linux|web|ohos>
  dart tool/package.dart setup-ohos

选项：
  --dry-run    显示将执行的命令，不检查工具链或启动构建

工具链环境变量：
  FLUTTER_BIN       可选；标准 Flutter 可执行文件路径
  OHOS_FLUTTER_BIN  必填；OpenHarmony 适配版 Flutter 可执行文件路径

Windows/macOS/Linux 桌面包必须在对应系统上构建；iOS 与 macOS 必须在 macOS 上构建。
''');
  }
}
