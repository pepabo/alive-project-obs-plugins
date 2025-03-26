obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.1.0",
    FILTER_NAME = "アニメーションフレーム",
    
    -- 設定キー
    SETTING_RADIUS = "radius",
    SETTING_FRAME_STYLE = "frame_style",
    SETTING_ANIMATION_SPEED = "animation_speed",
    SETTING_FRAME_WIDTH = "frame_width",
    SETTING_COLOR_PRIMARY = "color_primary",
    SETTING_COLOR_SECONDARY = "color_secondary",
    SETTING_COLOR_ANIMATION = "color_animation",
    SETTING_STATIC_MODE = "static_mode",
    SETTING_VERSION = "version"
}

-- フレームスタイル（更新版）
local FRAME_STYLES = {
    -- かわいい系
    "ふわふわ",     -- ふわふわした柔らかい枠線
    
    -- かっこいい系
    "シャープ",     -- 直線的でかっこいい枠
    "ネオン",       -- 光る縁取り
    "サイバー",     -- SF風デジタル
    
    -- おしゃれ系
    "水彩",         -- 水彩画風の柔らかいエッジ
    
    -- ベーシック
    "シンプル",     -- 通常の枠線
    "グラデーション" -- グラデーションカラー
}

DESCRIPTION = {
    TITLE = "アニメーションフレーム",
    BODY = "映像ソースに装飾的なフレーム効果を適用します。かわいい、かっこいい、おしゃれなど様々なスタイルが選べます。",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[<h3>%s</h3>
    <p>%s</p>
    <p>バージョン %s</p>
    <p>© <a href="%s">%s</a></p>]]
}

-- ソース定義
source_def = {}
source_def.id = "animation_frame_filter"
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

-- 色変換ヘルパー関数
function extract_color_values(color_int)
    local r = bit.band(color_int, 0xFF) / 255.0
    local g = bit.band(bit.rshift(color_int, 8), 0xFF) / 255.0
    local b = bit.band(bit.rshift(color_int, 16), 0xFF) / 255.0
    local a = bit.band(bit.rshift(color_int, 24), 0xFF) / 255.0
    
    return { r = r, g = g, b = b, a = a }
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
    filter.radius = 30  -- デフォルト値
    filter.frame_style = "ふわふわ" -- デフォルト値を変更
    filter.animation_speed = 1.0
    filter.frame_width = 5
    filter.width = 1
    filter.height = 1
    filter.last_time = 0
    filter.static_mode = false
    
    -- 色設定
    filter.color_primary = 0xFFFFCCEE -- デフォルト：パステルピンク
    filter.color_secondary = 0xFFFFAACC -- デフォルト：薄いピンク
    filter.color_animation = true
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- 基本パラメータ取得
        filter.params.radius = obs.gs_effect_get_param_by_name(filter.effect, "radius")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.frame_style = obs.gs_effect_get_param_by_name(filter.effect, "frame_style")
        filter.params.effect_time = obs.gs_effect_get_param_by_name(filter.effect, "effect_time")
        filter.params.frame_width = obs.gs_effect_get_param_by_name(filter.effect, "frame_width")
        filter.params.static_mode = obs.gs_effect_get_param_by_name(filter.effect, "static_mode")
        
        -- 色パラメータ取得
        filter.params.color1_r = obs.gs_effect_get_param_by_name(filter.effect, "color1_r")
        filter.params.color1_g = obs.gs_effect_get_param_by_name(filter.effect, "color1_g")
        filter.params.color1_b = obs.gs_effect_get_param_by_name(filter.effect, "color1_b")
        filter.params.color1_a = obs.gs_effect_get_param_by_name(filter.effect, "color1_a")
        
        filter.params.color2_r = obs.gs_effect_get_param_by_name(filter.effect, "color2_r")
        filter.params.color2_g = obs.gs_effect_get_param_by_name(filter.effect, "color2_g")
        filter.params.color2_b = obs.gs_effect_get_param_by_name(filter.effect, "color2_b")
        filter.params.color2_a = obs.gs_effect_get_param_by_name(filter.effect, "color2_a")
        
        filter.params.color_animation = obs.gs_effect_get_param_by_name(filter.effect, "color_animation")
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
    -- 基本設定
    filter.radius = obs.obs_data_get_int(settings, CONSTANTS.SETTING_RADIUS)
    filter.frame_style = obs.obs_data_get_string(settings, CONSTANTS.SETTING_FRAME_STYLE)
    filter.animation_speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_ANIMATION_SPEED)
    filter.frame_width = obs.obs_data_get_int(settings, CONSTANTS.SETTING_FRAME_WIDTH)
    filter.static_mode = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_STATIC_MODE)
    
    -- 色設定（直接選択）
    filter.color_primary = obs.obs_data_get_int(settings, CONSTANTS.SETTING_COLOR_PRIMARY)
    filter.color_secondary = obs.obs_data_get_int(settings, CONSTANTS.SETTING_COLOR_SECONDARY)
    filter.color_animation = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_COLOR_ANIMATION)
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
    
    -- エフェクト時間を更新 (静的モードでなければ)
    if not filter.static_mode then
        effect_time = effect_time + time_delta * filter.animation_speed
    end
    
    -- フレームスタイルを数値に変換
    local frame_style_num = 0
    for i, style in ipairs(FRAME_STYLES) do
        if style == filter.frame_style then
            frame_style_num = i - 1
            break
        end
    end
    
    -- 基本パラメータ設定
    obs.gs_effect_set_float(filter.params.radius, filter.radius)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.gs_effect_set_int(filter.params.frame_style, frame_style_num)
    obs.gs_effect_set_float(filter.params.effect_time, effect_time)
    obs.gs_effect_set_float(filter.params.frame_width, filter.frame_width)
    obs.gs_effect_set_bool(filter.params.static_mode, filter.static_mode)
    
    -- 色パラメータ設定
    local color_primary = extract_color_values(filter.color_primary)
    local color_secondary = extract_color_values(filter.color_secondary)
    
    obs.gs_effect_set_float(filter.params.color1_r, color_primary.r)
    obs.gs_effect_set_float(filter.params.color1_g, color_primary.g)
    obs.gs_effect_set_float(filter.params.color1_b, color_primary.b)
    obs.gs_effect_set_float(filter.params.color1_a, color_primary.a)
    
    obs.gs_effect_set_float(filter.params.color2_r, color_secondary.r)
    obs.gs_effect_set_float(filter.params.color2_g, color_secondary.g)
    obs.gs_effect_set_float(filter.params.color2_b, color_secondary.b)
    obs.gs_effect_set_float(filter.params.color2_a, color_secondary.a)
    
    obs.gs_effect_set_bool(filter.params.color_animation, filter.color_animation)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- フレームスタイル
    local frame_style_prop = obs.obs_properties_add_list(
        props,
        CONSTANTS.SETTING_FRAME_STYLE,
        "フレームスタイル",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )
    
    -- すべてのスタイルを順番に追加
    for _, style in ipairs(FRAME_STYLES) do
        obs.obs_property_list_add_string(frame_style_prop, style, style)
    end
    
    -- 色設定（常に表示）
    local color_group = obs.obs_properties_create()
    obs.obs_properties_add_color(color_group, CONSTANTS.SETTING_COLOR_PRIMARY, "メインカラー")
    obs.obs_properties_add_color(color_group, CONSTANTS.SETTING_COLOR_SECONDARY, "サブカラー（グラデーションなど）")
    obs.obs_properties_add_bool(color_group, CONSTANTS.SETTING_COLOR_ANIMATION, "色のアニメーション効果")
    obs.obs_properties_add_group(props, "color_group", "色設定", obs.OBS_GROUP_NORMAL, color_group)
    
    -- 枠設定
    local frame_group = obs.obs_properties_create()
    obs.obs_properties_add_int_slider(frame_group, CONSTANTS.SETTING_RADIUS, "角丸の半径", 0, 200, 1)
    obs.obs_properties_add_int_slider(frame_group, CONSTANTS.SETTING_FRAME_WIDTH, "フレームの幅", 1, 100, 1) -- 最大値を100に変更
    obs.obs_properties_add_group(props, "frame_group", "枠設定", obs.OBS_GROUP_NORMAL, frame_group)
    
    -- アニメーション設定
    local animation_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(animation_group, CONSTANTS.SETTING_STATIC_MODE, "アニメーション無効（静的モード）")
    obs.obs_properties_add_float_slider(
        animation_group,
        CONSTANTS.SETTING_ANIMATION_SPEED,
        "アニメーション速度",
        0.1,
        5.0,
        0.1
    )
    obs.obs_properties_add_group(props, "animation_group", "アニメーション設定", obs.OBS_GROUP_NORMAL, animation_group)
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    -- 基本設定
    obs.obs_data_set_default_string(settings, CONSTANTS.SETTING_FRAME_STYLE, FRAME_STYLES[1]) -- ふわふわ
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_RADIUS, 30)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_ANIMATION_SPEED, 1.0)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_FRAME_WIDTH, 5)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_STATIC_MODE, false)
    
    -- 色設定
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_COLOR_PRIMARY, 0xFFFFCCEE) -- パステルピンク
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_COLOR_SECONDARY, 0xFFFFAACC) -- 薄いピンク
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_COLOR_ANIMATION, true)
    
    -- バージョン情報の設定
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

-- スクリプト説明
function script_description()
    return string.format(DESCRIPTION.HTML, DESCRIPTION.TITLE, DESCRIPTION.BODY, CONSTANTS.VERSION, DESCRIPTION.COPYRIGHT.URL, DESCRIPTION.COPYRIGHT.NAME)
end

-- バージョン情報
function script_version()
    return CONSTANTS.VERSION
end

-- スクリプト読み込み
function script_load(settings)
    obs.obs_register_source(source_def)
end

-- スクリプト終了
function script_unload()
end

-- シェーダーコード（改良版）
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

// 基本パラメータ
uniform float radius;
uniform float resolution_x;
uniform float resolution_y;
uniform int frame_style;
uniform float effect_time;
uniform float frame_width;
uniform bool static_mode;

// 色パラメータ
uniform float color1_r;
uniform float color1_g;
uniform float color1_b;
uniform float color1_a;
uniform float color2_r;
uniform float color2_g;
uniform float color2_b;
uniform float color2_a;
uniform bool color_animation;

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

// ランダム関数
float random(float2 st) {
    return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453);
}

// 角からの距離計算
float corner_distance(float2 pixel, float2 corner, float radius) {
    return length(pixel - corner);
}

// 色混合関数
float3 blend_colors(float3 color1, float3 color2, float t) {
    return lerp(color1, color2, t);
}

// パステルカラー生成関数
float3 pastel_color(float3 base_color, float t) {
    return lerp(base_color, float3(1.0, 1.0, 1.0), 0.5 + t * 0.2);
}

// ネオン輝き関数（強化版）
float3 neon_glow(float3 base_color, float intensity, float time) {
    // 強い発光とパルス効果
    float pulse = pow(sin(time * 2.0) * 0.5 + 0.5, 0.5) * 0.5 + 0.7;
    return base_color * (1.0 + intensity * pulse * 1.5);
}

// デジタルグリッド関数
float digital_grid(float2 uv, float time, float scale) {
    float2 grid = frac(uv * scale);
    float lines = max(1.0 - abs(grid.x - 0.5) * 15.0, 1.0 - abs(grid.y - 0.5) * 15.0);
    lines *= 0.35;
    
    // 時間によって点滅する効果
    float blink = pow(sin(time * 3.0 + dot(floor(uv * scale), float2(0.5, 0.7))), 10.0) * 0.5 + 0.5;
    
    return lines * blink;
}

float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 color = image.Sample(linearSampler, uv);
    
    // ピクセル座標
    float2 pixel = float2(uv.x * resolution_x, uv.y * resolution_y);
    float2 size = float2(resolution_x, resolution_y);
    
    // 四つ角のコーナー座標
    float2 tl = float2(radius, radius);
    float2 tr = float2(size.x - radius, radius);
    float2 bl = float2(radius, size.y - radius);
    float2 br = float2(size.x - radius, size.y - radius);
    
    // 基本色の設定
    float3 primary_color = float3(color1_r, color1_g, color1_b);
    float3 secondary_color = float3(color2_r, color2_g, color2_b);
    float primary_alpha = color1_a;
    
    // 静的モードの場合、効果時間の代わりにランダム固定値を使用
    float anim_time = static_mode ? 1.5 : effect_time;
    
    // 時間変化する色のブレンド
    float color_blend_factor = color_animation ? (sin(anim_time) * 0.5 + 0.5) : 0.0;
    float3 current_color = blend_colors(primary_color, secondary_color, color_blend_factor);
    
    // 角の距離チェック
    bool in_corner = false;
    float corner_dist = 0.0;
    
    // 左上
    if (pixel.x < radius && pixel.y < radius) {
        corner_dist = corner_distance(pixel, tl, radius);
        in_corner = true;
    }
    // 右上
    else if (pixel.x > (size.x - radius) && pixel.y < radius) {
        corner_dist = corner_distance(pixel, tr, radius);
        in_corner = true;
    }
    // 左下
    else if (pixel.x < radius && pixel.y > (size.y - radius)) {
        corner_dist = corner_distance(pixel, bl, radius);
        in_corner = true;
    }
    // 右下
    else if (pixel.x > (size.x - radius) && pixel.y > (size.y - radius)) {
        corner_dist = corner_distance(pixel, br, radius);
        in_corner = true;
    }
    
    // 角の外側は透明に
    if (in_corner && corner_dist > radius) {
        return float4(0.0, 0.0, 0.0, 0.0); // 透明
    }
    
    // 辺からの距離計算
    float edge_dist = min(
        min(pixel.x, size.x - pixel.x),
        min(pixel.y, size.y - pixel.y)
    );
    
    // フレーム幅を基準にした相対位置（0～1）
    float rel_dist = 1.0;
    if (in_corner) {
        if (corner_dist > (radius - frame_width)) {
            rel_dist = (radius - corner_dist) / frame_width;
        }
    } else if (edge_dist < frame_width) {
        rel_dist = edge_dist / frame_width;
    }
    
    // フレームスタイルに応じた処理
    if (rel_dist < 1.0) {
        float4 frame_color = float4(0, 0, 0, 0);
        float angle = atan2(pixel.y - size.y * 0.5, pixel.x - size.x * 0.5);
        
        if (frame_style == 0) { // ふわふわ
            // ふわふわした波形
            float wave = sin(angle * 5.0 + anim_time * 2.0) * 0.3 + 1.0;
            float soft_edge = smoothstep(rel_dist * wave - 0.2, rel_dist * wave + 0.2, 0.5);
            float3 pastel = pastel_color(current_color, sin(angle + anim_time) * 0.5 + 0.5);
            frame_color = float4(pastel, soft_edge * primary_alpha);
        }
        else if (frame_style == 1) { // シャープ
            // シャープな直線的フレーム
            float sharp_factor = pow(rel_dist, 0.3);
            float3 sharp_color = blend_colors(primary_color, secondary_color, sharp_factor);
            frame_color = float4(sharp_color, primary_alpha * (1.0 - sharp_factor));
        }
        else if (frame_style == 2) { // ネオン（強化版）
            // 改良されたネオン効果
            float glow_intensity = pow(1.0 - rel_dist, 2.0);
            float3 neon_color = neon_glow(current_color, glow_intensity, anim_time);
            
            // 外側と内側で色を分ける
            float3 outer_glow = neon_glow(secondary_color, glow_intensity * 1.5, anim_time * 1.2);
            float3 inner_glow = neon_glow(primary_color, glow_intensity, anim_time);
            
            // 内外のブレンド
            float blend = pow(rel_dist, 0.5);
            float3 final_color = lerp(outer_glow, inner_glow, blend);
            
            // より強い発光効果
            frame_color = float4(final_color, primary_alpha * (glow_intensity * 1.2));
        }
        else if (frame_style == 3) { // サイバー
            // デジタルグリッドエフェクト
            float grid_pattern = digital_grid(uv, anim_time, 15.0);
            
            // 基本色
            float3 cyber_base = lerp(primary_color, secondary_color, pow(rel_dist, 0.7));
            
            // デジタルラインのハイライト
            float highlight = pow(1.0 - rel_dist, 2.0) * 1.5;
            float3 line_color = lerp(secondary_color * 1.5, float3(1.0, 1.0, 1.0), 0.5);
            
            // サイバーパンクのようなグリッチ効果
            float glitch = step(0.97, random(float2(floor(anim_time * 5.0), 0.0)));
            float glitch_intensity = random(float2(floor(anim_time * 10.0), floor(uv.y * 30.0))) * glitch;
            
            // 合成
            float3 cyber_color = lerp(cyber_base, line_color, grid_pattern * highlight);
            cyber_color = lerp(cyber_color, secondary_color * 1.5, glitch_intensity);
            
            frame_color = float4(cyber_color, primary_alpha * (1.0 - pow(rel_dist, 0.4)));
        }
        else if (frame_style == 4) { // 水彩
            // 水彩風エフェクト（改良版）
            float water_noise1 = sin(uv.x * 10.0 + uv.y * 12.0 + anim_time) * 0.5 + 0.5;
            float water_noise2 = sin(uv.x * 15.0 - uv.y * 8.0 + anim_time * 0.7) * 0.5 + 0.5;
            float water_noise = water_noise1 * 0.6 + water_noise2 * 0.4;
            
            // より自然な水彩効果
            float3 water_color = blend_colors(primary_color, secondary_color, water_noise);
            
            // 水色の透明感
            float soft_edge = smoothstep(0.0, 0.3, 1.0 - rel_dist) * (1.0 - smoothstep(0.7, 1.0, 1.0 - rel_dist));
            float edge_variation = sin(angle * 8.0 + anim_time) * 0.1 + 0.9; // エッジの揺らぎ
            
            frame_color = float4(water_color, primary_alpha * soft_edge * edge_variation);
        }
        else if (frame_style == 5) { // シンプル
            // シンプル枠線
            frame_color = float4(current_color, primary_alpha * (1.0 - rel_dist));
        }
        else if (frame_style == 6) { // グラデーション
            // 位置に基づくグラデーション（改良版）
            float grad_pos = frac(angle / 6.283185 + anim_time * 0.1);
            
            // よりスムーズなグラデーション
            float smoothed_pos = smoothstep(0.0, 1.0, grad_pos);
            float3 grad_color = blend_colors(primary_color, secondary_color, smoothed_pos);
            
            // エッジに沿った輝きを追加
            float edge_glow = pow(sin(anim_time + grad_pos * 6.283185) * 0.5 + 0.5, 2.0) * 0.2;
            grad_color = lerp(grad_color, float3(1.0, 1.0, 1.0), edge_glow * (1.0 - rel_dist));
            
            frame_color = float4(grad_color, primary_alpha * (1.0 - pow(rel_dist, 0.7)));
        }
        
        // フレームカラーを適用
        return lerp(color, frame_color, frame_color.a);
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