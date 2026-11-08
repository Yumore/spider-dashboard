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

const _artifactName = 'spider-worker';

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
        await _checkPackagingTools(target);
      }

      final flutter = _flutterExecutable(target, allowMissingOhos: dryRun);
      stdout.writeln('执行：${_formatCommand(flutter, buildArguments)}');
      if (dryRun) {
        stdout.writeln('预期产物：${_plannedArtifacts(target).join('、')}');
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

      final artifacts = await _packageArtifacts(target);
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

  Future<void> _checkPackagingTools(String target) async {
    switch (target) {
      case 'windows':
        _findTool('ISCC_BIN', ['ISCC.exe', 'iscc'], windowsInnoSetup: true);
        final wix = _findTool('WIX_BIN', ['wix.exe', 'wix']);
        final version = await Process.run(wix, ['--version']);
        if (version.exitCode != 0) {
          throw StateError('无法读取 WiX 版本：${version.stderr}');
        }
        final match = RegExp(
          r'\b(?:v)?(\d+)\.\d+',
        ).firstMatch(version.stdout.toString());
        if (match == null || int.parse(match.group(1)!) < 5) {
          throw StateError(
            'MSI 打包需要 WiX 5 或更新版本；当前版本为 ${version.stdout.toString().trim()}。',
          );
        }
      case 'linux':
        _findTool(null, ['dpkg-deb']);
        _findTool(null, ['dpkg']);
        _findTool(null, ['cp']);
      case 'macos':
        _findTool(null, ['hdiutil']);
        _findTool(null, ['ditto']);
    }
  }

  List<String> _plannedArtifacts(String target) => switch (target) {
    'android' => ['dist/$_artifactName.apk'],
    'ios' => ['dist/$_artifactName.ipa'],
    'macos' => ['dist/$_artifactName.dmg'],
    'windows' => [
      'dist/$_artifactName.exe (Inno Setup 安装程序)',
      'dist/$_artifactName.msi',
    ],
    'linux' => ['dist/$_artifactName.deb'],
    'web' => ['build/web/'],
    'ohos' => ['ohos/entry/build/default/outputs/*.hap'],
    _ => const [],
  };

  Future<List<String>> _packageArtifacts(String target) async {
    switch (target) {
      case 'android':
        return [
          await _copyToDistribution(
            'build/app/outputs/flutter-apk/app-release.apk',
            '$_artifactName.apk',
          ),
        ];
      case 'ios':
        final ipaFiles = await _findFiles(Directory('build/ios/ipa'), '.ipa');
        final ipa = _requireSingleArtifact(ipaFiles, 'IPA');
        return [await _copyToDistribution(ipa, '$_artifactName.ipa')];
      case 'macos':
        return [await _packageMacosDmg()];
      case 'windows':
        return _packageWindowsInstallers();
      case 'linux':
        return [await _packageLinuxDeb()];
      case 'web':
        const path = 'build/web';
        return File('$path/index.html').existsSync() ? [path] : const [];
      case 'ohos':
        return _findFiles(
          Directory('ohos/entry/build/default/outputs'),
          '.hap',
        );
      default:
        return const [];
    }
  }

  Future<String> _packageMacosDmg() async {
    final apps = await _findDirectories(
      Directory('build/macos/Build/Products/Release'),
      '.app',
      recursive: false,
    );
    final app = _requireSingleArtifact(apps, 'macOS .app');
    final output = await _distributionFile('$_artifactName.dmg');
    final staging = await Directory.systemTemp.createTemp('spider-worker-dmg-');
    try {
      final stagedApp = '${staging.path}/${_baseName(app)}';
      final copyResult = await _runRequiredTool('ditto', [
        app,
        stagedApp,
      ], '复制 macOS 应用');
      if (copyResult != 0 || !Directory(stagedApp).existsSync()) {
        throw StateError('复制 macOS 应用失败，退出码：$copyResult');
      }
      await Link('${staging.path}/Applications').create('/Applications');
      await _copyLegalNotices(staging.path);
      final result = await _runRequiredTool('hdiutil', [
        'create',
        '-volname',
        'Spider Worker',
        '-srcfolder',
        staging.path,
        '-ov',
        '-format',
        'UDZO',
        output,
      ], '创建 macOS DMG');
      if (result != 0) {
        throw StateError('创建 macOS DMG 失败，退出码：$result');
      }
    } finally {
      await staging.delete(recursive: true);
    }
    _requireOutputFile(output);
    return output;
  }

  Future<List<String>> _packageWindowsInstallers() async {
    final binaryName = _cmakeBinaryName('windows/CMakeLists.txt');
    final releaseDirectory = await _findWindowsReleaseDirectory(binaryName);
    await _copyLegalNotices(releaseDirectory);
    final outputDirectory = await _distributionDirectory();
    final appVersion = _readAppVersion();
    final setupCompiler = _findTool('ISCC_BIN', [
      'ISCC.exe',
      'iscc',
    ], windowsInnoSetup: true);
    final wix = _findTool('WIX_BIN', ['wix.exe', 'wix']);
    final setupResult = await _runRequiredTool(setupCompiler, [
      '/DBuildDir=${Directory(releaseDirectory).absolute.path}',
      '/DAppVersion=$appVersion',
      '/DAppExe=$binaryName.exe',
      '/O${Directory(outputDirectory).absolute.path}',
      'tool/packaging/windows/spider-worker.iss',
    ], '创建 Windows EXE 安装程序');
    if (setupResult != 0) {
      throw StateError('创建 Windows EXE 安装程序失败，退出码：$setupResult');
    }
    final exe = '$outputDirectory/$_artifactName.exe';
    _requireOutputFile(exe);

    final msi = '$outputDirectory/$_artifactName.msi';
    final wixResult = await _runRequiredTool(wix, [
      'build',
      '-arch',
      'x64',
      '-d',
      'PayloadDir=${Directory(releaseDirectory).absolute.path}',
      '-d',
      'AppVersion=$appVersion',
      '-o',
      Directory(msi).absolute.path,
      'tool/packaging/windows/spider-worker.wxs',
    ], '创建 Windows MSI');
    if (wixResult != 0) {
      throw StateError('创建 Windows MSI 失败，退出码：$wixResult');
    }
    _requireOutputFile(msi);
    return [exe, msi];
  }

  Future<String> _packageLinuxDeb() async {
    final binaryName = _cmakeBinaryName('linux/CMakeLists.txt');
    final bundles = await _findDirectories(Directory('build/linux'), 'bundle');
    final matchingBundles = bundles
        .where(
          (path) =>
              path.toLowerCase().contains('release') &&
              File('$path/$binaryName').existsSync(),
        )
        .toList();
    final bundle = _requireSingleArtifact(
      matchingBundles,
      'Linux release bundle',
    );
    final architectureResult = await Process.run(_findTool(null, ['dpkg']), [
      '--print-architecture',
    ], runInShell: Platform.isWindows);
    if (architectureResult.exitCode != 0) {
      throw StateError('无法读取 Debian 架构：${architectureResult.stderr}');
    }
    final architecture = architectureResult.stdout.toString().trim();
    if (architecture.isEmpty) {
      throw const FormatException('dpkg 未返回 Debian 架构。');
    }

    final stage = Directory('build/package/deb/root');
    if (stage.existsSync()) await stage.delete(recursive: true);
    final installDirectory = Directory('${stage.path}/opt/$_artifactName');
    await installDirectory.create(recursive: true);
    final copyResult = await _runRequiredTool('cp', [
      '-a',
      '$bundle/.',
      installDirectory.path,
    ], '整理 Linux 应用文件');
    if (copyResult != 0) {
      throw StateError('整理 Linux 应用文件失败，退出码：$copyResult');
    }

    final controlDirectory = Directory('${stage.path}/DEBIAN');
    await controlDirectory.create(recursive: true);
    final version = _readAppVersion();
    await File('${controlDirectory.path}/control').writeAsString('''
Package: $_artifactName
Version: $version
Section: multimedia
Priority: optional
Architecture: $architecture
Maintainer: Yumore
Depends: libc6, libstdc++6, libgtk-3-0 | libgtk-3-0t64
Description: Spider Worker content and media application
 Unified reading, media, community, and live content client.
''');

    final launcher = Link('${stage.path}/usr/bin/$_artifactName');
    await Directory(launcher.parent.path).create(recursive: true);
    await launcher.create('/opt/$_artifactName/$binaryName');
    final desktop = File(
      '${stage.path}/usr/share/applications/$_artifactName.desktop',
    );
    await desktop.parent.create(recursive: true);
    await desktop.writeAsString('''
[Desktop Entry]
Type=Application
Name=Spider Worker
Exec=$_artifactName
Icon=$_artifactName
Terminal=false
Categories=AudioVideo;Video;
''');
    final icon = File('assets/logo.png');
    if (icon.existsSync()) {
      final iconTarget = File(
        '${stage.path}/usr/share/icons/hicolor/256x256/apps/$_artifactName.png',
      );
      await iconTarget.parent.create(recursive: true);
      await icon.copy(iconTarget.path);
    }
    final documentation = Directory(
      '${stage.path}/usr/share/doc/$_artifactName',
    );
    await documentation.create(recursive: true);
    await _copyLegalNotices(documentation.path);

    final output = await _distributionFile('$_artifactName.deb');
    final result = await _runRequiredTool(_findTool(null, ['dpkg-deb']), [
      '--root-owner-group',
      '--build',
      stage.path,
      Directory(output).absolute.path,
    ], '创建 Linux DEB');
    if (result != 0) {
      throw StateError('创建 Linux DEB 失败，退出码：$result');
    }
    _requireOutputFile(output);
    return output;
  }

  Future<String> _findWindowsReleaseDirectory(String binaryName) async {
    final executableFiles = await _findFiles(
      Directory('build/windows'),
      '.exe',
    );
    final directories =
        executableFiles
            .where(
              (path) =>
                  _baseName(path).toLowerCase() == '$binaryName.exe' &&
                  path.toLowerCase().contains('release'),
            )
            .map((path) => File(path).parent.path)
            .toSet()
            .toList()
          ..sort();
    return _requireSingleArtifact(directories, 'Windows release bundle');
  }

  String _cmakeBinaryName(String cmakePath) {
    final source = File(cmakePath).readAsStringSync();
    final match = RegExp(
      r'set\(BINARY_NAME\s+"([^"]+)"\)',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) {
      throw FormatException('无法从 $cmakePath 读取 BINARY_NAME。');
    }
    return match.group(1)!;
  }

  String _readAppVersion() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    if (match == null) {
      throw const FormatException(
        'pubspec.yaml 需要 version: major.minor.patch+build 格式。',
      );
    }
    return match.group(1)!;
  }

  String _findTool(
    String? environmentVariable,
    List<String> names, {
    bool windowsInnoSetup = false,
  }) {
    final override = environmentVariable == null
        ? null
        : Platform.environment[environmentVariable];
    if (override != null && override.trim().isNotEmpty) {
      if (_isPath(override) && !File(override).existsSync()) {
        throw StateError('$environmentVariable 指定的工具不存在：$override');
      }
      return override;
    }

    final pathEntries = (Platform.environment['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    );
    final candidates = <String>[];
    if (windowsInnoSetup && Platform.isWindows) {
      for (final variable in ['ProgramFiles(x86)', 'ProgramFiles']) {
        final root = Platform.environment[variable];
        if (root != null && root.isNotEmpty) {
          candidates.add('$root\\Inno Setup 6\\ISCC.exe');
        }
      }
    }
    for (final pathEntry in pathEntries) {
      if (pathEntry.isEmpty) continue;
      for (final name in names) {
        candidates.add('$pathEntry${Platform.pathSeparator}$name');
      }
    }
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    final label = environmentVariable == null
        ? names.first
        : '$environmentVariable (${names.join(' / ')})';
    throw StateError('找不到打包工具 $label；请先安装并加入 PATH，或设置对应环境变量。');
  }

  bool _isPath(String value) =>
      value.contains('/') ||
      value.contains('\\') ||
      RegExp(r'^[A-Za-z]:').hasMatch(value);

  Future<int> _runRequiredTool(
    String executable,
    List<String> arguments,
    String task,
  ) async {
    stdout.writeln('$task：${_formatCommand(executable, arguments)}');
    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  Future<String> _copyToDistribution(String sourcePath, String name) async {
    final source = File(sourcePath);
    if (!source.existsSync()) throw StateError('缺少构建产物：$sourcePath');
    final output = await _distributionFile(name);
    await source.copy(output);
    _requireOutputFile(output);
    return output;
  }

  Future<void> _copyLegalNotices(String destination) async {
    for (final source in [
      File('LICENSE'),
      File('documents/THIRD_PARTY_NOTICES.md'),
    ]) {
      if (source.existsSync()) {
        await source.copy('$destination/${_baseName(source.path)}');
      }
    }
  }

  Future<String> _distributionFile(String name) async {
    final directory = await _distributionDirectory();
    return '$directory/$name';
  }

  Future<String> _distributionDirectory() async {
    final directory = Directory('dist');
    await directory.create(recursive: true);
    return directory.path;
  }

  String _requireSingleArtifact(List<String> artifacts, String description) {
    if (artifacts.isEmpty) throw StateError('未找到 $description。');
    if (artifacts.length > 1) {
      throw StateError('找到多个 $description，请清理旧构建目录后重试：${artifacts.join(', ')}');
    }
    return artifacts.single;
  }

  void _requireOutputFile(String path) {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError('打包工具未生成有效文件：$path');
    }
  }

  String _baseName(String path) =>
      path.split(Platform.isWindows ? RegExp(r'[\\/]') : '/').last;

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

  Future<List<String>> _findDirectories(
    Directory root,
    String suffix, {
    bool recursive = true,
  }) async {
    if (!root.existsSync()) return const [];
    final matches = <String>[];
    await for (final entry in root.list(
      recursive: recursive,
      followLinks: false,
    )) {
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

统一产物名称（Web/OHOS 保留 Flutter 原目录）：
  Android  dist/$_artifactName.apk
  iOS      dist/$_artifactName.ipa
  Windows  dist/$_artifactName.exe（安装程序）和 dist/$_artifactName.msi
  macOS    dist/$_artifactName.dmg
  Linux    dist/$_artifactName.deb

选项：
  --dry-run    显示将执行的命令，不检查工具链或启动构建

工具链环境变量：
  FLUTTER_BIN       可选；标准 Flutter 可执行文件路径
  OHOS_FLUTTER_BIN  必填；OpenHarmony 适配版 Flutter 可执行文件路径
  ISCC_BIN          可选；Inno Setup 编译器路径（Windows EXE 安装程序）
  WIX_BIN           可选；WiX 5+ CLI 路径（Windows MSI）

Windows/macOS/Linux 桌面包必须在对应系统上构建；iOS 与 macOS 必须在 macOS 上构建。
''');
  }
}
