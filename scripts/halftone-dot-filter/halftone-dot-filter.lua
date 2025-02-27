obs = obslua

-- 定数定義
local CONSTANTS = {
    VERSION = "1.1.0",
    
    -- UI表示テキスト
    FILTER_NAME = "ドット絵",
    DOT_SIZE_LABEL = "ドットサイズ",
    TONE_LABEL = "階調数",
    TEXT_VERSION = "バージョン",
    TEXT_ENABLED = "フィルタを有効にする",
    DOT_COLOR_LABEL = "ドットの色",
    BG_COLOR_LABEL = "背景の色",
    
    -- 設定キー
    DOT_SIZE_KEY = "dot_size",
    TONE_KEY = "tone",
    SETTING_VERSION = "version",
    SETTING_ENABLED = "enabled",
    DOT_COLOR_KEY = "dot_color",
    BG_COLOR_KEY = "bg_color",
    
    -- デフォルト値
    DEFAULT_DOT_SIZE = 12,
    DEFAULT_TONE = 8,
    DEFAULT_ENABLED = true,
    DEFAULT_DOT_COLOR = 0xFF000000, -- 黒 (ABGR形式)
    DEFAULT_BG_COLOR = 0xFFFFFFFF,  -- 白 (ABGR形式)

    -- 説明文
    DESCRIPTION = {
        TITLE = "入力映像をドット絵に変換するフィルタです。",
        USAGE = "「ドットサイズ」でドットの大きさを、「階調数」で色の段階数を調整できます。ドットと背景の色も変更できます。",
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
        filter.params.dot_color_r  = obs.gs_effect_get_param_by_name(filter.effect, "dot_color_r")
        filter.params.dot_color_g  = obs.gs_effect_get_param_by_name(filter.effect, "dot_color_g")
        filter.params.dot_color_b  = obs.gs_effect_get_param_by_name(filter.effect, "dot_color_b")
        filter.params.dot_color_a  = obs.gs_effect_get_param_by_name(filter.effect, "dot_color_a")
        filter.params.bg_color_r   = obs.gs_effect_get_param_by_name(filter.effect, "bg_color_r")
        filter.params.bg_color_g   = obs.gs_effect_get_param_by_name(filter.effect, "bg_color_g")
        filter.params.bg_color_b   = obs.gs_effect_get_param_by_name(filter.effect, "bg_color_b")
        filter.params.bg_color_a   = obs.gs_effect_get_param_by_name(filter.effect, "bg_color_a")
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
    
    -- 色の設定を整数値として取得
    local dot_color = obs.obs_data_get_int(settings, CONSTANTS.DOT_COLOR_KEY)
    local bg_color = obs.obs_data_get_int(settings, CONSTANTS.BG_COLOR_KEY)
    
    -- 各色成分に分解して保存（ABGRの順序で処理）
    -- Aは24-31ビット、Bは16-23ビット、Gは8-15ビット、Rは0-7ビット
    filter.dot_color_a = bit.band(bit.rshift(dot_color, 24), 0xFF) / 255.0
    filter.dot_color_b = bit.band(bit.rshift(dot_color, 16), 0xFF) / 255.0
    filter.dot_color_g = bit.band(bit.rshift(dot_color, 8), 0xFF) / 255.0
    filter.dot_color_r = bit.band(dot_color, 0xFF) / 255.0
    
    filter.bg_color_a = bit.band(bit.rshift(bg_color, 24), 0xFF) / 255.0
    filter.bg_color_b = bit.band(bit.rshift(bg_color, 16), 0xFF) / 255.0
    filter.bg_color_g = bit.band(bit.rshift(bg_color, 8), 0xFF) / 255.0
    filter.bg_color_r = bit.band(bg_color, 0xFF) / 255.0
    
    if filter.effect then
        obs.gs_effect_set_float(filter.params.dot_size, filter.dot_size)
        obs.gs_effect_set_float(filter.params.tone, filter.tone)
        
        -- 個別の色成分を直接設定
        obs.gs_effect_set_float(filter.params.dot_color_r, filter.dot_color_r)
        obs.gs_effect_set_float(filter.params.dot_color_g, filter.dot_color_g)
        obs.gs_effect_set_float(filter.params.dot_color_b, filter.dot_color_b)
        obs.gs_effect_set_float(filter.params.dot_color_a, filter.dot_color_a)
        
        obs.gs_effect_set_float(filter.params.bg_color_r, filter.bg_color_r)
        obs.gs_effect_set_float(filter.params.bg_color_g, filter.bg_color_g)
        obs.gs_effect_set_float(filter.params.bg_color_b, filter.bg_color_b)
        obs.gs_effect_set_float(filter.params.bg_color_a, filter.bg_color_a)
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
    
    -- 個別の色成分を直接設定
    obs.gs_effect_set_float(filter.params.dot_color_r, filter.dot_color_r)
    obs.gs_effect_set_float(filter.params.dot_color_g, filter.dot_color_g)
    obs.gs_effect_set_float(filter.params.dot_color_b, filter.dot_color_b)
    obs.gs_effect_set_float(filter.params.dot_color_a, filter.dot_color_a)
    
    obs.gs_effect_set_float(filter.params.bg_color_r, filter.bg_color_r)
    obs.gs_effect_set_float(filter.params.bg_color_g, filter.bg_color_g)
    obs.gs_effect_set_float(filter.params.bg_color_b, filter.bg_color_b)
    obs.gs_effect_set_float(filter.params.bg_color_a, filter.bg_color_a)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- フィルタ設定画面（プロパティ）の定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_ENABLED, CONSTANTS.TEXT_ENABLED)
    obs.obs_properties_add_int_slider(props, CONSTANTS.DOT_SIZE_KEY, CONSTANTS.DOT_SIZE_LABEL, 1, 100, 1)
    obs.obs_properties_add_int_slider(props, CONSTANTS.TONE_KEY, CONSTANTS.TONE_LABEL, 1, 20, 1)
    
    -- 色選択UIの追加
    obs.obs_properties_add_color(props, CONSTANTS.DOT_COLOR_KEY, CONSTANTS.DOT_COLOR_LABEL)
    obs.obs_properties_add_color(props, CONSTANTS.BG_COLOR_KEY, CONSTANTS.BG_COLOR_LABEL)
    
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, CONSTANTS.TEXT_VERSION, obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    return props
end

-- プロパティのデフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_ENABLED, CONSTANTS.DEFAULT_ENABLED)
    obs.obs_data_set_default_int(settings, CONSTANTS.DOT_SIZE_KEY, CONSTANTS.DEFAULT_DOT_SIZE)
    obs.obs_data_set_default_int(settings, CONSTANTS.TONE_KEY, CONSTANTS.DEFAULT_TONE)
    obs.obs_data_set_default_int(settings, CONSTANTS.DOT_COLOR_KEY, CONSTANTS.DEFAULT_DOT_COLOR)
    obs.obs_data_set_default_int(settings, CONSTANTS.BG_COLOR_KEY, CONSTANTS.DEFAULT_BG_COLOR)
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
// vec4を4つの個別成分に分ける
uniform float dot_color_r;
uniform float dot_color_g;
uniform float dot_color_b;
uniform float dot_color_a;
uniform float bg_color_r;
uniform float bg_color_g;
uniform float bg_color_b;
uniform float bg_color_a;

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
    
    // 個別成分から色ベクトルを作成
    float4 dot_color = float4(dot_color_r, dot_color_g, dot_color_b, dot_color_a);
    float4 bg_color = float4(bg_color_r, bg_color_g, bg_color_b, bg_color_a);
    
    // カスタム色による描画（ドット部分がドット色、背景が背景色）
    float4 finalColor = lerp(bg_color, dot_color, dotMask);
    
    return finalColor;
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]]