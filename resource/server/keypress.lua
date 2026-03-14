local function GetPlayerVehicle(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then
        vehicle = GetVehiclePedIsUsing(ped)
    end

    if not vehicle or vehicle == 0 then
        return nil
    end

    return vehicle
end

local function BroadcastSirenState(vehicle, state)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        print(('[MISS-ELS] server: no netId for vehicle %s'):format(tostring(vehicle)))
        return
    end

    local ent = Entity(vehicle)
    if ent and ent.state then
        ent.state:set('kjelsSiren', state, true)
    end

    TriggerClientEvent('kjELS:updateSiren', -1, netId, state)
end

local function BroadcastHornState(vehicle, state)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        print(('[MISS-ELS] server: no netId for vehicle %s'):format(tostring(vehicle)))
        return
    end

    TriggerClientEvent('kjELS:updateHorn', -1, netId, state)
end

RegisterServerEvent('kjELS:setSirenState')
AddEventHandler('kjELS:setSirenState', function(state)
    local vehicle = GetPlayerVehicle(source)
    if not vehicle then
        print(('[MISS-ELS] server: no vehicle found for player %s'):format(tostring(source)))
        return
    end

    BroadcastSirenState(vehicle, state)
end)

RegisterServerEvent('kjELS:toggleHorn')
AddEventHandler('kjELS:toggleHorn', function(state)
    local vehicle = GetPlayerVehicle(source)
    if not vehicle then
        print(('[MISS-ELS] server: no vehicle found for player %s'):format(tostring(source)))
        return
    end

    BroadcastHornState(vehicle, state)
end)

RegisterNetEvent('kjELS:sv_Indicator')
AddEventHandler('kjELS:sv_Indicator', function(direction, toggle)
    TriggerClientEvent('kjELS:updateIndicators', source, direction, toggle)
end)
