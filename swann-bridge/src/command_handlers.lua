local log = require "log"
local capabilities = require "st.capabilities"
local wiser = require "wiser"
local utils = require "st.utils"
local command_handlers = {}

-- callback to handle an `on` capability command
function command_handlers.push(driver, device, command)
  log.debug(string.format("[%s] create rooms button pressed", device.device_network_id))
  wiser.createRooms(driver,device,payload)
  wiser.refreshRooms(driver,device)
end

return command_handlers