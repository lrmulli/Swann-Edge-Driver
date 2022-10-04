local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"
local utils = require "st.utils"
local room_command_handlers = require "room_command_handlers"


local room_handler = {
NAME = "RoomHandler",
  capability_handlers = {
    [capabilities.switch.ID] = {
        [capabilities.switch.commands.on.NAME] = room_command_handlers.switch_on,
        [capabilities.switch.commands.off.NAME] = room_command_handlers.switch_off,
        }
    },
  can_handle = function(opts, driver, device, ...)
    return device:component_exists("roomlogger")
  end,
}

return room_handler