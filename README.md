# chocoLOG

chocoZAP利用者向けの、筋力トレーニングと有酸素運動の記録アプリです。

> [!NOTE]
> 本プロジェクトは非公式であり、RIZAP株式会社およびchocoZAPの公式・公認アプリではありません。

## 対象プラットフォーム

- iOS（先行開発）
- Android（将来対応）

## ドキュメント

- [要件定義](docs/requirements.md)
- [画面構成・ワイヤーフレーム](docs/wireframes.md)
- [Flutterアーキテクチャ](docs/architecture.md)

## 開発環境

- Flutter 3.44.9
- Dart 3.12.2
- Bundle ID / Application ID: `com.naolab.chocolog`

## セットアップ

```shell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

`*.g.dart`はリポジトリへ含めず、ローカルまたはCIで生成します。
