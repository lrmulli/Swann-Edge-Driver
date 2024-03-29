-- require st provided libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"
local socket = require'socket'
local json = require "dkjson"
local cosock = require "cosock"
local http = cosock.asyncify "socket.http"
local utils = require "st.utils"
local Listener = require "listener"
local harmony_utils = require "utils"
ltn12 = require("ltn12")


-- require custom handlers from driver package
local command_handlers = require "command_handlers"
local swann = require "swann"
local discovery = require "discovery"

-----------------------------------------------------------------
-- local functions
-----------------------------------------------------------------
-- this is called once a device is added by the cloud and synchronized down to the hub
local function device_added(driver, device)
  log.info("[" .. device.id .. "] Adding new Swann device")

  -- set a default or queried state for each capability attribute
  device:emit_event(capabilities.switch.switch.on())
end

-- this is called both when a device is added (but after `added`) and after a hub reboots.
local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing Swann device")

  -- mark device as online so it can be controlled from the app
  device:online()
  if (device:component_exists("bridgelogger")) then --this means that it is a wiser bridge
    --driver:call_on_schedule(60, function () poll(driver,device) end, 'POLLING')
  end
  local listener = Listener.create_device_event_listener(driver, device)
  device:set_field("listener", listener)
  listener:start()
end

-- this is called when a device is removed by the cloud and synchronized down to the hub
local function device_removed(driver, device)
  log.info("[" .. device.id .. "] Removing Swann device")
end

-- this is called when a device setting is changed
local function device_info_changed(driver, device, event, args)
      if args.old_st_store.preferences.deviceaddr ~= device.preferences.deviceaddr then
        log.info("device address preference changed - "..device.preferences.deviceaddr)
        device:set_field("ip", device.preferences.deviceaddr)
        local hid = harmony_utils.getHarmonyHubId(device,device.preferences.deviceaddr)
      end
  end


function poll(driver,device)
  log.info("Polling for updates")
  if device.preferences.deviceaddr ~= "192.168.1.n" then
    --we have an ip address
    --wiser.refreshRooms(driver,device)
  end
end
-- create the driver object
local swann_driver = Driver("org.mullineux.swannbridge.v1", {
  discovery = discovery.handle_discovery,
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    removed = device_removed,
    infoChanged = device_info_changed
  },
  capability_handlers = {
    [capabilities.momentary.ID] = {
      [capabilities.momentary.commands.push.NAME] = command_handlers.push
    },
  }
})

-- run the driver
swann_driver:run()
