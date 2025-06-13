obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "水中効果",

    -- 設定キー
    SETTING_WATER_LEVEL = "water_level",           -- 水面の高さ
    SETTING_WAVE_AMPLITUDE = "wave_amplitude",     -- 波の振幅
    SETTING_WAVE_SPEED = "wave_speed",             -- 波の速度
    SETTING_WATER_COLOR = "water_color",           -- 水の色
    SETTING_WATER_OPACITY = "water_opacity",       -- 水の透明度
    SETTING_REFLECTION = "reflection",             -- 反射の強さ
    SETTING_DISTORTION = "distortion",             -- 歪みの強さ
    SETTING_SURFACE_NOISE = "surface_noise",
    SETTING_VERSION = "version"
}

DESCRIPTION = {
    TITLE = "水中効果",
    USAGE = "アバターを水に浸かっているように見せるフィルターです。水面の歪み、反射、波紋などの効果を適用できます。",
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
source_def.id = "water_immersion_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- 変数
local time_value = 0

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
    filter.water_level = 0.5
    filter.wave_amplitude = 0.02
    filter.wave_speed = 1.0
    filter.water_color = 0x4D8BFFFF  -- デフォルトの水色
    filter.water_opacity = 0.5
    filter.reflection = 0.5
    filter.distortion = 0.1
    filter.surface_noise = 0.012
    filter.width = 1
    filter.height = 1
    filter.last_time = 0
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.time = obs.gs_effect_get_param_by_name(filter.effect, "time")
        filter.params.water_level = obs.gs_effect_get_param_by_name(filter.effect, "water_level")
        filter.params.wave_amplitude = obs.gs_effect_get_param_by_name(filter.effect, "wave_amplitude")
        filter.params.water_color_r = obs.gs_effect_get_param_by_name(filter.effect, "water_color_r")
        filter.params.water_color_g = obs.gs_effect_get_param_by_name(filter.effect, "water_color_g")
        filter.params.water_color_b = obs.gs_effect_get_param_by_name(filter.effect, "water_color_b")
        filter.params.water_opacity = obs.gs_effect_get_param_by_name(filter.effect, "water_opacity")
        filter.params.reflection = obs.gs_effect_get_param_by_name(filter.effect, "reflection")
        filter.params.distortion = obs.gs_effect_get_param_by_name(filter.effect, "distortion")
        filter.params.surface_noise = obs.gs_effect_get_param_by_name(filter.effect, "surface_noise")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
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
    filter.water_level = obs.obs_data_get_double(settings, CONSTANTS.SETTING_WATER_LEVEL)
    filter.wave_amplitude = obs.obs_data_get_double(settings, CONSTANTS.SETTING_WAVE_AMPLITUDE)
    filter.wave_speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_WAVE_SPEED)
    filter.water_color = obs.obs_data_get_int(settings, CONSTANTS.SETTING_WATER_COLOR)
    filter.water_opacity = obs.obs_data_get_double(settings, CONSTANTS.SETTING_WATER_OPACITY)
    filter.reflection = obs.obs_data_get_double(settings, CONSTANTS.SETTING_REFLECTION)
    filter.distortion = obs.obs_data_get_double(settings, CONSTANTS.SETTING_DISTORTION)
    filter.surface_noise = obs.obs_data_get_double(settings, CONSTANTS.SETTING_SURFACE_NOISE)
    
    -- 色の分解
    filter.water_color_r = bit.band(filter.water_color, 0xFF) / 255.0
    filter.water_color_g = bit.band(bit.rshift(filter.water_color, 8), 0xFF) / 255.0
    filter.water_color_b = bit.band(bit.rshift(filter.water_color, 16), 0xFF) / 255.0
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
    
    -- 時間の更新
    time_value = time_value + time_delta * filter.wave_speed
    
    -- パラメータ設定
    obs.gs_effect_set_float(filter.params.time, time_value)
    obs.gs_effect_set_float(filter.params.water_level, filter.water_level)
    obs.gs_effect_set_float(filter.params.wave_amplitude, filter.wave_amplitude)
    obs.gs_effect_set_float(filter.params.water_color_r, filter.water_color_r)
    obs.gs_effect_set_float(filter.params.water_color_g, filter.water_color_g)
    obs.gs_effect_set_float(filter.params.water_color_b, filter.water_color_b)
    obs.gs_effect_set_float(filter.params.water_opacity, filter.water_opacity)
    obs.gs_effect_set_float(filter.params.reflection, filter.reflection)
    obs.gs_effect_set_float(filter.params.distortion, filter.distortion)
    obs.gs_effect_set_float(filter.params.surface_noise, filter.surface_noise)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- 水面の高さ
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_WATER_LEVEL,
        "水面の高さ",
        0.0,
        1.0,
        0.01
    )
    
    -- 波の振幅
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_WAVE_AMPLITUDE,
        "波の大きさ",
        0.0,
        0.1,
        0.001
    )
    
    -- 波の速度
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_WAVE_SPEED,
        "波の速度",
        0.1,
        5.0,
        0.1
    )
    
    -- 水の色
    obs.obs_properties_add_color(
        props,
        CONSTANTS.SETTING_WATER_COLOR,
        "水の色"
    )
    
    -- 水の透明度（範囲を0.0-2.0に拡大）
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_WATER_OPACITY,
        "水の透明度",
        0.0,
        2.0,
        0.01
    )
    
    -- 反射の強さ
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_REFLECTION,
        "反射の強さ",
        0.0,
        1.0,
        0.01
    )
    
    -- 歪みの強さ
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_DISTORTION,
        "歪みの強さ",
        0.0,
        0.5,
        0.01
    )
    
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_SURFACE_NOISE,
        "水面ノイズの強さ",
        0.0,
        0.03,
        0.001
    )
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_WATER_LEVEL, 0.5)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_WAVE_AMPLITUDE, 0.02)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_WAVE_SPEED, 1.0)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_WATER_COLOR, 0x4D8BFFFF)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_WATER_OPACITY, 0.5)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_REFLECTION, 0.5)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_DISTORTION, 0.1)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SURFACE_NOISE, 0.012)
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

// 水中効果パラメータ
uniform float time;                  // 時間
uniform float water_level;           // 水面の高さ
uniform float wave_amplitude;        // 波の振幅
uniform float water_color_r;         // 水の色（R）
uniform float water_color_g;         // 水の色（G）
uniform float water_color_b;         // 水の色（B）
uniform float water_opacity;         // 水の透明度
uniform float reflection;            // 反射の強さ
uniform float distortion;            // 歪みの強さ
uniform float resolution_x;          // 画面の横幅
uniform float resolution_y;          // 画面の縦幅
uniform float surface_noise;

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

// 波の計算
float2 calculateWave(float2 uv, float time) {
    float2 wave;
    
    // 複数の波を重ね合わせる
    wave.x = sin(uv.y * 10.0 + time * 2.0) * 0.5 +
             sin(uv.y * 20.0 + time * 1.5) * 0.25 +
             sin(uv.y * 30.0 + time * 1.0) * 0.125;
             
    wave.y = cos(uv.x * 10.0 + time * 2.0) * 0.5 +
             cos(uv.x * 20.0 + time * 1.5) * 0.25 +
             cos(uv.x * 30.0 + time * 1.0) * 0.125;
             
    return wave * wave_amplitude;
}

float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 color = image.Sample(linearSampler, uv);
    float center_x = 0.5;
    float x = (uv.x - center_x) * 2.0;
    float noise = sin(uv.x * 30.0 + time * 1.5) * surface_noise + sin(uv.x * 80.0 - time * 2.0) * (surface_noise * 0.5);
    float water_level_curve = water_level + noise;

    // --- 水面の白いハイライト（縁取り） ---
    float edge = uv.y - water_level_curve;
    float highlight = smoothstep(0.0, 0.012, edge) * (1.0 - smoothstep(0.012, 0.035, edge));
    color.rgb = lerp(color.rgb, float3(1.0, 1.0, 1.0), highlight * 0.7);
    // --------------------------------------

    // 水面より下の部分のみ効果を適用
    if (uv.y > water_level_curve) {
        // 波による歪みを計算
        float2 wave = calculateWave(uv, time);
        float2 distorted_uv = uv + wave * distortion;
        
        // 歪んだUVで画像をサンプリング
        float4 distorted_color = image.Sample(linearSampler, distorted_uv);
        
        // 反射効果
        float2 reflection_uv = float2(uv.x, 2.0 * water_level_curve - uv.y);
        float4 reflection_color = image.Sample(linearSampler, reflection_uv);
        
        // 水の色を適用
        float3 water_color = float3(water_color_r, water_color_g, water_color_b);
        
        // 水面からの距離に応じた効果の強さを計算
        float depth_factor = (uv.y - water_level_curve) / (1.0 - water_level_curve);
        
        // 色の混合（透明度を大幅に下げて水中感を強調）
        float opacity_factor = water_opacity * (0.5 + depth_factor * 1.5);
        float3 final_color = lerp(distorted_color.rgb, water_color, min(1.0, opacity_factor));
        
        // 反射の適用（深さに応じて反射を弱める）
        final_color = lerp(final_color, reflection_color.rgb, reflection * (1.0 - depth_factor) * 0.3);
        
        // 波の影響で明るさを変化させる
        float wave_brightness = 1.0 + wave.x * 0.2;
        final_color *= wave_brightness;
        
        // 水中部分のコントラストを上げる
        float3 mid_gray = float3(0.5, 0.5, 0.5);
        final_color = lerp(mid_gray, final_color, 1.3);
        
        // 水中部分の彩度を下げる
        float luminance = dot(final_color, float3(0.299, 0.587, 0.114));
        final_color = lerp(float3(luminance, luminance, luminance), final_color, 0.7);
        
        // 深さと水の透明度に応じて大きく透過させる
        float alpha_factor = 1.0 - (depth_factor * water_opacity * 0.8); // 0.8は透過の強さ
        color.rgb = final_color;
        color.a = color.a * clamp(alpha_factor, 0.0, 1.0);
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