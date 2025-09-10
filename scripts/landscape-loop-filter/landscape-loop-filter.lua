obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "風景ループフィルター",
    
    -- 設定キー
    SETTING_LOOP_DIRECTION = "loop_direction",
    SETTING_MOVEMENT_DIRECTION = "movement_direction",
    SETTING_MOVEMENT_SPEED = "movement_speed",
    SETTING_LOOP_OFFSET = "loop_offset",
    SETTING_ENABLED = "enabled",
    SETTING_VERSION = "version"
}

-- ループ方向
local LOOP_DIRECTIONS = {
    "水平（左右）",
    "垂直（上下）",
    "水平+垂直（斜め）"
}

-- 移動方向
local MOVEMENT_DIRECTIONS = {
    "右方向",
    "左方向",
    "下方向", 
    "上方向"
}

DESCRIPTION = {
    TITLE = "風景ループフィルター",
    BODY = "映像を水平・垂直方向にループさせて、ロケットや船に乗っているような動的な風景の流れを表現します。",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[<h3>%s</h3><p>%s</p><p>バージョン %s</p><p>© <a href="%s">%s</a></p>]]
}

-- ソース定義
source_def = {}
source_def.id = "landscape_loop_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- 変数
local effect_time = 0

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
    filter.loop_direction = 0  -- 0: 水平, 1: 垂直, 2: 両方
    filter.movement_direction = 0  -- 0: 右/下, 1: 左/上
    filter.movement_speed = 1.0
    filter.loop_offset = 0.0
    filter.enabled = true
    filter.width = 1
    filter.height = 1
    filter.last_time = 0
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.loop_direction = obs.gs_effect_get_param_by_name(filter.effect, "loop_direction")
        filter.params.movement_direction = obs.gs_effect_get_param_by_name(filter.effect, "movement_direction")
        filter.params.movement_speed = obs.gs_effect_get_param_by_name(filter.effect, "movement_speed")
        filter.params.loop_offset = obs.gs_effect_get_param_by_name(filter.effect, "loop_offset")
        filter.params.resolution_x = obs.gs_effect_get_param_by_name(filter.effect, "resolution_x")
        filter.params.resolution_y = obs.gs_effect_get_param_by_name(filter.effect, "resolution_y")
        filter.params.effect_time = obs.gs_effect_get_param_by_name(filter.effect, "effect_time")
        
        -- パラメータの存在確認
        if not filter.params.loop_direction then
            obs.obs_leave_graphics()
            source_def.destroy(filter)
            return nil
        end
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
    filter.loop_direction = obs.obs_data_get_int(settings, CONSTANTS.SETTING_LOOP_DIRECTION)
    filter.movement_direction = obs.obs_data_get_int(settings, CONSTANTS.SETTING_MOVEMENT_DIRECTION)
    filter.movement_speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_MOVEMENT_SPEED)
    filter.loop_offset = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LOOP_OFFSET)
    filter.enabled = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_ENABLED)
end

-- レンダリング処理
source_def.video_render = function(filter, effect)
    if not filter.enabled then
        obs.obs_source_skip_video_filter(filter.context)
        return
    end
    
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
    effect_time = effect_time + time_delta * filter.movement_speed
    
    -- パラメータ設定
    obs.gs_effect_set_int(filter.params.loop_direction, filter.loop_direction)
    obs.gs_effect_set_int(filter.params.movement_direction, filter.movement_direction)
    obs.gs_effect_set_float(filter.params.movement_speed, filter.movement_speed)
    obs.gs_effect_set_float(filter.params.loop_offset, filter.loop_offset)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)
    obs.gs_effect_set_float(filter.params.effect_time, effect_time)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- 有効/無効
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_ENABLED, "フィルターを有効にする")
    
    -- ループ方向
    local direction_prop = obs.obs_properties_add_list(props, CONSTANTS.SETTING_LOOP_DIRECTION, "ループ方向", 
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    
    for i, direction in ipairs(LOOP_DIRECTIONS) do
        obs.obs_property_list_add_int(direction_prop, direction, i - 1)
    end
    
    -- 移動方向
    local movement_prop = obs.obs_properties_add_list(props, CONSTANTS.SETTING_MOVEMENT_DIRECTION, "移動方向", 
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    
    for i, direction in ipairs(MOVEMENT_DIRECTIONS) do
        obs.obs_property_list_add_int(movement_prop, direction, i - 1)
    end
    
    -- 移動速度
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_MOVEMENT_SPEED,
        "移動速度",
        0.1,
        5.0,
        0.1
    )
    
    -- ループオフセット
    obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LOOP_OFFSET,
        "ループオフセット",
        0.0,
        1.0,
        0.01
    )
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_LOOP_DIRECTION, 0)
    obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_MOVEMENT_DIRECTION, 0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_MOVEMENT_SPEED, 1.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LOOP_OFFSET, 0.0)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_ENABLED, true)
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

-- スクリプトの説明
function script_description()
    return string.format(DESCRIPTION.HTML,
        DESCRIPTION.TITLE,
        DESCRIPTION.BODY,
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
uniform int loop_direction;
uniform int movement_direction;
uniform float movement_speed;
uniform float loop_offset;
uniform float resolution_x;
uniform float resolution_y;
uniform float effect_time;

sampler_state linearSampler {
    Filter = Linear;
    AddressU = Mirror;
    AddressV = Mirror;
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
    float2 looped_uv = uv;
    
    // 一方向に連続的に流れる移動量計算
    float horizontal_offset = fmod(effect_time * 0.5, 1.0);
    float vertical_offset = fmod(effect_time * 0.3, 1.0);
    
    // 移動方向に応じてオフセットを調整
    if (movement_direction == 1) {
        // 左方向・上方向の場合は逆方向
        horizontal_offset = 1.0 - horizontal_offset;
        vertical_offset = 1.0 - vertical_offset;
    }
    
    // ループ方向に応じてUV座標を調整
    if (loop_direction == 0) {
        // 水平ループ
        looped_uv.x = fmod(uv.x + horizontal_offset + loop_offset, 1.0);
    } else if (loop_direction == 1) {
        // 垂直ループ
        looped_uv.y = fmod(uv.y + vertical_offset + loop_offset, 1.0);
    } else if (loop_direction == 2) {
        // 両方向ループ
        looped_uv.x = fmod(uv.x + horizontal_offset + loop_offset, 1.0);
        looped_uv.y = fmod(uv.y + vertical_offset + loop_offset, 1.0);
    }
    
    // サンプリング
    float4 color = image.Sample(linearSampler, looped_uv);
    
    return color;
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]] 