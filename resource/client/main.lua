-- indicator state
Indicators = {
    left = false,
    right = false,
    hazard = false
}

local function IsValidVehicle(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
end

local function GetVehicleVCFData(vehicle)
    if not IsValidVehicle(vehicle) then
        return nil
    end

    if not kjxmlData then
        return nil
    end

    local carHash = GetCarHash(vehicle)
    if not carHash then
        return nil
    end

    return kjxmlData[carHash]
end

local function GetVehicleSounds(vehicle)
    local vcf = GetVehicleVCFData(vehicle)
    if not vcf then
        return nil
    end

    return vcf.sounds
end

local function EnsureVehicleState(vehicle)
    if not IsValidVehicle(vehicle) then
        return nil
    end

    if kjEnabledVehicles[vehicle] == nil then
        AddVehicleToTable(vehicle)
    end

    return kjEnabledVehicles[vehicle]
end

local function HandleIndicators(type)
    if not type then
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(ped)
    if not IsValidVehicle(vehicle) or not PedIsDriver(vehicle) then
        return
    end

    if type ~= 'left' and Indicators.left then
        Indicators.left = false
    elseif type ~= 'right' and Indicators.right then
        Indicators.right = false
    elseif type ~= 'hazard' and Indicators.hazard then
        Indicators.hazard = false
    end

    Indicators[type] = not Indicators[type]
    TriggerServerEvent('kjELS:sv_Indicator', type, Indicators[type])
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
end

if Config.Indicators then
    RegisterCommand('MISS-ELS:toggle-indicator-hazard', function()
        HandleIndicators('hazard')
    end)

    RegisterCommand('MISS-ELS:toggle-indicator-left', function()
        HandleIndicators('left')
    end)

    RegisterCommand('MISS-ELS:toggle-indicator-right', function()
        HandleIndicators('right')
    end)
end

local function HandleHorn()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(ped)
    if not IsValidVehicle(vehicle) or not PedIsDriver(vehicle) then
        return
    end

    local sounds = GetVehicleSounds(vehicle)
    if not sounds or not sounds.mainHorn then
        return
    end

    local mainHorn = sounds.mainHorn
    if not mainHorn.allowUse then
        return
    end

    DisableControlAction(0, 86, true)

    if IsDisabledControlJustPressed(0, 86) then
        TriggerServerEvent('kjELS:toggleHorn', true)
    end

    if IsDisabledControlJustReleased(0, 86) then
        TriggerServerEvent('kjELS:toggleHorn', false)
    end
end

local function ToggleLights(vehicle, stage, toggle)
    local ELSvehicle = EnsureVehicleState(vehicle)
    if not ELSvehicle then
        return
    end

    TriggerEvent('kjELS:toggleLights', vehicle, stage, toggle)

    if not ELSvehicle.primary and not ELSvehicle.secondary and not ELSvehicle.warning then
        TriggerServerEvent('kjELS:setSirenState', 0)
    end
end

local function HandleLightStage(stage)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(ped)
    if not IsValidVehicle(vehicle) then
        return
    end

    local ELSvehicle = EnsureVehicleState(vehicle)
    if not ELSvehicle then
        return
    end

    local sounds = GetVehicleSounds(vehicle)

    if ELSvehicle[stage] then
        ToggleLights(vehicle, stage, false)
    else
        ToggleLights(vehicle, stage, true)

        if stage == 'primary' and sounds and sounds.nineMode then
            SendNUIMessage({
                transactionType = 'playSound',
                transactionFile = '999mode',
                transactionVolume = 1.0
            })
        end
    end
end

local function HandleSiren(siren)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(ped)
    if not IsValidVehicle(vehicle) then
        return
    end

    local ELSvehicle = EnsureVehicleState(vehicle)
    if not ELSvehicle then
        return
    end

    if not ELSvehicle.primary and not Config.SirenAlwaysAllowed then
        return
    end

    local sounds = GetVehicleSounds(vehicle)
    if not sounds then
        return
    end

    local currentSiren = ELSvehicle.siren
    local sirenOn = currentSiren ~= 0

    if (not sirenOn) or (sirenOn and siren and siren ~= currentSiren) then
        if siren then
            local tone = sounds['srnTone' .. siren]
            if not tone or not tone.allowUse then
                return
            end
        end

        local desiredSiren = siren or 1
        TriggerServerEvent('kjELS:setSirenState', desiredSiren)

        local netId = VehToNet(vehicle)
        if netId and netId ~= 0 then
            TriggerEvent('kjELS:updateSiren', netId, desiredSiren)
        end

        if Config.HornBlip then
            SoundVehicleHornThisFrame(vehicle)
        end
    elseif sirenOn or not siren then
        TriggerServerEvent('kjELS:setSirenState', 0)

        local netId = VehToNet(vehicle)
        if netId and netId ~= 0 then
            TriggerEvent('kjELS:updateSiren', netId, 0)
        end

        if Config.HornBlip then
            Wait(100)
            SoundVehicleHornThisFrame(vehicle)
            Wait(100)
            SoundVehicleHornThisFrame(vehicle)
        end
    end

    if Config.Beeps then
        SendNUIMessage({
            transactionType = 'playSound',
            transactionFile = 'Beep',
            transactionVolume = 0.025
        })
    end
end

local function NextSiren()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(ped)
    if not IsValidVehicle(vehicle) then
        return
    end

    local ELSvehicle = EnsureVehicleState(vehicle)
    if not ELSvehicle then
        return
    end

    local sounds = GetVehicleSounds(vehicle)
    if not sounds then
        return
    end

    local next = ELSvehicle.siren + 1
    local max = 4
    local count = 0

    if next > 4 then
        next = 1
    end

    while true do
        local tone = sounds['srnTone' .. next]
        if tone and tone.allowUse then
            break
        end

        if count == max then
            return
        end

        next = next + 1
        if next > 4 then
            next = 1
        end

        count = count + 1
    end

    HandleSiren(next)
end

RegisterCommand('MISS-ELS:toggle-stage-primary', function()
    if not CanControlELS() then return end
    HandleLightStage('primary')
end)

RegisterCommand('MISS-ELS:toggle-stage-secondary', function()
    if not CanControlELS() then return end
    HandleLightStage('secondary')
end)

RegisterCommand('MISS-ELS:toggle-stage-warning', function()
    if not CanControlELS() then return end
    HandleLightStage('warning')
end)

RegisterCommand('MISS-ELS:toggle-siren', function()
    if not CanControlELS() then return end
    HandleSiren()
end)

RegisterCommand('MISS-ELS:toggle-siren-next', function()
    if not CanControlELS() then return end
    NextSiren()
end)

RegisterCommand('MISS-ELS:toggle-siren-one', function()
    if not CanControlELS() then return end
    HandleSiren(1)
end)

RegisterCommand('MISS-ELS:toggle-siren-two', function()
    if not CanControlELS() then return end
    HandleSiren(2)
end)

RegisterCommand('MISS-ELS:toggle-siren-three', function()
    if not CanControlELS() then return end
    HandleSiren(3)
end)

RegisterCommand('MISS-ELS:toggle-siren-four', function()
    if not CanControlELS() then return end
    HandleSiren(4)
end)

AddEventHandler('onClientResourceStart', function(name)
    if not Config then
        CancelEvent()
        return
    end

    if name:lower() ~= GetCurrentResourceName():lower() then
        CancelEvent()
        return
    end

    Citizen.CreateThread(function()
        while true do
            if not kjxmlData then
                TriggerServerEvent('kjELS:requestELSInformation')
                while not kjxmlData do
                    Citizen.Wait(0)
                end
            end

            while not IsPedInAnyVehicle(PlayerPedId(), false) do
                Citizen.Wait(0)
            end

            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsUsing(ped)

            if IsValidVehicle(vehicle) and IsELSVehicle(vehicle) and CanControlSirens(vehicle) then
                local controls = {
                    { 0, 58 },
                    { 0, 73 },
                    { 0, 80 },
                    { 1, 80 },
                    { 0, 81 },
                    { 0, 82 },
                    { 0, 83 },
                    { 0, 84 },
                }

                for _, control in ipairs(controls) do
                    DisableControlAction(control[1], control[2], true)
                end

                SetVehRadioStation(vehicle, 'OFF')
                SetVehicleRadioEnabled(vehicle, false)
                SetVehicleAutoRepairDisabled(vehicle, true)
                EnsureVehicleState(vehicle)
                HandleHorn()

                if not IsUsingKeyboard(0) then
                    if IsDisabledControlJustReleased(1, 85) then
                        HandleLightStage('primary')
                    elseif IsDisabledControlJustReleased(1, 170) then
                        NextSiren()
                    elseif IsDisabledControlJustReleased(1, 173) then
                        HandleSiren()
                    end
                end
            end

            Citizen.Wait(0)
        end
    end)
end)
