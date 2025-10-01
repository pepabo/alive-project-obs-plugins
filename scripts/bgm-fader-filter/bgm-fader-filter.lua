obs = obslua
source_name = "BGM"

-- バージョンと説明
VERSION = "1.0.0"
DESCRIPTION = {
    TITLE = "BGMフェーダー",
    USAGE = "配信中のBGM音量をホットキーで素早く調整できるスクリプトです。話す時は音量を下げ、通常時に戻す、さらに配信終了時にスムーズにフェードアウトさせることができます。",
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

-- デフォルト値
lowered_db = -40   -- 話している間の音量
normal_db  = -20   -- 通常の音量
lower_time_ms  = 200    -- 下げる時間
raise_time_ms  = 600    -- 戻す時間
end_time_ms    = 5000   -- 終了時のフェードアウト時間（デフォルト5秒）

-- 内部
fade_active = false
fade_from_db = normal_db
fade_to_db = lowered_db
fade_steps = 20
fade_step = 0
fade_interval = 30

-- dB → linear
function db_to_lin(db)
    if db <= -100 then return 0.0 end -- -∞扱い
    return 10 ^ (db / 20)
end

-- 音量設定
function set_volume(db)
    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        obs.obs_source_set_volume(source, db_to_lin(db))
        obs.obs_source_release(source)
    end
end

-- 現在の音量を dB で取得
function get_current_db()
    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        local vol = obs.obs_source_get_volume(source)
        obs.obs_source_release(source)
        if vol <= 0.000001 then
            return -100  -- ほぼゼロ扱い
        else
            return 20 * math.log(vol, 10)
        end
    end
    return normal_db
end

-- フェード更新
function fade_tick()
    if fade_step > fade_steps then
        obs.timer_remove(fade_tick)
        fade_active = false
        return
    end
    local db = fade_from_db + (fade_to_db - fade_from_db) * (fade_step / fade_steps)
    set_volume(db)
    fade_step = fade_step + 1
end

-- フェード開始
function start_fade(from_db, to_db, duration_ms, steps)
    if fade_active then return end
    fade_active = true
    fade_from_db = from_db
    fade_to_db = to_db
    fade_steps = steps or 40 -- デフォルトは40ステップ
    fade_step = 0
    fade_interval = duration_ms / fade_steps
    obs.timer_add(fade_tick, fade_interval)
end

-- ホットキー処理
function on_lower(pressed)
    if pressed then
        -- 常に -20 → -40 に下げる
        start_fade(normal_db, lowered_db, lower_time_ms, 30)
    end
end

function on_raise(pressed)
    if pressed then
        -- 常に -40 → -20 に戻す
        start_fade(lowered_db, normal_db, raise_time_ms, 30)
    end
end

function on_end(pressed)
    if pressed then
        -- 現在の値から完全にゼロまで、滑らかに
        start_fade(get_current_db(), -100, end_time_ms, 100)
    end
end

-- UI説明
function script_description()
    return string.format(DESCRIPTION.HTML,
        DESCRIPTION.TITLE,
        DESCRIPTION.USAGE,
        VERSION,
        DESCRIPTION.COPYRIGHT.URL,
        DESCRIPTION.COPYRIGHT.NAME)
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_text(props, "source", "音声ソース名", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props, "lowered_db", "話している間の音量 (dB)", -60, 0, 1)
    obs.obs_properties_add_int(props, "normal_db", "通常の音量 (dB)", -60, 0, 1)
    obs.obs_properties_add_int(props, "lower_time_ms", "下げる時間 (ms)", 50, 2000, 50)
    obs.obs_properties_add_int(props, "raise_time_ms", "戻す時間 (ms)", 50, 5000, 50)
    obs.obs_properties_add_int(props, "end_time_ms", "終了フェードアウトの時間 (ms)", 100, 20000, 100)
    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "source", "BGM")
    obs.obs_data_set_default_int(settings, "lowered_db", -40)
    obs.obs_data_set_default_int(settings, "normal_db", -20)
    obs.obs_data_set_default_int(settings, "lower_time_ms", 200)
    obs.obs_data_set_default_int(settings, "raise_time_ms", 600)
    obs.obs_data_set_default_int(settings, "end_time_ms", 5000) -- デフォルト5秒
end

function script_update(settings)
    source_name    = obs.obs_data_get_string(settings, "source")
    lowered_db     = obs.obs_data_get_int(settings, "lowered_db")
    normal_db      = obs.obs_data_get_int(settings, "normal_db")
    lower_time_ms  = obs.obs_data_get_int(settings, "lower_time_ms")
    raise_time_ms  = obs.obs_data_get_int(settings, "raise_time_ms")
    end_time_ms    = obs.obs_data_get_int(settings, "end_time_ms")
end

-- ホットキー登録
hotkey_id_lower = obs.OBS_INVALID_HOTKEY_ID
hotkey_id_raise = obs.OBS_INVALID_HOTKEY_ID
hotkey_id_end   = obs.OBS_INVALID_HOTKEY_ID

function script_load(settings)
    hotkey_id_lower = obs.obs_hotkey_register_frontend("lower_bgm", "BGMを下げる（話す時）", on_lower)
    hotkey_id_raise = obs.obs_hotkey_register_frontend("raise_bgm", "BGMを戻す（通常に）", on_raise)
    hotkey_id_end   = obs.obs_hotkey_register_frontend("end_bgm", "BGMを終了（フェードアウト）", on_end)

    local arr = obs.obs_data_get_array(settings, "lower_bgm_hotkey")
    obs.obs_hotkey_load(hotkey_id_lower, arr); obs.obs_data_array_release(arr)

    arr = obs.obs_data_get_array(settings, "raise_bgm_hotkey")
    obs.obs_hotkey_load(hotkey_id_raise, arr); obs.obs_data_array_release(arr)

    arr = obs.obs_data_get_array(settings, "end_bgm_hotkey")
    obs.obs_hotkey_load(hotkey_id_end, arr); obs.obs_data_array_release(arr)
end

function script_save(settings)
    local arr = obs.obs_hotkey_save(hotkey_id_lower)
    obs.obs_data_set_array(settings, "lower_bgm_hotkey", arr); obs.obs_data_array_release(arr)

    arr = obs.obs_hotkey_save(hotkey_id_raise)
    obs.obs_data_set_array(settings, "raise_bgm_hotkey", arr); obs.obs_data_array_release(arr)

    arr = obs.obs_hotkey_save(hotkey_id_end)
    obs.obs_data_set_array(settings, "end_bgm_hotkey", arr); obs.obs_data_array_release(arr)
end
