obs = obslua

-- 定数
local CONSTANTS = {
  VERSION = "1.0.0",
  FILTER_NAME = "残像効果",

  -- 設定キー
  SETTING_CAPTURE_INTERVAL = "capture_interval",
  SETTING_FADE_SPEED = "fade_speed",
  SETTING_MAX_IMAGES = "max_images",
  SETTING_VERSION = "version",
}

DESCRIPTION = {
  TITLE = "残像効果",
  USAGE = "ソースの動きに残像効果を適用します。一定間隔でスクリーンショットを撮り、時間経過とともに徐々に薄くなっていく残像を表示します。",
  COPYRIGHT = {
    NAME = "Alive Project by GMOペパボ",
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
source_def.id = "afterimage_filter"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = obs.OBS_SOURCE_VIDEO

-- グローバル変数
local last_capture_time = 0
local captured_frames = {}
local texrender = nil

-- フィルターの作成時に呼ばれる
function source_def.create(settings, source)
  local filter = {}
  filter.source = source
  filter.width = 0
  filter.height = 0
  filter.settings = settings

  -- 設定の読み込み
  update_settings(filter, settings)

  obs.obs_source_update(source, settings)
  return filter
end

-- 設定の更新
function update_settings(filter, settings)
  filter.capture_interval = obs.obs_data_get_double(settings, CONSTANTS.SETTING_CAPTURE_INTERVAL)
  filter.fade_speed = obs.obs_data_get_double(settings, CONSTANTS.SETTING_FADE_SPEED)
  filter.max_images = obs.obs_data_get_int(settings, CONSTANTS.SETTING_MAX_IMAGES)
end

-- 設定の更新時に呼ばれる
function source_def.update(filter, settings)
  update_settings(filter, settings)
end

-- 描画処理
function source_def.video_render(filter, effect)
  local parent = obs.obs_filter_get_parent(filter.source)
  local target = obs.obs_filter_get_target(filter.source)

  -- 親ソースのサイズを取得
  local width = obs.obs_source_get_base_width(parent)
  local height = obs.obs_source_get_base_height(parent)

  -- サイズが変わったらテクスチャをリセット
  if width ~= filter.width or height ~= filter.height then
    filter.width = width
    filter.height = height

    -- テクスチャレンダラを再作成
    if texrender ~= nil then
      obs.obs_enter_graphics()
      obs.gs_texrender_destroy(texrender)
      texrender = nil
      obs.obs_leave_graphics()
    end
  end

  -- テクスチャレンダラの作成（必要な場合）
  if texrender == nil then
    obs.obs_enter_graphics()
    texrender = obs.gs_texrender_create(obs.GS_RGBA, obs.GS_ZS_NONE)
    obs.obs_leave_graphics()
  end

  -- 現在の時間を取得
  local current_time = obs.os_gettime_ns() / 1000000000.0

  -- 一定間隔でキャプチャを行う
  if current_time - last_capture_time >= filter.capture_interval then
    last_capture_time = current_time
    capture_frame(filter, parent, width, height)
  end

  -- 親ソースを描画
  obs.obs_source_process_filter_begin(filter.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)
  obs.obs_source_process_filter_end(filter.source, effect, 0, 0)

  -- 保存された残像を描画
  draw_afterimages(filter, width, height)

  -- フレームの透明度を更新し、完全に透明になったフレームを削除
  update_frames(filter, current_time)
end

-- フレームをキャプチャする関数
function capture_frame(filter, source, width, height)
  if width <= 0 or height <= 0 then
    return
  end

  obs.obs_enter_graphics()

  -- テクスチャレンダラの設定
  if not obs.gs_texrender_begin(texrender, width, height) then
    obs.obs_leave_graphics()
    return
  end

  -- 描画エリアをクリア
  obs.gs_clear_color(0, 0, 0, 0)
  obs.gs_clear(obs.GS_CLEAR_COLOR + obs.GS_CLEAR_DEPTH)

  -- ソースを描画
  local param = {}
  param.source = source
  param.x = 0
  param.y = 0
  param.cx = width
  param.cy = height

  obs.gs_blend_state_push()
  obs.gs_blend_function(obs.GS_BLEND_ONE, obs.GS_BLEND_ZERO)
  obs.obs_source_video_render(source)
  obs.gs_blend_state_pop()

  obs.gs_texrender_end(texrender)

  -- テクスチャを取得
  local texture = obs.gs_texrender_get_texture(texrender)

  if texture ~= nil then
    -- 新しいフレームを保存
    local frame = {
      texture = obs.gs_texture_get_obj(texture),
      time = obs.os_gettime_ns() / 1000000000.0,
      opacity = 1.0
    }

    table.insert(captured_frames, 1, frame)

    -- 最大保存数を超えたら古いものを削除
    if #captured_frames > filter.max_images then
      -- 最後のフレームのテクスチャを解放
      local last_frame = table.remove(captured_frames)
      obs.gs_texture_destroy(last_frame.texture)
    end
  end

  obs.obs_leave_graphics()
end

-- 残像を描画する関数
function draw_afterimages(filter, width, height)
  if #captured_frames == 0 then
    return
  end

  obs.obs_enter_graphics()

  -- 残像描画のブレンド設定
  obs.gs_blend_state_push()
  obs.gs_blend_function(obs.GS_BLEND_ONE, obs.GS_BLEND_INVSRCALPHA)

  obs.gs_matrix_push()
  obs.gs_matrix_identity()

  -- 各フレームを描画
  for i, frame in ipairs(captured_frames) do
    if i > 1 then -- 最新のフレームは除外（すでに通常描画されているため）
      -- テクスチャを設定
      local effect = obs.gs_effect_create("draw_image", nil, nil)
      if effect ~= nil then
        local param = obs.gs_effect_get_param_by_name(effect, "image")
        obs.gs_effect_set_texture(param, frame.texture)

        local param_opacity = obs.gs_effect_get_param_by_name(effect, "opacity")
        obs.gs_effect_set_float(param_opacity, frame.opacity)

        -- 描画
        while obs.gs_effect_loop(effect, "Draw") do
          obs.gs_draw_sprite(frame.texture, 0, width, height)
        end

        obs.gs_effect_destroy(effect)
      end
    end
  end

  obs.gs_matrix_pop()
  obs.gs_blend_state_pop()

  obs.obs_leave_graphics()
end

-- フレームの更新（透明度の減少と古いフレームの削除）
function update_frames(filter, current_time)
  local frames_to_keep = {}

  -- 各フレームの透明度を更新
  for i, frame in ipairs(captured_frames) do
    local elapsed_time = current_time - frame.time
    frame.opacity = math.max(0, 1.0 - (elapsed_time * filter.fade_speed))

    -- まだ表示すべきフレームなら保持
    if frame.opacity > 0 then
      table.insert(frames_to_keep, frame)
    else
      -- 完全に透明になったフレームのテクスチャを解放
      obs.gs_texture_destroy(frame.texture)
    end
  end

  -- フレームを更新
  captured_frames = frames_to_keep
end

-- フィルターが破棄されるときに呼ばれる
function source_def.destroy(filter)
  -- 保存されたフレームを全て解放
  obs.obs_enter_graphics()

  for _, frame in ipairs(captured_frames) do
    obs.gs_texture_destroy(frame.texture)
  end

  if texrender ~= nil then
    obs.gs_texrender_destroy(texrender)
    texrender = nil
  end

  captured_frames = {}

  obs.obs_leave_graphics()
end

-- 設定プロパティの取得
function source_def.get_properties(filter)
  local props = obs.obs_properties_create()

  -- 残像のキャプチャ間隔（秒）
  local p = obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_CAPTURE_INTERVAL,
    "キャプチャ間隔（秒）", 0.05, 1.0, 0.05)
  obs.obs_property_set_long_description(p, "残像をキャプチャする間隔を設定します。値が小さいほど多くの残像が表示されます。")

  -- フェードアウトの速度
  p = obs.obs_properties_add_float_slider(props, CONSTANTS.SETTING_FADE_SPEED,
    "フェード速度", 0.1, 2.0, 0.1)
  obs.obs_property_set_long_description(p, "残像が消えていく速度を設定します。値が大きいほど速く消えます。")

  -- 最大保存フレーム数
  p = obs.obs_properties_add_int_slider(props, CONSTANTS.SETTING_MAX_IMAGES,
    "最大残像数", 1, 30, 1)
  obs.obs_property_set_long_description(p, "保存する残像の最大数を設定します。多すぎるとパフォーマンスに影響する可能性があります。")

  return props
end

-- デフォルト設定の取得
function source_def.get_defaults(settings)
  obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_CAPTURE_INTERVAL, 0.1)
  obs.obs_data_set_default_double(settings, CONSTANTS.SETTING_FADE_SPEED, 0.5)
  obs.obs_data_set_default_int(settings, CONSTANTS.SETTING_MAX_IMAGES, 10)
  obs.obs_data_set_default_string(settings, CONSTANTS.SETTING_VERSION, CONSTANTS.VERSION)
end

-- 表示名の取得
function source_def.get_name(type)
  return CONSTANTS.FILTER_NAME
end

-- プラグインの説明
function script_description()
  return string.format(DESCRIPTION.HTML,
    DESCRIPTION.TITLE,
    DESCRIPTION.USAGE,
    CONSTANTS.VERSION,
    DESCRIPTION.COPYRIGHT.URL,
    DESCRIPTION.COPYRIGHT.NAME)
end

-- スクリプトのロード時に呼ばれる
function script_load(settings)
  obs.obs_register_source(source_def)
end
