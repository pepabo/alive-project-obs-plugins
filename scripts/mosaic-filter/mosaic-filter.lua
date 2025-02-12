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
-- @param filter フィルターオブジェクト
function set_render_size(filter)
    local target = obs.obs_filter_get_target(filter.context)
    if target == nil then
        filter.width = 0
        filter.height = 0
    else
        -- ターゲットソースの基本サイズを取得
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
        -- シェーダーパラメータの取得
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

-- プロパティの設定
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_ENABLED, CONSTANTS.TEXT_ENABLED)
    obs.obs_properties_add_int_slider(props, CONSTANTS.DOT_SIZE_KEY, CONSTANTS.DOT_SIZE_LABEL, 1, 100, 1)
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, CONSTANTS.TEXT_VERSION, obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    return props
end

-- デフォルト値の設定
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

-- スクリプトの説明
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
// モザイクシェーダー
// 映像をモザイク化するシェーダー

uniform float4x4 ViewProj;
uniform texture2d image;

// 解像度とモザイクサイズのパラメータ
uniform float resolution_x;  // 画面の横幅
uniform float resolution_y;  // 画面の縦幅
uniform float dot_size;      // モザイクの大きさ

// テクスチャサンプラーの設定
sampler_state linearSampler {
    Filter = Linear;    // 線形フィルタリング
    AddressU = Clamp;   // U方向のクランプ
    AddressV = Clamp;   // V方向のクランプ
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

    // モザイク計算
    // resolution_x / dot_sizeでドットの数を決定
    float scale = resolution_x / dot_size;
    // uvを量子化してモザイク効果を作成
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