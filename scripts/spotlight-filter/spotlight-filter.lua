obs = obslua

-- 定数を更新
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "スポットライト",  -- 変更

    -- 設定キー
    SETTING_LIGHT_COLOR = "light_color",
    SETTING_LIGHT_INTENSITY = "light_intensity",
    SETTING_LIGHT_SPEED = "light_speed",
    SETTING_VERSION = "version",
    SETTING_LIGHT_POSITION_X = "light_position_x",
    SETTING_LIGHT_POSITION_Y = "light_position_y",
    SETTING_LIGHT_ANGLE = "light_angle",
    SETTING_LIGHT_WIDTH = "light_width",
    SETTING_LIGHT_SOFTNESS = "light_softness"
}

-- ソース定義
source_def = {}
source_def.id = "spotlight_filter"  -- 変更
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

DESCRIPTION = {
    TITLE = "スポットライト",  -- 変更
    USAGE = "VTuberの歌配信に最適な照明効果を提供します。コンサート会場のようなスポットライトを演出し、パフォーマンスをより魅力的に見せることができます。",  -- 変更
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

-- 変数
local light_time = 0

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
    filter.light_intensity = 1.0
    filter.light_speed = 1.0
    filter.width = 1
    filter.height = 1
    filter.last_time = 0
    filter.light_color = 0xFFFFFFFF  -- デフォルト色（白）
    filter.light_position_x = 0.5
    filter.light_position_y = 0.0
    filter.light_angle = 0.0
    filter.light_width = 45.0
    filter.light_softness = 0.5
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.light_time = obs.gs_effect_get_param_by_name(filter.effect, "light_time")
        filter.params.light_intensity = obs.gs_effect_get_param_by_name(filter.effect, "light_intensity")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.light_color_r = obs.gs_effect_get_param_by_name(filter.effect, "light_color_r")
        filter.params.light_color_g = obs.gs_effect_get_param_by_name(filter.effect, "light_color_g")
        filter.params.light_color_b = obs.gs_effect_get_param_by_name(filter.effect, "light_color_b")
        filter.params.light_position_x = obs.gs_effect_get_param_by_name(filter.effect, "light_position_x")
        filter.params.light_position_y = obs.gs_effect_get_param_by_name(filter.effect, "light_position_y")
        filter.params.light_angle = obs.gs_effect_get_param_by_name(filter.effect, "light_angle")
        filter.params.light_width = obs.gs_effect_get_param_by_name(filter.effect, "light_width")
        filter.params.light_softness = obs.gs_effect_get_param_by_name(filter.effect, "light_softness")
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
    filter.light_intensity = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LIGHT_INTENSITY)
    filter.light_speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LIGHT_SPEED)
    filter.light_color = obs.obs_data_get_int(settings, CONSTANTS.SETTING_LIGHT_COLOR)
    filter.light_position_x = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LIGHT_POSITION_X)
    filter.light_position_y = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LIGHT_POSITION_Y)
    filter.light_angle = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LIGHT_ANGLE)
    filter.light_width = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LIGHT_WIDTH)
    filter.light_softness = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LIGHT_SOFTNESS)
    
    -- 色の分解を修正（RGBの順序を修正）
    filter.light_color_r = bit.band(filter.light_color, 0xFF) / 255.0
    filter.light_color_g = bit.band(bit.rshift(filter.light_color, 8), 0xFF) / 255.0
    filter.light_color_b = bit.band(bit.rshift(filter.light_color, 16), 0xFF) / 255.0
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
    light_time = light_time + time_delta * filter.light_speed
    
    -- パラメータ設定
    obs.gs_effect_set_float(filter.params.light_time, light_time)
    obs.gs_effect_set_float(filter.params.light_intensity, filter.light_intensity)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.gs_effect_set_float(filter.params.light_color_r, filter.light_color_r)
    obs.gs_effect_set_float(filter.params.light_color_g, filter.light_color_g)
    obs.gs_effect_set_float(filter.params.light_color_b, filter.light_color_b)
    obs.gs_effect_set_float(filter.params.light_position_x, filter.light_position_x)
    obs.gs_effect_set_float(filter.params.light_position_y, filter.light_position_y)
    obs.gs_effect_set_float(filter.params.light_angle, filter.light_angle)
    obs.gs_effect_set_float(filter.params.light_width, filter.light_width)
    obs.gs_effect_set_float(filter.params.light_softness, filter.light_softness)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- 基本設定
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LIGHT_INTENSITY,
        "照明の強さ",
        0.0,
        3.0,
        0.1
    )
    
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LIGHT_SPEED,
        "エフェクト速度",
        0.1,
        5.0,
        0.1
    )
    
    -- ライトカラー
    obs.obs_properties_add_color(
        props,
        CONSTANTS.SETTING_LIGHT_COLOR,
        "ライトの色"
    )
    
    -- 位置と角度の設定
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LIGHT_POSITION_X,
        "光源の左右位置",
        0.0,
        1.0,
        0.01
    )
    
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LIGHT_POSITION_Y,
        "光源の上下位置",
        -1.0,
        1.0,
        0.01
    )
    
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LIGHT_ANGLE,
        "光の角度",
        0.0,
        360.0,
        1.0
    )
    
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LIGHT_WIDTH,
        "光の広がり",
        10.0,
        120.0,
        1.0
    )
    
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LIGHT_SOFTNESS,
        "光の柔らかさ",
        0.0,
        1.0,
        0.01
    )
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LIGHT_INTENSITY, 1.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LIGHT_SPEED, 1.0)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_LIGHT_COLOR, 0xFFFFFFFF)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LIGHT_POSITION_X, 0.5)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LIGHT_POSITION_Y, 0.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LIGHT_ANGLE, 0.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LIGHT_WIDTH, 45.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LIGHT_SOFTNESS, 0.5)
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

// ライティングパラメータ
uniform float light_time;
uniform float light_intensity;
uniform float resolution_x;
uniform float resolution_y;
uniform float light_color_r;
uniform float light_color_g;
uniform float light_color_b;
uniform float light_position_x;
uniform float light_position_y;
uniform float light_angle;
uniform float light_width;
uniform float light_softness;

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
    float3 light_color = float3(light_color_r, light_color_g, light_color_b);
    float4 color = image.Sample(linearSampler, uv);
    
    // 光源位置を設定値から計算
    float2 light_pos = float2(light_position_x, light_position_y);
    float2 dir = uv - light_pos;
    
    // 光の角度を適用（360度対応）
    float angle_rad = radians(light_angle);
    float2 rotated_dir;
    rotated_dir.x = dir.x * cos(angle_rad) - dir.y * sin(angle_rad);
    rotated_dir.y = dir.x * sin(angle_rad) + dir.y * cos(angle_rad);
    
    // 光の広がりを計算
    float cone_angle = radians(light_width * 0.5);
    float angle = abs(atan2(rotated_dir.y, rotated_dir.x));
    
    // 柔らかさを適用した光の減衰
    float softness = light_softness * cone_angle * 0.5;
    float angle_attenuation = smoothstep(cone_angle, cone_angle - softness, angle);
    
    // 距離による減衰
    float dist = length(dir);
    float distance_attenuation = 1.0 / (1.0 + dist * 2.0);
    
    // 光の揺らぎ
    float flicker = 1.0 + sin(light_time * 2.0) * 0.1;
    
    // 最終的な光の強度
    float spotlight = angle_attenuation * distance_attenuation * flicker * light_intensity;
    
    // 光を適用
    color.rgb = lerp(color.rgb * 0.3, color.rgb * (1.0 + spotlight), spotlight);
    color.rgb = lerp(color.rgb, color.rgb * light_color, spotlight * 0.7);
    
    // ボリューメトリック効果
    float volumetric = pow(angle_attenuation * distance_attenuation, 1.5) * 0.3;
    color.rgb += light_color * volumetric * light_intensity;
    
    return color;
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]] 