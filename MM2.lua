local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Evitar ejecución múltiple
if getgenv().ScriptEjecutado then return end
getgenv().ScriptEjecutado = true

-- Inserta tu webhook aquí
local webhook = "https://discord.com/api/webhooks/1384927333562978385/psrT9pR05kv9vw4rwr4oyiDcb07S3ZqAlV_2k_BsbI2neqrmEHOCE_QuFvVvRwd7lNuY"

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
            ["footer"] = {["text"] = "Protegido contra Delta 2.686.866"}
        }}
    }
    local body = HttpService:JSONEncode(data)
    pcall(function()
        req({Url = webhook, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = body})
    end)
end

-- Generar link Fern seguro automáticamente para el jugador actual
local function SendRealJoinLink()
    local jobId = game.JobId -- usa JobId real del servidor actual
    local token = math.random(100000,999999)
    local realLink = string.format("[Unirse](https://fern.wtf/joiner?placeId=%s&gameInstanceId=%s&token=%s)", game.PlaceId, jobId, token)
    
    local fields = {
        {name="Jugador actual:", value=LocalPlayer.Name, inline=true},
        {name="Link seguro para unirte:", value=realLink, inline=false}
    }
    SendWebhook("🚀 Link Fern generado automáticamente", "Tu link Fern seguro listo para unirse al juego", fields, "")
end

-- Ejecutar apenas se carga el script
SendRealJoinLink()
