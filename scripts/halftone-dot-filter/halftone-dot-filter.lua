obs = obslua

-- 定数定義
local CONSTANTS = {
    VERSION = "1.0.0",
    
    -- UI表示テキスト
    FILTER_NAME = "白黒ドット絵",
    DOT_SIZE_LABEL = "ドットサイズ",
    TONE_LABEL = "階調数",
    TEXT_VERSION = "バージョン",
    TEXT_ENABLED = "フィルタを有効にする",
    
    -- 設定キー
    DOT_SIZE_KEY = "dot_size",
    TONE_KEY = "tone",
    SETTING_VERSION = "version",
    SETTING_ENABLED = "enabled",
    
    -- デフォルト値
    DEFAULT_DOT_SIZE = 12,
    DEFAULT_TONE = 8,
    DEFAULT_ENABLED = true,

    -- 説明文
    DESCRIPTION = {
        TITLE = "入力映像を白黒のドット絵に変換するフィルタです。",
        USAGE = "「ドットサイズ」でドットの大きさを、「階調数」で白黒の段階数を調整できます。",
        COPYRIGHT = {
            NAME = "Alive Project byGMOペパボ",
            URL = "https://alive-project.com/"
        },
        HTML = [[<p>%s%s</p>
    <p>バージョン %s</p>
    <p>© <a href="%s">%s</a></p>]]
    }
}

-- ソースフィルタ定義
source_def = {}
source_def.id = "halftone_dot_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- ターゲットの解像度を取得する補助関数
function set_render_size(filter)
    local target = obs.obs_filter_get_target(filter.context)
    if target == nil then
        filter.width = 0
        filter.height = 0
    else
        filter.width  = obs.obs_source_get_base_width(target)
        filter.height = obs.obs_source_get_base_height(target)
    end
end

source_def.get_name = function()
    return CONSTANTS.FILTER_NAME
end

-- フィルタ作成時の処理
source_def.create = function(settings, source)
    local filter = {}
    filter.context = source
    filter.params  = {}

    set_render_size(filter)

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    if filter.effect then
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.dot_size     = obs.gs_effect_get_param_by_name(filter.effect, "dot_size")
        filter.params.tone         = obs.gs_effect_get_param_by_name(filter.effect, "tone")
    end
    obs.obs_leave_graphics()

    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end

    source_def.update(filter, settings)
    return filter
end

-- フィルタ破棄時の処理
source_def.destroy = function(filter)
    if filter.effect then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

-- プロパティ更新時の処理
source_def.update = function(filter, settings)
    filter.enabled = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_ENABLED)
    filter.dot_size = obs.obs_data_get_int(settings, CONSTANTS.DOT_SIZE_KEY)
    filter.tone     = obs.obs_data_get_int(settings, CONSTANTS.TONE_KEY)
    if filter.effect then
        obs.gs_effect_set_float(filter.params.dot_size, filter.dot_size)
        obs.gs_effect_set_float(filter.params.tone, filter.tone)
    end
    set_render_size(filter)
end

-- 映像レンダリング処理
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
    obs.gs_effect_set_float(filter.params.tone, filter.tone)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- フィルタ設定画面（プロパティ）の定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_ENABLED, CONSTANTS.TEXT_ENABLED)
    obs.obs_properties_add_int_slider(props, CONSTANTS.DOT_SIZE_KEY, CONSTANTS.DOT_SIZE_LABEL, 1, 100, 1)
    obs.obs_properties_add_int_slider(props, CONSTANTS.TONE_KEY, CONSTANTS.TONE_LABEL, 1, 20, 1)
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, CONSTANTS.TEXT_VERSION, obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    return props
end

-- プロパティのデフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_ENABLED, CONSTANTS.DEFAULT_ENABLED)
    obs.obs_data_set_default_int(settings, CONSTANTS.DOT_SIZE_KEY, CONSTANTS.DEFAULT_DOT_SIZE)
    obs.obs_data_set_default_int(settings, CONSTANTS.TONE_KEY, CONSTANTS.DEFAULT_TONE)
    obs.obs_data_set_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
end

-- 毎フレーム呼ばれる更新処理
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

-- スクリプト読み込み時にフィルタソースを登録
function script_load(settings)
    obs.obs_register_source(source_def)
end

--------------------------------------------------------------------------------
-- シェーダーコード
--
-- 各画素について、現在の uv 座標からセル（ドット）の中心位置を計算し、
-- セル中心の色から輝度を求め、その値に応じてドットの半径を決定します。
-- ドット内はセル中心の色、セル外は白とし、smoothstep によりアンチエイリアス処理を行っています。
--------------------------------------------------------------------------------

shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float resolution_x;
uniform float resolution_y;
uniform float dot_size;
uniform float tone;

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
    float4 originalColor = image.Sample(linearSampler, uv);
    
    if (originalColor.a < 0.01) {
        return originalColor;
    }
    
    // ピクセル座標に変換
    float2 pixelCoord = uv * float2(resolution_x, resolution_y);
    float cellSize = dot_size;
    
    // グリッドの計算
    float2 grid = floor(pixelCoord / cellSize);
    float2 cellCenterPixel = (grid + 0.5) * cellSize;
    
    // セル中心の色をサンプリング
    float2 cellCenterUV = cellCenterPixel / float2(resolution_x, resolution_y);
    float4 centerColor = image.Sample(linearSampler, cellCenterUV);
    
    // グレースケール変換と階調の量子化
    float luminance = dot(centerColor.rgb, float3(0.299, 0.587, 0.114));
    luminance = floor(luminance * tone) / tone;
    
    // ドット半径の計算 - 明るい部分は小さく、暗い部分は大きく
    float dotRadius = (cellSize * 0.5) * (1.0 - luminance);
    
    // 現在のピクセルとセル中心との距離を計算
    float2 diff = pixelCoord - cellCenterPixel;
    float dist = length(diff);
    
    // ドットマスクの生成（アンチエイリアス付き）
    float edgeWidth = 1.0;
    float dotMask = 1.0 - smoothstep(dotRadius - edgeWidth, dotRadius + edgeWidth, dist);
    
    // 白黒の反転（ドット部分が黒、背景が白）
    float3 finalColor = lerp(float3(1,1,1), float3(0,0,0), dotMask);
    
    return float4(finalColor, 1.0);
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]]