--- Made By Jayson, Update Date : 2020.12.7---

_app = {name="ESPHome", version="1.0.1"}

local url = ""
local http = net.HTTPClient({timeout=10000})
local device = {}
local domain = {}
local id = {}
local state = {}
local installedDevice = {}

local ESPHomeType = {
sensor = {ftype="com.fibaro.multilevelSensor",class="ESPHome_MultilevelSensor"},
binary_sensor = {ftype="com.fibaro.binarySensor",class="ESPHome_BinarySensor"},
binary_switch = {ftype="com.fibaro.binarySwitch",class="ESPHome_BinarySwitch"},
light = {ftype="com.fibaro.binarySwitch",class="ESPHome_Light"},
-- light = {ftype="com.fibaro.colorController",class="ESPHome_Light"},
fan = {ftype="com.fibaro.binarySwitch",class="ESPHome_Fan"},
}

function searchFType(type)
    for t, i in pairs(ESPHomeType) do if t == type then return i.ftype end end
    return nil
end
function searchEType(type)
    for t, i in pairs(ESPHomeType) do if t == type then return i.class end end
    return nil
end

function receivedData(response)
    local res = response.data
    for i, v in pairs(splitString(res, "data:")) do
        if (string.find(v, "{")) ~= nil then
            recievedData = json.decode(v)
            if not contains(device, recievedData.id) then
                table.insert(device, recievedData.id)
                for i, v in pairs(splitString(recievedData.id, "-")) do
                    if i == 1 then table.insert(domain, v)
                    elseif i == 2 then table.insert(id, v)
                    end
                end
                table.insert(state, recievedData.state)
            else
                for i, v in pairs(device) do
                    if v == recievedData.id then state[i] = recievedData.state end
                end
            end
        end
    end
end

function get(url, cont)
    http:request(url, {
        options={ method = 'GET'},
        success = function(response) receivedData(response) end,
        error = function(err) print("error:",err) end
    })
end

function post(url, state)
    http:request(url, {
        options={ method = 'POST'},
        success = function(res) if state == "turn_on" then print("Turned On") else print("Turned Off") end end,
        error = function(err) print("error:",err) end
    })
end

function getStates(url)
    local eventUrl = url .. "/events"
    get(eventUrl)
end

function QuickApp:onInit()
    self:debug(string.format("%s ( %s ) ESPHome Connector onInit", _app.name, self.id, _app.version))
    self.ip = self:getVariable("ip")
    self.port = self:getVariable("port")
    url = "http://" .. self.ip .. ":" .. self.port
    self:debug(string.format("%s ESPHome device URL is %s ",_app.name, url))

    getStates(url)
    self:initChildDevices({
        ["com.fibaro.binarySwitch"] = ESPHome_BinarySwitch,
        ["com.fibaro.multilevelSensor"] = ESPHome_MultilevelSensor,
        ["com.fibaro.binarySensor"] = ESPHome_BinarySensor
    })
    
    self:debug("Child devices:")
    for id,device in pairs(self.childDevices) do
        self:debug("[", id, "]", device.name, ", type of: ", device.type)
        table.insert(installedDevice, device.name)
    end
end

function QuickApp:btnLoadClicked()
    self:debug(json.encode(domain))
    self:debug(json.encode(id))
    self:debug(json.encode(state))
    self:debug("ESPHome Device is Loaded")
end

function QuickApp:btnInstallClicked()
    local devNumber = #domain
    for i=1, tonumber(devNumber), 1 do
        self:createESPHome(i, domain[i], id[i], state[i])
    end
    self:debug("ESPHome Device has been installed")
end

function QuickApp:btnRemoveClicked()
    for id,device in pairs(self.childDevices) do
        self:removeChildDevice(id)
    end
    installedDevice = {}
    self:debug("ESPHome Device has been removed")
end

function QuickApp:createESPHome(childNo, d, i, s)
    local c = {}
    c.name = i
    c.type = searchFType(d)
    if d == 'sensor' then
        for i,v in pairs(splitString(s, " ")) do
            if i == 1 then c.value = tonumber(v)
            elseif i == 2 then c.unit = v end
        end
    else
        if s == "ON" then c.value = true elseif s == "OFF" then c.value = false else c.value = s end
    end
    local property ={ 
        userDescription = childNo,
        unit = c.unit
    }
    c.initialProperties = property
    deviceClass = searchEType(d)
    if not contains(installedDevice, c.name) then local child = self:createChildDevice(c, _G[deviceClass]) table.insert(installedDevice, c.name)
    else self:debug(string.format("Device ( %s ) is already installed", c.name)) end
end

--------------------- ESPHome ---------------------
class 'ESPHome' (QuickAppChild)
function ESPHome:__init(device)
    QuickAppChild.__init(self, device)
    self.childNo = fibaro.getValue(self.id, "userDescription")
    self.value = fibaro.getValue(self.id, "value")
    self:setValue()
end

function ESPHome:setValue()
    if domain[self.childNo] == 'sensor' then
        for i,v in pairs(splitString(state[self.childNo], " ")) do
            if i == 1 then self.updatedValue = tonumber(v) end
        end
    else
        if state[self.childNo] == "ON" then self.updatedValue = true
        elseif state[self.childNo] == "OFF" then self.updatedValue = false end
    end
    if self.value ~= self.updatedValue then self.value = self.updatedValue end
    self:update(self.value)
    fibaro.setTimeout(1000,function() self:setValue() end)
end

function ESPHome:update(value) self:updateProperty("value", value) end

--------------------- ESPHome BinarySwitch ---------------------
class 'ESPHome_BinarySwitch' (ESPHome)
function ESPHome_BinarySwitch:__init(device)  ESPHome.__init(self, device) end

function ESPHome_BinarySwitch:turnOn()
    local deviceDomain = domain[self.childNo]
    local deviceName = id[self.childNo]
    self.turnOnUrl = url .. "/" .. deviceDomain .. "/" .. deviceName .. "/turn_on"
    post(self.turnOnUrl, "turn_on")
end

function ESPHome_BinarySwitch:turnOff()
    local deviceDomain = domain[self.childNo]
    local deviceName = id[self.childNo]
    self.turnOffUrl = url .. "/" .. deviceDomain .. "/" .. deviceName .. "/turn_off"
    post(self.turnOffUrl, "turn_off")
end
--------------------- ESPHome Fan ---------------------

class 'ESPHome_Fan' (ESPHome_BinarySwitch)
function ESPHome_Fan:__init(device)  ESPHome_BinarySwitch.__init(self, device) end

--------------------- ESPHome Light ---------------------
class 'ESPHome_Light' (ESPHome_BinarySwitch)
function ESPHome_Light:__init(device)  ESPHome_BinarySwitch.__init(self, device) end

--------------------- ESPHome Binary Sensor ---------------------
class 'ESPHome_BinarySensor' (ESPHome)
function ESPHome_BinarySensor:__init(device)  ESPHome.__init(self, device) end

--------------------- ESPHome Multilevel Sensor ---------------------
class 'ESPHome_MultilevelSensor' (ESPHome)
function ESPHome_MultilevelSensor:__init(device)  ESPHome.__init(self, device) end
