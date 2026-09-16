# Android ゲームエミュレータ

Apple Silicon Macから、ローカルのAndroid SDKとAVDを使ってゲームを起動する最小ランチャーです。

特定のゲーム、販売元、APK、ログ形式、描画エンジンには依存しません。Google Play Storeイメージを含む、ユーザーが用意した任意のAVDを対象にします。

## できること

- Android Emulatorの起動と停止
- AVD名の指定
- Android SDKの場所の指定
- Androidパッケージ名を指定したゲーム起動
- 設定のmacOSユーザーデフォルトへの保存

## 必要環境

- Apple Silicon Mac
- macOS 12以降
- XcodeまたはXcode Command Line Tools
- Android SDKの`platform-tools`と`emulator`
- 起動対象のAVD

Google Play Storeを利用するゲームでは、Android Studioから対応するPlay Store system imageを導入し、Googleの利用規約に従ってください。

## ビルド

```zsh
./scripts/build-mactician.command
```

生成物は`dist/Mactician.app`です。ゲームAPKや認証情報はビルドへ含めません。

## 起動

1. `dist/Mactician.app`を起動します。
2. Android SDKのパスを入力します。
3. 起動するAVD名を入力します。
4. 必要ならAndroidパッケージ名を入力します。
5. 「起動」を押します。

パッケージ名を空欄にすると、AVDだけを起動します。Play Storeから導入したゲームは、インストール後にパッケージ名を指定して起動できます。

## Play Store用AVD

専用AVDを作成する場合は、[Play Storeランタイムの手順](docs/playstore-runtime.md)を参照してください。Play Storeイメージと、root可能な開発用イメージは別AVDで管理します。

## 設計方針

- ゲーム固有の処理をランチャー本体へ入れない
- Android SDK、AVD、APK、ゲームデータをリポジトリへ保存しない
- 起動対象はユーザーが入力したAVDとパッケージに限定する
- 追加の高速化は、標準動作を壊さない独立した実験として追加する

## ライセンス

MIT License。Android、Google Play、ゲーム本体および各ゲームの名称・データは、それぞれの権利者に帰属します。
