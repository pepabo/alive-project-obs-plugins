obs = obslua

-- 定数定義
local CONSTANTS = {
    VERSION = "1.0.0",
    
    -- UI表示テキスト
    FILTER_NAME = "顔ハメパネル",
    TEXT_VERSION = "バージョン",
    TEXT_ENABLED = "フィルターを有効にする",
    TEXT_HOLE_X = "穴の位置 X",
    TEXT_HOLE_Y = "穴の位置 Y",
    TEXT_HOLE_WIDTH = "穴の幅",
    TEXT_HOLE_HEIGHT = "穴の高さ",
    TEXT_SMOOTHNESS = "エッジの滑らかさ",
    
    -- 設定キー
    SETTING_ENABLED = "enabled",
    SETTING_HOLE_X = "hole_x",
    SETTING_HOLE_Y = "hole_y",
    SETTING_HOLE_WIDTH = "hole_width",
    SETTING_HOLE_HEIGHT = "hole_height",
    SETTING_SMOOTHNESS = "smoothness",
    SETTING_VERSION = "version",
    
    -- デフォルト値
    DEFAULT_ENABLED = true,
    DEFAULT_HOLE_X = 0.5,
    DEFAULT_HOLE_Y = 0.5,
    DEFAULT_HOLE_WIDTH = 0.3,
    DEFAULT_HOLE_HEIGHT = 0.4,
    DEFAULT_SMOOTHNESS = 0.01
}

-- 説明テキスト
local DESCRIPTION = {
    TITLE = "顔ハメパネルフィルター",
    BODY = "画像に穴を開けて、顔をはめることができるフィルターです。穴の位置と大きさを調整できます。",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[<h3>%s</h3>
    <p>%s</p>
    <p>© <a href="%s">%s</a></p>]]
}

-- デバッグログ関数
local function log(level, message)
    obs.blog(level, "[顔ハメパネル] " .. message)
end

-- シェーダーコードを修正（関数呼び出し形式に変更）
local shader_code = [[
uniform float4x4 ViewProj;
uniform texture2d image;
uniform float hole_x;
uniform float hole_y;
uniform float hole_width;
uniform float hole_height;
uniform float smoothness;

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
    
    // 穴の中心と楕円の半径
    float2 center = float2(hole_x, hole_y);
    float2 radius = float2(hole_width / 2.0, hole_height / 2.0);
    
    // 現在のピクセルと穴の中心との相対距離を計算
    float2 delta = uv - center;
    
    // 楕円方程式: (x/a)^2 + (y/b)^2 = 1
    // 1以下なら穴の内側、1より大きいなら外側
    float dist = pow(delta.x / radius.x, 2.0) + pow(delta.y / radius.y, 2.0);
    
    // エッジを滑らかにするためのスムーステップ
    float alpha = smoothstep(1.0 - smoothness, 1.0 + smoothness, dist);
    
    // 穴の内側は透明に、外側は元の色を保持
    color.a *= alpha;
    
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
source_def.id = "face_hole_filter"
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
    filter.hole_x = CONSTANTS.DEFAULT_HOLE_X
    filter.hole_y = CONSTANTS.DEFAULT_HOLE_Y
    filter.hole_width = CONSTANTS.DEFAULT_HOLE_WIDTH
    filter.hole_height = CONSTANTS.DEFAULT_HOLE_HEIGHT
    filter.smoothness = CONSTANTS.DEFAULT_SMOOTHNESS
    filter.width = 1
    filter.height = 1
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader_code, nil, nil)
    
    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.hole_x = obs.gs_effect_get_param_by_name(filter.effect, "hole_x")
        filter.params.hole_y = obs.gs_effect_get_param_by_name(filter.effect, "hole_y")
        filter.params.hole_width = obs.gs_effect_get_param_by_name(filter.effect, "hole_width")
        filter.params.hole_height = obs.gs_effect_get_param_by_name(filter.effect, "hole_height")
        filter.params.smoothness = obs.gs_effect_get_param_by_name(filter.effect, "smoothness")
        
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
    filter.hole_x = obs.obs_data_get_double(settings, CONSTANTS.SETTING_HOLE_X)
    filter.hole_y = obs.obs_data_get_double(settings, CONSTANTS.SETTING_HOLE_Y)
    filter.hole_width = obs.obs_data_get_double(settings, CONSTANTS.SETTING_HOLE_WIDTH)
    filter.hole_height = obs.obs_data_get_double(settings, CONSTANTS.SETTING_HOLE_HEIGHT)
    filter.smoothness = obs.obs_data_get_double(settings, CONSTANTS.SETTING_SMOOTHNESS)
    
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
    obs.gs_effect_set_float(filter.params.hole_x, filter.hole_x)
    obs.gs_effect_set_float(filter.params.hole_y, filter.hole_y)
    obs.gs_effect_set_float(filter.params.hole_width, filter.hole_width)
    obs.gs_effect_set_float(filter.params.hole_height, filter.hole_height)
    obs.gs_effect_set_float(filter.params.smoothness, filter.smoothness)
    
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
    
    -- 穴の位置設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_HOLE_X, 
                                       CONSTANTS.TEXT_HOLE_X, 
                                       0.0, 1.0, 0.01)
    
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_HOLE_Y, 
                                       CONSTANTS.TEXT_HOLE_Y, 
                                       0.0, 1.0, 0.01)
    
    -- 穴のサイズ設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_HOLE_WIDTH, 
                                       CONSTANTS.TEXT_HOLE_WIDTH, 
                                       0.01, 1.0, 0.01)
    
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_HOLE_HEIGHT, 
                                       CONSTANTS.TEXT_HOLE_HEIGHT, 
                                       0.01, 1.0, 0.01)
    
    -- エッジの滑らかさ
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_SMOOTHNESS, 
                                       CONSTANTS.TEXT_SMOOTHNESS, 
                                       0.001, 0.1, 0.001)
    
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, 
                                                    CONSTANTS.TEXT_VERSION, 
                                                    obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    
    return props
end

-- デフォルト値の設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_ENABLED, CONSTANTS.DEFAULT_ENABLED)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_HOLE_X, CONSTANTS.DEFAULT_HOLE_X)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_HOLE_Y, CONSTANTS.DEFAULT_HOLE_Y)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_HOLE_WIDTH, CONSTANTS.DEFAULT_HOLE_WIDTH)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_HOLE_HEIGHT, CONSTANTS.DEFAULT_HOLE_HEIGHT)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SMOOTHNESS, CONSTANTS.DEFAULT_SMOOTHNESS)
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
        DESCRIPTION.COPYRIGHT.URL, 
        DESCRIPTION.COPYRIGHT.NAME)
end

-- スクリプト読み込み
function script_load(settings)
    log(obs.LOG_INFO, "スクリプトロード: v" .. CONSTANTS.VERSION)
    obs.obs_register_source(source_def)
end 