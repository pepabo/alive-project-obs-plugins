obs = obslua

-- 定数定義
local CONSTANTS = {
    VERSION = "1.0.0",
    
    -- UI表示テキスト
    FILTER_NAME = "ルーペ",
    TEXT_VERSION = "バージョン",
    TEXT_ENABLED = "フィルターを有効にする",
    TEXT_MAGNIFIER_X = "ルーペの位置 X",
    TEXT_MAGNIFIER_Y = "ルーペの位置 Y",
    TEXT_MAGNIFIER_SIZE = "ルーペのサイズ",
    TEXT_MAGNIFICATION = "拡大率",
    TEXT_BORDER_WIDTH = "枠線の太さ",
    TEXT_BORDER_COLOR = "枠線の色",
    TEXT_VERTICAL_RATIO = "縦比率",
    TEXT_HORIZONTAL_RATIO = "横比率",
    
    -- 設定キー
    SETTING_ENABLED = "enabled",
    SETTING_MAGNIFIER_X = "magnifier_x",
    SETTING_MAGNIFIER_Y = "magnifier_y",
    SETTING_MAGNIFIER_SIZE = "magnifier_size",
    SETTING_MAGNIFICATION = "magnification",
    SETTING_BORDER_WIDTH = "border_width",
    SETTING_BORDER_COLOR = "border_color",
    SETTING_VERTICAL_RATIO = "vertical_ratio",
    SETTING_HORIZONTAL_RATIO = "horizontal_ratio",
    SETTING_VERSION = "version",
    
    -- デフォルト値
    DEFAULT_ENABLED = true,
    DEFAULT_MAGNIFIER_X = 0.5,
    DEFAULT_MAGNIFIER_Y = 0.5,
    DEFAULT_MAGNIFIER_SIZE = 0.2,
    DEFAULT_MAGNIFICATION = 2.0,
    DEFAULT_BORDER_WIDTH = 3.0,
    DEFAULT_BORDER_COLOR = 0xFFFFFFFF,
    DEFAULT_VERTICAL_RATIO = 1.0,
    DEFAULT_HORIZONTAL_RATIO = 1.0
}

-- 形状タイプ
local SHAPE_TYPES = {
    "楕円",
    "正円", 
    "ハート"
}

-- 説明テキスト
local DESCRIPTION = {
    TITLE = "ルーペフィルター",
    BODY = "映像の特定の部分を拡大表示するルーペフィルターです。ルーペの位置、サイズ、拡大率を自由に調整できます。",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[<h3>%s</h3>
    <p>%s</p>
    <p>バージョン %s</p>
    <p>© <a href="%s">%s</a></p>]]
}

-- デバッグログ関数
local function log(level, message)
    obs.blog(level, "[ルーペフィルター] " .. message)
end

-- シェーダーコード
local shader_code = [[
uniform float4x4 ViewProj;
uniform texture2d image;
uniform float magnifier_x;
uniform float magnifier_y;
uniform float magnifier_size;
uniform float magnification;
uniform float border_width;
uniform float border_color_r;
uniform float border_color_g;
uniform float border_color_b;
uniform float border_color_a;
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

float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 color = image.Sample(linearSampler, uv);
    float aspect = resolution_x / resolution_y;
    float2 aspect_center = float2(magnifier_x * aspect, magnifier_y);
    float2 aspect_uv = float2(uv.x * aspect, uv.y);
    float radius = magnifier_size * 0.5;
    float2 delta = aspect_uv - aspect_center;
    float dist = length(delta);
    // 正円判定（アスペクト比補正空間）
    if (dist <= radius) {
        // 正円内の拡大サンプリングもアスペクト比補正空間で計算
        float2 norm_delta = delta / radius;
        float2 mag_aspect_uv = aspect_center + norm_delta * radius / magnification;
        // 元のUV空間に戻す
        float2 mag_uv = float2(mag_aspect_uv.x / aspect, mag_aspect_uv.y);
        if (mag_uv.x >= 0.0 && mag_uv.x <= 1.0 && mag_uv.y >= 0.0 && mag_uv.y <= 1.0) {
            color = image.Sample(linearSampler, mag_uv);
        }
    }
    // 枠線
    float border_inner = radius - border_width * 0.001;
    float border_outer = radius + border_width * 0.001;
    if (dist >= border_inner && dist <= border_outer) {
        float3 border_color = float3(border_color_r, border_color_g, border_color_b);
        color.rgb = border_color;
        color.a = border_color_a;
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

-- ソース定義
local source_def = {}
source_def.id = "magnifier_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- シェーダーコード
source_def.shader_code = shader_code

-- サイズ設定関数
local function set_render_size(filter)
    local target = obs.obs_filter_get_target(filter.context)
    
    if target == nil then
        filter.width = 0
        filter.height = 0
        return
    end
    
    filter.width = obs.obs_source_get_base_width(target)
    filter.height = obs.obs_source_get_base_height(target)
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
    filter.enabled = CONSTANTS.DEFAULT_ENABLED
    filter.magnifier_x = CONSTANTS.DEFAULT_MAGNIFIER_X
    filter.magnifier_y = CONSTANTS.DEFAULT_MAGNIFIER_Y
    filter.magnifier_size = CONSTANTS.DEFAULT_MAGNIFIER_SIZE
    filter.magnification = CONSTANTS.DEFAULT_MAGNIFICATION
    filter.border_width = CONSTANTS.DEFAULT_BORDER_WIDTH
    filter.border_color = CONSTANTS.DEFAULT_BORDER_COLOR
    filter.vertical_ratio = CONSTANTS.DEFAULT_VERTICAL_RATIO
    filter.horizontal_ratio = CONSTANTS.DEFAULT_HORIZONTAL_RATIO
    filter.width = 1
    filter.height = 1
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader_code, nil, nil)
    
    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.magnifier_x = obs.gs_effect_get_param_by_name(filter.effect, "magnifier_x")
        filter.params.magnifier_y = obs.gs_effect_get_param_by_name(filter.effect, "magnifier_y")
        filter.params.magnifier_size = obs.gs_effect_get_param_by_name(filter.effect, "magnifier_size")
        filter.params.magnification = obs.gs_effect_get_param_by_name(filter.effect, "magnification")
        filter.params.border_width = obs.gs_effect_get_param_by_name(filter.effect, "border_width")
        filter.params.border_color_r = obs.gs_effect_get_param_by_name(filter.effect, "border_color_r")
        filter.params.border_color_g = obs.gs_effect_get_param_by_name(filter.effect, "border_color_g")
        filter.params.border_color_b = obs.gs_effect_get_param_by_name(filter.effect, "border_color_b")
        filter.params.border_color_a = obs.gs_effect_get_param_by_name(filter.effect, "border_color_a")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        
        log(obs.LOG_INFO, "シェーダー作成成功")
    else
        log(obs.LOG_ERROR, "シェーダー作成失敗")
    end
    
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end
    
    source_def.update(filter, settings)
    set_render_size(filter)
    
    return filter
end

-- フィルター破棄
source_def.destroy = function(filter)
    if filter == nil then
        return
    end
    
    log(obs.LOG_INFO, "フィルター破棄")
    
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

-- 設定更新
source_def.update = function(filter, settings)
    if filter == nil then
        return
    end
    
    -- 基本設定の更新
    filter.enabled = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_ENABLED)
    filter.magnifier_x = obs.obs_data_get_double(settings, CONSTANTS.SETTING_MAGNIFIER_X)
    filter.magnifier_y = obs.obs_data_get_double(settings, CONSTANTS.SETTING_MAGNIFIER_Y)
    filter.magnifier_size = obs.obs_data_get_double(settings, CONSTANTS.SETTING_MAGNIFIER_SIZE)
    filter.magnification = obs.obs_data_get_double(settings, CONSTANTS.SETTING_MAGNIFICATION)
    filter.border_width = obs.obs_data_get_double(settings, CONSTANTS.SETTING_BORDER_WIDTH)
    filter.border_color = obs.obs_data_get_int(settings, CONSTANTS.SETTING_BORDER_COLOR)
    filter.vertical_ratio = obs.obs_data_get_double(settings, CONSTANTS.SETTING_VERTICAL_RATIO)
    filter.horizontal_ratio = obs.obs_data_get_double(settings, CONSTANTS.SETTING_HORIZONTAL_RATIO)
    
    -- 色の分解
    filter.border_color_r = bit.band(filter.border_color, 0xFF) / 255.0
    filter.border_color_g = bit.band(bit.rshift(filter.border_color, 8), 0xFF) / 255.0
    filter.border_color_b = bit.band(bit.rshift(filter.border_color, 16), 0xFF) / 255.0
    filter.border_color_a = bit.band(bit.rshift(filter.border_color, 24), 0xFF) / 255.0
    
    -- バージョン情報の更新
    local version = obs.obs_data_get_string(settings, CONSTANTS.SETTING_VERSION)
    if version ~= CONSTANTS.VERSION then
        obs.obs_data_set_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
    end
    
    -- サイズ更新
    set_render_size(filter)
end

-- レンダリング処理
source_def.video_render = function(filter, effect)
    if filter == nil or filter.effect == nil then 
        return
    end
    
    if not filter.enabled then
        obs.obs_source_skip_video_filter(filter.context)
        return
    end
    
    -- フィルター処理開始
    if not obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
        return
    end
    
    -- パラメータセット
    obs.gs_effect_set_float(filter.params.magnifier_x, filter.magnifier_x)
    obs.gs_effect_set_float(filter.params.magnifier_y, filter.magnifier_y)
    obs.gs_effect_set_float(filter.params.magnifier_size, filter.magnifier_size)
    obs.gs_effect_set_float(filter.params.magnification, filter.magnification)
    obs.gs_effect_set_float(filter.params.border_width, filter.border_width)
    obs.gs_effect_set_float(filter.params.border_color_r, filter.border_color_r)
    obs.gs_effect_set_float(filter.params.border_color_g, filter.border_color_g)
    obs.gs_effect_set_float(filter.params.border_color_b, filter.border_color_b)
    obs.gs_effect_set_float(filter.params.border_color_a, filter.border_color_a)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    
    -- フィルター処理終了
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- 定期更新
source_def.video_tick = function(filter, seconds)
    if filter == nil then
        return
    end
    
    set_render_size(filter)
end

-- プロパティUI定義
source_def.get_properties = function()
    local props = obs.obs_properties_create()
    
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_ENABLED, CONSTANTS.TEXT_ENABLED)
    
    -- ルーペの位置設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_MAGNIFIER_X, 
                                       CONSTANTS.TEXT_MAGNIFIER_X, 
                                       0.0, 1.0, 0.01)
    
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_MAGNIFIER_Y, 
                                       CONSTANTS.TEXT_MAGNIFIER_Y, 
                                       0.0, 1.0, 0.01)
    
    -- ルーペのサイズ設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_MAGNIFIER_SIZE, 
                                       CONSTANTS.TEXT_MAGNIFIER_SIZE, 
                                       0.05, 0.5, 0.01)
    
    -- 拡大率設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_MAGNIFICATION, 
                                       CONSTANTS.TEXT_MAGNIFICATION, 
                                       1.1, 5.0, 0.1)
    
    -- 枠線設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_BORDER_WIDTH, 
                                       CONSTANTS.TEXT_BORDER_WIDTH, 
                                       0.0, 10.0, 0.5)
    
    obs.obs_properties_add_color(props, CONSTANTS.SETTING_BORDER_COLOR, 
                                CONSTANTS.TEXT_BORDER_COLOR)
    
    -- 縦横比率設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_VERTICAL_RATIO, CONSTANTS.TEXT_VERTICAL_RATIO, 0.2, 3.0, 0.01)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_HORIZONTAL_RATIO, CONSTANTS.TEXT_HORIZONTAL_RATIO, 0.2, 3.0, 0.01)
    
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, 
                                                    CONSTANTS.TEXT_VERSION, 
                                                    obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    
    return props
end

-- デフォルト値の設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_ENABLED, CONSTANTS.DEFAULT_ENABLED)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_MAGNIFIER_X, CONSTANTS.DEFAULT_MAGNIFIER_X)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_MAGNIFIER_Y, CONSTANTS.DEFAULT_MAGNIFIER_Y)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_MAGNIFIER_SIZE, CONSTANTS.DEFAULT_MAGNIFIER_SIZE)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_MAGNIFICATION, CONSTANTS.DEFAULT_MAGNIFICATION)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_BORDER_WIDTH, CONSTANTS.DEFAULT_BORDER_WIDTH)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_BORDER_COLOR, CONSTANTS.DEFAULT_BORDER_COLOR)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_VERTICAL_RATIO, CONSTANTS.DEFAULT_VERTICAL_RATIO)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_HORIZONTAL_RATIO, CONSTANTS.DEFAULT_HORIZONTAL_RATIO)
    obs.obs_data_set_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
end

-- 幅と高さの取得関数
source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

-- バージョン情報
function script_version()
    return CONSTANTS.VERSION
end

-- スクリプト説明
function script_description()
    return string.format(DESCRIPTION.HTML, 
        DESCRIPTION.TITLE, 
        DESCRIPTION.BODY,
        CONSTANTS.VERSION,
        DESCRIPTION.COPYRIGHT.URL, 
        DESCRIPTION.COPYRIGHT.NAME)
end

-- スクリプト読み込み
function script_load(settings)
    log(obs.LOG_INFO, "スクリプトロード: v" .. CONSTANTS.VERSION)
    obs.obs_register_source(source_def)
end 