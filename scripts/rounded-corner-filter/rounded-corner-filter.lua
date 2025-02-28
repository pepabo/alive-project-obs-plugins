obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "角丸フィルター",
    
    -- 設定キー
    SETTING_RADIUS = "radius",
    SETTING_DEBUG = "debug_mode",
    SETTING_VERSION = "version",
    
    -- 枠線設定
    SETTING_BORDER = "border_enabled",
    SETTING_BORDER_SIZE = "border_size",
    SETTING_BORDER_COLOR = "border_color"
}

DESCRIPTION = {
    TITLE = "角丸フィルター",
    BODY = "映像ソースに角丸効果と枠線を適用します。映像の四隅が透明になるエフェクトです。",
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
source_def.id = "rounded_corner_filter"
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
    filter.radius = 20  -- デフォルト値
    filter.debug_mode = false
    filter.width = 1
    filter.height = 1
    
    -- 枠線設定
    filter.border_enabled = true
    filter.border_size = 2
    filter.border_color = 0xFFFFFFFF -- 白色
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- 基本パラメータ取得
        filter.params.radius = obs.gs_effect_get_param_by_name(filter.effect, "radius")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.debug_mode = obs.gs_effect_get_param_by_name(filter.effect, "debug_mode")
        
        -- 枠線パラメータ取得
        filter.params.border_enabled = obs.gs_effect_get_param_by_name(filter.effect, "border_enabled")
        filter.params.border_size = obs.gs_effect_get_param_by_name(filter.effect, "border_size")
        filter.params.border_color_r = obs.gs_effect_get_param_by_name(filter.effect, "border_color_r")
        filter.params.border_color_g = obs.gs_effect_get_param_by_name(filter.effect, "border_color_g")
        filter.params.border_color_b = obs.gs_effect_get_param_by_name(filter.effect, "border_color_b")
        filter.params.border_color_a = obs.gs_effect_get_param_by_name(filter.effect, "border_color_a")
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
    filter.debug_mode = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_DEBUG)
    
    -- 枠線設定
    filter.border_enabled = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_BORDER)
    filter.border_size = obs.obs_data_get_int(settings, CONSTANTS.SETTING_BORDER_SIZE)
    filter.border_color = obs.obs_data_get_int(settings, CONSTANTS.SETTING_BORDER_COLOR)
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
    
    -- 基本パラメータ設定
    obs.gs_effect_set_float(filter.params.radius, filter.radius)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.gs_effect_set_bool(filter.params.debug_mode, filter.debug_mode)
    
    -- 枠線パラメータ設定
    obs.gs_effect_set_bool(filter.params.border_enabled, filter.border_enabled)
    obs.gs_effect_set_float(filter.params.border_size, filter.border_size)
    
    local border_color = extract_color_values(filter.border_color)
    obs.gs_effect_set_float(filter.params.border_color_r, border_color.r)
    obs.gs_effect_set_float(filter.params.border_color_g, border_color.g)
    obs.gs_effect_set_float(filter.params.border_color_b, border_color.b)
    obs.gs_effect_set_float(filter.params.border_color_a, border_color.a)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- 角丸半径の設定
    obs.obs_properties_add_int_slider(props, CONSTANTS.SETTING_RADIUS, "角丸の半径", 0, 200, 1)
    
    -- 枠線設定グループ
    local border_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(border_group, CONSTANTS.SETTING_BORDER, "枠線を表示")
    obs.obs_properties_add_int_slider(border_group, CONSTANTS.SETTING_BORDER_SIZE, "枠線の太さ", 1, 20, 1)
    obs.obs_properties_add_color(border_group, CONSTANTS.SETTING_BORDER_COLOR, "枠線の色")
    obs.obs_properties_add_group(props, "border_group", "枠線設定", obs.OBS_GROUP_NORMAL, border_group)
    
    -- デバッグモードの切り替え
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_DEBUG, "デバッグモード (赤色表示)")
    
    -- バージョン情報（無効化状態で表示）
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, "バージョン", obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    -- 基本設定
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_RADIUS, 30)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_DEBUG, false)
    
    -- 枠線設定
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_BORDER, true)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_BORDER_SIZE, 2)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_BORDER_COLOR, 0xFFFFFFFF)
    
    -- バージョン情報の設定
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

-- シェーダーコード（シンプル版）
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

// 基本パラメータ
uniform float radius;
uniform float resolution_x;
uniform float resolution_y;
uniform bool debug_mode;

// 枠線パラメータ
uniform bool border_enabled;
uniform float border_size;
uniform float border_color_r;
uniform float border_color_g;
uniform float border_color_b;
uniform float border_color_a;

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

// シンプルな距離チェック関数
float corner_distance(float2 pixel, float2 corner, float radius) {
    return length(pixel - corner);
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
        if (debug_mode) {
            return float4(1.0, 0.0, 0.0, 1.0); // デバッグ用赤色
        }
        return float4(0.0, 0.0, 0.0, 0.0); // 透明
    }
    
    // 枠線処理
    if (border_enabled) {
        // エッジからの距離
        float edge_dist = 0.0;
        
        if (in_corner) {
            // コーナー部分の枠線（外側から内側に向かって border_size ピクセル）
            if (corner_dist > (radius - border_size) && corner_dist <= radius) {
                return float4(border_color_r, border_color_g, border_color_b, border_color_a);
            }
        } else {
            // 辺の部分の枠線（外側から内側に向かって border_size ピクセル）
            edge_dist = min(
                min(pixel.x, size.x - pixel.x),
                min(pixel.y, size.y - pixel.y)
            );
            
            if (edge_dist < border_size) {
                return float4(border_color_r, border_color_g, border_color_b, border_color_a);
            }
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

