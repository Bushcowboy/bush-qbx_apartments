local isInApartment = false
local interiorCoords = vector4(-295.64, -811.46, 85.18, 342.74)
local outsideCoords = vector4(-291.40, -818.83, 32.42, 255.84)
local stashCoords = vector3(-294.84, -807.93, 85.18)
local clothingCoords = vec3(-294.43, -809.98, 85.18)

CreateThread(function()
	local blip = AddBlipForCoord(outsideCoords.x, outsideCoords.y, outsideCoords.z)
	SetBlipSprite(blip, 40)
	SetBlipAsShortRange(blip, true)
	SetBlipScale(blip, 0.8)
	SetBlipColour(blip, 2)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentString(label)
	EndTextCommandSetBlipName(blip)
	return blip
end)

function OpenMenu()
    local playerOwnsApartment = lib.callback.await("bush_apartment:server:getApartmentId", source)
    if not playerOwnsApartment then
        lib.registerContext({
            id = "bush_apartment:client:openMenu",
        title = "Apartment Menu",
        options = {
            { 
                label = "Create Apartment", 
                description = "Create a new apartment", 
                icon = "door-open", 
                onSelect = function()
                    lib.callback.await("bush_apartment:server:createApartment", source)
                end 
            },
        }
        })
        lib.showContext("bush_apartment:client:openMenu")
    else
        lib.registerContext({
            id = "bush_apartment:client:openMenu",
            title = "Apartment Menu",
            options = {
                { 
                    label = "Enter Apartment", 
                    description = "Enter your apartment", 
                    icon = "door-open", 
                    onSelect = function()
                        EnterApartment()
                    end 
                },
                { 
                    label = "Delete Apartment", 
                    description = "Delete your apartment", 
                    icon = "door-open", 
                    onSelect = function()
                        
                        DeleteApartment()
                    end 
                }
            }
        })
        lib.showContext("bush_apartment:client:openMenu")
    end
end

function DeleteApartment(source)
    lib.registerContext({
        id = "bush_apartment:client:deleteApartment",
        title = "Are you sure?",
        options = {
            { 
                label = "Yes", 
                description = "Yes, delete my apartment", 
                icon = "door-open", 
                onSelect = function()
                    lib.callback.await("bush_apartment:server:deleteApartment", source)
                end 
            },
            { 
                label = "No", 
                description = "No, do not delete my apartment", 
                icon = "door-open", 
                onSelect = function()
                    lib.notify({
                        title = 'Cancelled',
                        description = 'You did not delete your apartment',
                        type = 'error'
                    })  
                end 
            }
        }
    })
    lib.showContext("bush_apartment:client:deleteApartment")
end

function OpenStash()
    local apartment = lib.callback.await("bush_apartment:server:getApartmentId", source)
    if not apartment then
        lib.notify({
            title = 'Error',
            description = 'You do not own an apartment',
            type = 'error'
        })
        return
    end
    exports.ox_inventory:openInventory('stash', {id=apartment.citizenid})
end

function ChangeClothes()
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end

function EnterApartment()
    local playerOwnsApartment = lib.callback.await("bush_apartment:server:getApartmentId", source)
    if not playerOwnsApartment then
        CreateApartment()
    else
        lib.callback.await("bush_apartment:server:setbuckets", source)
        SetEntityCoords(PlayerPedId(), interiorCoords.x, interiorCoords.y, interiorCoords.z, interiorCoords.h, false, false, false)
    end
end

function LeaveApartment()
    local playerOwnsApartment = lib.callback.await("bush_apartment:server:getApartmentId", source)
    if playerOwnsApartment then
        lib.callback.await("bush_apartment:server:resetbuckets", source)
        SetEntityCoords(PlayerPedId(), outsideCoords.x, outsideCoords.y, outsideCoords.z, outsideCoords.h, false, false, false)
    else
        print("You don't own this apartment")
    end
end

function RegisterTarget()
    exports.ox_target:addBoxZone({
        coords = outsideCoords,
        size = vec3(1, 1, 1),
        options = {
            {
                id = "open_menu",
                icon = "door-open",
                label = "Open Menu",
                onSelect = function()
                    OpenMenu()
                end
            }
        }
    })

    exports.ox_target:addBoxZone({
        coords = interiorCoords,
        size = vec3(1, 1, 1),
        options = {
            {
                id = "leave_apartment",
                icon = "box",
                label = "Leave Apartment",
                onSelect = function()
                    LeaveApartment()
                end
            }
        }
    })

    exports.ox_target:addBoxZone({
        coords = stashCoords,
        size = vec3(1, 1, 1),
        options = {
            {
                id = "stash",
                icon = "box",
                label = "Open Stash",
                onSelect = function()
                    OpenStash()
                end
            }
        }
    })

    exports.ox_target:addBoxZone({
        coords = clothingCoords,
        size = vec3(1, 1, 1),
        options = {
            {
                id = "clothing",
                icon = "box",
                label = "Change Clothes",
                onSelect = function()
                    ChangeClothes()
                end
            }
        }
    })
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RegisterTarget()
    end
end)