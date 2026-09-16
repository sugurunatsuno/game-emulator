# アーキテクチャ

HakoはApple Silicon MacでAndroidゲーム用のローカルVMを扱うランチャーです。ゲーム本体の解析や変更は行わず、Android実行環境の起動と初期設定を担当します。

## 構成

- `launcher/Sources/HakoApp.swift`: SwiftUI画面、設定、Android Emulatorプロセスの管理
- `launcher/Info.plist`: Hakoのbundle情報とアプリアイコン設定
- `scripts/build-hako.command`: macOSアプリのビルド、Hakoアイコン生成、署名
- `scripts/provision-custom-runtime.command`: 個人利用向けの初期設定済みAndroid実行環境を生成
- `scripts/provision-playstore-avd.command`: Google Play Store system image用AVDを生成
- `scripts/android-environment.sh`: Android SDK探索の共通処理
- `branding/hako-app-icon.svg`: Hakoのアプリアイコン原本

## Android実行環境

Hakoでは用途の違うAndroid環境を分けて扱います。

- `HakoCustom`はGoogle APIs系ARM64イメージを基に、画面設定やゲーム向けの初期設定を済ませた開発用環境です
- Play Store用AVDはGoogle Play Store system imageを改変せずに使います
- ROM、userdata、ゲームAPKはリポジトリへ保存しません

将来Guest Agentをsystem側へ組み込む場合も、生成手順だけを管理し、生成済みROMは配布しない方針です。

## 起動フロー

- SDK配下の`emulator`と`adb`を確認します
- 選択したAVDを`-gpu host`と`-no-boot-anim`で起動します
- ADBから`sys.boot_completed`を確認します
- パッケージ名が指定されていれば`monkey`でアプリを起動します
- 停止時はHakoが起動したEmulatorプロセスを終了します

## カスタム実行環境の生成

`provision-custom-runtime.command`は初回起動を行い、UIアニメーション、解像度、DPI、画面消灯などを設定してからAVDを停止します。任意のGuest Agent APKをuserdataへ事前導入することもできます。

これは現段階では独自ROMそのものではなく、system imageと初期化済みuserdataを組み合わせたローカルVMテンプレートです。system UIDのGuest Agentやnative daemonが必要になった段階でAOSPビルドへ移行します。
