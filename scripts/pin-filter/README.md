# 📍 位置情報ピンフィルター

映像ソースを円形にくり抜き、下部に三角マークを付けたピン型のフィルターです。地図上の位置を示すピンのような見た目で、配信画面をより魅力的に演出できます。

## 🎥 使用例

![フィルター適用](pinfilter_capture.png)

## 🔧 インストール方法

1. [`pin-filter.lua`](https://raw.githubusercontent.com/pepabo/alive-project-obs-plugins/main/scripts/pin-filter/pin-filter.lua)をダウンロード

    - リンクを右クリックして、「リンク先を別名で保存」を選択するとダウンロードできます。

2. OBSメニューの「ツール」→「スクリプト」を選択
3. 「+」ボタンをクリックし、ダウンロードした「pin-filter.lua」を選択
4. 「有効なプロパティがありません」と表示されますが、これは正常です

## 🎬 フィルター適用方法

1. シーンまたはソースを右クリック→「フィルター」を選択
2. 「+」ボタンをクリック→「位置情報ピンフィルター」を選択
3. フィルターの設定を調整

## ⚙️ 設定項目

| 項目 | 説明 | 範囲 |
| ---- | ---- | ---- |
| 円の半径 | 円形の大きさを調整 | 10-500ピクセル |
| 三角マークのサイズ | 下部の三角マークの大きさを調整 | 5-50ピクセル |
| 枠の色 | 円の枠線と三角マークの色を設定 | カラーピッカー |


## 💡 活用例

- 位置やキャラクターを示す演出
- 注目ポイントの強調
- 装飾パーツとしての使用
- 以下のような演出が可能：
  - 画面上での位置表示
  - ゲーム配信などで選択キャラクターをわかりやすく表示
  - 装飾的な要素としての使用

## 📝 ライセンス

このソフトウェアはMITライセンスのもとで公開されています。利用に際して生じたいかなる問題についても、開発元は一切の責任を負いません。詳しくは[LICENSE](../../LICENSE)をご確認ください。

## 🎯 提供

[![Alive Studio](../../assets/alive-studio-logo.png)](https://alive-project.com/studio)

© 2025 GMO Pepabo, Inc. All rights reserved. 