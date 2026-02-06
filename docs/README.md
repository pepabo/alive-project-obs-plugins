# GitHub Pages サイト

このディレクトリには、GitHub Pages で公開するサイトの Hugo ソースファイルが含まれています。

## 構成

- `hugo.toml` - Hugo 設定ファイル
- `layouts/` - HTML テンプレート
- `static/` - CSS などの静的ファイル
- `content/` - コンテンツ（`_index.md` 以外は CI で自動生成）
- `generate-content.sh` - `scripts/*/README.md` から Hugo コンテンツを生成するスクリプト

## コンテンツ自動生成の仕組み

`generate-content.sh` が各フィルターの README.md からページを自動生成します。

- **タイトル**: README.md の1行目（`# 🎭 スポットライト` → `🎭 スポットライト`）
- **概要**: README.md の3行目（タイトル直後の空行の次にある説明文）
- **サムネイル**: README.md 内で最初に出現する画像（`![...](./ファイル名.png)` 形式）が一覧ページのカードに表示される。画像がないフィルターはテキストのみで表示される

例えば以下のような README.md の場合:

```markdown
# 🎭 スポットライト
                           ← 2行目（空行）
VTuberの歌配信に最適な...   ← 3行目（これが概要になる）
```

タイトルは `🎭 スポットライト`、概要は `VTuberの歌配信に最適な...` になります。

## ローカルでの確認方法

### Hugoのインストール

Macの場合

```
brew install hugo
```

詳しくはこちら
https://formulae.brew.sh/formula/hugo

### Hugoの実行

```bash
# コンテンツ生成
bash docs/generate-content.sh

# 開発サーバー起動
cd docs && hugo server
```
