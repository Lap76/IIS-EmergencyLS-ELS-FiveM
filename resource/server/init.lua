kjxmlData = {}
local systemOS = nil

local function parseObjSet(data, fileName)
    local xml = SLAXML:dom(data)

    if xml and xml.root and xml.root.name == 'vcfroot' then
        ParseVCF(xml, fileName)
    end
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
        osType = osType:lower()

        if osType == "windows" then
            return "windows"
        end

        if osType == "linux" or osType == "unix" then
            return "unix"
        end
    end

    if os.getenv("HOME") then
        return "unix"
    end

    if os.getenv("HOMEPATH") or os.getenv("USERPROFILE") then
        return "windows"
    end

    -- veilige fallback voor FXServer
    return "unix"
end

local function scanDir(folder)
    local pathSeparator = '/'
    local command = 'ls -1A'

    if systemOS == 'windows' then
        pathSeparator = '\\'
        command = 'dir /B'
    end

    local resourcePath = GetResourcePath(GetCurrentResourceName())
    if not resourcePath then
        error('Could not resolve resource path.')
    end

    local directory = resourcePath .. pathSeparator .. folder
    local t = {}
    local pfile = io.popen(command .. ' "' .. directory .. '"')

    if not pfile then
        error('Could not open directory listing for: ' .. directory)
    end

    for filename in pfile:lines() do
        if filename and filename ~= '.' and filename ~= '..' then
            t[#t + 1] = filename
        end
    end

    pfile:close()

    if #t == 0 then
        error("Couldn't find any VCF files. Are they in the correct directory?")
    end

    return t
end

local function loadFile(file)
    return LoadResourceFile(GetCurrentResourceName(), file)
end

local function sendELSData(target)
    if not target then
        return
    end

    if type(kjxmlData) ~= "table" then
        print("^1MISS-ELS: kjxmlData is not a table, aborting sync.^7")
        return
    end

    TriggerClientEvent('kjELS:sendELSInformation', target, kjxmlData)
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

    systemOS = determineOS()

    for _, file in pairs(scanDir(folder)) do
        local data = loadFile(folder .. '/' .. file)

        if data then
            local ok, err = pcall(function()
                parseObjSet(data, file)
            end)

            if ok then
                print('Parsed VCF for: ' .. file)
            else
                print('VCF file ' .. file .. ' could not be parsed: ' .. tostring(err))
            end
        else
            print('VCF file ' .. file .. ' not found: does the file exist?')
        end
    end

    -- Stuur data alleen naar spelers die al online zijn
    local players = GetPlayers()
    if players and #players > 0 then
        for _, playerId in ipairs(players) do
            sendELSData(tonumber(playerId))
        end
    end
end)

RegisterServerEvent('kjELS:requestELSInformation')
AddEventHandler('kjELS:requestELSInformation', function()
    sendELSData(source)
end)

AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function()
        Wait(2000)
        sendELSData(src)
    end)
end)

RegisterNetEvent('baseevents:enteredVehicle')
AddEventHandler('baseevents:enteredVehicle', function(veh, seat, name)
    TriggerClientEvent('kjELS:initVehicle', source)
end)
