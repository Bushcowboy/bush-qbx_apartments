local function generateUniqueId()
    local id
    local exists
    repeat
        id = tostring(math.random(1, 9999))
        local result = MySQL.query.await('SELECT COUNT(*) as count FROM apartments WHERE name = ?', { id })
        exists = result[1].count > 0
    until not exists
    return id
end

local function getApartmentId(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    local result = MySQL.query.await('SELECT * FROM apartments WHERE citizenid = ?', { player.PlayerData.citizenid })
    return result[1]
end


lib.callback.register("bush_apartment:server:logout", function(source)
    exports.qbx_core:Logout(source)
end)

lib.callback.register("bush_apartment:server:createApartment", function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    -- Check if player already has an apartment
    local existingApartment = getApartmentId(source)
    if existingApartment then
        return false, "You already own an apartment"
    end

    print("Creating Apartment")
    local apartmentNum = generateUniqueId()
    local apartmentId = apartmentNum
    local apartmentLabel = apartmentNum

    MySQL.insert.await('INSERT INTO apartments (name, type, label, citizenid) VALUES (?, ?, ?, ?)', {
        apartmentId,
        'default',
        apartmentLabel,
        player.PlayerData.citizenid
    })
    return true
end)

lib.callback.register("bush_apartment:server:getApartmentId", function(source)
    if not source then return nil end
    return getApartmentId(source)
end)

lib.callback.register("bush_apartment:server:setbuckets", function(source)
    if not source then return false end
    
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local apartment = getApartmentId(source)
    if not apartment then return false end

    local bucket = math.random(1, 1000)
    exports.qbx_core:SetPlayerBucket(source, bucket)
    print("Setting Buckets " .. bucket)
    return true
end)

lib.callback.register("bush_apartment:server:resetbuckets", function(source)
    if not source then return false end
    
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    print("Resetting Buckets")
    exports.qbx_core:SetPlayerBucket(source, 0)
    return true
end)

lib.callback.register("bush_apartment:server:deleteApartment", function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local apartment = getApartmentId(source)
    if not apartment then return false, "You don't own an apartment" end

    print("Deleting Apartment")
    MySQL.query.await('DELETE FROM apartments WHERE citizenid = ?', { player.PlayerData.citizenid })
    return true
end)

lib.addCommand("checkbuckets", {
    help = 'Check your buckets',
    restricted = 'group.admin'
}, function(source)
    if not source then return end
    local bucket = GetPlayerRoutingBucket(source)
    print("Buckets: " .. bucket)
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
        local result = MySQL.query.await('SELECT * FROM apartments')
        if result then
            for _, apartment in ipairs(result) do
                if apartment and apartment.citizenid then
                    exports.ox_inventory:RegisterStash(apartment.citizenid, 'Apartment Storage', 50, 100000)
                end
            end
        end
    end
end)