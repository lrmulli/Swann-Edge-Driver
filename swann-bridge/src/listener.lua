local log = require "log"
local xml2lua = require "xml2lua"
local xml_handler = require "xmlhandler.tree"
local socket = require "cosock.socket"
local Config = require"lustre".Config
local ws = require"lustre".WebSocket
local CloseCode = require"lustre.frame.close".CloseCode
local capabilities = require "st.capabilities"
local utils = require "st.utils"
local harmony_utils = require "utils"
local MAX_RECONNECT_ATTEMPTS = 10
local RECONNECT_PERIOD = 120 -- 2 min

local Listener = {}
Listener.__index = Listener
Listener.WS_PORT = 8088

local function is_empty(t)
  -- empty tables should be nil instead
  return not t or (type(t) == "table" and #t == 0)
end

function Listener:try_reconnect()
    local retries = 0
    local ip = self.device:get_field("ip")


    if not ip then
      log.warn(string.format("[%s](%s) Cannot reconnect because no device ip",
                             harmony_utils.get_serial_number(self.device), self.device.label))
      return
    end
    log.info(string.format("[%s](%s) Attempting to reconnect websocket for speaker at %s",
                           harmony_utils.get_serial_number(self.device), self.device.label, ip))
    while retries < MAX_RECONNECT_ATTEMPTS do
      if self:start() then
       -- self.driver:inject_capability_command(self.device,
       --                                       { capability = capabilities.refresh.ID,
       --                                         command = capabilities.refresh.commands.refresh.NAME,
       --                                         args = {}
       --                                       })
        return
      end
      retries = retries + 1
      log.info(string.format("Retry reconnect in %s seconds", RECONNECT_PERIOD))
      socket.sleep(RECONNECT_PERIOD)
    end
    log.warn(string.format("[%s](%s) failed to reconnect websocket for device events",
                           harmony_utils.get_serial_number(self.device), self.device.label))
  end
  
  --- @return success boolean
  function Listener:start()
    local url = "/"
    local sock, err = socket.tcp()
    local ip = self.device:get_field("ip")
    local hubId = self.device:get_field("harmony_hub_id")
    log.info(string.format("IP Address: %s", ip))
    log.info(string.format("Hub Id: %s", hubId))
    local hub_path = "/?domain=svcs.myharmony.com&hubId="..hubId
    log.info(string.format("Path: %s", hub_path))
    local serial_number = harmony_utils.get_serial_number(self.device)
    if not ip then
      log.error("failed to get ip address for device")
      return false
    end
    log.info(string.format("[%s](%s) Starting websocket listening client on %s:%s",
                           harmony_utils.get_serial_number(self.device), self.device.label, ip, url))
    if err then
      log.error(string.format("failed to get tcp socket: %s", err))
      return false
    end
    sock:settimeout(3)
    local config = Config.default():protocol("sync"):keep_alive(30)
    local websocket = ws.client(sock, hub_path, config)
    websocket:register_message_cb(function(msg)
      self:handle_msg_event(msg.data)
      --log.debug(string.format("(%s:%s) Websocket message: %s", self.device.device_network_id, ip, utils.stringify_table(event, nil, true)))
    end):register_error_cb(function(err)
      -- TODO some muxing on the error conditions
      log.error(string.format("[%s](%s) Websocket error: %s", serial_number,
                              self.device.label, err))
      if err and (err:match("closed") or err:match("no response to keep alive ping commands")) then
        self.device:offline()
        self:try_reconnect()
      end
    end)
    websocket:register_close_cb(function(reason)
      log.info(string.format("[%s](%s) Websocket closed: %s", serial_number,
                             self.device.label, reason))
      self.websocket = nil -- TODO make sure it is set to nil correctly
      if not self._stopped then self:try_reconnect() end
    end)
    log.info(string.format("[%s](%s) Connecting websocket to %s", serial_number,
                           self.device.label, ip))
    local success, err = websocket:connect(ip, Listener.WS_PORT)
    if err then
      log.error(string.format("failed to connect websocket: %s", err))
      return false
    end
    self._stopped = false
    self.websocket = websocket
    self.device:online()
    return true
  end
  
  function Listener.create_device_event_listener(driver, device)
    return setmetatable({device = device, driver = driver, _stopped = true}, Listener)
  end
  
  function Listener:stop()
    self._stopped = true
    if not self.websocket then
      log.warn(string.format("[%s](%s) no websocket exists to close", harmony_utils.get_serial_number(self.device),
                             self.device.label))
      return
    end
    local suc, err = self.websocket:close(CloseCode.normal())
    if not suc then
      log.error(string.format("[%s](%s) failed to close websocket: %s", harmony_utils.get_serial_number(self.device),
                              self.device.label, err))
    end
  end
  
  function Listener:send_msg(msg)
    self.websocket.send_text(msg)
  end

  function Listener:handle_msg_event(msg)
    log.info(string.format("Msg Recd: %s", msg))
  end


  return Listener