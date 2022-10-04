-- require st provided libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"
local socket = require'socket'
local json = require "dkjson"
local cosock = require "cosock"
local http = cosock.asyncify "socket.http"
local utils = require "st.utils"
ltn12 = require("ltn12")


-- require custom handlers from driver package
local command_handlers = require "command_handlers"
local wiser = require "wiser"
local discovery = require "discovery"

-----------------------------------------------------------------
-- local functions
-----------------------------------------------------------------
-- this is called once a device is added by the cloud and synchronized down to the hub
local function device_added(driver, device)
  log.info("[" .. device.id .. "] Adding new Wiser device")

  -- set a default or queried state for each capability attribute
  device:emit_event(capabilities.switch.switch.on())
end

-- this is called both when a device is added (but after `added`) and after a hub reboots.
local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing Wiser device")

  -- mark device as online so it can be controlled from the app
  device:online()
  if (device:component_exists("bridgelogger")) then --this means that it is a wiser bridge
    driver:call_on_schedule(60, function () poll(driver,device) end, 'POLLING')
  end
end

-- this is called when a device is removed by the cloud and synchronized down to the hub
local function device_removed(driver, device)
  log.info("[" .. device.id .. "] Removing Wiser device")
end

-- this is called when a device setting is changed
local function device_info_changed(driver, device, event, args)
      if args.old_st_store.preferences.deviceaddr ~= device.preferences.deviceaddr then
        log.info("Wiser device address preference changed - "..device.preferences.deviceaddr)
      end
      if args.old_st_store.preferences.secret ~= device.preferences.secret then
        log.info("Wiser secret preference changed - "..device.preferences.secret)
      end
  end


function poll(driver,device)
  log.info("Polling for updates")
  if device.preferences.deviceaddr ~= "192.168.1.n" then
    --we have an ip address
    wiser.refreshRooms(driver,device)
  end
end
-- create the driver object
local wiser_driver = Driver("org.mullineux.wiserbridge.v1", {
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
  },
  sub_drivers = { require("room")}
})

-- run the driver
wiser_driver:run()
