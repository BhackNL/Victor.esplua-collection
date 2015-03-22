-- Compile ds18b20
compiled=false
for n,s in pairs(file.list()) do
     if n == "ds18b20.lc" then
          compiled = true
     end
end

if not compiled then node.compile("ds18b20.lua") end
require('ds18b20')
ds18b20.setup(4)

-- Variables
INTERVAL = 60000 -- milliseconds

-- MQTT init
BROKER = "192.168.1.20"
BRPORT = 1883
BRUSER = "user"
BRPWD  = "pwd"
CLIENTID = "ESP8266-" ..  node.chipid()

----------------------------------------------------------------------------------------
-- Data collection
-- temperature, heapsize and ip adres 
----------------------------------------------------------------------------------------
function collect()
     print("collecting data")
     temp=ds18b20.read()
     if temp < 50 then
          -- Skip false readings
          -- TODO: replace with sliding avarage
          coroutine.resume(publisher, "sensors/".. CLIENTID .. "/temp", ds18b20.read())
     end
     coroutine.resume(publisher, "sensors/".. CLIENTID .. "/heap", node.heap())
     coroutine.resume(publisher, "sensors/".. CLIENTID .. "/ip", wifi.sta.getip())
end

----------------------------------------------------------------------------------------
-- MQTT client
-- Last will and testament setup 
-- Initialization on connect --> subscribe --> start data collection 
----------------------------------------------------------------------------------------
m = mqtt.Client( CLIENTID, 10, BRUSER, BRPWD)
m:lwt("sensors/".. CLIENTID .. "/state", "OFF", 0, 0)
m:on("connect", function(con)
   m:subscribe("sensors/".. CLIENTID .. "/command",0, function(conn) 
     print("mqtt: connected")
     print("mqtt: subscribed to /command") 
     coroutine.resume(publisher)
     tmr.alarm(1, 1000, 1, function()
       coroutine.resume(publisher, "CHECK")
     end)
     coroutine.resume(publisher, "sensors/".. CLIENTID .. "/state", "ON")
     -----------------------------------------------------------------------------------
     -- Data collection at now and INTERVAL
     -----------------------------------------------------------------------------------
     collect()
     tmr.alarm(2, INTERVAL, 1, collect)
   end)
end)

----------------------------------------------------------------------------------------
-- MQTT Offline 
----------------------------------------------------------------------------------------
m:on("offline", function(con) 
     node.restart()
end)

----------------------------------------------------------------------------------------
-- MQTT Command channel
----------------------------------------------------------------------------------------
m:on("message", function(conn, topic, data) 
  print("mqtt: received ".. data ) 
  if data ~= nil then
    if data == 'restart' then node.restart() end
    if data == 'collect' then collect() end
  end
end)

----------------------------------------------------------------------------------------
-- Workaround for MQTT not having queues leading to overlapping sends :-(
-- https://github.com/nodemcu/nodemcu-firmware/issues/146
----------------------------------------------------------------------------------------
publisher = coroutine.create(
  function()
    -- define timeout to 6 seconds
    local timeout = 6000000

    -- reference the current coroutine
    local self = coroutine.running()

    -- create a queue
    local queue = {}

   -- init status to OK
   local status = "OK"

   -- init start_time to now
   local start_time = tmr.now()

    -- main loop
    while true do
      -- wait for status while accepting new items
      repeat
        value1, value2 = coroutine.yield()

        if value2 == nil then  -- status
          if value1 == "CHECK" then
            if #queue > 0 and tmr.now() - start_time > timeout then
              status = "TIMEOUT"
            end
          else
            status = value1
          end
        else  -- topic + message
          table.insert(queue, {value1, value2})
        end
      until status ~= "PENDING"

      -- consume the queue
      item = table.remove(queue)
      if item ~= nil then
        local topic, message = unpack(item)
        start_time = tmr.now()
        status = "PENDING"

        -- publish and set status to OK in callback
        print("sending:" .. message)
        m:publish(topic, message, 0, 0, function(conn)
          coroutine.resume(self, "OK")
        end)
      end
    end
  end
)

----------------------------------------------------------------------------------------
-- Connect to MQTT broker and start data collection when connected to wireless network
----------------------------------------------------------------------------------------
function connect()
  tries = tries + 1
  wifi_ip = wifi.sta.getip()
  if wifi_ip == nil then
    if tries < 5 then
      tmr.alarm(0, 1000, 0, connect)
    else
      tmr.delay(10000000)
      print("restarting: no valid IP")
      node.restart()
    end
  else
     m:connect(BROKER , BRPORT, 0)
  end
end

tries = 0
connect()
