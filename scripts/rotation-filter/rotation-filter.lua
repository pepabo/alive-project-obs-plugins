obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "回転フィルター",
    
    -- 設定キー
    SETTING_ANGLE = "angle",
    SETTING_AUTO_ROTATE = "auto_rotate",
    SETTING_SPEED = "speed",
    SETTING_CENTER_X = "center_x",
    SETTING_CENTER_Y = "center_y",
    SETTING_VERSION = "version"
}

DESCRIPTION = {
    TITLE = "回転フィルター",
    BODY = "映像ソースに回転効果を適用します。回転角度や中心点、自動回転などを設定できます。",
    COPYRIGHT = {
        NAME = "Alive Project byGMOペパボ",
        URL = "https://alive-project.com/"
    },
    HTML = [[<h3>%s</h3>
    <p>%s</p>
    <p>© <a href="%s">%s</a></p>]]
}

-- ソース定義
source_def = {}
source_def.id = "rotation_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

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
    filter.angle = 0.0  -- デフォルト値
    filter.auto_rotate = false
    filter.speed = 1.0
    filter.center_x = 0.5
    filter.center_y = 0.5
    filter.width = 1
    filter.height = 1
    filter.last_time = 0
    filter.current_angle = 0.0
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- 基本パラメータ取得
        filter.params.angle = obs.gs_effect_get_param_by_name(filter.effect, "angle")
        filter.params.center_x = obs.gs_effect_get_param_by_name(filter.effect, "center_x")
        filter.params.center_y = obs.gs_effect_get_param_by_name(filter.effect, "center_y")
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
    -- 基本設定
    filter.angle = obs.obs_data_get_double(settings, CONSTANTS.SETTING_ANGLE)
    filter.auto_rotate = obs.obs_data_get_bool(settings, CONSTANTS.SETTING_AUTO_ROTATE)
    filter.speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_SPEED)
    filter.center_x = obs.obs_data_get_double(settings, CONSTANTS.SETTING_CENTER_X)
    filter.center_y = obs.obs_data_get_double(settings, CONSTANTS.SETTING_CENTER_Y)
    
    -- 自動回転がONの場合、現在の角度を設定したアングルに設定
    if not filter.auto_rotate then
        filter.current_angle = filter.angle
    end
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
    
    -- パラメータ設定
    obs.gs_effect_set_float(filter.params.angle, filter.current_angle)
    obs.gs_effect_set_float(filter.params.center_x, filter.center_x)
    obs.gs_effect_set_float(filter.params.center_y, filter.center_y)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- 定期更新（自動回転用）
source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
    
    if filter.auto_rotate then
        -- 角度を更新 (度数法)
        filter.current_angle = filter.current_angle + (filter.speed * 90.0 * seconds)
        
        -- 360度でリセット
        if filter.current_angle >= 360.0 then
            filter.current_angle = filter.current_angle - 360.0
        end
    else
        filter.current_angle = filter.angle
    end
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- 回転角度の設定
    local angle_prop = obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_ANGLE, "回転角度（度）", 0.0, 359.0, 1.0)
    
    -- 自動回転の設定
    obs.obs_properties_add_bool(props, CONSTANTS.SETTING_AUTO_ROTATE, "自動回転")
    
    -- 回転速度の設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_SPEED, "回転速度", 0.1, 5.0, 0.1)
    
    -- 回転中心の設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_CENTER_X, "回転中心 X", 0.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_CENTER_Y, "回転中心 Y", 0.0, 1.0, 0.01)
    
    -- バージョン情報（無効化状態で表示）
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, "バージョン", obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    -- 基本設定
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_ANGLE, 0.0)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_AUTO_ROTATE, false)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SPEED, 1.0)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_CENTER_X, 0.5)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_CENTER_Y, 0.5)
    
    -- バージョン情報の設定
    obs.obs_data_set_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
end

-- サイズ取得
source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

-- スクリプト説明
function script_description()
    return string.format(DESCRIPTION.HTML, DESCRIPTION.TITLE, DESCRIPTION.BODY, DESCRIPTION.COPYRIGHT.URL, DESCRIPTION.COPYRIGHT.NAME)
end

-- バージョン情報
function script_version()
    return CONSTANTS.VERSION
end

-- スクリプト読み込み
function script_load(settings)
    obs.obs_register_source(source_def)
end

-- スクリプト終了
function script_unload()
end

-- シェーダーコード
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

// 回転パラメータ
uniform float angle;
uniform float center_x;
uniform float center_y;

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
    
    // 回転中心点
    float2 center = float2(center_x, center_y);
    
    // UV座標を回転中心を原点として調整
    float2 centered_uv = uv - center;
    
    // ラジアンに変換
    float angle_rad = radians(angle);
    
    // 回転行列を適用
    float s = sin(angle_rad);
    float c = cos(angle_rad);
    float2 rotated_uv;
    rotated_uv.x = centered_uv.x * c - centered_uv.y * s;
    rotated_uv.y = centered_uv.x * s + centered_uv.y * c;
    
    // 元の原点に戻す
    float2 final_uv = rotated_uv + center;
    
    // テクスチャ座標が範囲外の場合は透明を返す
    if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    
    // サンプリング
    return image.Sample(linearSampler, final_uv);
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]] 