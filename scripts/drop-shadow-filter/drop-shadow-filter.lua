obs = obslua
local bit = bit or bit32

-- 定数
local CONSTANTS = {
    VERSION = "shadow-stable",
    FILTER_NAME = "影フィルター",
    -- 設定キー
    SETTING_OFFSET_X = "offset_x",
    SETTING_OFFSET_Y = "offset_y",
    SETTING_OPACITY = "shadow_opacity",
    SETTING_COLOR = "shadow_color",
    SETTING_BLUR = "shadow_blur",
    SETTING_SCALE = "shadow_scale"
}

DESCRIPTION = {
    TITLE = "ドロップシャドウ",
    USAGE = "VTuberの背後に自然な影を落とすフィルターです。影の色・ぼかし・位置・不透明度を細かく調整できます。",
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
source_def.id = "drop_shadow_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- 変数
local filter_time = 0

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

source_def.get_name = function()
    return CONSTANTS.FILTER_NAME
end

source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source
    filter.width = 1
    filter.height = 1
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    if filter.effect ~= nil then
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.offset_x = obs.gs_effect_get_param_by_name(filter.effect, "offset_x")
        filter.params.offset_y = obs.gs_effect_get_param_by_name(filter.effect, "offset_y")
        filter.params.shadow_opacity = obs.gs_effect_get_param_by_name(filter.effect, "shadow_opacity")
        filter.params.shadow_color_r = obs.gs_effect_get_param_by_name(filter.effect, "shadow_color_r")
        filter.params.shadow_color_g = obs.gs_effect_get_param_by_name(filter.effect, "shadow_color_g")
        filter.params.shadow_color_b = obs.gs_effect_get_param_by_name(filter.effect, "shadow_color_b")
        filter.params.shadow_blur = obs.gs_effect_get_param_by_name(filter.effect, "shadow_blur")
        filter.params.shadow_scale = obs.gs_effect_get_param_by_name(filter.effect, "shadow_scale")
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
    if filter == nil then return end
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
        filter.effect = nil
    end
end

source_def.update = function(filter, settings)
    filter.offset_x = obs.obs_data_get_double(settings, CONSTANTS.SETTING_OFFSET_X) or 20.0
    filter.offset_y = obs.obs_data_get_double(settings, CONSTANTS.SETTING_OFFSET_Y) or 20.0
    filter.shadow_opacity = obs.obs_data_get_double(settings, CONSTANTS.SETTING_OPACITY) or 0.7
    filter.shadow_color = obs.obs_data_get_int(settings, CONSTANTS.SETTING_COLOR) or 0xFF000000
    filter.shadow_blur = obs.obs_data_get_double(settings, CONSTANTS.SETTING_BLUR) or 20.0
    filter.shadow_scale = obs.obs_data_get_double(settings, CONSTANTS.SETTING_SCALE) or 1.0
    -- 色分解
    filter.shadow_color_r = bit.band(filter.shadow_color, 0xFF) / 255.0
    filter.shadow_color_g = bit.band(bit.rshift(filter.shadow_color, 8), 0xFF) / 255.0
    filter.shadow_color_b = bit.band(bit.rshift(filter.shadow_color, 16), 0xFF) / 255.0
end

source_def.video_render = function(filter, effect)
    if not obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
        return
    end
    set_render_size(filter)
    if filter.width == 0 or filter.height == 0 or filter.effect == nil then
        obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
        return
    end
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.gs_effect_set_float(filter.params.offset_x, filter.offset_x)
    obs.gs_effect_set_float(filter.params.offset_y, filter.offset_y)
    obs.gs_effect_set_float(filter.params.shadow_opacity, filter.shadow_opacity)
    obs.gs_effect_set_float(filter.params.shadow_color_r, filter.shadow_color_r)
    obs.gs_effect_set_float(filter.params.shadow_color_g, filter.shadow_color_g)
    obs.gs_effect_set_float(filter.params.shadow_color_b, filter.shadow_color_b)
    obs.gs_effect_set_float(filter.params.shadow_blur, filter.shadow_blur)
    obs.gs_effect_set_float(filter.params.shadow_scale, filter.shadow_scale)
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_OFFSET_X, "影のオフセットX", -100.0, 100.0, 1.0)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_OFFSET_Y, "影のオフセットY", -100.0, 100.0, 1.0)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_OPACITY, "影の不透明度", 0.0, 1.0, 0.01)
    obs.obs_properties_add_color(props, CONSTANTS.SETTING_COLOR, "影の色")
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_BLUR, "影のぼかし量", 0.0, 50.0, 1.0)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_SCALE, "影の大きさ（スケール）", 0.5, 2.0, 0.01)
    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_OFFSET_X, 20.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_OFFSET_Y, 20.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_OPACITY, 0.7)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_COLOR, 0xFF000000)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_BLUR, 20.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SCALE, 1.0)
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

function script_description()
    return "安定動作重視の影フィルターです。ぼかし・色・大きさも調整可能。"
end

function script_load(settings)
    obs.obs_register_source(source_def)
end

-- シェーダーコード（3x3ガウスぼかし）
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;
uniform float resolution_x;
uniform float resolution_y;
uniform float offset_x;
uniform float offset_y;
uniform float shadow_opacity;
uniform float shadow_color_r;
uniform float shadow_color_g;
uniform float shadow_color_b;
uniform float shadow_blur;
uniform float shadow_scale;

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

// 3x3ガウスぼかし（配列・for文なし、重み定数）
float sample_shadow_alpha(float2 uv, float2 offset, float blur, float scale, float2 texel_size) {
    float2 center = float2(0.5, 0.5);
    float2 scaled_uv = (uv - center) * scale + center;
    float2 base = scaled_uv - offset;
    float a00 = image.Sample(linearSampler, base + float2(-blur, -blur) * texel_size).a;
    float a01 = image.Sample(linearSampler, base + float2( 0.0, -blur) * texel_size).a;
    float a02 = image.Sample(linearSampler, base + float2( blur, -blur) * texel_size).a;
    float a10 = image.Sample(linearSampler, base + float2(-blur,  0.0) * texel_size).a;
    float a11 = image.Sample(linearSampler, base).a;
    float a12 = image.Sample(linearSampler, base + float2( blur,  0.0) * texel_size).a;
    float a20 = image.Sample(linearSampler, base + float2(-blur,  blur) * texel_size).a;
    float a21 = image.Sample(linearSampler, base + float2( 0.0,  blur) * texel_size).a;
    float a22 = image.Sample(linearSampler, base + float2( blur,  blur) * texel_size).a;
    float sum = a00*0.077847 + a01*0.123317 + a02*0.077847 +
                a10*0.123317 + a11*0.195346 + a12*0.123317 +
                a20*0.077847 + a21*0.123317 + a22*0.077847;
    return sum;
}

float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 texel_size = float2(1.0 / resolution_x, 1.0 / resolution_y);
    float2 shadow_offset = float2(offset_x / resolution_x, offset_y / resolution_y);
    float shadow_alpha = sample_shadow_alpha(uv, shadow_offset, shadow_blur, shadow_scale, texel_size) * shadow_opacity;
    float3 shadow_color = float3(shadow_color_r, shadow_color_g, shadow_color_b);
    float4 shadow_pixel = float4(shadow_color, shadow_alpha);
    float4 color = image.Sample(linearSampler, uv);
    // 影を下に敷き、元画像を上に合成
    float out_a = color.a + shadow_pixel.a * (1.0 - color.a);
    float3 out_rgb = (color.rgb * color.a + shadow_pixel.rgb * shadow_pixel.a * (1.0 - color.a)) / (out_a + 1e-6);
    return float4(out_rgb, out_a);
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]] 