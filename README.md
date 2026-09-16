# Hako

Apple Silicon MacでAndroidゲーム用のローカルVMを起動するランチャーです。

特定のゲーム、販売元、APK、ログ形式、描画エンジンには依存しません。Google Play Storeイメージを含む、ユーザーが用意した任意のAVDを対象にします。

## できること

- Android Emulatorの起動と停止
- AVD名の指定
- Android SDKの場所の指定
- Androidパッケージ名を指定したゲーム起動
- 設定のmacOSユーザーデフォルトへの保存
- 個人利用向けカスタムAndroid実行環境のローカル生成

## 必要環境

- Apple Silicon Mac
- macOS 12以降
- XcodeまたはXcode Command Line Tools
- Android SDKの`platform-tools`と`emulator`
- 起動対象のAVD

Google Play Storeを利用するゲームでは、Android Studioから対応するPlay Store system imageを導入し、Googleの利用規約に従ってください。

## ビルド

```zsh
./scripts/build-hako.command
```

生成物は`dist/Hako.app`です。ゲームAPKや認証情報はビルドへ含めません。

アプリアイコンは`branding/hako-app-icon.svg`からビルド時に`Hako.icns`へ変換します。

## Android実行環境の導入

Platform ToolsとAndroid Emulatorがない場合は、Google公式配布物をダウンロードします。

```zsh
./scripts/install-android-runtime.command
```

保存先を変更する場合:

```zsh
ANDROID_RUNTIME_ROOT="$HOME/Library/Application Support/Hako/sdk" \
  ./scripts/install-android-runtime.command
```

AVDはAndroid Studioで作成してください。Google Playを使うゲームでは、Play Store system imageを選択します。既存のSDKが`/Volumes/SSD-4TB/HakoData/sdk`など標準外の場所にある場合も、ランチャーが自動検出します。

## カスタム実行環境

個人利用向けに、root可能なGoogle APIs系ARM64イメージから初期設定済みAVDを生成できます。ROMや生成済みuserdataはリポジトリへ含めません。

```zsh
zsh scripts/provision-custom-runtime.command
```

既定ではUIアニメーション、画面設定、DPI、logcatサイズなどをゲーム向けに初期化します。任意のGuest Agent APKも初期userdataへ事前導入できます。

詳しくは[カスタムAndroid実行環境](docs/custom-runtime.md)を参照してください。

## 起動

- `dist/Hako.app`を起動します。
- Android SDKのパスを入力します。
- 起動するAVD名を入力します。
- 必要ならAndroidパッケージ名を入力します。
- `起動`を押します。

パッケージ名を空欄にすると、AVDだけを起動します。Play Storeから導入したゲームは、インストール後にパッケージ名を指定して起動できます。

## Play Store用AVD

専用AVDを作成する場合は、[Play Storeランタイムの手順](docs/playstore-runtime.md)を参照してください。Play Storeイメージと、root可能な開発用イメージは別AVDで管理します。

## 設計方針

- ゲーム固有の処理をランチャー本体へ入れない
- Android SDK、AVD、APK、ゲームデータをリポジトリへ保存しない
- 起動対象はユーザーが入力したAVDとパッケージに限定する
- カスタム実行環境の生成物は配布せず、生成手順と設定だけを管理する
- Play Store用AVDと改変可能な開発用AVDを分離する
- 追加の高速化は、標準動作を壊さない独立した実験として追加する

## ライセンス

MIT License。Android、Google Play、ゲーム本体および各ゲームの名称やデータは、それぞれの権利者に帰属します。
