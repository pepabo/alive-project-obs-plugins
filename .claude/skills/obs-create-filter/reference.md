# OBSフィルター 実装リファレンス

## 既存フィルター一覧

| id | 日本語名 | 配置場所 | 主な機能 |
|----|---------|---------|---------|
| halftone_dot_filter | ドット絵フィルター | scripts/halftone-dot-filter/ | 映像をドット絵に変換 |
| mosaic_filter | モザイク | scripts/mosaic-filter/ | 映像にモザイクをかける |
| rounded_corner_filter | 角丸フィルター | scripts/rounded-corner-filter/ | 映像に角丸効果を追加 |
| animation_filter | アニメーション | scripts/animation-filter/ | 映像にアニメーションを追加 |
| face_hole_filter | 顔ハメパネル | scripts/face-hole-filter/ | 映像に顔ハメパネルを追加 |
| rotation_filter | 回転フィルター | scripts/rotation-filter/ | 映像を回転させる |
| 3drotation_filter | 3D回転フィルター | scripts/3drotation-filter/ | 映像を3D的に回転させる |
| animation_frame_filter | アニメーションフレーム | scripts/animation-frame-filter/ | 映像にアニメーションフレームを追加 |
| transition_filter | トランジションフィルター | scripts/transition-filter/ | 映像にトランジション効果を追加 |
| film_camera_filter | フィルムカメラフィルター | scripts/film-camera-filter/ | 映像にフィルムカメラのような質感を追加 |
| spotlight_filter | スポットライト | scripts/spotlight-filter/ | 映像にスポットライトを追加 |
| pendulum_filter | 振り子フィルター | scripts/pendulum-filter/ | 映像を振り子のように揺らす |
| pin_filter | ピンフィルター | scripts/pin-filter/ | 映像にピン型のフィルターを追加 |
| water_immersion_filter | 水中効果フィルター | scripts/water-immersion-filter/ | 映像に水中効果を追加 |
| popout_wipe_filter | ポップアウトワイプフィルター | scripts/popout-wipe-filter/ | 映像にポップアウトワイプ効果を追加 |
| drop_shadow_filter | 影フィルター | scripts/drop-shadow-filter/ | 映像に影を追加 |
| magnifier_filter | ルーペフィルター | scripts/magnifier-filter/ | 映像にルーペを追加 |
| landscape_loop_filter | 風景ループフィルター | scripts/landscape-loop-filter/ | 映像の風景をループさせる効果を追加 |

## ファイル配置パス

```text
scripts/
├── {filter-name}-filter/
│   ├── {filter-name}-filter.lua    # メインスクリプト
│   ├── README.md                    # ドキュメント
│   └── {filter-name}-filter.gif     # 使用例GIF（オプション）
├── README.md                        # メインREADME（スクリプト一覧）
├── LICENSE                          # ライセンスファイル
└── assets/
    └── alive-studio-logo.png        # ロゴ画像
```

## 完全な実装例: モザイクフィルター（シンプル）

```lua
obs = obslua

-- 定数定義
local CONSTANTS = {
    VERSION = "1.0.0",

    -- UI表示テキスト
    FILTER_NAME = "モザイク",
    DOT_SIZE_LABEL = "モザイクサイズ",
    TEXT_VERSION = "バージョン",
    TEXT_ENABLED = "フィルターを有効にする",

    -- 設定キー
    DOT_SIZE_KEY = "dot_size",
    SETTING_VERSION = "version",
    SETTING_ENABLED = "enabled",

    -- デフォルト値
    DEFAULT_DOT_SIZE = 12,
    DEFAULT_ENABLED = true,

    -- 説明文
    DESCRIPTION = {
        TITLE = "映像ソースにモザイクをかけるフィルターです。",
        USAGE = "「モザイクサイズ」で粗さを調整できます。",
        COPYRIGHT = {
            NAME = "Alive Project byGMOペパボ",
            URL = "https://alive-project.com/"
        },
        HTML = [[<p>%s%s</p>
    <p>バージョン %s</p>
    <p>© <a href="%s">%s</a></p>]]
    }
}

-- ソース定義
source_def = {}
source_def.id = 'mosaic_filter'
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- レンダリングサイズを設定する関数
function set_render_size(filter)
    local target = obs.obs_filter_get_target(filter.context)
    if target == nil then
        filter.width = 0
        filter.height = 0
    else
        filter.width = obs.obs_source_get_base_width(target)
        filter.height = obs.obs_source_get_base_height(target)
    end
end

-- フィルター名を返す関数
source_def.get_name = function()
    return CONSTANTS.FILTER_NAME
end

-- フィルターの作成時に呼ばれる関数
source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source

    set_render_size(filter)

    -- シェーダーエフェクトの作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    if filter.effect ~= nil then
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, 'resolution_x')
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, 'resolution_y')
        filter.params.dot_size = obs.gs_effect_get_param_by_name(filter.effect, 'dot_size')
    end
    obs.obs_leave_graphics()

    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end

    source_def.update(filter, settings)
    return filter
end

source_def.destroy = function(filter)
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

source_def.update = function(filter, settings)
    filter.enabled = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_ENABLED)
    filter.dot_size = obs.obs_data_get_int(settings, CONSTANTS.DOT_SIZE_KEY)
    if filter.effect ~= nil then
        obs.gs_effect_set_float(filter.params.dot_size, filter.dot_size)
    end
    set_render_size(filter)
end

source_def.video_render = function(filter, effect)
    if not filter.enabled then
        obs.obs_source_skip_video_filter(filter.context)
        return
    end

    if not obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
        return
    end

    if filter.width and filter.height then
        obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
        obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    end

    obs.gs_effect_set_float(filter.params.dot_size, filter.dot_size)
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_ENABLED, CONSTANTS.TEXT_ENABLED)
    obs.obs_properties_add_int_slider(props, CONSTANTS.DOT_SIZE_KEY, CONSTANTS.DOT_SIZE_LABEL, 1, 100, 1)
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, CONSTANTS.TEXT_VERSION, obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_ENABLED, CONSTANTS.DEFAULT_ENABLED)
    obs.obs_data_set_default_int(settings, CONSTANTS.DOT_SIZE_KEY, CONSTANTS.DEFAULT_DOT_SIZE)
    obs.obs_data_set_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
end

source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

function script_description()
    return string.format(CONSTANTS.DESCRIPTION.HTML,
        CONSTANTS.DESCRIPTION.TITLE,
        CONSTANTS.DESCRIPTION.USAGE,
        CONSTANTS.VERSION,
        CONSTANTS.DESCRIPTION.COPYRIGHT.URL,
        CONSTANTS.DESCRIPTION.COPYRIGHT.NAME)
end

function script_load(settings)
    obs.obs_register_source(source_def)
end

shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;
uniform float resolution_x;
uniform float resolution_y;
uniform float dot_size;

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
    float scale = resolution_x / dot_size;
    uv = floor(uv * scale) / scale;
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

## 完全な実装例: 影フィルター（カラーピッカー + ぼかし）

```lua
obs = obslua
local bit = bit or bit32

local CONSTANTS = {
    VERSION = "shadow-stable",
    FILTER_NAME = "影フィルター",
    SETTING_OFFSET_X = "offset_x",
    SETTING_OFFSET_Y = "offset_y",
    SETTING_OPACITY = "shadow_opacity",
    SETTING_COLOR = "shadow_color",
    SETTING_BLUR = "shadow_blur",
    SETTING_SCALE = "shadow_scale"
}

-- ソース定義
source_def = {}
source_def.id = "drop_shadow_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

source_def.update = function(filter, settings)
    filter.offset_x = obs.obs_data_get_double(settings, CONSTANTS.SETTING_OFFSET_X) or 20.0
    filter.offset_y = obs.obs_data_get_double(settings, CONSTANTS.SETTING_OFFSET_Y) or 20.0
    filter.shadow_opacity = obs.obs_data_get_double(settings, CONSTANTS.SETTING_OPACITY) or 0.7
    filter.shadow_color = obs.obs_data_get_int(settings, CONSTANTS.SETTING_COLOR) or 0xFF000000
    filter.shadow_blur = obs.obs_data_get_double(settings, CONSTANTS.SETTING_BLUR) or 20.0
    filter.shadow_scale = obs.obs_data_get_double(settings, CONSTANTS.SETTING_SCALE) or 1.0

    -- 色分解（重要）
    filter.shadow_color_r = bit.band(filter.shadow_color, 0xFF) / 255.0
    filter.shadow_color_g = bit.band(bit.rshift(filter.shadow_color, 8), 0xFF) / 255.0
    filter.shadow_color_b = bit.band(bit.rshift(filter.shadow_color, 16), 0xFF) / 255.0
end

source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_OFFSET_X, "影のオフセットX", -100.0, 100.0, 1.0)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_OFFSET_Y, "影のオフセットY", -100.0, 100.0, 1.0)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_OPACITY, "影の不透明度", 0.0, 1.0, 0.01)
    obs.obs_properties_add_color(props, CONSTANTS.SETTING_COLOR, "影の色")
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_BLUR, "影のぼかし量", 0.0, 50.0, 1.0)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_SCALE, "影の大きさ（スケール）", 0.5, 2.0, 0.01)
    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_OFFSET_X, 20.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_OFFSET_Y, 20.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_OPACITY, 0.7)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_COLOR, 0xFF000000)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_BLUR, 20.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SCALE, 1.0)
end
```

## 完全な実装例: 風景ループフィルター（時間アニメーション + リスト選択）

```lua
obs = obslua

local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "風景ループフィルター",
    SETTING_LOOP_DIRECTION = "loop_direction",
    SETTING_MOVEMENT_DIRECTION = "movement_direction",
    SETTING_MOVEMENT_SPEED = "movement_speed",
    SETTING_LOOP_OFFSET = "loop_offset",
    SETTING_ENABLED = "enabled"
}

-- 選択肢リスト
local LOOP_DIRECTIONS = {
    "水平（左右）",
    "垂直（上下）",
    "水平+垂直（斜め）"
}

local MOVEMENT_DIRECTIONS = {
    "右方向",
    "左方向",
    "下方向",
    "上方向"
}

-- 時間管理用グローバル変数
local effect_time = 0

source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source
    filter.loop_direction = 0
    filter.movement_direction = 0
    filter.movement_speed = 1.0
    filter.loop_offset = 0.0
    filter.enabled = true
    filter.width = 1
    filter.height = 1
    filter.last_time = 0  -- 時間追跡用

    -- シェーダー作成とパラメータ取得
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)

    if filter.effect ~= nil then
        filter.params.loop_direction = obs.gs_effect_get_param_by_name(filter.effect, "loop_direction")
        filter.params.movement_direction = obs.gs_effect_get_param_by_name(filter.effect, "movement_direction")
        filter.params.movement_speed = obs.gs_effect_get_param_by_name(filter.effect, "movement_speed")
        filter.params.loop_offset = obs.gs_effect_get_param_by_name(filter.effect, "loop_offset")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.effect_time = obs.gs_effect_get_param_by_name(filter.effect, "effect_time")
    end

    obs.obs_leave_graphics()

    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end

    source_def.update(filter, settings)
    return filter
end

source_def.video_render = function(filter, effect)
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

    -- 時間更新（アニメーション用）
    local current_time = obs.os_gettime_ns() / 1000000000.0
    local time_delta = current_time - filter.last_time
    filter.last_time = current_time
    effect_time = effect_time + time_delta * filter.movement_speed

    -- パラメータ設定
    obs.gs_effect_set_int(filter.params.loop_direction, filter.loop_direction)
    obs.gs_effect_set_int(filter.params.movement_direction, filter.movement_direction)
    obs.gs_effect_set_float(filter.params.movement_speed, filter.movement_speed)
    obs.gs_effect_set_float(filter.params.loop_offset, filter.loop_offset)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.gs_effect_set_float(filter.params.effect_time, effect_time)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- リスト選択プロパティ
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()

    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_ENABLED, "フィルターを有効にする")

    -- ループ方向リスト
    local direction_prop = obs.obs_properties_add_list(props, CONSTANTS.SETTING_LOOP_DIRECTION, "ループ方向",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)

    for i, direction in ipairs(LOOP_DIRECTIONS) do
        obs.obs_property_list_add_int(direction_prop, direction, i - 1)
    end

    -- 移動方向リスト
    local movement_prop = obs.obs_properties_add_list(props, CONSTANTS.SETTING_MOVEMENT_DIRECTION, "移動方向",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)

    for i, direction in ipairs(MOVEMENT_DIRECTIONS) do
        obs.obs_property_list_add_int(movement_prop, direction, i - 1)
    end

    -- スライダー
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_MOVEMENT_SPEED, "移動速度", 0.1, 5.0, 0.1)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_LOOP_OFFSET, "ループオフセット", 0.0, 1.0, 0.01)

    return props
end
```

## シェーダーパターン集

### UV座標の歪み（波紋効果）

```hlsl
float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);

    // 波紋効果
    float wave = sin(dist * frequency - time * speed) * amplitude;
    float2 offset = normalize(uv - center) * wave;

    return image.Sample(linearSampler, uv + offset);
}
```

### 色調変更（セピア）

```hlsl
float4 PS(VertData v_in) : TARGET {
    float4 color = image.Sample(linearSampler, v_in.uv);

    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
    float3 sepia = float3(gray * 1.2, gray * 1.0, gray * 0.8);

    return float4(lerp(color.rgb, sepia, intensity), color.a);
}
```

### ぼかし（ガウシアン3x3）

```hlsl
float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 texel = float2(1.0 / resolution_x, 1.0 / resolution_y) * blur_amount;

    float4 sum = float4(0, 0, 0, 0);
    sum += image.Sample(linearSampler, uv + float2(-texel.x, -texel.y)) * 0.0625;
    sum += image.Sample(linearSampler, uv + float2(0, -texel.y)) * 0.125;
    sum += image.Sample(linearSampler, uv + float2(texel.x, -texel.y)) * 0.0625;
    sum += image.Sample(linearSampler, uv + float2(-texel.x, 0)) * 0.125;
    sum += image.Sample(linearSampler, uv) * 0.25;
    sum += image.Sample(linearSampler, uv + float2(texel.x, 0)) * 0.125;
    sum += image.Sample(linearSampler, uv + float2(-texel.x, texel.y)) * 0.0625;
    sum += image.Sample(linearSampler, uv + float2(0, texel.y)) * 0.125;
    sum += image.Sample(linearSampler, uv + float2(texel.x, texel.y)) * 0.0625;

    return sum;
}
```

### ビネット（周辺減光）

```hlsl
float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 color = image.Sample(linearSampler, uv);

    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);
    float vignette = 1.0 - smoothstep(inner_radius, outer_radius, dist);

    return float4(color.rgb * vignette, color.a);
}
```

### 回転

```hlsl
float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 center = float2(0.5, 0.5);

    float2 centered = uv - center;
    float s = sin(angle);
    float c = cos(angle);
    float2 rotated = float2(
        centered.x * c - centered.y * s,
        centered.x * s + centered.y * c
    );

    return image.Sample(linearSampler, rotated + center);
}
```

### スケール（拡大縮小）

```hlsl
float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 center = float2(0.5, 0.5);
    float2 scaled = (uv - center) / scale + center;

    return image.Sample(linearSampler, scaled);
}
```

## OBS Lua API リファレンス

### 設定データの取得

```lua
-- 各型の取得関数
obs.obs_data_get_bool(settings, key)      -- bool
obs.obs_data_get_int(settings, key)       -- int
obs.obs_data_get_double(settings, key)    -- double (float)
obs.obs_data_get_string(settings, key)    -- string
```

### 設定データのデフォルト値設定

```lua
obs.obs_data_set_default_bool(settings, key, value)
obs.obs_data_set_default_int(settings, key, value)
obs.obs_data_set_default_double(settings, key, value)
obs.obs_data_set_default_string(settings, key, value)
```

### プロパティUI

```lua
-- 基本プロパティ
obs.obs_properties_add_bool(props, key, label)
obs.obs_properties_add_int(props, key, label, min, max, step)
obs.obs_properties_add_int_slider(props, key, label, min, max, step)
obs.obs_properties_add_float(props, key, label, min, max, step)
obs.obs_properties_add_float_slider(props, key, label, min, max, step)
obs.obs_properties_add_text(props, key, label, type)
obs.obs_properties_add_color(props, key, label)
obs.obs_properties_add_path(props, key, label, type, filter, default)

-- リスト
local list = obs.obs_properties_add_list(props, key, label, combo_type, format)
obs.obs_property_list_add_int(list, name, value)
obs.obs_property_list_add_string(list, name, value)
```

### シェーダーパラメータ設定

```lua
obs.gs_effect_set_bool(param, value)
obs.gs_effect_set_int(param, value)
obs.gs_effect_set_float(param, value)
obs.gs_effect_set_vec2(param, vec)
obs.gs_effect_set_vec3(param, vec)
obs.gs_effect_set_vec4(param, vec)
obs.gs_effect_set_texture(param, texture)
```

### 時間取得

```lua
-- ナノ秒で現在時刻を取得
local ns = obs.os_gettime_ns()
-- 秒に変換
local seconds = ns / 1000000000.0
```

## チェックリスト

新しいフィルター作成時:

- [ ] `scripts/{filter-name}-filter/` ディレクトリ作成
- [ ] `{filter-name}-filter.lua` 作成
  - [ ] CONSTANTS定義
  - [ ] source_def定義
  - [ ] set_render_size関数
  - [ ] get_name関数
  - [ ] create関数（シェーダー作成）
  - [ ] destroy関数
  - [ ] update関数
  - [ ] video_render関数
  - [ ] get_properties関数
  - [ ] get_defaults関数
  - [ ] video_tick関数
  - [ ] get_width/get_height関数
  - [ ] script_description関数
  - [ ] script_load関数
  - [ ] シェーダーコード
- [ ] `README.md` 作成
  - [ ] フィルター説明
  - [ ] 使用例GIF（オプション）
  - [ ] インストール方法
  - [ ] フィルター適用方法
  - [ ] 設定項目テーブル
  - [ ] 活用例
  - [ ] ライセンス
  - [ ] 提供元
- [ ] メイン `README.md` のスクリプト一覧に追加
- [ ] OBSでテスト
  - [ ] フィルターが正しく登録されるか
  - [ ] パラメータが反映されるか
  - [ ] 有効/無効が動作するか
