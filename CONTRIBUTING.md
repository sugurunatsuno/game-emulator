# コントリビューション

小さく、検証可能な変更を歓迎します。

## 開発環境

- Apple Silicon Mac
- macOS 12以降
- XcodeまたはXcode Command Line Tools
- Android SDKの`platform-tools`と`emulator`
- zsh

確認コマンド:

```zsh
zsh -n scripts/build-mactician.command
zsh -n scripts/provision-playstore-avd.command
./scripts/build-mactician.command
```

ゲームAPK、認証情報、AVDデータ、ログ、秘密情報はコミットしないでください。
