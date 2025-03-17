obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "3D回転フィルター",
    
    -- 設定キー
    SETTING_AUTO_ROTATE = "auto_rotate",
    SETTING_SPEED = "speed",
    SETTING_ANGLE = "angle",
    SETTING_VERSION = "version"
}

DESCRIPTION = {
    TITLE = "3D回転フィルター",
    BODY = "映像ソースをY軸周りに3D回転させます。立体的な回転をシミュレートし、自動回転も設定できます。",
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
source_def.id = "3drotation_filter"
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
    
    -- バージョン情報（無効化状態で表示）
    local version_prop = obs.obs_properties_add_text(props, CONSTANTS.SETTING_VERSION, "バージョン", obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_enabled(version_prop, false)
    
    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    -- 基本設定
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_ANGLE, 0.0)
    obs.obs_data_set_default_bool(settings, CONSTANTS.SETTING_AUTO_ROTATE, true)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SPEED, 1.0)
    
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
    
    // 中心点
    float2 center = float2(0.5, 0.5);
    
    // UV座標を中心を原点として調整
    float2 centered_uv = uv - center;
    
    // ラジアンに変換
    float angle_rad = radians(angle);
    
    // Y軸周りの3D回転をシミュレート
    float scale_factor = max(abs(cos(angle_rad)), 0.05);
    
    // 裏面表示の判定（90度〜270度の間は裏面）
    bool show_backside = (angle > 90 && angle < 270);
    
    // 裏面表示のときはX座標を反転
    if (show_backside) {
        centered_uv.x = -centered_uv.x;
    }
    
    // 横方向のスケーリングを適用（3D回転効果）
    centered_uv.x = centered_uv.x / scale_factor;
    
    // スケーリング後のUVが範囲外になる場合は透明に
    if (abs(centered_uv.x) > 0.5) {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    
    // 元の原点に戻す
    float2 final_uv = centered_uv + center;
    
    // テクスチャ座標が範囲外の場合は透明を返す
    if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    
    // サンプリング（透明度の調整なし）
    return image.Sample(linearSampler, final_uv);
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]] 