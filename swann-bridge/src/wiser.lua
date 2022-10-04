local log = require "log"
local capabilities = require "st.capabilities"
local socket = require'socket'
local json = require "dkjson"
local cosock = require "cosock"
local http = cosock.asyncify "socket.http"
ltn12 = require("ltn12")
local utils = require "st.utils"
local wiser = {}
local room_command_handlers = require "room_command_handlers"

-- callback to handle an `on` capability command
function wiser.makeApiGetCall(driver,device,path)
  local url = "http://"..device.preferences.deviceaddr..path
  local secret = device.preferences.secret
  log.debug("Making API Call to ",url)
  local respbody = {} -- for the response body
  http.TIMEOUT = 50;
  log.info("Sending request...")

  local result, respcode, respheaders, respstatus = http.request {
    method = "GET",
    url = url,
    headers = {
        ["Secret"] = secret
    },
    sink = ltn12.sink.table(respbody)
    }
  -- get body as string by concatenating table filled by sink
  respbody = table.concat(respbody)
  log.debug("Response Body "..respbody)
  print(result,respcode,respstatus)
  return respbody
end
function wiser.createRooms(driver,device)
  local payload = wiser.makeApiGetCall(driver,device,"/data/domain/")
  local wiserdata = json.decode(payload)
  if wiserdata.Room ~= nil then
    --the room object is not empty
    for _, r in ipairs(wiserdata.Room) do
      if(r.CalculatedTemperature == -32768) then
        log.debug("Not Processing Room: "..r.Name.." Invalid Temperature")
      else
        log.debug("Processing Room: "..r.Name)
        local dni = "WiserRoom_"..r.id
        local metadata = {
          type = "LAN",
          -- the DNI must be unique across your hub, using static ID here so that we
          -- only ever have a single instance of this "device"
          device_network_id = dni,
          label = "Wiser Room: "..r.Name,
          profile = "wiser-bridge.room.v1",
          manufacturer = "Wiser",
          model = "Wiser Room",
          vendor_provided_label = "room_"..r.id,
          parent_device_id = device.id
        }
        --make some rooms
        driver:try_create_device(metadata)
      end
    end
  end
end
function wiser.refreshRooms(driver,device)
  local payload = wiser.makeApiGetCall(driver,device,"/data/domain/")
  local wiserdata = json.decode(payload)
  if wiserdata.Room ~= nil then
    --the room object is not empty
    for _, r in ipairs(wiserdata.Room) do
      if(r.CalculatedTemperature == -32768) then
        log.debug("Not Processing Room: "..r.Name.." Invalid Temperature")
      else
        log.debug("Processing Room: "..r.Name)
        local device_list = driver:get_devices()
        for _, d in ipairs(device_list) do
          if (d.parent_device_id == device.id and d:component_exists("roomlogger")) then
              --this is a child device, that is a room
              local label_identifier = "room_"..r.id
              if (label_identifier == d.vendor_provided_label) then
                --this is the correct room
                if r.RoomStatId ~= nil then
                  log.info(r.Name.." has a roomstat")
                  for _, rs in ipairs(wiserdata.RoomStat) do
                    if r.RoomStatId == rs.id then
                      log.info("Matching Roomstat Found: "..utils.stringify_table(rs,"Roomstat: ",true))
                      room_command_handlers.processUpdateRoomStat(driver, d,rs)
                    end
                  end
                end
                room_command_handlers.processUpdate(driver, d, r)
              end
          end
        end
      end
    end
  end
end


return wiser