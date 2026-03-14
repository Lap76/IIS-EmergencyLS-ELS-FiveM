local function IsValidVehicle(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
end

local function GetVehicleFromNetId(netId)
    if not netId then
        return nil
    end

    if not NetworkDoesNetworkIdExist(netId) then
        return nil
    end

    if not NetworkDoesEntityExistWithNetworkId(netId) then
        return nil
    end

    local vehicle = NetToVeh(netId)
    if not IsValidVehicle(vehicle) then
        return nil
    end

    return vehicle
end

local function RemoveVehicleFromTable(vehicle)
    if vehicle and kjEnabledVehicles[vehicle] then
        kjEnabledVehicles[vehicle] = nil
    end
end

local function ToggleExtra(vehicle, extra, toggle)
    if not IsValidVehicle(vehicle) then
        RemoveVehicleFromTable(vehicle)
        return
    end

    local value = toggle and 0 or 1

    SetVehicleAutoRepairDisabled(vehicle, true)
    SetVehicleExtra(vehicle, extra, value)
end

local function ToggleMisc(vehicle, misc, toggle)
    if not IsValidVehicle(vehicle) then
        RemoveVehicleFromTable(vehicle)
        return
    end

    SetVehicleModKit(vehicle, 0)
    -- TODO: respect custom wheel setting
    SetVehicleMod(vehicle, misc, toggle, false)
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

local function SetLightStage(vehicle, stage, toggle)
    if not IsValidVehicle(vehicle) then
        RemoveVehicleFromTable(vehicle)
        return
    end

    if kjEnabledVehicles[vehicle] == nil then
        AddVehicleToTable(vehicle)
    end

    local ELSvehicle = kjEnabledVehicles[vehicle]
    if not ELSvehicle then
        return
    end

    local VCFdata = GetVehicleVCFData(vehicle)
    if not VCFdata then
        print(('[MISS-ELS] SetLightStage: no VCF data for vehicle %s / hash %s'):format(
            tostring(vehicle),
            tostring(GetCarHash(vehicle))
        ))
        return
    end

    local patternKey = ConvertStageToPattern(stage)
    local patternData = VCFdata.patterns and VCFdata.patterns[patternKey]

    if not patternData then
        print(('[MISS-ELS] SetLightStage: no pattern data for stage %s on %s'):format(
            tostring(stage),
            tostring(GetCarHash(vehicle))
        ))
        return
    end

    TriggerEvent('kjELS:resetExtras', vehicle)
    TriggerEvent('kjELS:resetMiscs', vehicle)

    ELSvehicle[stage] = toggle

    if patternData.isEmergency then
        SetVehicleSiren(vehicle, toggle)
    end

    if patternData.flashHighBeam then
        Citizen.CreateThread(function()
            if not IsValidVehicle(vehicle) then
                ELSvehicle[stage] = false
                RemoveVehicleFromTable(vehicle)
                return
            end

            local _, lightsOn, highbeamsOn = GetVehicleLightsState(vehicle)

            if lightsOn == 0 then
                SetVehicleLights(vehicle, 2)
            end

            while ELSvehicle[stage] do
                if not IsValidVehicle(vehicle) then
                    ELSvehicle[stage] = false
                    RemoveVehicleFromTable(vehicle)
                    break
                end

                if ELSvehicle.highBeamEnabled then
                    SetVehicleFullbeam(vehicle, true)
                    SetVehicleLightMultiplier(vehicle, Config.HighBeamIntensity or 5.0)

                    Wait(500)

                    if not IsValidVehicle(vehicle) then
                        ELSvehicle[stage] = false
                        RemoveVehicleFromTable(vehicle)
                        break
                    end

                    SetVehicleFullbeam(vehicle, false)
                    SetVehicleLightMultiplier(vehicle, 1.0)

                    Wait(500)
                end

                Wait(0)
            end

            if IsValidVehicle(vehicle) then
                if lightsOn == 0 then
                    SetVehicleLights(vehicle, 0)
                end
                if highbeamsOn == 1 then
                    SetVehicleFullbeam(vehicle, true)
                end
            end

            Wait(0)
        end)
    end

    if patternData.enableWarningBeep then
        Citizen.CreateThread(function()
            while ELSvehicle[stage] do
                if not IsValidVehicle(vehicle) then
                    ELSvehicle[stage] = false
                    RemoveVehicleFromTable(vehicle)
                    break
                end

                SendNUIMessage({
                    transactionType = 'playSound',
                    transactionFile = 'WarningBeep',
                    transactionVolume = 0.2
                })

                Citizen.Wait((Config.WarningBeepDuration or 0) * 1000)
            end
        end)
    end

    Citizen.CreateThread(function()
        while ELSvehicle[stage] do
            if not IsValidVehicle(vehicle) then
                ELSvehicle[stage] = false
                RemoveVehicleFromTable(vehicle)
                break
            end

            SetVehicleEngineOn(vehicle, true, true, false)

            local lastFlash = {
                extras = {},
                miscs = {},
            }

            for _, flash in ipairs(patternData) do
                if not IsValidVehicle(vehicle) then
                    ELSvehicle[stage] = false
                    RemoveVehicleFromTable(vehicle)
                    break
                end

                if ELSvehicle[stage] then
                    for _, extra in ipairs(flash['extras']) do
                        if not IsValidVehicle(vehicle) then
                            ELSvehicle[stage] = false
                            RemoveVehicleFromTable(vehicle)
                            break
                        end

                        SetVehicleAutoRepairDisabled(vehicle, true)
                        ToggleExtra(vehicle, extra, true)
                        table.insert(lastFlash.extras, extra)
                    end

                    for _, misc in ipairs(flash['miscs']) do
                        if not IsValidVehicle(vehicle) then
                            ELSvehicle[stage] = false
                            RemoveVehicleFromTable(vehicle)
                            break
                        end

                        ToggleMisc(vehicle, misc, true)
                        table.insert(lastFlash.miscs, misc)
                    end

                    Citizen.Wait(flash.duration)
                end

                if not IsValidVehicle(vehicle) then
                    ELSvehicle[stage] = false
                    RemoveVehicleFromTable(vehicle)
                    break
                end

                for _, v in ipairs(lastFlash.extras) do
                    ToggleExtra(vehicle, v, false)
                end

                for _, v in ipairs(lastFlash.miscs) do
                    ToggleMisc(vehicle, v, false)
                end

                lastFlash.extras = {}
                lastFlash.miscs = {}
            end

            Citizen.Wait(0)
        end

        Wait(0)
    end)
end

local function StaticsIncludesExtra(model, extra)
    return kjxmlData[model]
        and kjxmlData[model].statics
        and kjxmlData[model].statics.extras
        and kjxmlData[model].statics.extras[extra] ~= nil
end

local function StaticsIncludesMisc(model, misc)
    return kjxmlData[model]
        and kjxmlData[model].statics
        and kjxmlData[model].statics.miscs
        and kjxmlData[model].statics.miscs[misc] ~= nil
end

RegisterNetEvent('kjELS:resetExtras')
AddEventHandler('kjELS:resetExtras', function(vehicle)
    if not IsValidVehicle(vehicle) then
        RemoveVehicleFromTable(vehicle)
        CancelEvent()
        return
    end

    if not kjxmlData then
        CancelEvent()
        return
    end

    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))

    if not SetContains(kjxmlData, model) then
        CancelEvent()
        return
    end

    if not kjxmlData[model] or not kjxmlData[model].extras then
        CancelEvent()
        return
    end

    for extra, info in pairs(kjxmlData[model].extras) do
        if info.enabled == true and not StaticsIncludesExtra(model, extra) then
            SetVehicleAutoRepairDisabled(vehicle, true)
            ToggleExtra(vehicle, extra, false)
        end
    end
end)

RegisterNetEvent('kjELS:resetMiscs')
AddEventHandler('kjELS:resetMiscs', function(vehicle)
    if not IsValidVehicle(vehicle) then
        RemoveVehicleFromTable(vehicle)
        CancelEvent()
        return
    end

    if not kjxmlData then
        CancelEvent()
        return
    end

    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))

    if not SetContains(kjxmlData, model) then
        CancelEvent()
        return
    end

    if not kjxmlData[model] or not kjxmlData[model].miscs then
        CancelEvent()
        return
    end

    for misc, info in pairs(kjxmlData[model].miscs) do
        if info.enabled == true and not StaticsIncludesMisc(model, misc) then
            ToggleMisc(vehicle, misc, false)
        end
    end
end)

RegisterNetEvent('kjELS:toggleLights')
AddEventHandler('kjELS:toggleLights', function(vehicle, stage, toggle)
    if not IsValidVehicle(vehicle) then
        RemoveVehicleFromTable(vehicle)
        CancelEvent()
        return
    end

    if kjEnabledVehicles[vehicle] == nil then
        AddVehicleToTable(vehicle)
    end

    SetLightStage(vehicle, stage, toggle)
end)

RegisterNetEvent('kjELS:updateHorn')
AddEventHandler('kjELS:updateHorn', function(netId, status)
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle then
        return
    end

    local vehicleData = GetVehicleVCFData(vehicle)
    if not vehicleData then
        return
    end

    local sounds = vehicleData.sounds
    if not sounds or not sounds.mainHorn then
        return
    end

    if kjEnabledVehicles[vehicle] == nil then
        AddVehicleToTable(vehicle)
    end

    local ELSvehicle = kjEnabledVehicles[vehicle]
    if not ELSvehicle then
        return
    end

    ELSvehicle.horn = status

    if ELSvehicle.sound_id ~= nil then
        StopSound(ELSvehicle.sound_id)
        ReleaseSoundId(ELSvehicle.sound_id)
        ELSvehicle.sound_id = nil
    end

    if status then
        ELSvehicle.sound_id = GetSoundId()

        PlaySoundFromEntity(
            ELSvehicle.sound_id,
            sounds.mainHorn.audioString,
            vehicle,
            sounds.mainHorn.soundSet or 0,
            0, 0
        )
    end
end)

RegisterNetEvent('kjELS:updateSiren')
AddEventHandler('kjELS:updateSiren', function(netId, status)
    if not netId then
        print('[MISS-ELS] updateSiren: missing netId')
        return
    end

    local vehicle = NetToVeh(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        print(('[MISS-ELS] updateSiren: vehicle not in scope for netId %s'):format(tostring(netId)))
        return
    end

    local vehicleData = GetVehicleVCFData(vehicle)
    if not vehicleData then
        print(('[MISS-ELS] updateSiren: no VCF data for vehicle %s'):format(tostring(vehicle)))
        return
    end

    local sounds = vehicleData.sounds
    if not sounds then
        print(('[MISS-ELS] updateSiren: no sounds table for vehicle %s'):format(tostring(vehicle)))
        return
    end

    if kjEnabledVehicles[vehicle] == nil then
        AddVehicleToTable(vehicle)
    end

    local ELSvehicle = kjEnabledVehicles[vehicle]
    if not ELSvehicle then
        print(('[MISS-ELS] updateSiren: no ELS state for vehicle %s'):format(tostring(vehicle)))
        return
    end

    ELSvehicle.siren = status

    if ELSvehicle.sound ~= nil then
        StopSound(ELSvehicle.sound)
        ReleaseSoundId(ELSvehicle.sound)
        ELSvehicle.sound = nil
    end

    local statuses = {1, 2, 3, 4}

    if TableHasValue(statuses, status) then
        local tone = sounds['srnTone' .. status]
        if not tone then
            print(('[MISS-ELS] updateSiren: missing srnTone%s'):format(tostring(status)))
            return
        end

        ELSvehicle.sound = GetSoundId()

        PlaySoundFromEntity(
            ELSvehicle.sound,
            tone.audioString,
            vehicle,
            tone.soundSet or 0,
            0,
            0
        )
    end

    SetVehicleHasMutedSirens(vehicle, true)
end)

RegisterNetEvent('kjELS:updateIndicators')
AddEventHandler('kjELS:updateIndicators', function(dir, toggle)
    local vehicle = GetVehiclePedIsIn(PlayerPedId())
    if not IsValidVehicle(vehicle) then
        return
    end

    SetVehicleIndicatorLights(vehicle, 1, false)
    SetVehicleIndicatorLights(vehicle, 0, false)

    if dir == 'left' then
        SetVehicleIndicatorLights(vehicle, 1, toggle)
    elseif dir == 'right' then
        SetVehicleIndicatorLights(vehicle, 0, toggle)
    elseif dir == 'hazard' then
        SetVehicleIndicatorLights(vehicle, 1, toggle)
        SetVehicleIndicatorLights(vehicle, 0, toggle)
    end
end)

local function CreateEnviromentLight(vehicle, light, offset, color)
    if not IsValidVehicle(vehicle) then
        RemoveVehicleFromTable(vehicle)
        return
    end

    local boneIndex = GetEntityBoneIndexByName(vehicle, light.type .. '_' .. tostring(light.name))
    if boneIndex == -1 then
        return
    end

    local coords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    local position = coords + offset

    local rgb = { 0, 0, 0 }
    local range = Config.EnvironmentalLights.Range or 50.0
    local intensity = Config.EnvironmentalLights.Intensity or 1.0
    local shadow = 1.0

    if string.lower(color) == 'blue' then
        rgb = { 0, 0, 255 }
    elseif string.lower(color) == 'red' then
        rgb = { 255, 0, 0 }
    elseif string.lower(color) == 'green' then
        rgb = { 0, 255, 0 }
    elseif string.lower(color) == 'white' then
        rgb = { 255, 255, 255 }
    elseif string.lower(color) == 'amber' then
        rgb = { 255, 194, 0 }
    end

    DrawLightWithRangeAndShadow(
        position.x, position.y, position.z,
        rgb[1], rgb[2], rgb[3],
        range, intensity, shadow
    )
end

Citizen.CreateThread(function()
    while true do
        while not kjxmlData do
            Citizen.Wait(0)
        end

        for vehicle, _ in pairs(kjEnabledVehicles) do
            if not IsValidVehicle(vehicle) then
                RemoveVehicleFromTable(vehicle)
            else
                local data = GetVehicleVCFData(vehicle)

                if data then
                    if data.extras then
                        for extra, info in pairs(data.extras) do
                            if IsValidVehicle(vehicle) and IsVehicleExtraTurnedOn(vehicle, extra) and info.env_light then
                                local offset = vector3(info.env_pos.x, info.env_pos.y, info.env_pos.z)
                                local light = {
                                    type = 'extra',
                                    name = extra
                                }

                                CreateEnviromentLight(vehicle, light, offset, info.env_color)
                            end
                        end
                    end

                    if data.miscs then
                        for misc, info in pairs(data.miscs) do
                            if IsValidVehicle(vehicle) and IsVehicleMiscTurnedOn(vehicle, misc) and info.env_light then
                                local offset = vector3(info.env_pos.x, info.env_pos.y, info.env_pos.z)
                                local light = {
                                    type = 'misc',
                                    name = ConvertMiscIdToName(misc)
                                }

                                CreateEnviromentLight(vehicle, light, offset, info.env_color)
                            end
                        end
                    end
                end
            end
        end

        Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function()
    while true do
        for vehicle, _ in pairs(kjEnabledVehicles) do
            if not IsValidVehicle(vehicle) then
                RemoveVehicleFromTable(vehicle)
            end
        end

        Citizen.Wait(2000)
    end
end)
