obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "振り子フィルター",
    
    -- 設定キー
    SETTING_AMPLITUDE = "amplitude",  -- 振り幅
    SETTING_SPEED = "speed",         -- 振り子の速さ
    SETTING_PIVOT_X = "pivot_x",     -- 支点のX座標
    SETTING_PIVOT_Y = "pivot_y",     -- 支点のY座標
    SETTING_VERSION = "version"
}

DESCRIPTION = {
    TITLE = "振り子フィルター",
    BODY = "映像ソースを振り子のように左右に揺らします。",
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
source_def.id = "pendulum_filter"
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
    filter.amplitude = 0.2  -- デフォルトの振り幅
    filter.speed = 1.0     -- デフォルトの速さ
    filter.pivot_x = 0.5   -- デフォルトの支点X座標（中心）
    filter.pivot_y = 0.0   -- デフォルトの支点Y座標（上端）
    filter.width = 1
    filter.height = 1
    filter.last_time = 0
    filter.current_angle = 0.2  -- 初期角度を設定
    filter.velocity = 0.0  -- 振り子の速度
    
    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)
    
    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.angle = obs.gs_effect_get_param_by_name(filter.effect, "angle")
        filter.params.pivot_x = obs.gs_effect_get_param_by_name(filter.effect, "pivot_x")
        filter.params.pivot_y = obs.gs_effect_get_param_by_name(filter.effect, "pivot_y")
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
    local old_amplitude = filter.amplitude
    local old_speed = filter.speed
    
    filter.amplitude = obs.obs_data_get_double(settings, CONSTANTS.SETTING_AMPLITUDE)
    filter.speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_SPEED)
    filter.pivot_x = obs.obs_data_get_double(settings, CONSTANTS.SETTING_PIVOT_X)
    filter.pivot_y = obs.obs_data_get_double(settings, CONSTANTS.SETTING_PIVOT_Y)
    
    -- 振り幅または速度が変更された場合の処理
    if old_amplitude ~= filter.amplitude or old_speed ~= filter.speed then
        -- 現在の角度を新しい振り幅に合わせて調整
        if old_amplitude ~= filter.amplitude then
            local ratio = filter.amplitude / old_amplitude
            filter.current_angle = filter.current_angle * ratio
        end
        
        -- 速度を新しい設定に合わせて調整
        local speed_ratio = filter.speed / old_speed
        local amplitude_ratio = filter.amplitude / old_amplitude
        filter.velocity = filter.velocity * math.sqrt(speed_ratio * amplitude_ratio)
        
        -- 速度が小さすぎる場合は最小速度を保証
        local min_velocity = 0.01 * filter.amplitude * filter.speed
        if math.abs(filter.velocity) < min_velocity then
            filter.velocity = (filter.velocity > 0 and 1 or -1) * min_velocity
        end
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
    obs.gs_effect_set_float(filter.params.pivot_x, filter.pivot_x)
    obs.gs_effect_set_float(filter.params.pivot_y, filter.pivot_y)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- 定期更新（振り子の物理演算）
source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
    
    -- 重力加速度（スケーリングを調整）
    local gravity = 9.8 * (filter.speed * filter.speed)
    
    -- 振り子の長さ（スケーリングを調整）
    local length = 1.0 / (filter.speed * filter.speed)
    
    -- 角度の加速度を計算（単振り子の運動方程式）
    local angular_acceleration = -(gravity / length) * math.sin(filter.current_angle)
    
    -- 速度を更新（時間ステップを調整）
    filter.velocity = filter.velocity + angular_acceleration * seconds * 0.1
    
    -- 角度を更新（時間ステップを調整）
    filter.current_angle = filter.current_angle + filter.velocity * seconds * 0.1
    
    -- 振幅を制限（現在の振り幅に関係なく新しい振り幅を適用可能に）
    if math.abs(filter.current_angle) > filter.amplitude then
        -- 振り幅を超えた場合は、その方向の最大値で反転
        filter.current_angle = (filter.current_angle > 0 and 1 or -1) * filter.amplitude
        -- 反発係数を振り幅に応じて調整（小さい振り幅でも活発に動くように）
        local bounce_factor = 0.8 + (0.2 * (1.0 - math.abs(filter.current_angle) / 0.3))
        filter.velocity = -filter.velocity * bounce_factor
    end
    
    -- 最小速度を保証（小さな振り幅でも動き続けるように）
    local min_velocity = 0.01 * filter.amplitude * filter.speed
    if math.abs(filter.velocity) < min_velocity and math.abs(filter.current_angle) < filter.amplitude * 0.5 then
        filter.velocity = (filter.velocity > 0 and 1 or -1) * min_velocity
    end
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()
    
    -- 振り幅の設定（最大値を0.3に制限）
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_AMPLITUDE, "振り幅（ラジアン）", 0.01, 0.3, 0.01)
    
    -- 速さの設定（最小値を0.01に変更）
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_SPEED, "速さ", 0.01, 5.0, 0.01)
    
    -- 支点の位置設定
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_PIVOT_X, "支点のX座標", 0.0, 1.0, 0.1)
    obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_PIVOT_Y, "支点のY座標", 0.0, 1.0, 0.1)
    
    -- バージョン情報（無効化状態で表示）
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, "バージョン", obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_AMPLITUDE, 0.2)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SPEED, 0.1)  -- デフォルトの速さを0.1に変更
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_PIVOT_X, 0.5)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_PIVOT_Y, 0.0)
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

// 振り子パラメータ
uniform float angle;
uniform float pivot_x;
uniform float pivot_y;

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
    
    // 支点の位置
    float2 pivot = float2(pivot_x, pivot_y);
    
    // UV座標を支点を原点として調整
    float2 centered_uv = uv - pivot;
    
    // 回転行列の計算（角度を2倍に抑えて歪みを軽減）
    float s = sin(angle * 2.0);
    float c = cos(angle * 2.0);
    
    // 回転を適用（Y軸方向の変形を抑制）
    float2 rotated_uv;
    rotated_uv.x = centered_uv.x * c - centered_uv.y * s;
    rotated_uv.y = centered_uv.x * s + centered_uv.y * c;
    
    // 元の原点に戻す
    float2 final_uv = rotated_uv + pivot;
    
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
