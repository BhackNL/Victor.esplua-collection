print("Space init")
print("- Filelist -------------")
l = file.list();
for k,v in pairs(l) do
print("name:"..k..", size:"..v)
end
-- reset lEDbar
-- gpio.ws2812(string.char(0,0,0):rep(62))

cnt=0
-- Wait 10 seconds before starting autorun.lua
-- Give some time to re-program ;-)
tmr.alarm(1,10000,1,function()
     print "Start autorun"
     tmr.stop(1)
     compiled=false
     file.remove("autorun.lc")
     node.compile("autorun.lua")
     dofile("autorun.lc")
end)
