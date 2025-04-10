obs = obslua

-- 定数
local CONSTANTS = {
    VERSION = "1.0.0",
    FILTER_NAME = "フィルムカメラ",

    -- 設定キー
    SETTING_GRAIN_AMOUNT = "grain_amount",
    SETTING_VIGNETTE_INTENSITY = "vignette_intensity",
    SETTING_COLOR_SHIFT = "color_shift",
    SETTING_SATURATION = "saturation",
    SETTING_CONTRAST = "contrast",
    SETTING_LIGHT_LEAK = "light_leak",
    SETTING_SCRATCHES = "scratches",
    SETTING_FILM_TYPE = "film_type",
    SETTING_VERSION = "version",
}

-- フィルムタイプ
local FILM_TYPES = {
    "クラシック",      -- 一般的な古いフィルム
    "ヴィンテージ",    -- より古い、セピア調
    "トイカメラ",      -- 鮮やかで不均一な色
    "モノクローム",    -- 白黒フィルム
    "インスタント",    -- インスタントカメラ風
    "カラーネガ",      -- カラーネガフィルム
    "ポジフィルム"     -- ポジフィルム（鮮やかな色）
}

-- 説明文
DESCRIPTION = {
    TITLE = "フィルムカメラ",
    USAGE = "配信映像にアナログ調のフィルムカメラやトイカメラのような質感を追加します。フィルムグレイン、ビネット効果、スクラッチ、色調変化、光漏れなど様々な効果を適用できます。",
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

-- シェーダーコード
local shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

// フィルムカメラパラメータ
uniform float time;                  // 時間
uniform float grain_amount;          // フィルムグレインの量
uniform float vignette_intensity;    // ビネット効果の強さ
uniform float color_shift;           // 色調変化
uniform float saturation;            // 彩度
uniform float contrast;              // コントラスト
uniform float light_leak;            // 光漏れ
uniform float scratches;             // フィルムスクラッチ
uniform int film_type;               // フィルムタイプ
uniform float resolution_x;          // 画面の横幅
uniform float resolution_y;          // 画面の縦幅

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

// 乱数生成関数
float random(float2 st) {
    return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

// ノイズ関数
float noise(float2 st) {
    float2 i = floor(st);
    float2 f = frac(st);
    
    // 4点の乱数を取得
    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));
    
    // スムーズ補間
    float2 u = f * f * (3.0 - 2.0 * f);
    
    // 補間した値を返す
    return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// グレースケール変換
float luminance(float3 color) {
    return dot(color, float3(0.299, 0.587, 0.114));
}

// 彩度調整
float3 adjustSaturation(float3 color, float saturation) {
    float grey = luminance(color);
    return lerp(float3(grey, grey, grey), color, saturation);
}

// フィルムタイプ別のカラーグレーディング
float3 applyFilmType(float3 color, int film_type) {
    if (film_type == 0) { // クラシック
        // 少し青みを抑え、黄色味を強調
        color.r = min(1.0, color.r * 1.05);
        color.g = min(1.0, color.g * 1.02);
        color.b = max(0.0, color.b * 0.97);
        return color;
    }
    else if (film_type == 1) { // ヴィンテージ
        // セピア調
        float3 sepia;
        sepia.r = min(1.0, dot(color, float3(0.393, 0.769, 0.189)));
        sepia.g = min(1.0, dot(color, float3(0.349, 0.686, 0.168)));
        sepia.b = min(1.0, dot(color, float3(0.272, 0.534, 0.131)));
        return lerp(color, sepia, 0.6);
    }
    else if (film_type == 2) { // トイカメラ
        // 色の不均一さとコントラスト強調
        color.r = min(1.0, color.r * 1.1);
        color.g = min(1.0, color.g * 0.95);
        color.b = min(1.0, color.b * 1.05);
        
        // ビネットとカラーシフトを強調
        color = adjustSaturation(color, 1.2);
        return color;
    }
    else if (film_type == 3) { // モノクローム
        // 白黒
        float grey = luminance(color);
        return float3(grey, grey, grey);
    }
    else if (film_type == 4) { // インスタント
        // インスタントカメラ風
        float3 instant;
        instant.r = min(1.0, color.r * 1.1);
        instant.g = min(1.0, color.g * 1.05);
        instant.b = max(0.0, color.b * 0.9);
        
        color = lerp(color, instant, 0.7);
        
        // 明るい部分を若干強調
        float highlight = smoothstep(0.7, 1.0, luminance(color));
        color = lerp(color, min(float3(1.0, 1.0, 1.0), color * 1.3), highlight * 0.3);
        
        return color;
    }
    else if (film_type == 5) { // カラーネガ
        // カラーネガフィルム風
        float3 neg;
        neg.r = min(1.0, color.r * 1.05);
        neg.g = min(1.0, color.g * 0.98);
        neg.b = min(1.0, color.b * 0.9);
        
        // 赤みを増加
        neg = lerp(neg, float3(min(1.0, neg.r * 1.1), neg.g, neg.b), 0.3);
        
        // シャドウ部分を濃くする
        float shadow = 1.0 - smoothstep(0.0, 0.6, luminance(color));
        neg = lerp(neg, neg * 0.7, shadow * 0.4);
        
        return neg;
    }
    else if (film_type == 6) { // ポジフィルム
        // ポジフィルム風（鮮やかな色）
        float3 pos;
        pos.r = min(1.0, color.r * 1.07);
        pos.g = min(1.0, color.g * 1.05);
        pos.b = min(1.0, color.b * 1.03);
        
        // 彩度を上げる
        pos = adjustSaturation(pos, 1.1);
        
        // コントラストを上げる
        float grey = luminance(pos);
        pos = lerp(float3(0.5, 0.5, 0.5), pos, 1.1);
        
        return pos;
    }
    
    return color;
}

float4 PS(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 center = float2(0.5, 0.5);
    
    // 原画像の取得
    float4 color = image.Sample(linearSampler, uv);
    
    // フィルムグレイン
    if (grain_amount > 0.0) {
        float grain_value = noise(float2(uv.x * resolution_x * 0.5, uv.y * resolution_y * 0.5 + time * 10.0)) * 2.0 - 1.0;
        grain_value *= grain_amount;
        color.rgb += grain_value * 0.1;
    }
    
    // ビネット効果（周辺減光）
    if (vignette_intensity > 0.0) {
        float2 rel_uv = uv - center;
        float dist = length(rel_uv) * 2.0;
        float vignette = 1.0 - dist * vignette_intensity;
        vignette = min(1.0, max(0.0, vignette));
        color.rgb *= vignette;
    }
    
    // フィルムスクラッチ - 大幅に強化して目立つように
    if (scratches > 0.0) {
        // 時間パラメータを調整してスクラッチの動きを変更
        float scratch_time = time * 0.3;
        
        // より多くのスクラッチラインを生成（5本のメインスクラッチ）
        for(int i = 0; i < 5; i++) {
            // スクラッチの位置（画面全体に分散）
            float scratch_x = frac(random(float2(i * 0.333, floor(scratch_time * 0.2))) * 0.9 + 0.05);
            
            // スクラッチの幅と強度を大きく
            float scratch_width = 0.003 + 0.002 * random(float2(i, scratch_time));
            float scratch_intensity = 0.5 + 0.5 * random(float2(i + 10.0, scratch_time));
            
            // スクラッチを描画（より明確な線）
            float scratch_mask = 1.0 - smoothstep(0.0, scratch_width, abs(uv.x - scratch_x));
            
            // より長いスクラッチにする（断続性を減らす）
            float scratch_random = step(0.2, noise(float2(0.0, uv.y * 15.0 + scratch_time * (i + 1.0) * 2.0)));
            
            // スクラッチをより明るく、白色を強調
            if (scratch_mask > 0.0 && scratch_random > 0.0) {
                color.rgb = lerp(color.rgb, float3(1.2, 1.2, 1.2), scratch_mask * scratch_random * scratches * scratch_intensity * 1.5);
            }
        }
        
        // 短い断片的なスクラッチを追加（微細なスクラッチ）
        for(int j = 0; j < 8; j++) {
            float micro_scratch_x = frac(random(float2(j * 0.765, floor(scratch_time * 0.5 + j))) * 0.95 + 0.025);
            float micro_scratch_width = 0.001 + 0.001 * random(float2(j * 3.33, scratch_time));
            float micro_scratch_mask = 1.0 - smoothstep(0.0, micro_scratch_width, abs(uv.x - micro_scratch_x));
            
            // より短くランダムなパターン
            float micro_y_offset = random(float2(j * 1.234, floor(scratch_time))) * 0.8;
            float micro_y_length = 0.05 + random(float2(j * 4.321, floor(scratch_time))) * 0.1;
            float micro_y_pos = smoothstep(micro_y_offset, micro_y_offset + micro_y_length, uv.y) 
                              * (1.0 - smoothstep(micro_y_offset + micro_y_length, micro_y_offset + micro_y_length + 0.05, uv.y));
            
            if (micro_scratch_mask > 0.0 && micro_y_pos > 0.0) {
                color.rgb = lerp(color.rgb, float3(1.1, 1.1, 1.1), micro_scratch_mask * micro_y_pos * scratches * 0.7);
            }
        }
        
        // 水平方向のスクラッチも追加（より多く、目立つように）
        for(int k = 0; k < 3; k++) {
            float h_scratch_y = frac(random(float2(k * 2.5, floor(scratch_time * 0.3))) * 0.8 + 0.1);
            float h_scratch_width = 0.0015 + 0.001 * random(float2(k * 7.77, scratch_time));
            float h_scratch_mask = 1.0 - smoothstep(0.0, h_scratch_width, abs(uv.y - h_scratch_y));
            
            // 水平スクラッチの断続性
            float h_scratch_pattern = step(0.6, noise(float2(uv.x * 20.0 + scratch_time * 3.0, k)));
            
            if (h_scratch_mask > 0.0 && h_scratch_pattern > 0.0 && random(float2(scratch_time + k, 0.0)) > 0.3) {
                color.rgb = lerp(color.rgb, float3(1.15, 1.15, 1.15), h_scratch_mask * h_scratch_pattern * scratches * 0.8);
            }
        }
        
        // ダスト（小さな点状のノイズ）を追加
        for(int d = 0; d < 10; d++) {
            float2 dust_pos = float2(
                frac(random(float2(d * 0.333, floor(scratch_time * 0.1)))),
                frac(random(float2(d * 0.777, floor(scratch_time * 0.1 + 10.0))))
            );
            
            float dust_size = 0.002 + 0.003 * random(float2(d, scratch_time));
            float dust_dist = distance(uv, dust_pos);
            float dust_mask = 1.0 - smoothstep(0.0, dust_size, dust_dist);
            
            if (dust_mask > 0.0 && random(float2(d, scratch_time)) > 0.3) {
                color.rgb = lerp(color.rgb, float3(1.2, 1.2, 1.2), dust_mask * scratches * 0.6);
            }
        }
    }
    
    // 光漏れエフェクト
    if (light_leak > 0.0) {
        // 画面の端から漏れる光
        float2 leak_uv = float2(
            uv.x * 2.0 - 1.0, 
            uv.y * 2.0 - 1.0
        );
        
        // 光漏れの位置（時間によって変化）
        float leak_angle = time * 0.05;
        float2 leak_dir = float2(cos(leak_angle), sin(leak_angle));
        float leak_dist = max(0.0, dot(normalize(leak_uv), leak_dir) - 0.7) * 3.0; // 端からの距離
        
        // 光漏れの色と強度
        float3 leak_color = float3(1.0, 0.6, 0.3); // オレンジ系の光
        float leak_intensity = leak_dist * light_leak;
        
        // 光漏れを適用
        color.rgb += leak_color * leak_intensity;
    }
    
    // 色調変化 - 効果を強化
    if (color_shift > 0.0) {
        // 強化された色調変化
        float3 shifted_color;
        
        // フィルムタイプによって色調変化の効果を調整
        if (film_type == 0 || film_type == 1) { // クラシックとヴィンテージ
            // ウォームトーン（より暖かい色調）
            shifted_color.r = min(1.0, color.r * (1.0 + color_shift * 0.3));
            shifted_color.g = min(1.0, color.g * (1.0 + color_shift * 0.1));
            shifted_color.b = max(0.0, color.b * (1.0 - color_shift * 0.2));
        } 
        else if (film_type == 2) { // トイカメラ
            // よりビビッドで不均一な色
            shifted_color.r = min(1.0, color.r * (1.0 + color_shift * 0.25 * sin(uv.y * 3.14159)));
            shifted_color.g = min(1.0, color.g * (1.0 - color_shift * 0.05));
            shifted_color.b = min(1.0, color.b * (1.0 + color_shift * 0.15 * cos(uv.x * 6.28318)));
        }
        else if (film_type == 3) { // モノクローム
            // モノクロでも微妙な調整（セピア方向）
            float grey = luminance(color.rgb);
            shifted_color = float3(
                min(1.0, grey * (1.0 + color_shift * 0.1)),
                grey,
                max(0.0, grey * (1.0 - color_shift * 0.1))
            );
        }
        else {
            // デフォルト
            shifted_color = color.rgb;
        }
        
        // 明るさに応じた色調変化
        float brightness = luminance(color.rgb);
        float shadow_strength = 1.0 - smoothstep(0.0, 0.3, brightness); // 暗い部分
        float midtone_strength = 1.0 - abs(brightness - 0.5) * 2.0;     // 中間トーン
        float highlight_strength = smoothstep(0.7, 1.0, brightness);    // 明るい部分
        
        // 領域ごとに異なる効果を適用
        float3 result = color.rgb;
        
        // 暗い部分では彩度を下げつつ色調を変更
        if (shadow_strength > 0.0) {
            float3 shadow_color = shifted_color * (1.0 - shadow_strength * color_shift * 0.3);
            result = lerp(result, shadow_color, shadow_strength * color_shift);
        }
        
        // 中間トーンでは主に色相を変更
        if (midtone_strength > 0.0) {
            result = lerp(result, shifted_color, midtone_strength * color_shift);
        }
        
        // 明るい部分ではより強い効果
        if (highlight_strength > 0.0) {
            float3 highlight_color = min(float3(1.0, 1.0, 1.0), shifted_color * (1.0 + highlight_strength * color_shift * 0.2));
            result = lerp(result, highlight_color, highlight_strength * color_shift);
        }
        
        color.rgb = result;
    }
    
    // 彩度調整
    color.rgb = adjustSaturation(color.rgb, saturation);
    
    // コントラスト調整
    float mid_gray = 0.5;
    color.rgb = (color.rgb - mid_gray) * contrast + mid_gray;
    
    // フィルムタイプ適用
    color.rgb = applyFilmType(color.rgb, film_type);
    
    // 最終的な色の範囲を制限
    color.rgb = max(float3(0.0, 0.0, 0.0), min(float3(1.0, 1.0, 1.0), color.rgb));
    
    return color;
}

technique Draw {
    pass {
        vertex_shader = VS(v_in);
        pixel_shader = PS(v_in);
    }
}
]]

-- ソース定義
source_def = {}
source_def.id = "film_camera_filter"
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
    filter.grain_amount = 0.2     -- デフォルト値
    filter.vignette_intensity = 0.3
    filter.color_shift = 0.3
    filter.saturation = 0.9
    filter.contrast = 1.1
    filter.light_leak = 0.1
    filter.scratches = 0.3
    filter.film_type = FILM_TYPES[1]
    filter.width = 1
    filter.height = 1
    filter.last_time = 0

    -- シェーダー作成
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader, nil, nil)

    if filter.effect ~= nil then
        -- パラメータ取得
        filter.params.time = obs.gs_effect_get_param_by_name(filter.effect, "time")
        filter.params.grain_amount = obs.gs_effect_get_param_by_name(filter.effect, "grain_amount")
        filter.params.vignette_intensity = obs.gs_effect_get_param_by_name(filter.effect, "vignette_intensity")
        filter.params.color_shift = obs.gs_effect_get_param_by_name(filter.effect, "color_shift")
        filter.params.saturation = obs.gs_effect_get_param_by_name(filter.effect, "saturation")
        filter.params.contrast = obs.gs_effect_get_param_by_name(filter.effect, "contrast")
        filter.params.light_leak = obs.gs_effect_get_param_by_name(filter.effect, "light_leak")
        filter.params.scratches = obs.gs_effect_get_param_by_name(filter.effect, "scratches")
        filter.params.film_type = obs.gs_effect_get_param_by_name(filter.effect, "film_type")
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
    filter.grain_amount = obs.obs_data_get_double(settings, CONSTANTS.SETTING_GRAIN_AMOUNT)
    filter.vignette_intensity = obs.obs_data_get_double(settings, CONSTANTS.SETTING_VIGNETTE_INTENSITY)
    filter.color_shift = obs.obs_data_get_double(settings, CONSTANTS.SETTING_COLOR_SHIFT)
    filter.saturation = obs.obs_data_get_double(settings, CONSTANTS.SETTING_SATURATION)
    filter.contrast = obs.obs_data_get_double(settings, CONSTANTS.SETTING_CONTRAST)
    filter.light_leak = obs.obs_data_get_double(settings, CONSTANTS.SETTING_LIGHT_LEAK)
    filter.scratches = obs.obs_data_get_double(settings, CONSTANTS.SETTING_SCRATCHES)
    filter.film_type = obs.obs_data_get_string(settings, CONSTANTS.SETTING_FILM_TYPE)
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
    time_value = time_value + time_delta

    -- フィルムタイプを数値に変換
    local film_type_num = 0
    for i, film_type in ipairs(FILM_TYPES) do
        if film_type == filter.film_type then
            film_type_num = i - 1
            break
        end
    end

    -- パラメータ設定
    obs.gs_effect_set_float(filter.params.time, time_value)
    obs.gs_effect_set_float(filter.params.grain_amount, filter.grain_amount)
    obs.gs_effect_set_float(filter.params.vignette_intensity, filter.vignette_intensity)
    obs.gs_effect_set_float(filter.params.color_shift, filter.color_shift)
    obs.gs_effect_set_float(filter.params.saturation, filter.saturation)
    obs.gs_effect_set_float(filter.params.contrast, filter.contrast)
    obs.gs_effect_set_float(filter.params.light_leak, filter.light_leak)
    obs.gs_effect_set_float(filter.params.scratches, filter.scratches)
    obs.gs_effect_set_int(filter.params.film_type, film_type_num)
    obs.gs_effect_set_float(filter.params.resolution_x, filter.width)
    obs.gs_effect_set_float(filter.params.resolution_y, filter.height)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- プロパティUI定義
source_def.get_properties = function(settings)
    local props = obs.obs_properties_create()

    -- フィルムタイプ
    local film_type_prop = obs.obs_properties_add_list(
        props,
        CONSTANTS.SETTING_FILM_TYPE,
        "フィルムタイプ",
        obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING
    )

    for _, film_type in ipairs(FILM_TYPES) do
        obs.obs_property_list_add_string(film_type_prop, film_type, film_type)
    end

    -- フィルムグレイン
    local grain_prop = obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_GRAIN_AMOUNT,
        "フィルムグレイン",
        0.0,
        1.0,
        0.01
    )
    obs.obs_property_set_long_description(grain_prop, "フィルム特有の粒状感を追加します。値が大きいほど粒状感が強くなります。")
    
    -- ビネット効果
    local vignette_prop = obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_VIGNETTE_INTENSITY,
        "ビネット効果",
        0.0,
        1.0,
        0.01
    )
    obs.obs_property_set_long_description(vignette_prop, "画面の周辺部を暗くする効果です。値が大きいほど周辺減光が強くなります。")
    
    -- 色調変化
    local color_shift_prop = obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_COLOR_SHIFT,
        "色調変化",
        0.0,
        1.0,
        0.01
    )
    obs.obs_property_set_long_description(color_shift_prop, "フィルムカメラ特有の色調変化を適用します。フィルムタイプによって効果が異なります。")
    
    -- 彩度
    local saturation_prop = obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_SATURATION,
        "彩度",
        0.5,
        1.5,
        0.01
    )
    obs.obs_property_set_long_description(saturation_prop, "色の鮮やかさを調整します。低いと色が薄く、高いと色が鮮やかになります。")
    
    -- コントラスト
    local contrast_prop = obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_CONTRAST,
        "コントラスト",
        0.8,
        1.5,
        0.01
    )
    obs.obs_property_set_long_description(contrast_prop, "明暗の差を調整します。高いと明暗の差が強調されます。")
    
    -- 光漏れ
    local light_leak_prop = obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_LIGHT_LEAK,
        "光漏れ",
        0.0,
        0.7,
        0.01
    )
    obs.obs_property_set_long_description(light_leak_prop, "フィルムカメラに特有の光漏れ効果を追加します。古いカメラの雰囲気を出せます。")
    
    -- フィルムスクラッチ
    local scratches_prop = obs.obs_properties_add_float_slider(
        props,
        CONSTANTS.SETTING_SCRATCHES,
        "フィルムスクラッチ",
        0.0,
        1.0,
        0.01
    )
    obs.obs_property_set_long_description(scratches_prop, "古いフィルムのような傷や汚れを追加します。値が大きいほど傷が目立ちます。")

    return props
end

-- デフォルト値設定
source_def.get_defaults = function(settings)
    obs.obs_data_set_default_string(settings, CONSTANTS.SETTING_FILM_TYPE, FILM_TYPES[1])
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_GRAIN_AMOUNT, 0.2)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_VIGNETTE_INTENSITY, 0.3)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_COLOR_SHIFT, 0.3)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SATURATION, 0.9)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_CONTRAST, 1.1)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_LIGHT_LEAK, 0.1)
    obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_SCRATCHES, 0.3)
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

-- スクリプトのプロパティ
function script_properties()
    local props = obs.obs_properties_create()
    
    -- バージョン情報
    local version_info = obs.obs_properties_add_text(
        props,
        "version_info",
        "バージョン情報",
        obs.OBS_TEXT_INFO
    )
    
    -- 著作権情報
    obs.obs_properties_add_button(
        props,
        "copyright_button",
        "© " .. DESCRIPTION.COPYRIGHT.NAME,
        function()
            obs.obs_browser_open(DESCRIPTION.COPYRIGHT.URL)
            return true
        end
    )
    
    return props
end

-- スクリプトのデフォルト値
function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "version_info", CONSTANTS.FILTER_NAME .. " v" .. CONSTANTS.VERSION)
end

-- スクリプト設定の更新
function script_update(settings)
    -- スクリプト自体の設定更新時の処理
end

-- スクリプト読み込み時の処理
function script_load(settings)
    obs.obs_register_source(source_def)
end 