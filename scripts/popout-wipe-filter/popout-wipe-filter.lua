obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "ポップアウトワイプ",
    -- 設定キー
    SETTING_FRAME_SHAPE = "frame_shape",
    SETTING_RADIUS = "radius",
    SETTING_BG_COLOR = "frame_bg_color",
    SETTING_CENTER_X = "center_x",
    SETTING_CENTER_Y = "center_y",
    SETTING_POP_TOP = "pop_out_top",
    SETTING_POP_LEFT = "pop_out_left",
    SETTING_POP_RIGHT = "pop_out_right",
    SETTING_VERSION = "version"
}

DESCRIPTION = {
    TITLE = "ポップアウトワイプ",
    BODY = "ワイプ枠から一部（例：頭）だけ飛び出す可愛い演出ができるフィルターです。形状やはみ出し量を調整できます。",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[<h3>%s</h3><p>%s</p><p>バージョン %s</p><p>© <a href="%s">%s</a></p>]]
}

source_def = {}
source_def.id = "popout_wipe_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

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
    filter.frame_shape = "まる"
    filter.radius = 60
    filter.frame_bg_color = 0xFFFFFFFF -- デフォルト白
    filter.center_x = 0.5
    filter.center_y = 0.5
    filter.pop_out_top = 60
    filter.pop_out_left = 0
    filter.pop_out_right = 0
    filter.width = 1
    filter.height = 1

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    if filter.effect ~= nil then
        filter.params.frame_shape = obs.gs_effect_get_param_by_name(filter.effect, "frame_shape")
        filter.params.radius = obs.gs_effect_get_param_by_name(filter.effect, "radius")
        filter.params.center_x = obs.gs_effect_get_param_by_name(filter.effect, "center_x")
        filter.params.center_y = obs.gs_effect_get_param_by_name(filter.effect, "center_y")
        filter.params.frame_bg_color_r = obs.gs_effect_get_param_by_name(filter.effect, "frame_bg_color_r")
        filter.params.frame_bg_color_g = obs.gs_effect_get_param_by_name(filter.effect, "frame_bg_color_g")
        filter.params.frame_bg_color_b = obs.gs_effect_get_param_by_name(filter.effect, "frame_bg_color_b")
        filter.params.frame_bg_color_a = obs.gs_effect_get_param_by_name(filter.effect, "frame_bg_color_a")
        filter.params.pop_out_top = obs.gs_effect_get_param_by_name(filter.effect, "pop_out_top")
        filter.params.pop_out_left = obs.gs_effect_get_param_by_name(filter.effect, "pop_out_left")
        filter.params.pop_out_right = obs.gs_effect_get_param_by_name(filter.effect, "pop_out_right")
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
    filter.frame_shape = obs.obs_data_get_string(settings, CONSTANTS.SETTING_FRAME_SHAPE)
    filter.radius = obs.obs_data_get_int(settings, CONSTANTS.SETTING_RADIUS)
    filter.frame_bg_color = obs.obs_data_get_int(settings, CONSTANTS.SETTING_BG_COLOR)
    filter.center_x = obs.obs_data_get_double(settings, CONSTANTS.SETTING_CENTER_X)
    filter.center_y = obs.obs_data_get_double(settings, CONSTANTS.SETTING_CENTER_Y)
    filter.pop_out_top = obs.obs_data_get_int(settings, CONSTANTS.SETTING_POP_TOP)
    filter.pop_out_left = obs.obs_data_get_int(settings, CONSTANTS.SETTING_POP_LEFT)
    filter.pop_out_right = obs.obs_data_get_int(settings, CONSTANTS.SETTING_POP_RIGHT)
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
    -- 色分解
    local r = bit.band(filter.frame_bg_color, 0xFF) / 255.0
    local g = bit.band(bit.rshift(filter.frame_bg_color, 8), 0xFF) / 255.0
    local b = bit.band(bit.rshift(filter.frame_bg_color, 16), 0xFF) / 255.0
    local a = bit.band(bit.rshift(filter.frame_bg_color, 24), 0xFF) / 255.0
    obs.gs_effect_set_float(filter.params.radius, filter.radius)
    obs.gs_effect_set_float(filter.params.center_x, filter.center_x)
    obs.gs_effect_set_float(filter.params.center_y, filter.center_y)
    obs.gs_effect_set_float(filter.params.frame_bg_color_r, r)
    obs.gs_effect_set_float(filter.params.frame_bg_color_g, g)
    obs.gs_effect_set_float(filter.params.frame_bg_color_b, b)
    obs.gs_effect_set_float(filter.params.frame_bg_color_a, a)
    obs.gs_effect_set_float(filter.params.pop_out_top, filter.pop_out_top)
    obs.gs_effect_set_float(filter.params.pop_out_left, filter.pop_out_left)
    obs.gs_effect_set_float(filter.params.pop_out_right, filter.pop_out_right)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    obs.obs_properties_add_int_slider(props, CONSTANTS.SETTING_RADIUS, "角丸半径（まるの場合は半径）", 0, 400, 1)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_CENTER_X, "ワイプ中心X（0.0-1.0）", 0.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_CENTER_Y, "ワイプ中心Y（0.0-1.0）", 0.0, 1.0, 0.01)
    obs.obs_properties_add_color(props, CONSTANTS.SETTING_BG_COLOR, "背景色")
    obs.obs_properties_add_int_slider(props, CONSTANTS.SETTING_POP_TOP, "上方向はみ出し量", 0, 1000, 1)
    obs.obs_properties_add_int_slider(props, CONSTANTS.SETTING_POP_LEFT, "左方向はみ出し量", 0, 1000, 1)
    obs.obs_properties_add_int_slider(props, CONSTANTS.SETTING_POP_RIGHT, "右方向はみ出し量", 0, 1000, 1)
    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_string(settings, CONSTANTS.SETTING_FRAME_SHAPE, "まる")
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_RADIUS, 60)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_BG_COLOR, 0xFFFFFFFF)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_CENTER_X, 0.5)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_CENTER_Y, 0.5)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_POP_TOP, 60)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_POP_LEFT, 0)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_POP_RIGHT, 0)
    obs.obs_data_set_default_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
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
    return string.format(DESCRIPTION.HTML, DESCRIPTION.TITLE, DESCRIPTION.BODY, CONSTANTS.VERSION, DESCRIPTION.COPYRIGHT.URL, DESCRIPTION.COPYRIGHT.NAME)
end
function script_version()
    return CONSTANTS.VERSION
end
function script_load(settings)
    obs.obs_register_source(source_def)
end
function script_unload() end

-- シェーダーコード
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform int frame_shape; // 0:まる, 1:角丸四角
uniform float radius;
uniform float center_x;
uniform float center_y;
uniform float frame_bg_color_r;
uniform float frame_bg_color_g;
uniform float frame_bg_color_b;
uniform float frame_bg_color_a;
uniform float pop_out_top;
uniform float pop_out_left;
uniform float pop_out_right;
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
    float2 pixel = float2(uv.x * resolution_x, uv.y * resolution_y);
    float4 color = image.Sample(linearSampler, uv);
    float4 bg_col = float4(frame_bg_color_r, frame_bg_color_g, frame_bg_color_b, frame_bg_color_a);
    bool in_frame = false;
    float2 center = float2(resolution_x * center_x, resolution_y * center_y);
    float dist = length(pixel - center);
    in_frame = dist < radius;
    bool pop_out = false;
    if (pixel.y < pop_out_top) pop_out = true;
    if (pixel.x < pop_out_left) pop_out = true;
    if (pixel.x > (resolution_x - pop_out_right)) pop_out = true;
    if (in_frame) {
        return lerp(bg_col, color, color.a);
    } else if (pop_out) {
        return color;
    } else {
        return float4(0,0,0,0);
    }
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]] 