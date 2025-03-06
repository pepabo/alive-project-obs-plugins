obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "アニメーション",

    -- 設定キー
    SETTING_ANIMATION_TYPE = "animation_type",
    SETTING_ANIMATION_SPEED = "animation_speed",
    SETTING_ANIMATION_INTENSITY = "animation_intensity",
    SETTING_VERSION = "version",
}

-- アニメーションタイプ
local ANIMATION_TYPES = {
    "なし",
    "ゆらゆら",      -- 波のような動き
    "ぴょんぴょん",  -- ジャンプ
    "ぽよぽよ",      -- パルス（拡大縮小）
    "ぶるぶる",      -- シェイク
    "ふわふわ",      -- 浮遊感
    "ばんばん",      -- 弾む
    "もじもじ",      -- 恥ずかしがるような動き
    "にこにこ",      -- 笑顔のような膨らむ動き
    "どきどき",      -- 鼓動のような動き
    "ランダム"       -- ランダムに動きが変化
}

DESCRIPTION = {
    TITLE = "アニメーション",
    USAGE = "映像ソースにアニメーション効果を適用します。ぷるぷるしたり、はねたりなど動きを変えることで、配信画面をより魅力的なものにできます。",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[
    <h3>%s</h3>
    <p>%s</p>
    <p>バージョン %s</p>
    <p>© <a href="%s">%s</a></p>]]
}

-- ソース定義
source_def = {}
source_def.id = "animation_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- アニメーション関連の変数
local animation_time = 0

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

    -- 基本設定
    filter.animation_type = "なし"  -- デフォルト値
    filter.animation_speed = 1.0
    filter.animation_intensity = 1.0
    filter.width = 1
    filter.height = 1
    filter.last_time = 0

    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)

    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.animation_time = obs.gs_effect_get_param_by_name(filter.effect, "animation_time")
        filter.params.animation_type = obs.gs_effect_get_param_by_name(filter.effect, "animation_type")
        filter.params.animation_intensity = obs.gs_effect_get_param_by_name(filter.effect, "animation_intensity")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
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
    filter.animation_type = obs.obs_data_get_string(settings, CONSTANTS.SETTING_ANIMATION_TYPE)
    filter.animation_speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_ANIMATION_SPEED)
    filter.animation_intensity = obs.obs_data_get_double(settings, CONSTANTS.SETTING_ANIMATION_INTENSITY)
end

-- レンダリング処理
source_def.video_render = function(filter, effect)
    if not obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
        return
    end

    set_render_size(filter)

    if filter.width == 0 or filter.height == 0 or filter.effect == nil then
        obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
        return
    end

    -- 現在の時間を取得
    local current_time = obs.os_gettime_ns() / 1000000000.0
    local time_delta = current_time - filter.last_time
    filter.last_time = current_time

    -- アニメーション時間を更新
    animation_time = animation_time + time_delta * filter.animation_speed

    -- アニメーションタイプを数値に変換
    local animation_type_num = 0
    for i, anim_type in ipairs(ANIMATION_TYPES) do
        if anim_type == filter.animation_type then
            animation_type_num = i - 1
            break
        end
    end

    -- パラメータ設定
    obs.gs_effect_set_float(filter.params.animation_time, animation_time)
    obs.gs_effect_set_int(filter.params.animation_type, animation_type_num)
    obs.gs_effect_set_float(filter.params.animation_intensity, filter.animation_intensity)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()

    -- アニメーションタイプ
    local animation_type_prop = obs.obs_properties_add_list(
        props,
        CONSTANTS.SETTING_ANIMATION_TYPE,
        "エフェクトの種類",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )

    for _, animation_type in ipairs(ANIMATION_TYPES) do
        obs.obs_property_list_add_string(animation_type_prop, animation_type, animation_type)
    end

    -- アニメーション速度
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_ANIMATION_SPEED,
        "動きの速さ",
        0.1,
        5.0,
        0.1
    )

    -- アニメーション強度
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_ANIMATION_INTENSITY,
        "動きの大きさ",
        0.1,
        3.0,
        0.1
    )

    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_string(settings, CONSTANTS.SETTING_ANIMATION_TYPE, ANIMATION_TYPES[1])
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_ANIMATION_SPEED, 1.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_ANIMATION_INTENSITY, 1.0)
    obs.obs_data_set_default_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
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
      DESCRIPTION.USAGE,
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

// アニメーションパラメータ
uniform float animation_time;
uniform int animation_type;
uniform float animation_intensity;
uniform float resolution_x;
uniform float resolution_y;

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

// 簡易的なランダム関数
float random(float seed) {
    return frac(sin(seed * 12.9898) * 43758.5453);
}

float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 center = float2(0.5, 0.5);
    float intensity = animation_intensity;

    // ランダムモード用の変数
    float random_seed = floor(animation_time * 0.2); // 約5秒ごとに変化
    float random_type = floor(random(random_seed) * 9) + 1; // 1～9のランダム値

    // アニメーションタイプの決定（ランダムモードの場合は動的に決定）
    int current_type = animation_type;
    if (animation_type == 10) { // ランダムモード
        current_type = int(random_type);
    }

    // アニメーションタイプに応じた変換を適用
    if (current_type == 1) { // ゆらゆら（波のような動き）
        uv.x += sin(animation_time * 2 + uv.y * 10) * 0.02 * intensity;
        uv.y += sin(animation_time * 1.5 + uv.x * 8) * 0.01 * intensity;
    }
    else if (current_type == 2) { // ぴょんぴょん（ジャンプ）
        float jump = abs(sin(animation_time * 3)) * 0.05 * intensity;
        float stretch = 1.0 + sin(animation_time * 3) * 0.03 * intensity;

        // 中心からの相対座標
        float2 rel_uv = uv - center;

        // Y方向の移動と伸縮
        rel_uv.y /= stretch;
        uv = rel_uv + center;
        uv.y -= jump;
    }
    else if (current_type == 3) { // ぽよぽよ（パルス・拡大縮小）
        float pulse = 1.0 + sin(animation_time * 4) * 0.05 * intensity;

        // 中心からの相対座標
        float2 rel_uv = uv - center;

        // 均等にスケーリング
        rel_uv /= pulse;

        // 中心に戻す
        uv = rel_uv + center;
    }
    else if (current_type == 4) { // ぶるぶる（シェイク）
        uv.x += sin(animation_time * 20) * 0.01 * intensity;
        uv.y += cos(animation_time * 18) * 0.005 * intensity;
    }
    else if (current_type == 5) { // ふわふわ（浮遊感）
        // 浮遊する動き
        uv.y += sin(animation_time * 1.2) * 0.03 * intensity;

        // 中心からの相対座標
        float2 rel_uv = uv - center;

        // 軽いパルス効果
        float pulse = 1.0 + sin(animation_time * 0.8) * 0.02 * intensity;
        rel_uv /= pulse;

        // 軽い回転
        float angle = sin(animation_time * 0.5) * 0.1 * intensity;
        float s = sin(angle);
        float c = cos(angle);
        float2 rotated_uv;
        rotated_uv.x = rel_uv.x * c - rel_uv.y * s;
        rotated_uv.y = rel_uv.x * s + rel_uv.y * c;

        // 中心に戻す
        uv = rotated_uv + center;
    }
    else if (current_type == 6) { // ばんばん（弾む）
        float bounce = abs(frac(animation_time * 0.8) * 2.0 - 1.0);
        bounce = 1.0 - bounce * bounce; // イージング

        // 中心からの相対座標
        float2 rel_uv = uv - center;

        // X方向に広がり、Y方向に縮む
        float scale_y = 1.0 - bounce * 0.15 * intensity;
        float scale_x = 1.0 + bounce * 0.1 * intensity;
        rel_uv.x /= scale_x;
        rel_uv.y /= scale_y;

        // 中心に戻す
        uv = rel_uv + center;

        // 上方向への移動
        uv.y += bounce * 0.05 * intensity;
    }
    else if (current_type == 7) { // もじもじ（恥ずかしがるような動き）
        // もじもじの基本パターン（小刻みに揺れる）
        float time_factor = animation_time * 5.0;

        // 不規則な小刻みな動き（波ではなく、ランダムな揺れ）
        float mojimoji_x = sin(time_factor) * sin(time_factor * 1.5) * sin(time_factor * 0.7);
        float mojimoji_y = cos(time_factor * 1.2) * sin(time_factor * 0.8);

        // 強度調整
        mojimoji_x *= intensity * 0.015;
        mojimoji_y *= intensity * 0.01;

        // 中心からの相対座標
        float2 rel_uv = uv - center;
        float dist = length(rel_uv);

        // 距離に応じた変形（端の方が強く揺れる）
        float edge_factor = smoothstep(0.3, 0.5, dist);

        // 小刻みに揺れる動き
        uv.x += mojimoji_x * edge_factor;
        uv.y += mojimoji_y * edge_factor;

        // 時々縮こまる（恥ずかしがるような動き）
        float shrink = abs(sin(animation_time * 0.8)) * intensity * 0.03;

        // 縮こまる動きを適用（中心に向かって少し引っ張られる）
        uv = lerp(uv, center, shrink * edge_factor);
    }
    else if (current_type == 8) { // にこにこ（笑顔のような膨らむ動き）
        // よりはっきりとした笑顔の動き
        float smile_time = animation_time * 1.2;
        float smile_strength = (sin(smile_time) * 0.5 + 0.5) * intensity * 0.2; // 強度を2倍に

        // 中心からの相対座標
        float2 rel_uv = uv - center;

        // 下半分を膨らませる（笑顔のように）
        if (rel_uv.y > 0) {
            // 下半分の中央部分を強調
            float y_factor = smoothstep(0, 0.5, rel_uv.y);
            float x_factor = pow(1.0 - min(1.0, abs(rel_uv.x) * 2.5), 2.0); // より中央に集中

            // 横方向に膨らむ（より強く）
            rel_uv.x *= 1.0 + smile_strength * y_factor * x_factor * 1.5;

            // 縦方向は少し縮める（笑顔の形に）
            rel_uv.y *= 1.0 - smile_strength * 0.3 * x_factor;
        }
        // 上半分は少し縮める（目が細くなるイメージ）
        else {
            float y_factor = smoothstep(-0.4, 0, rel_uv.y);
            float x_factor = 1.0 - min(1.0, abs(rel_uv.x) * 3.0);

            // 上部中央を少し下に引っ張る（目が細くなる感じ）
            rel_uv.y += smile_strength * 0.1 * x_factor * y_factor;
        }

        // 中心に戻す
        uv = rel_uv + center;

        // 全体的に少し上に移動（笑顔で上を向くような感じ）
        uv.y -= smile_strength * 0.03;
    }
    else if (current_type == 9) { // どきどき（鼓動のような動き）
        // 鼓動のタイミング（不規則に）
        float beat_time = animation_time * 1.2;
        float beat_phase = frac(beat_time);

        // 鼓動の強さ（急に大きくなってゆっくり戻る）
        float beat_strength = exp(-beat_phase * 5.0) * 0.1 * intensity;

        // 中心からの相対座標
        float2 rel_uv = uv - center;

        // 鼓動に合わせて拡大縮小
        rel_uv /= 1.0 + beat_strength;

        // 中心に戻す
        uv = rel_uv + center;

        // 鼓動に合わせて少し揺れる
        uv.x += sin(animation_time * 8) * beat_strength * 0.1;
        uv.y += cos(animation_time * 7) * beat_strength * 0.1;
    }

    // 範囲外の場合は透明を返す
    if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1) {
        return float4(0, 0, 0, 0);
    }

    return image.Sample(linearSampler, uv);
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]]
