# esplua-collection
mqtt oriented ESP8266 lua scripts

## Installation
* Flash nodemcu firmware
* Setup a mqtt broker (mosquitto)
* set ip adress of broker in the code
* Upload with ESPlorer


## Use
* Monitor data
  mosquitto_sub -h <broker name> -v -t sensors/#

* restart esp remote
  mosquitto_pub -h <broker name> -t sensors/ESP8266-<clientid>/command -m "restart"


## Next steps
Install another great product wich lets you program actions visualy around mqtt and other sources.
- http://nodered.org/
Store data in influxdb
- http://influxdb.com/
Create charts with grafana
- http://grafana.org/
