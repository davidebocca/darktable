local dt = require "darktable"
local log = require "lib/dtutils.log"

local DEFAULT_LOG_LEVEL <const> = log.info
local MISSING_IMAGES_TAG = "missing-images"

log.log_level(DEFAULT_LOG_LEVEL)

local script_data = {}

local function destroy()

end

script_data.destroy = destroy

local function scan()
  local film = dt.collection[1].film

  log.msg(log.info, "checking folder " .. film.path)

  for i = 1, #film do
    local image = film[i]

    log.msg(log.info, image)

    dt.tags.attach(MISSING_IMAGES_TAG, image)

    local image_tags = dt.tags.get_tags(image)

    for _, v in pairs(image_tags) do
      log.msg(log.info, v)
    end
  end

  -- for _, el in ipairs(dt.films) do
  --   -- log.msg(log.info,el)
  --   dt.print_log(el.path)
  -- end
end

scan()

return script_data
