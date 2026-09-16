# アーキテクチャ

本プロジェクトは、ゲームの内容を解析・変更するものではなく、macOSからAndroid Emulatorを起動する薄いランチャーです。

## 構成

- `launcher/Sources/MacticianApp.swift`: SwiftUI画面、設定、Emulatorプロセスのライフサイクル
- `scripts/build-mactician.command`: macOSアプリのビルドと署名
- `scripts/provision-playstore-avd.command`: Play Store system image用AVDの作成
- `scripts/android-environment.sh`: SDK探索の共通処理

## 起動フロー

1. SDK配下の`emulator`と`adb`を検証する。
2. 指定AVDを`-gpu host`、`-no-snapshot`で起動する。
3. `sys.boot_completed`をADBで確認する。
4. パッケージ名が指定されていれば`monkey`で起動する。
5. 停止時はランチャーが起動したEmulatorプロセスだけを終了する。

ゲーム固有のoverlay、root化、バイナリパッチ、画面分類、認証自動化は実装しません。
