# GitHub Pages サイト

このリポジトリのscriptsフォルダに追加されたReadMe.mdファイルはmainにマージされた直後に以下のURLで公開されます

https://pepabo.github.io/alive-project-obs-plugins/

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
- **概要**: README.md の `#` 見出しの後、最初の空でない行
- **サムネイル**: README.md 内で最初に出現する画像（`![...](./ファイル名.png)` 形式）が一覧ページのカードに表示される。画像がないフィルターはテキストのみで表示される

例えば以下のような README.md の場合:

```markdown
# 🎭 スポットライト

VTuberの歌配信に最適な...   ← これが概要になる
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

## サイトデザインの変更方法

| 変更したい内容 | 修正するファイル |
|---|---|
| 色・フォント・レイアウト | `static/css/style.css` |
| ヘッダー・フッター | `layouts/_default/baseof.html` |
| トップページ（カード一覧） | `layouts/_default/list.html` |
| フィルター個別ページ | `layouts/_default/single.html` |
| サイト名・baseURL | `hugo.toml` |
| トップページの説明文 | `layouts/_default/list.html` 内の `site-description` |


layouts内に現れる謎の構文についてはここを参照してください

Hugo テンプレート入門
https://juggernautjp.info/templates/introduction/