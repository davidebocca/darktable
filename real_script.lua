local dt = require "darktable"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"

local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"
local DEFAULT_LOG_LEVEL <const> = log.info

local MISSING_IMAGES_TAG = dt.tags.create("missing-images")

log.log_level(DEFAULT_LOG_LEVEL)

local script_data = {}

local images_to_scan_count = 0
local scanned_images_count = 0
local missing_images_count = 0
local update_perc_images_count = 100

local function destroy()
  --do nothing
end

script_data.destroy = destroy

local function checkImage(image)
  scanned_images_count = scanned_images_count + 1

  dt.tags.detach(MISSING_IMAGES_TAG, image)

  if not df.check_if_file_exists(image.path .. PS .. image.filename) then
    missing_images_count = missing_images_count + 1

    log.msg(log.info, image.path .. PS .. image.filename .. " is missing")
    dt.tags.attach(MISSING_IMAGES_TAG, image)
  end
  local current_perc = string.format("%.1f %%", scanned_images_count / images_to_scan_count * 100)

  if scanned_images_count % update_perc_images_count == 0 then
    dt.print(log.info,
      "Scanned " .. scanned_images_count .. " images of " .. images_to_scan_count .. " (" .. current_perc .. ")")
  end
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
  images_to_scan_count = 0
  scanned_images_count = 0
  missing_images_count = 0

  if global_scan then
    for _, filmroll in ipairs(dt.films) do
      images_to_scan_count = images_to_scan_count + #filmroll
    end

    dt.print(log.info, "Start global scan of " .. images_to_scan_count .. " images")

    for _, filmroll in ipairs(dt.films) do
      scanFilm(filmroll)
    end
  else
    images_to_scan_count = #dt.collection
    dt.print(log.info, "Start scanning " .. images_to_scan_count .. " images")

    scanCollection(dt.collection)
  end

  log.msg(log.info, "scan done")
  dt.print(log.info, "Scan done - missing images found: " .. missing_images_count)
end

scan(false)

return script_data
