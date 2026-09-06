# Vietnam (VNG) edition

The launch screen offers Global and Vietnam (VNG), remembers the last selection,
and defaults to Global. Selecting an uninstalled edition downloads it when the
shared Android runtime is already present. A fresh setup still requires the
Android SDK license step. Game language remains an independent setting.

Vietnam is a separate Android application,
[`com.riotgames.league.teamfighttacticsvn`](https://play.google.com/store/apps/details?id=com.riotgames.league.teamfighttacticsvn).
Both packages coexist in `Tft.avd` and retain separate sign-ins, files, caches,
and updates. Switching is disabled until installation, stopping, or gameplay
finishes. Reset removes both games and the shared runtime.

## Verified release input

Prepared on 2026-09-04 from APKMirror’s VNG `18.1-5423749` APKM bundle. Android
manifest metadata confirms version code `8423749`. Official Android Build Tools
36 `aapt` and `apksigner` verified all four APKs. All use the existing pinned Riot
certificate SHA-256:

```text
931d969502f3de01a4c239e4199211ebdc57bb9a7526394b9e3e2d1cc079ff0c
```

| APK | Bytes | SHA-256 |
| --- | ---: | --- |
| base.apk | 100258103 | e14b47a3e54051b5b99fdbd6402f595da705be2ef424367ae79e05a12e95708c |
| config.arm64_v8a.apk | 94057697 | a40a49947587fc9f8a3a97a6350cf0e7f3779fac8393846585baa0bd71d32ade |
| config.en.apk | 37273 | bc86795c9efcbf562dd2867e712e495b33d9cd1337d86a211ce630803ba9365c |
| config.mdpi.apk | 83007 | ba1619706fc9921c299e844fde384f28b75bb10b811ef3b2b23e26833a1d523f |

The four private inputs live in `private/tft-vietnam-apks/`. The signed update
feed is generated with `MACTICIAN_GAME_EDITION=vietnam`; see
[the release procedure](releasing.md#publish-a-tft-game-update).

## Distribution

The VNG channel was published on 2026-09-05 with the verified release above.
The existing Global feed and launcher appcast were unchanged. Existing launcher
releases continue using Global; the edition selector requires the new build.

Global keeps its bundled APKs and existing feed URL. Vietnam is downloaded on
demand and has no bundled Global fallback. Its feed uses the same pinned game
update signing key and the path `/mactician/updates/game/vietnam/manifest.json`.
APK paths are `/mactician/updates/game/vietnam/releases/<baseSHA256>/<filename>`.
Publish this signed feed and its APKs before distributing the new launcher.
Preparation alone does not make the VNG download available to users.

The first game launch separately requests its own content download (about
3.7 GB for this release), then its own sign-in. The launcher’s APK download size
does not include that content. No credentials transfer between editions.

## Validation

Unit tests cover schema 1 migration to Global, schema 2 round trips with both
editions, edition selection defaults, signed cross-edition feed rejection,
exact APK URL validation, downgrade rejection, and isolated cache/overlay paths.
Runtime lifecycle fixtures exercise process polling for both Android packages.

A test copy of an existing Global AVD was used to install VNG with the production
installer. Both per-game state records survived. VNG reached Unreal GameActivity,
stayed alive for more than 25 seconds, and displayed its content-download prompt
in the selected English language with an empty crash log. Switching back to Global
and launching it from the new UI also reached GameActivity with no crash records.
The selector was disabled during gameplay and re-enabled after stopping.
Account sign-in and a
full match are separate manual checks; neither is implied by this startup test.
