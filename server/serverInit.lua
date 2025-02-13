kjxmlData = {}
local systemOS = nil

local function parseObjSet(data, fileName)
    local xml = SLAXML:dom(data)

    if xml and xml.root and xml.root.name == 'vcfroot' then ParseVCF(xml, fileName) end
end

local function checkForUpdate()
    local versionFile = LoadResourceFile(GetCurrentResourceName(), 'version.json')

    if not versionFile then
        print("Couldn't read version file!")
        return
    end

    local currentVersion = Semver(json.decode(versionFile)['version'] or 'unknown')

    if currentVersion.prerelease then
        print('WARNING: you are using a pre-release of MISS ELS!')
        print('>> This version might be unstable and probably contains some bugs.')
        print('>> Please report bugs and other problems via https://github.com/matsn0w/MISS-ELS/issues')
    end

    PerformHttpRequest('https://api.github.com/repos/matsn0w/MISS-ELS/releases/latest', function(status, response, headers)
        if status ~= 200 then
            print("Something went wrong! Couldn't fetch latest version. Status: " .. tostring(status))
            return
        end

        local newVersion = Semver(json.decode(response)['tag_name'] or 'unknown')

        if newVersion > currentVersion then
            print('---------------------------- MISS ELS ----------------------------')
            print('--------------------- NEW VERSION AVAILABLE! ---------------------')
            print('>> You are using v' .. tostring(currentVersion))
            print('>> You can upgrade to v' .. tostring(newVersion))
            print()
            print('Download it at https://github.com/matsn0w/MISS-ELS/releases/latest')
            print('------------------------------------------------------------------')
        end
    end)
end

local function determineOS()
    local osType = GetConvar("os_type", "")
    
    if osType and osType ~= "" then
        return osType
    end
    
    if os.getenv("HOME") then return "unix" end
    if os.getenv("HOMEPATH") then return "windows" end

    if package and package.config and package.config:sub(1,1) == "\\" then
        return "windows"
    else
        return "unix"
    end

    error("Couldn't determine your OS! Please report this issue.")
end

local function scanDir(folder)
    local pathSeparator = '/'
    local command = 'ls -A'

    if systemOS == 'windows' then
        pathSeparator = '\\'
        command = 'dir /R /B'
    end

    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local directory = resourcePath .. pathSeparator .. folder
    local i, t, popen = 0, {}, io.popen
    local pfile = popen(command .. ' "' .. directory .. '"')

    for filename in pfile:lines() do
        i = i + 1
        t[i] = filename
    end

    if #t == 0 then
        error("Couldn't find any VCF files. Are they in the correct directory?")
    end

    pfile:close()
    return t
end

local function loadFile(file)
    return LoadResourceFile(GetCurrentResourceName(), file)
end

AddEventHandler('onResourceStart', function(name)
    if not Config then
        error('You probably forgot to copy the example configuration file. Please see the installation instructions for further details.')
        StopResource(GetCurrentResourceName())
        CancelEvent()
        return
    end

    if name:lower() ~= GetCurrentResourceName():lower() then
        CancelEvent()
        return
    end

    Citizen.CreateThread(function()
        checkForUpdate()
    end)

    local folder = 'xmlFiles'

    -- Bepaal het besturingssysteem van de server
    systemOS = determineOS()

    if not systemOS then
        error("Couldn't determine your OS! Please report this issue.")
    end

    for _, file in pairs(scanDir(folder)) do
        local data = loadFile(folder .. '/' .. file)

        if data then
            if pcall(function() parseObjSet(data, file) end) then
                print('Parsed VCF for: ' .. file)
            else
                print('VCF file ' .. file .. ' could not be parsed: is your XML valid?')
            end
        else
            print('VCF file ' .. file .. ' not found: does the file exist?')
        end
    end

    -- Stuur de ELS-data naar alle clients
    TriggerClientEvent('kjELS:sendELSInformation', -1, kjxmlData)
end)

RegisterServerEvent('kjELS:requestELSInformation')
AddEventHandler('kjELS:requestELSInformation', function()
    TriggerClientEvent('kjELS:sendELSInformation', source, kjxmlData)
end)

RegisterNetEvent('baseevents:enteredVehicle')
AddEventHandler('baseevents:enteredVehicle', function(veh, seat, name)
    TriggerClientEvent('kjELS:initVehicle', source)
end)
