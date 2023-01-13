local log = require "log"
local capabilities = require "st.capabilities"
local swann = require "swann"
local utils = require "st.utils"
local Listener = require "listener"
local command_handlers = {}

-- callback to handle an `on` capability command
function command_handlers.push(driver, device, command)
  log.debug(string.format("[%s] create rooms button pressed", device.device_network_id))
  local listener = Listener.create_device_event_listener(driver, device)
  device:set_field("listener", listener)
  listener:start()
  listener:send_msg("abc123")
end

return command_handlers