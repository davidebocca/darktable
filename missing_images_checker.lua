local dt = require "darktable"
local du = require "lib/dtutils"
local log = require "lib/dtutils.log"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "missing_images_checker"

local DEFAULT_LOG_LEVEL <const> = log.debug
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

du.check_min_api_version("9.4.0", MODULE)

-- translation facilities

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

local script_data = {}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

script_data.metadata = {
  name = _("missing image checker"),
  purpose = _("tool used to check which images in database are missing on actual disk"),
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

local missing_images_checker = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

missing_images_checker.main_widget = nil

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = missing_images_checker

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
  dt.gui.libs[MODULE].visible = false

  if namespace.event_registered then
    dt.destroy_event(MODULE, "view-changed")
  end
end

local function restart()
  dt.gui.libs[MODULE].visible = true
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function scan()
  dt.print(_("button clicked"))
end

missing_images_checker.scan_button = dt.new_widget("box") -- widget
{
  orientation = "vertical",
  dt.new_widget("button"){
    label = _("scan"),
    clicked_callback = function (this)
      scan()
    end
  }
};

local function install_module()
  if not namespace.module_installed then
    dt.register_lib(
      MODULE,     -- Module name
      _("mssing images cecker"),     -- Visible name
      true,                -- expandable
      true,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 0}},   -- containers
      missing_images_checker.scan_button,
      nil,-- view_enter
      nil -- view_leave
    )
    namespace.module_installed = true
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

missing_images_checker.main_widget = missing_images_checker.scan_button

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

if dt.gui.current_view().id == "lighttable" then
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
