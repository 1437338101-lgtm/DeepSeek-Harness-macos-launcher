# DSH Launcher for macOS

An unofficial, lightweight macOS launcher for the browser-based Web UI of
[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness).

DSH Launcher is a thin shell application: it does not embed Harness, Node.js,
credentials, sessions, or plugins. Double-clicking the app discovers an
existing `dsh` installation, starts the Web backend on a loopback port, waits
for HTTP readiness, and opens the page in the default browser. Reopening the
app reuses the existing backend instead of starting a duplicate.

> This is an independent community project. It is not affiliated with or
> endorsed by DeepSeek.

## Features

- Native macOS `.app` with no Electron or bundled browser runtime
- Apple Silicon and Intel-aware launch behavior
- Dynamic DSH discovery with an optional `DSH_BIN` override
- Loopback-only Web server and automatic port conflict fallback
- PID verification before backend reuse or shutdown
- Isolated logs and state under the current user's Library directory
- Reproducible icon, app, ZIP, checksum, and privacy-check scripts

## Requirements

- macOS 14 or newer
- A working Node.js installation supported by DeepSeek Harness
- A persistent `dsh` executable installed separately

The launcher searches these locations in order:

1. `DSH_BIN`, when explicitly set
2. `dsh` on `PATH`
3. `~/.local/bin/dsh`
4. `~/Library/pnpm/dsh`
5. `~/.local/share/pnpm/dsh`
6. `/opt/homebrew/bin/dsh`
7. `/usr/local/bin/dsh`

See the [upstream project](https://github.com/deepseek-ai/deepseek-harness)
for current Harness installation and compatibility information.

## Build

```bash
./scripts/build.sh
```

The app is written to `dist/DSH Launcher.app` and receives an ad-hoc local
signature. To create a distributable ZIP and SHA-256 checksum:

```bash
./scripts/package.sh
```

## Test

With `dsh` already installed:

```bash
./scripts/smoke-test.sh
./scripts/privacy-check.sh
```

The smoke test uses an isolated state directory and a temporary loopback port.
It does not read or modify the user's Harness configuration.

## Runtime behavior

The default preferred port is `3080`. If another program owns it, the launcher
tries ports `3081` through `3090`. Override the first candidate with
`DSH_PORT=<port>`.

Logs and state are stored at:

```text
~/Library/Logs/DSH Launcher/server.log
~/Library/Application Support/DSH Launcher/
```

To stop a backend started by the launcher:

```bash
"/Applications/DSH Launcher.app/Contents/Resources/stop-backend.zsh"
```

Adjust the app path when running it from another directory.

## Signing and notarization

GitHub Release artifacts are ad-hoc signed unless a maintainer supplies an
Apple Developer ID certificate and notarizes the build. On first launch of an
unsigned or unnotarized community build, macOS may require Control-clicking the
app and choosing **Open**.

Do not disable Gatekeeper globally.

## Privacy

The repository and release artifacts must not contain usernames, home-directory
paths, credentials, logs, PIDs, sessions, or local Harness settings. Run
`./scripts/privacy-check.sh` before every release.

## License and branding

The launcher is available under the MIT License. DeepSeek Harness remains
subject to its own license, notices, safety guidance, and policies. See
[NOTICE.md](NOTICE.md).

The included launcher icon is an original community asset. It intentionally
contains no DeepSeek logo, whale, product wordmark, or other official brand
element.

## 中文说明

本项目是一个非官方、轻量的 macOS 启动器，不捆绑 DeepSeek Harness 后端、
Node.js、API Key、会话或插件。双击应用后，它会查找用户已安装的 `dsh`，
在本机回环地址启动 Web UI，并自动打开浏览器。再次双击会复用现有后端，
不会重复启动进程。

公开发布前请运行构建、冒烟测试与隐私检查脚本。未经许可，请勿将 DeepSeek
官方 Logo 或其他品牌素材加入发行包。
