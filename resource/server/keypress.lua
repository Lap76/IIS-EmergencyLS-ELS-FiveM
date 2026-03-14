local function GetPlayerVehicleNetId(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return nil
    end

    local vehicle = GetVehiclePedIsUsing(ped)
    if not vehicle or vehicle == 0 then
        return nil
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        return nil
    end

    return netId
end

RegisterServerEvent('kjELS:setSirenState')
AddEventHandler('kjELS:setSirenState', function(state)
    local netId = GetPlayerVehicleNetId(source)
    if not netId then
        return
    end

    TriggerClientEvent('kjELS:updateSiren', -1, netId, state)
end)

RegisterServerEvent('kjELS:toggleHorn')
AddEventHandler('kjELS:toggleHorn', function(state)
    local netId = GetPlayerVehicleNetId(source)
    if not netId then
        return
    end

    TriggerClientEvent('kjELS:updateHorn', -1, netId, state)
end)

RegisterNetEvent('kjELS:sv_Indicator')
AddEventHandler('kjELS:sv_Indicator', function(direction, toggle)
    TriggerClientEvent('kjELS:updateIndicators', source, direction, toggle)
end)
