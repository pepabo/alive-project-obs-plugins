obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "ピンフィルター",
    
    -- 設定キー
    SETTING_RADIUS = "radius",
    SETTING_TRIANGLE_SIZE = "triangle_size",
    SETTING_COLOR = "color",
    SETTING_VERSION = "version"
}

DESCRIPTION = {
    TITLE = "ピンフィルター",
    BODY = "映像ソースを円形にくり抜き、下部に三角マークを付けたピン型のフィルターを適用します。",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[<h3>%s</h3>
    <p>%s</p>
    <p>© <a href="%s">%s</a></p>]]
}

-- ソース定義
source_def = {}
source_def.id = "pin_filter"
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
    filter.radius = 300  -- デフォルト値を300に変更
    filter.triangle_size = 35  -- デフォルト値を35に変更
    filter.color = 0xFFFFFFFF -- 白色
    filter.width = 1
    filter.height = 1
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.radius = obs.gs_effect_get_param_by_name(filter.effect, "radius")
        filter.params.triangle_size = obs.gs_effect_get_param_by_name(filter.effect, "triangle_size")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.color_r = obs.gs_effect_get_param_by_name(filter.effect, "color_r")
        filter.params.color_g = obs.gs_effect_get_param_by_name(filter.effect, "color_g")
        filter.params.color_b = obs.gs_effect_get_param_by_name(filter.effect, "color_b")
        filter.params.color_a = obs.gs_effect_get_param_by_name(filter.effect, "color_a")
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
    filter.radius = obs.obs_data_get_int(settings, CONSTANTS.SETTING_RADIUS)
    filter.triangle_size = obs.obs_data_get_int(settings, CONSTANTS.SETTING_TRIANGLE_SIZE)
    filter.color = obs.obs_data_get_int(settings, CONSTANTS.SETTING_COLOR)
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
    
    -- パラメータ設定
    obs.gs_effect_set_float(filter.params.radius, filter.radius)
    obs.gs_effect_set_float(filter.params.triangle_size, filter.triangle_size)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    
    local color = extract_color_values(filter.color)
    obs.gs_effect_set_float(filter.params.color_r, color.r)
    obs.gs_effect_set_float(filter.params.color_g, color.g)
    obs.gs_effect_set_float(filter.params.color_b, color.b)
    obs.gs_effect_set_float(filter.params.color_a, color.a)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- 円の半径設定
    obs.obs_properties_add_int_slider(props, CONSTANTS.SETTING_RADIUS, "円の半径", 10, 500, 1)
    
    -- 三角マークのサイズ設定
    obs.obs_properties_add_int_slider(props, CONSTANTS.SETTING_TRIANGLE_SIZE, "三角マークのサイズ", 5, 50, 1)
    
    -- 色設定
    obs.obs_properties_add_color(props, CONSTANTS.SETTING_COLOR, "枠の色")
    
    -- バージョン情報（無効化状態で表示）
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, "バージョン", obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_RADIUS, 300)  -- デフォルト値を300に変更
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_TRIANGLE_SIZE, 35)  -- デフォルト値を35に変更
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_COLOR, 0xFFFFFFFF)
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

-- スクリプト説明
function script_description()
    return string.format(DESCRIPTION.HTML, DESCRIPTION.TITLE, DESCRIPTION.BODY, DESCRIPTION.COPYRIGHT.URL, DESCRIPTION.COPYRIGHT.NAME)
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

-- シェーダーコード
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

// パラメータ
uniform float radius;
uniform float triangle_size;
uniform float resolution_x;
uniform float resolution_y;
uniform float color_r;
uniform float color_g;
uniform float color_b;
uniform float color_a;

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
    float4 color = image.Sample(linearSampler, uv);
    
    // ピクセル座標
    float2 pixel = float2(uv.x * resolution_x, uv.y * resolution_y);
    float2 center = float2(resolution_x * 0.5, resolution_y * 0.5);  // 中心を中央に
    
    // 円の中心からの距離
    float dist = length(pixel - center);
    
    // 正規化された三角形サイズ（2倍に）
    float norm_triangle_size = triangle_size * 1.6 / resolution_x;  // サイズを1.6倍に
    
    // 三角形の位置を計算（正規化座標系）
    float circle_bottom = 0.5 + (radius / resolution_y);  // 円の下端
    float triangle_top = circle_bottom;  // 円の下端から三角形開始
    float triangle_bottom = triangle_top + norm_triangle_size;
    float triangle_width = norm_triangle_size * 3.0;  // 幅を3倍に
    
    // 三角形の領域かどうかを判定
    bool in_triangle = false;
    if (uv.y > triangle_top && uv.y < triangle_bottom) {
        float triangle_center_x = 0.5;
        float triangle_x_dist = abs(uv.x - triangle_center_x);
        float triangle_y_ratio = (uv.y - triangle_top) / (triangle_bottom - triangle_top);
        float triangle_width_at_y = triangle_width * (1.0 - triangle_y_ratio * 0.95);  // 先端を太く
        
        if (triangle_x_dist < triangle_width_at_y * 0.5) {
            in_triangle = true;
        }
    }
    
    // 影の色を計算（メインカラーより暗く）
    float4 shadow_color = float4(color_r * 0.7, color_g * 0.7, color_b * 0.7, color_a);
    
    // 三角形の描画を優先（影付き）
    if (in_triangle) {
        // 三角形の下端に近いほど影を濃く
        float shadow_intensity = 1.0 - (uv.y - triangle_top) / (triangle_bottom - triangle_top);
        return lerp(shadow_color, float4(color_r, color_g, color_b, color_a), shadow_intensity);
    }
    
    // 円の処理
    if (dist > radius) {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    
    // 円の枠線の描画（より太く、影付き）
    if (dist > (radius - 45.0)) {  // 枠線を45ピクセルに
        // 外側ほど影を濃く
        float shadow_intensity = (dist - (radius - 45.0)) / 45.0;
        return lerp(shadow_color, float4(color_r, color_g, color_b, color_a), shadow_intensity);
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