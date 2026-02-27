---
name: obs-create-filter
description: OBS用のLuaフィルタープラグインを実装する。シェーダーを使った映像エフェクト（ぼかし、色調変更、歪み、モザイク等）をLuaスクリプトとして作成。「フィルター追加」「新しいフィルターを作りたい」「〇〇エフェクトを実装して」といったリクエストで使用。Luaスクリプト、シェーダーコード、READMEの全てを実装する。
---

# OBS Lua フィルター作成ガイド

OBSフィルターとは、映像ソースにリアルタイムでエフェクトを適用するプラグイン（モザイク、ぼかし、色調変更、歪み等）。

## 実装手順

### 1. ディレクトリ作成

`scripts/{filter-name}-filter/` ディレクトリを作成

### 2. Luaスクリプト作成

場所: `scripts/{filter-name}-filter/{filter-name}-filter.lua`

#### 基本構造

```lua
obs = obslua

-- 定数定義
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "{日本語フィルター名}",

    -- 設定キー
    SETTING_{PARAM1} = "{param1}",
    SETTING_{PARAM2} = "{param2}",
    SETTING_ENABLED = "enabled",
    SETTING_VERSION = "version",

    -- デフォルト値
    DEFAULT_{PARAM1} = {default_value1},
    DEFAULT_{PARAM2} = {default_value2},
    DEFAULT_ENABLED = true
}

-- 説明文
DESCRIPTION = {
    TITLE = "{フィルター名}",
    BODY = "{フィルターの説明文}",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[<h3>%s</h3><p>%s</p><p>バージョン %s</p><p>© <a href="%s">%s</a></p>]]
}

-- ソース定義
source_def = {}
source_def.id = "{filter_id}_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- サイズ設定関数
function set_render_size(filter)
    local target = obs.obs_filter_get_target(filter.context)
    if target == nil then
        filter.width = 0
        filter.height = 0
        return
    end

    local width = obs.obs_source_get_base_width(target)
    local height = obs.obs_source_get_base_height(target)

    if width ~= filter.width or height ~= filter.height then
        filter.width = width
        filter.height = height
    end
end

-- フィルター名取得
source_def.get_name = function()
    return CONSTANTS.FILTER_NAME
end

-- フィルター作成
source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source
    filter.width = 1
    filter.height = 1

    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)

    if filter.effect ~= nil then
        -- シェーダーパラメータ取得
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        -- 各パラメータを取得
        filter.params.{param1} = obs.gs_effect_get_param_by_name(filter.effect, "{param1}")
    end

    obs.obs_leave_graphics()

    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end

    source_def.update(filter, settings)
    return filter
end

-- フィルター削除
source_def.destroy = function(filter)
    if filter == nil then
        return
    end

    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
        filter.effect = nil
    end
end

-- 設定更新
source_def.update = function(filter, settings)
    filter.enabled = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_ENABLED)
    filter.{param1} = obs.obs_data_get_{type}(settings, CONSTANTS.SETTING_{PARAM1})
    -- 他のパラメータも同様に取得
end

-- レンダリング処理
source_def.video_render = function(filter, effect)
    -- 無効時はスキップ
    if not filter.enabled then
        obs.obs_source_skip_video_filter(filter.context)
        return
    end

    if not obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
        return
    end

    set_render_size(filter)

    if filter.width == 0 or filter.height == 0 or filter.effect == nil then
        obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
        return
    end

    -- パラメータ設定
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.gs_effect_set_float(filter.params.{param1}, filter.{param1})

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()

    -- 有効/無効チェックボックス
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_ENABLED, "フィルターを有効にする")

    -- パラメータ追加（スライダー、リスト、カラーピッカー等）
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_{PARAM1},
        "{パラメータ名}",
        {min}, {max}, {step}
    )

    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_ENABLED, CONSTANTS.DEFAULT_ENABLED)
    obs.obs_data_set_default_{type}(settings, CONSTANTS.SETTING_{PARAM1}, CONSTANTS.DEFAULT_{PARAM1})
    obs.obs_data_set_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
end

-- 定期更新
source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

-- サイズ取得
source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

-- スクリプトの説明
function script_description()
    return string.format(DESCRIPTION.HTML,
        DESCRIPTION.TITLE,
        DESCRIPTION.BODY,
        CONSTANTS.VERSION,
        DESCRIPTION.COPYRIGHT.URL,
        DESCRIPTION.COPYRIGHT.NAME)
end

-- スクリプト読み込み時の処理
function script_load(settings)
    obs.obs_register_source(source_def)
end

-- シェーダーコード
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;
uniform float resolution_x;
uniform float resolution_y;
uniform float {param1};

sampler_state linearSampler {
    Filter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VertData {
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
};

VertData VS(VertData v_in) {
    VertData vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv = v_in.uv;
    return vert_out;
}

float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;

    // エフェクト処理をここに実装

    return image.Sample(linearSampler, uv);
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]]
```

### 3. README.md作成

場所: `scripts/{filter-name}-filter/README.md`

```markdown
# {絵文字} {フィルター名}

{フィルターの詳細な説明文}

## 使用例

![フィルター適用例](./{filter-name}-filter.gif)

## インストール方法

1. [`{filter-name}-filter.lua`](https://raw.githubusercontent.com/pepabo/alive-project-obs-plugins/main/scripts/{filter-name}-filter/{filter-name}-filter.lua) をダウンロード
2. OBSメニューの「ツール」→「スクリプト」を選択
3. 「+」ボタンをクリックし、ダウンロードした「{filter-name}-filter.lua」を選択
4. 「有効なプロパティがありません」と表示されますが、これは正常です

## フィルター適用方法

1. シーンまたはソースを右クリック→「フィルター」を選択
2. 「+」ボタンをクリック→「{日本語フィルター名}」を選択
3. フィルターの設定を調整

## 設定項目

| 項目 | 説明 | 範囲 |
|------|------|------|
| {設定項目名1} | {説明} | {範囲} |
| {設定項目名2} | {説明} | {範囲} |

## 活用例

- {活用例1}
- {活用例2}
- {活用例3}

## ライセンス

このソフトウェアはMITライセンスのもとで公開されています。利用に際して生じたいかなる問題についても、開発元は一切の責任を負いません。詳しくは[LICENSE](https://raw.githubusercontent.com/pepabo/alive-project-obs-plugins/refs/heads/main/LICENSE)をご確認ください。

## 提供

[![Alive Studio](../../assets/alive-studio-logo.png)](https://alive-project.com/studio)

© 2025 GMO Pepabo, Inc. All rights reserved.
```

### 4. メインREADME更新

`README.md` のスクリプト一覧に追加:

```markdown
- [{フィルター名}](./scripts/{filter-name}-filter/README.md) - {簡単な説明}
```

## プロパティの種類

### スライダー

```lua
-- 整数スライダー
obs.obs_properties_add_int_slider(props, "key", "ラベル", min, max, step)

-- 浮動小数スライダー
obs.obs_properties_add_float_slider(props, "key", "ラベル", min, max, step)
```

### リスト

```lua
local list_prop = obs.obs_properties_add_list(
    props, "key", "ラベル",
    obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT
)
obs.obs_property_list_add_int(list_prop, "選択肢1", 0)
obs.obs_property_list_add_int(list_prop, "選択肢2", 1)
```

### カラーピッカー

```lua
obs.obs_properties_add_color(props, "key", "色")
```

### チェックボックス

```lua
obs.obs_properties_add_bool(props, "key", "ラベル")
```

### 画像ファイル

```lua
obs.obs_properties_add_path(props, "key", "画像", obs.OBS_PATH_FILE,
    "Images (*.png *.jpg *.jpeg *.gif *.bmp)", nil)
```

## シェーダーパラメータ型

| Lua型 | シェーダー型 | obs関数 |
|-------|-------------|---------|
| int | int | `obs.gs_effect_set_int()` |
| double | float | `obs.gs_effect_set_float()` |
| bool | bool | `obs.gs_effect_set_bool()` |
| color (int) | float3/float4 | 色分解が必要 |

### 色の分解例

```lua
-- 更新時
local bit = bit or bit32
filter.color_r = bit.band(filter.color, 0xFF) / 255.0
filter.color_g = bit.band(bit.rshift(filter.color, 8), 0xFF) / 255.0
filter.color_b = bit.band(bit.rshift(filter.color, 16), 0xFF) / 255.0
```

## 時間ベースアニメーション

```lua
-- グローバル変数
local effect_time = 0

-- video_render内で時間を更新
local current_time = obs.os_gettime_ns() / 1000000000.0
local time_delta = current_time - filter.last_time
filter.last_time = current_time
effect_time = effect_time + time_delta * filter.speed

-- シェーダーに渡す
obs.gs_effect_set_float(filter.params.effect_time, effect_time)
```

## 画像テクスチャの読み込み

```lua
-- create時
if filter.image_path and filter.image_path ~= "" then
    obs.obs_enter_graphics()
    filter.image_texture = obs.gs_image_file_create(filter.image_path)
    if filter.image_texture and filter.image_texture.loaded then
        filter.params.overlay_image = obs.gs_effect_get_param_by_name(filter.effect, "overlay_image")
    end
    obs.obs_leave_graphics()
end

-- destroy時
if filter.image_texture then
    obs.obs_enter_graphics()
    obs.gs_image_file_free(filter.image_texture)
    obs.obs_leave_graphics()
end

-- video_render時
if filter.image_texture and filter.image_texture.texture then
    obs.gs_effect_set_texture(filter.params.overlay_image, filter.image_texture.texture)
end
```

## 命名規則

| 項目 | 形式 | 例 |
|------|------|-----|
| ディレクトリ名 | kebab-case | `drop-shadow-filter` |
| ファイル名 | kebab-case | `drop-shadow-filter.lua` |
| source_def.id | snake_case | `drop_shadow_filter` |
| 定数キー | SCREAMING_SNAKE | `SETTING_SHADOW_BLUR` |
| シェーダー変数 | snake_case | `shadow_blur` |

## 既存フィルター参照

実装の詳細は以下のフィルターを参照:

- シンプルな例: `scripts/mosaic-filter/mosaic-filter.lua`
- 影・ぼかし: `scripts/drop-shadow-filter/drop-shadow-filter.lua`
- 時間アニメーション: `scripts/landscape-loop-filter/landscape-loop-filter.lua`
- 画像オーバーレイ: `scripts/face-hole-filter/face-hole-filter.lua`
