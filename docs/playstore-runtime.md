# Google Play Store runtime

MacticianのTFTランタイムとは別に、Google Play Store system image用のAVDを作成する。

## 方針

- TFT: `google_apis` + root可能なAVD + ANGLE/OpenGL overlay + ASG/QEMU実験。
- Play Store系ゲーム: `google_apis_playstore` + 専用AVD。TFT用overlay、branding patch、ASG設定は適用しない。
- ゲームAPKとGoogleのアプリはリポジトリに同梱しない。Google Play Storeからユーザーが取得する。

Play Store imageはPlay StoreとGoogle Play servicesを含む一方、release-key署名のためroot化できない。したがって、TFTの高速化経路と同じAVDに統合しない。

## 作成

Android Studioで `system-images;android-35;google_apis_playstore;arm64-v8a` を導入した後、次を実行する。

```zsh
PLAYSTORE_ANDROID_SDK_ROOT="$HOME/Library/Android/sdk" \
PLAYSTORE_AVD_HOME="$HOME/Library/Application Support/Mactician/playstore-avd" \
./scripts/provision-playstore-avd.command
```

Apple Siliconでイメージの場所が異なる場合は、`PLAYSTORE_SYSTEM_IMAGE_DIR` に `system.img` を含むディレクトリを指定する。

MuMu Player Proで確認できた基準値（Android 12 / arm64-v8a / 900x1600 / density 240 / GLES 3.2）を初期値に採用した。ただし、これは比較用の基準であり、MuMuの実装をコピーしたものではない。
