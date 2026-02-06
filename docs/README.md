# GitHub Pages サイト

このディレクトリには、GitHub Pages で公開するサイトの Hugo ソースファイルが含まれています。

## 構成

- `hugo.toml` - Hugo 設定ファイル
- `layouts/` - HTML テンプレート
- `static/` - CSS などの静的ファイル
- `content/` - コンテンツ（`_index.md` 以外は CI で自動生成）
- `generate-content.sh` - `scripts/*/README.md` から Hugo コンテンツを生成するスクリプト

## ローカルでの確認方法

```bash
# コンテンツ生成
bash docs/generate-content.sh

# 開発サーバー起動
cd docs && hugo server
```
