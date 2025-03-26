obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "トランジションフィルター",
    
    -- 設定キー
    SETTING_TRANSITION_TYPE = "transition_type",
    SETTING_TRANSITION_SPEED = "transition_speed",
    SETTING_COLOR_ACCENT = "color_accent",
    SETTING_VERSION = "version",
}

-- トランジションタイプ
local TRANSITION_TYPES = {
    "フェード",      -- クロスフェード効果
    "スライド",      -- 左右にスライド
    "ズーム",        -- ズームイン・アウト
    "回転",          -- 回転エフェクト
    "カラーワイプ",  -- 色の変化を伴うワイプ
    "キラキラ",      -- きらめく星のようなエフェクト
    "波紋"           -- 水の波紋のような効果
}

DESCRIPTION = {
    TITLE = "トランジションフィルター",
    USAGE = "映像ソースにリズミカルなトランジション効果を適用します。配信中の画面切り替えをよりスタイリッシュに演出できます。",
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
source_def.id = "transition_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- 変数
local effect_time = 0

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
    filter.transition_type = "フェード"  -- デフォルト値
    filter.transition_speed = 1.0
    filter.width = 1
    filter.height = 1
    filter.last_time = 0
    filter.color_accent = 0xFF00FFFF  -- デフォルト色（ピンク）
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.effect_time = obs.gs_effect_get_param_by_name(filter.effect, "effect_time")
        filter.params.transition_type = obs.gs_effect_get_param_by_name(filter.effect, "transition_type")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.accent_color_r = obs.gs_effect_get_param_by_name(filter.effect, "accent_color_r")
        filter.params.accent_color_g = obs.gs_effect_get_param_by_name(filter.effect, "accent_color_g")
        filter.params.accent_color_b = obs.gs_effect_get_param_by_name(filter.effect, "accent_color_b")
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
    filter.transition_type = obs.obs_data_get_string(settings, CONSTANTS.SETTING_TRANSITION_TYPE)
    filter.transition_speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_TRANSITION_SPEED)
    filter.color_accent = obs.obs_data_get_int(settings, CONSTANTS.SETTING_COLOR_ACCENT)
    
    -- 色を分解
    filter.accent_color_r = bit.band(filter.color_accent, 0xFF) / 255.0
    filter.accent_color_g = bit.band(bit.rshift(filter.color_accent, 8), 0xFF) / 255.0
    filter.accent_color_b = bit.band(bit.rshift(filter.color_accent, 16), 0xFF) / 255.0
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
    
    -- エフェクト時間を更新
    effect_time = effect_time + time_delta * filter.transition_speed
    
    -- トランジションタイプを数値に変換
    local transition_type_num = 0
    for i, trans_type in ipairs(TRANSITION_TYPES) do
        if trans_type == filter.transition_type then
            transition_type_num = i - 1
            break
        end
    end
    
    -- パラメータ設定
    obs.gs_effect_set_float(filter.params.effect_time, effect_time)
    obs.gs_effect_set_int(filter.params.transition_type, transition_type_num)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.gs_effect_set_float(filter.params.accent_color_r, filter.accent_color_r)
    obs.gs_effect_set_float(filter.params.accent_color_g, filter.accent_color_g)
    obs.gs_effect_set_float(filter.params.accent_color_b, filter.accent_color_b)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- トランジションタイプ
    local transition_type_prop = obs.obs_properties_add_list(
        props,
        CONSTANTS.SETTING_TRANSITION_TYPE,
        "トランジションの種類",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    
    for _, transition_type in ipairs(TRANSITION_TYPES) do
        obs.obs_property_list_add_string(transition_type_prop, transition_type, transition_type)
    end
    
    -- トランジション速度
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_TRANSITION_SPEED,
        "トランジション速度",
        0.1,
        5.0,
        0.1
    )
    
    -- アクセントカラー
    obs.obs_properties_add_color(
        props,
        CONSTANTS.SETTING_COLOR_ACCENT,
        "アクセントカラー"
    )
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_string(settings, CONSTANTS.SETTING_TRANSITION_TYPE, TRANSITION_TYPES[1])
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_TRANSITION_SPEED, 1.0)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_COLOR_ACCENT, 0xFF00FFFF)  -- ピンク色
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

-- シェーダーコード (シンプル化したバージョン)
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

// トランジションパラメータ
uniform float effect_time;
uniform int transition_type;
uniform float resolution_x;
uniform float resolution_y;
uniform float accent_color_r;
uniform float accent_color_g;
uniform float accent_color_b;

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
float random(float2 st) {
    return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453);
}

float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 center = float2(0.5, 0.5);
    float cycle_time = sin(effect_time * 1.5) * 0.5 + 0.5; // 0〜1の周期的な値
    float3 accent_color = float3(accent_color_r, accent_color_g, accent_color_b);
    float4 color = image.Sample(linearSampler, uv);
    
    // トランジションタイプに応じた効果
    if (transition_type == 0) { // フェード
        float4 white = float4(1.0, 1.0, 1.0, color.a);
        // フェードイン・アウト（中央で白くなる）
        float fade_effect = cycle_time;
        color = lerp(color, white, fade_effect);
    }
    else if (transition_type == 1) { // スライド
        float slide = cycle_time * 0.2;
        uv.x += slide;
        // 範囲外処理
        if (uv.x > 1.0) {
            uv.x = uv.x - 1.0;
            // スライド部分を色付けする
            color = image.Sample(linearSampler, uv);
            color.rgb = lerp(color.rgb, accent_color, 0.5);
        } else {
            color = image.Sample(linearSampler, uv);
        }
    }
    else if (transition_type == 2) { // ズーム
        float zoom = 1.0 + cycle_time * 0.3;
        float2 rel_uv = uv - center;
        rel_uv /= zoom;
        uv = rel_uv + center;
        
        if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
            color = image.Sample(linearSampler, uv);
            // ズームエフェクト時に少し色を変える
            color.rgb = lerp(color.rgb, accent_color, cycle_time * 0.3);
        }
    }
    else if (transition_type == 3) { // 回転
        float angle = cycle_time * 0.5; // 最大30度回転
        float2 rel_uv = uv - center;
        float s = sin(angle);
        float c = cos(angle);
        float2 rotated_uv;
        rotated_uv.x = rel_uv.x * c - rel_uv.y * s;
        rotated_uv.y = rel_uv.x * s + rel_uv.y * c;
        rotated_uv += center;
        
        if (rotated_uv.x >= 0.0 && rotated_uv.x <= 1.0 && rotated_uv.y >= 0.0 && rotated_uv.y <= 1.0) {
            color = image.Sample(linearSampler, rotated_uv);
        }
    }
    else if (transition_type == 4) { // カラーワイプ
        float wipe_pos = cycle_time * 2.0 - 0.5;
        float wipe_width = 0.3;
        float wipe_effect = smoothstep(wipe_pos - wipe_width, wipe_pos, uv.x) * 
                             smoothstep(uv.x, wipe_pos + wipe_width, wipe_pos + wipe_width * 2.0);
        color.rgb = lerp(color.rgb, accent_color, wipe_effect);
    }
    else if (transition_type == 5) { // キラキラ
        float4 original_color = color;
        
        // 周期的な時間値
        float sparkle_time = effect_time * 2.0;
        
        // 星の数と大きさ
        float star_count = 30.0;
        float star_size = 0.004 + cycle_time * 0.003;
        
        // 星をランダムに配置
        for (int i = 0; i < 10; i++) {
            // 各星の位置（時間とともに動く）
            float2 star_pos = float2(
                random(float2(i, 0.0)) * 1.0,
                random(float2(0.0, i)) * 1.0
            );
            
            // 時間経過で星を動かす
            star_pos.x += sin(sparkle_time * random(float2(i, i+1))) * 0.1;
            star_pos.y += cos(sparkle_time * random(float2(i+1, i))) * 0.1;
            
            // 現在のピクセルと星の距離
            float dist = distance(uv, star_pos);
            
            // 星の明るさ（時間とともに点滅）
            float brightness = sin(sparkle_time * 3.0 * random(float2(i, i))) * 0.5 + 0.5;
            
            // 星を描画
            if (dist < star_size * brightness) {
                // 星の中心からの距離に基づいてグラデーション
                float gradient = 1.0 - dist / (star_size * brightness);
                float star_alpha = pow(gradient, 2.0) * brightness;
                
                // 星の色はアクセントカラーを基本に
                float3 star_color = lerp(accent_color, float3(1.0, 1.0, 1.0), 0.7) * brightness;
                
                // 元の色に星を合成
                color.rgb = lerp(color.rgb, star_color, star_alpha * cycle_time);
            }
        }
        
        // 全体的な輝きエフェクト
        float glow = pow(cycle_time, 2.0) * 0.2;
        color.rgb = lerp(original_color.rgb, accent_color, glow);
    }
    else if (transition_type == 6) { // 波紋
        float ripple_time = effect_time * 1.0;
        float ripple_count = 3.0; // 波紋の数
        
        // 中心からの距離
        float dist = distance(uv, center);
        
        // 複数の波紋を重ね合わせる
        float ripple_effect = 0.0;
        for (int i = 0; i < 3; i++) {
            float t = ripple_time - float(i) * 0.3; // 各波紋の時間差
            float ripple_radius = frac(t * 0.5) * 1.0; // 波紋の半径
            float ripple_width = 0.05; // 波紋の幅
            
            // 波紋のエフェクト強度（中心から離れるほど弱くなる）
            float ripple = smoothstep(ripple_radius - ripple_width, ripple_radius, dist) * 
                           smoothstep(ripple_radius + ripple_width, ripple_radius, dist);
            
            // 時間経過で波紋が弱くなる
            ripple *= (1.0 - frac(t * 0.5));
            
            ripple_effect += ripple;
        }
        
        // 波紋効果の適用
        ripple_effect = min(ripple_effect, 1.0) * cycle_time;
        
        // 波紋の色を元の色とアクセントカラーの間でブレンド
        color.rgb = lerp(color.rgb, accent_color, ripple_effect * 0.7);
        
        // 波紋によるわずかな歪み
        float2 ripple_distortion = normalize(uv - center) * ripple_effect * 0.03;
        float2 distorted_uv = uv - ripple_distortion;
        
        if (distorted_uv.x >= 0.0 && distorted_uv.x <= 1.0 && distorted_uv.y >= 0.0 && distorted_uv.y <= 1.0) {
            float4 distorted_color = image.Sample(linearSampler, distorted_uv);
            color = lerp(color, distorted_color, ripple_effect * 0.5);
        }
    }
    
    return color;
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]] 