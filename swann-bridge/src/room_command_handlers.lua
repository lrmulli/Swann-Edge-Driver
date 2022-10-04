local log = require "log"
local capabilities = require "st.capabilities"
local utils = require "st.utils"
local room_command_handlers = {}
local logger = capabilities["universevoice35900.log"]

-- callback to handle an `on` capability command
function room_command_handlers.switch_on(driver, device, command)
    log.debug(string.format("[%s] calling set_power(on)", device.device_network_id))
    device:emit_event(capabilities.switch.switch.on())
  end
  
  -- callback to handle an `off` capability command
  function room_command_handlers.switch_off(driver, device, command)
    log.debug(string.format("[%s] calling set_power(off)", device.device_network_id))
    device:emit_event(capabilities.switch.switch.off())
  end

  function room_command_handlers.processUpdate(driver, device, update)
    log.debug(string.format("[%s] processing update message", device.device_network_id))
    if (device.preferences.verboserecdlog == true) then
        device:emit_component_event(device.profile.components.roomlogger,logger.logger(utils.stringify_table(update,"Room Update Message: ",true)))
    end
    log.info(utils.stringify_table(update,"Room Update Message: ",true))
    --set current temperature
    local temp = {value = update.CalculatedTemperature / 10, unit = "C"}
    device:emit_event(capabilities.temperatureMeasurement.temperature(temp))
    --set set point temperature
    local setpoint = {value = update.CurrentSetPoint / 10, unit = "C"}
    device:emit_component_event(device.profile.components.thermostatsetpoint,capabilities.thermostatHeatingSetpoint.heatingSetpoint(setpoint))
  end
  function room_command_handlers.processUpdateRoomStat(driver, device, update)
    log.debug(string.format("[%s] processing update message", device.device_network_id))
    if (device.preferences.verboserecdlog == true) then
        device:emit_component_event(device.profile.components.roomlogger,logger.logger(utils.stringify_table(update,"Room Update Message: ",true)))
    end
    log.info(utils.stringify_table(update,"Room Update Message: ",true))
    if (device:component_exists("relativehumidity") ~= true) then
      --this device has the wrong profile - lets try to fix it
      log.debug("Changing device profile")
      device:try_update_metadata({profile = "wiser-bridge.room_with_stat.v1"})
    end
    local humidity = {value = update.MeasuredHumidity, unit = "%"}
    device:emit_component_event(device.profile.components.relativehumidity,capabilities.relativeHumidityMeasurement.humidity(humidity))

  end

return room_command_handlers