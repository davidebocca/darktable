local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE <const> = "missing_images_finder"

local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"
local DEFAULT_LOG_LEVEL <const> = log.info

local MISSING_IMAGES_TAG = dt.tags.create("missing-images")

du.check_min_api_version("9.4.0", MODULE)

-- translation facilities

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

local script_data = {}

script_data.destroy = nil        -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil        -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil           -- only required for libs since the destroy_method only hides them

local images_to_scan_count = 0
local scanned_images_count = 0
local missing_images_count = 0
local update_perc_images_count = 100

script_data.metadata = {
  name = _("missing image finder"),
  purpose = _("tool used to find images in database that are missing on disk"),
  author = "Davide Bocca",
  help = ""
}

-- - - - - - - - - - - - - - - - - - - - - - - -
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - -

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - -
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - -

local missing_images_finder = {}

-- - - - - - - - - - - - - - - - - - - - - - - -
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - -

missing_images_finder.main_widget = nil

-- - - - - - - - - - - - - - - - - - - - - - - -
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - -

local namespace = missing_images_finder

-- - - - - - - - - - - - - - - - - - - - - - - -
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - -

missing_images_finder.progress_images_count =
    dt.new_widget("label") {
      ellipsize = "middle",
      halign = "end"
    };

missing_images_finder.progress_perc_label =
    dt.new_widget("label") {
      ellipsize = "middle",
      halign = "end"
    };

missing_images_finder.progress_perc_label.label = "- %"

missing_images_finder.missing_images_count_label =
    dt.new_widget("label") {
      ellipsize = "middle",
      halign = "end"
    };

missing_images_finder.missing_images_count_label.label = missing_images_count

missing_images_finder.scan_collection_button = dt.new_widget("button") {
  label = _("collection"),
  tooltip = _("scan current collection")
};

missing_images_finder.scan_global_button = dt.new_widget("button") {
  label = _("global"),
  tooltip = _("scan globally")
};

-- - - - - - - - - - - - - - - - - - - - - - - -
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -

local function destroy()
  dt.gui.libs[MODULE].visible = false

  if namespace.event_registered then
    dt.destroy_event(MODULE, "view-changed")
  end
end

local function restart()
  dt.gui.libs[MODULE].visible = true
end

local function checkImage(image)
  scanned_images_count = scanned_images_count + 1

  missing_images_finder.progress_images_count.label = scanned_images_count .. " of " .. images_to_scan_count

  dt.tags.detach(MISSING_IMAGES_TAG, image)

  if not df.check_if_file_exists(image.path .. PS .. image.filename) then
    missing_images_count = missing_images_count + 1

    log.msg(log.info, image.path .. PS .. image.filename .. " is missing")
    dt.tags.attach(MISSING_IMAGES_TAG, image)

    missing_images_finder.missing_images_count_label.label = missing_images_count
  end
  missing_images_finder.progress_perc_label.label = string.format("%.1f %%", scanned_images_count / images_to_scan_count * 100)
end

local function scanFilm(film)
  log.msg(log.info, "scanning film " .. film.path)

  for i = 1, #film do
    checkImage(film[i])
  end
end

local function scanCollection(collection)
  log.msg(log.info, "scanning collection")

  for i, image in ipairs(collection) do
    checkImage(image)
  end
end

local function scan(global_scan)

  dt.print(log.info, "Start scan")

  images_to_scan_count = 0
  scanned_images_count = 0
  missing_images_count = 0

  missing_images_finder.missing_images_count_label.label = missing_images_count

  missing_images_finder.scan_collection_button.sensitive = false
  missing_images_finder.scan_global_button.sensitive = false

  if global_scan then
    for _, filmroll in ipairs(dt.films) do
      images_to_scan_count = images_to_scan_count + #filmroll
    end

    for _, filmroll in ipairs(dt.films) do
      scanFilm(filmroll)
    end
  else
    images_to_scan_count = #dt.collection
    scanCollection(dt.collection)
  end

  log.msg(log.info, "scan done")
  dt.print(log.info, "Scan done - missing images found: " .. missing_images_count)

  missing_images_finder.scan_collection_button.sensitive = true
  missing_images_finder.scan_global_button.sensitive = true
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- U S E R  I N T E R F A C E (CALLING FUNCTIONS)
-- - - - - - - - - - - - - - - - - - - - - - - -

missing_images_finder.scan_collection_button.clicked_callback =
    function(this)
      scan(false)
    end

missing_images_finder.scan_global_button.clicked_callback =
    function(this)
      scan(true)
    end

missing_images_finder.main_widget =
    dt.new_widget("box") {
      orientation = "vertical",
      dt.new_widget("section_label") { label = _("start scan") },
      dt.new_widget("box") {
        orientation = "horizontal",
        missing_images_finder.scan_collection_button,
        missing_images_finder.scan_global_button
      },
      dt.new_widget("section_label") { label = _("status") },
      dt.new_widget("box") {
        orientation = "horizontal",
        dt.new_widget("label") {
          ellipsize = "middle",
          halign = "start",
          label = "progress"
        },
        missing_images_finder.progress_images_count
      },
      dt.new_widget("box") {
        orientation = "horizontal",
        dt.new_widget("label") {
          ellipsize = "middle",
          halign = "start",
          label = "progress %"
        },
        missing_images_finder.progress_perc_label
      },
      dt.new_widget("box") {
        orientation = "horizontal",
        dt.new_widget("label") {
          ellipsize = "middle",
          halign = "start",
          label = "missing images"
        },
        missing_images_finder.missing_images_count_label
      }
    }

local function install_module()
  if not namespace.module_installed then
    dt.register_lib(
      MODULE,                                                                      -- Module name
      _("missing images finder"),                                                  -- Visible name
      true,                                                                        -- expandable
      true,                                                                        -- resetable
      { [dt.gui.views.lighttable] = { "DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 0 } }, -- containers
      missing_images_finder.main_widget,
      nil,                                                                         -- view_enter
      nil                                                                          -- view_leave
    )
    namespace.module_installed = true
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

if dt.gui.current_view().id == "lighttable" then
  log.msg(log.info, namespace.module_installed)
  install_module()
else
  if not namespace.event_registered then
    dt.register_event(MODULE, "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
        end
      end
    )
    namespace.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
