import os
import platform
import shutil
import subprocess
from pathlib import Path


root = Path(__file__).resolve().parents[1]
environment = os.environ.copy()
environment.setdefault('GOPROXY', 'https://goproxy.cn,direct')
environment.setdefault('GOSUMDB', 'off')
environment['CGO_ENABLED'] = '1'
all_sources = environment.get('SHORT_DRAMA_ALL_SOURCES', 'true').lower() == 'true'


def android_sdk() -> Path:
    configured = environment.get('ANDROID_HOME') or environment.get('ANDROID_SDK_ROOT')
    if configured:
        return Path(configured)
    properties = root / 'android' / 'local.properties'
    if properties.is_file():
        for line in properties.read_text().splitlines():
            if line.startswith('sdk.dir='):
                return Path(line.partition('=')[2].replace('\\:', ':').replace('\\\\', '\\'))
    raise SystemExit('未找到 Android SDK；请设置 ANDROID_HOME 或 android/local.properties 中的 sdk.dir。')


def build(go: str, ndk_bin: Path, abi: str, architecture: str, compiler_name: str) -> None:
    compiler = ndk_bin / (compiler_name + ('.cmd' if platform.system() == 'Windows' else ''))
    if not compiler.is_file():
        raise SystemExit('缺少 Android NDK 编译器：' + str(compiler))
    output = root / 'android' / 'app' / 'src' / 'main' / 'jniLibs' / abi / 'libduanju_core.so'
    output.parent.mkdir(parents=True, exist_ok=True)
    build_environment = environment.copy()
    build_environment.update(
        GOOS='android',
        GOARCH=architecture,
        CC=str(compiler),
        CGO_LDFLAGS='-Wl,-z,max-page-size=16384',
    )
    if architecture == 'arm':
        build_environment['GOARM'] = '7'
    print(f'Building Android short drama core for {abi}', flush=True)
    subprocess.run(
        [
            go,
            'build',
            '-trimpath',
            '-buildmode=c-shared',
            '-ldflags=-s -w -X dashboard/native/core.buildAllSources=' + str(all_sources).lower(),
            '-o',
            str(output),
            './bridge',
        ],
        cwd=root / 'native',
        env=build_environment,
        check=True,
    )
    header = output.with_suffix('.h')
    if header.exists():
        header.unlink()


def main() -> None:
    go = shutil.which('go')
    if not go:
        raise SystemExit('构建短剧 Android 原生核心需要 Go 1.24.1 或更新版本。')
    sdk = android_sdk()
    ndk = Path(environment.get('ANDROID_NDK_HOME', sdk / 'ndk' / '28.2.13676358'))
    host = {
        'Darwin': 'darwin-x86_64',
        'Linux': 'linux-x86_64',
        'Windows': 'windows-x86_64',
    }.get(platform.system())
    if host is None:
        raise SystemExit('当前构建主机没有配置 Android NDK 工具链。')
    ndk_bin = ndk / 'toolchains' / 'llvm' / 'prebuilt' / host / 'bin'
    abis = (
        ('arm64-v8a', 'arm64', 'aarch64-linux-android23-clang'),
        ('armeabi-v7a', 'arm', 'armv7a-linux-androideabi23-clang'),
        ('x86_64', 'amd64', 'x86_64-linux-android23-clang'),
    )
    for abi, architecture, compiler in abis:
        build(go, ndk_bin, abi, architecture, compiler)


if __name__ == '__main__':
    main()
