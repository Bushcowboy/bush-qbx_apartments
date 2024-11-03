local config = require 'config.client'
local sharedConfig = require 'config.shared'
local apartmentZones = {}
local rangDoorbell = false
local currentApartment = nil
local currentApartmentId = nil
local currentEntrance = nil
local currentDoorBell = 0
local playerState = LocalPlayer.state

-- Functions
local function openHouseAnim()
    lib.requestAnimDict('anim@heists@keycard@', 1000)
    TaskPlayAnim(cache.ped, 'anim@heists@keycard@', 'exit', 5.0, 1.0, -1, 16, 0, false, false, false)
    Wait(400)
    StopAnimTask(cache.ped, 'anim@heists@keycard@', 'exit', 1.0)
end

local function showEntranceHeaderMenu(id)
    local headerMenu = {}

    local isOwned = lib.callback.await('apartments:IsOwner', false, id)

    if isOwned then
        headerMenu[#headerMenu + 1] = {
            icon = "fa-solid fa-door-open",
            title = Lang:t('text.enter'),
            event = 'apartments:client:EnterApartment',
            args = id
        }
    else
        headerMenu[#headerMenu + 1] = {
            icon = "fa-solid fa-boxes-packing", 
            title = Lang:t('text.move_here'),
            event = 'apartments:client:UpdateApartment',
            args = id
        }
    end

    headerMenu[#headerMenu + 1] = {
        icon = "fa-solid fa-bell",
        title = Lang:t('text.ring_doorbell'),
        event = 'apartments:client:DoorbellMenu',
    }

    lib.registerContext({
        id = 'apartment_context_menu',
        title = Lang:t('text.menu_header'),
        options = headerMenu
    })

    lib.showContext('apartment_context_menu')
end

local function showExitHeaderMenu()
    lib.registerContext({
        id = 'apartment_exit_context_menu',
        title = Lang:t('text.menu_header'),
        options = {
            { icon = "fa-solid fa-lock-open", title = Lang:t('text.open_door'), event = 'apartments:client:OpenDoor', },
            { icon = "fa-solid fa-door-open", title = Lang:t('text.leave'), event = 'apartments:client:LeaveApartment', },
        }
    })
    lib.showContext('apartment_exit_context_menu')
end

local function createEntrances()
    for id, data in pairs(sharedConfig.locations) do
        apartmentZones[id] = {}
        exports.ox_target:addSphereZone({
            coords = data.Exterior.xyz,
            radius = 1.5,
            debug = false,
            options = {
                {
                    name = 'apartment_entrance_'..id,
                    icon = 'fas fa-door-open',
                    label = Lang:t('text.door_outside'),
                    onSelect = function()
                        showEntranceHeaderMenu(id)
                    end
                }
            }
        })
    end
end

local function removeEntrances()
    for id, _ in pairs(apartmentZones) do
        exports.ox_target:removeZone('apartment_entrance_'..id)
    end
end

local function createInsidePoints(id, data)
    exports.ox_target:addSphereZone({
        coords = data.Interior.xyz,
        radius = 1.0,
        debug = false,
        options = {
            {
                name = 'apartment_exit_'..id,
                icon = 'fas fa-door-open',
                label = Lang:t('text.door_inside'),
                onSelect = function()
                    showExitHeaderMenu()
                end
            }
        }
    })

    exports.ox_target:addSphereZone({
        coords = data.Stash,
        radius = 1.0,
        debug = false,
        options = {
            {
                name = 'apartment_stash_'..id,
                icon = 'fas fa-box',
                label = Lang:t('text.open_stash'),
                onSelect = function()
                    TriggerEvent('apartments:client:OpenStash', currentApartment)
                end
            }
        }
    })

    exports.ox_target:addSphereZone({
        coords = data.Clothing,
        radius = 1.0,
        debug = false,
        options = {
            {
                name = 'apartment_clothing_'..id,
                icon = 'fas fa-tshirt',
                label = Lang:t('text.change_outfit'),
                onSelect = function()
                    TriggerEvent('apartments:client:ChangeOutfit')
                end
            }
        }
    })
end

local function removeInsidePoints(id)
    exports.ox_target:removeZone('apartment_exit_'..id)
    exports.ox_target:removeZone('apartment_stash_'..id) 
    exports.ox_target:removeZone('apartment_clothing_'..id)
end

local function enterApartment(house, apartmentId, new)
    currentApartmentId = apartmentId
    currentApartment = house

    TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.1)
    openHouseAnim()
    
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    
    SetEntityCoords(cache.ped, sharedConfig.locations[house].Interior.x, sharedConfig.locations[house].Interior.y, sharedConfig.locations[house].Interior.z)
    SetEntityHeading(cache.ped, sharedConfig.locations[house].Interior.w)
    
    Wait(100)
    
    DoScreenFadeIn(1000)
    
    -- Play apartment ambient sounds and radio
    StartAudioScene('DLC_MPHEIST_TRANSITION_TO_APT_FADE_IN_RADIO_SCENE')
    PlaySoundFrontend(-1, "OPENING", "MP_PROPERTIES_ELEVATOR_DOORS", true)
    
    TriggerServerEvent('apartments:server:SetInsideMeta', house, apartmentId, true)
    TriggerServerEvent("apartments:server:setCurrentApartment", apartmentId)
    createInsidePoints(house, sharedConfig.locations[house])

    if new then
        SetTimeout(1250, function()
            TriggerEvent('qb-clothes:client:CreateFirstCharacter')
        end)
    end
end

local function menuOwners()
    local apartments = lib.callback.await('apartments:GetAvailableApartments', false, currentEntrance)
    if not next(apartments) then
        exports.qbx_core:Notify(Lang:t('error.nobody_home'), "error", 3500)
        lib.hideContext(false)
    else
        local aptsMenu = {}

        for k, v in pairs(apartments) do
            aptsMenu[#aptsMenu+1] = {
                title = v,
                event = 'apartments:client:RingMenu',
                args = { apartmentId = k }
            }
        end

        lib.registerContext({
            id = 'apartment_tennants_context_menu',
            title = Lang:t('text.tennants'),
            options = aptsMenu
        })

        lib.showContext('apartment_tennants_context_menu')
    end
end

local function exitApartment()
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.1)
    openHouseAnim()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end

    local coord = sharedConfig.locations[currentApartment].Exterior
    SetEntityCoords(cache.ped, coord.x, coord.y, coord.z, false, false, false, false)
    SetEntityHeading(cache.ped, coord.w)
    
    Wait(1000)
    
    TriggerServerEvent('apartments:server:SetInsideMeta', currentApartmentId, false)
    DoScreenFadeIn(1000)
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_close", 0.1)
    TriggerServerEvent("apartments:server:setCurrentApartment", nil)
    removeInsidePoints(currentApartment)
    currentApartment, currentApartmentId = nil, nil
end

local function loggedIn()
    createEntrances()
end

local function loggedOff()
    removeEntrances()
    if not currentApartment then return end
    removeInsidePoints(currentApartment)
    
    local coord = sharedConfig.locations[currentApartment].Exterior
    SetEntityCoords(cache.ped, coord.x, coord.y, coord.z, false, false, false, false)
    SetEntityHeading(cache.ped, coord.w)
    
    Wait(1000)
    DoScreenFadeIn(1000)
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_close", 0.1)
    TriggerServerEvent("apartments:server:setCurrentApartment", nil)
    currentApartment, currentApartmentId = nil, nil
end

-- Events
RegisterNetEvent('apartments:client:EnterApartment', function(id)
    local result = lib.callback.await('apartments:GetOwnedApartment')
    if not result then return end
    enterApartment(id, result.name, false)
end)

RegisterNetEvent('apartments:client:UpdateApartment', function(id)
    TriggerServerEvent("apartments:server:UpdateApartment", id, sharedConfig.locations[id].label)
end)

RegisterNetEvent('apartments:client:LeaveApartment', function()
    if not currentApartment then return end
    exitApartment()
end)

RegisterNetEvent('apartments:client:DoorbellMenu', function()
    menuOwners()
end)

RegisterNetEvent('apartments:client:RingMenu', function(data)
    rangDoorbell = currentEntrance
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "doorbell", 0.1)
    TriggerServerEvent("apartments:server:RingDoor", data.apartmentId, currentEntrance)
end)

RegisterNetEvent('apartments:client:RingDoor', function(player, _)
    currentDoorBell = player
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "doorbell", 0.1)
    exports.qbx_core:Notify(Lang:t('info.at_the_door'))
end)

RegisterNetEvent('apartments:client:OpenDoor', function()
    if currentDoorBell == 0 then
        exports.qbx_core:Notify(Lang:t('error.nobody_at_door'))
        return
    end
    TriggerServerEvent("apartments:server:OpenDoor", currentDoorBell, currentApartmentId, currentEntrance)
    currentDoorBell = 0
end)

RegisterNetEvent('apartments:client:SetHomeBlip', function(home)
    CreateThread(function()
        for name, _ in pairs(sharedConfig.locations) do
            RemoveBlip(sharedConfig.locations[name].blip)

            sharedConfig.locations[name].blip = AddBlipForCoord(sharedConfig.locations[name].Exterior.x, sharedConfig.locations[name].Exterior.y, sharedConfig.locations[name].Exterior.z)
            if (name == home) then
                SetBlipSprite(sharedConfig.locations[name].blip, 475)
                SetBlipCategory(sharedConfig.locations[name].blip, 11)
            else
                SetBlipSprite(sharedConfig.locations[name].blip, 476)
                SetBlipCategory(sharedConfig.locations[name].blip, 10)
            end
            SetBlipDisplay(sharedConfig.locations[name].blip, 4)
            SetBlipScale(sharedConfig.locations[name].blip, 0.65)
            SetBlipAsShortRange(sharedConfig.locations[name].blip, true)
            SetBlipColour(sharedConfig.locations[name].blip, 3)

            AddTextEntry(sharedConfig.locations[name].label, sharedConfig.locations[name].label)
            BeginTextCommandSetBlipName(sharedConfig.locations[name].label)
            EndTextCommandSetBlipName(sharedConfig.locations[name].blip)
        end
    end)
end)

RegisterNetEvent('apartments:client:ChangeOutfit', function()
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "Clothes1", 0.4)
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end)

RegisterNetEvent('apartments:client:OpenStash', function(apId)
    exports.ox_inventory:openInventory('stash', apId)
end)

RegisterNetEvent('apartments:client:SpawnInApartment', function(apartmentId, apartment, ownerCid)
    local pos = GetEntityCoords(cache.ped)
    local new = true
    
    if rangDoorbell then
        new = false
        local doorbelldist = #(pos - sharedConfig.locations[rangDoorbell].Exterior.xyz)
        if doorbelldist > 5 then
            exports.qbx_core:Notify(Lang:t('error.to_far_from_door'))
            return
        end
    end

    currentApartment = apartment
    currentApartmentId = apartmentId
    enterApartment(apartment, apartmentId, new)
end)

RegisterNetEvent('qb-apartments:client:LastLocationHouse', function(apartmentType, apartmentId)
    currentApartmentId = apartmentType
    currentApartment = apartmentType
    enterApartment(apartmentType, apartmentId, false)
end)

-- Handlers
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName or not playerState.isLoggedIn then return end
    loggedIn()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeEntrances()
    if currentApartment then
        local coord = sharedConfig.locations[currentApartment].Exterior
        SetEntityCoords(cache.ped, coord.x, coord.y, coord.z, false, false, false, false)
        SetEntityHeading(cache.ped, coord.w)
        removeInsidePoints(currentApartment)
        currentApartment, currentApartmentId = nil, nil
    end
end)

AddStateBagChangeHandler('isLoggedIn', _, function(_bagName, _key, value, _reserved, _replicated)
    if value then loggedIn() else loggedOff() end
end)

-- QB Spawn
RegisterNetEvent('apartments:client:setupSpawnUI', function(cData)
    local result = lib.callback.await('apartments:GetOwnedApartment', false, cData.citizenid)
    if result then
        TriggerEvent('qb-spawn:client:setupSpawns', cData, false, nil)
        TriggerEvent("apartments:client:SetHomeBlip", result.type)
    elseif config.starting then
        TriggerEvent('qb-spawn:client:setupSpawns', cData, true, sharedConfig.locations)
    else
        TriggerEvent('qb-spawn:client:setupSpawns', cData, false, nil)
    end
    TriggerEvent('qb-spawn:client:openUI', true)
end)
