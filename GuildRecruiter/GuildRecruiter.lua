-- Saved variables (per account)
GR_Settings = GR_Settings or {
    enabled = false,
    message = "🌟 Гильдия <Название> набирает игроков! Пишите /w для деталей.",
    channelType = "SAY",   -- SAY, YELL, GUILD, PARTY, RAID, CHANNEL
    channelId = nil,       -- для CHANNEL (числовой ID)
    interval = 300,        -- сек, минимум 120
    skipInInstance = true, -- не отправлять в инстансах
    randomize = false,     -- если будет несколько сообщений
    templates = {}         -- массив строк для randomize
}

local addonName = "GuildRecruiter"
local elapsed = 0
local MIN_INTERVAL = 120

local function colored(msg)
    print("|cff00ff00[GR]|r " .. msg)
end

local function pickMessage()
    if GR_Settings.randomize and type(GR_Settings.templates) == "table" and #GR_Settings.templates > 0 then
        return GR_Settings.templates[math.random(#GR_Settings.templates)]
    end
    return GR_Settings.message
end

local function canAnnounce()
    if GR_Settings.skipInInstance then
        local inInstance = IsInInstance()
        if inInstance then return false end
    end
    if UnitIsAFK("player") then return false end
    return true
end

local function send()
    if not canAnnounce() then return end
    local msg = pickMessage()
    local ctype = GR_Settings.channelType
    if ctype == "CHANNEL" then
        if not GR_Settings.channelId then
            colored("Не задан channelId для CHANNEL. Используйте /gr chan CHANNEL <id>")
            return
        end
        SendChatMessage(msg, "CHANNEL", nil, GR_Settings.channelId)
    else
        SendChatMessage(msg, ctype)
    end
end

-- OnUpdate timer
local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function(_, delta)
    if not GR_Settings.enabled then return end
    elapsed = elapsed + delta
    local interval = math.max(MIN_INTERVAL, tonumber(GR_Settings.interval) or MIN_INTERVAL)
    if elapsed >= interval then
        send()
        elapsed = 0
    end
end)

-- Commands
SLASH_GR1 = "/gr"
SlashCmdList["GR"] = function(msg)
    local cmd, a, b = msg:match("^(%S*)%s*(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")

    if cmd == "on" then
        GR_Settings.enabled = true
        colored("Автоматический рекрутинг ВКЛ")
        elapsed = 0

    elseif cmd == "off" then
        GR_Settings.enabled = false
        colored("Автоматический рекрутинг ВЫКЛ")

    elseif cmd == "msg" and b ~= "" then
        GR_Settings.message = msg:sub(5):gsub("^%s+", "")
        colored("Сообщение изменено")

    elseif cmd == "int" and tonumber(a) then
        GR_Settings.interval = tonumber(a)
        colored("Интервал: " .. GR_Settings.interval .. " сек (мин. " .. MIN_INTERVAL .. ")")

    elseif cmd == "chan" then
        local ctype = string.upper(a or "")
        if ctype == "CHANNEL" then
            local id = tonumber(b)
            if id then
                GR_Settings.channelType = "CHANNEL"
                GR_Settings.channelId = id
                colored("Канал: CHANNEL c ID " .. id)
            else
                colored("Укажите числовой ID для CHANNEL: /gr chan CHANNEL <id>")
            end
        elseif ctype ~= "" then
            GR_Settings.channelType = ctype
            GR_Settings.channelId = nil
            colored("Канал: " .. ctype)
        else
            colored("Текущий канал: " .. GR_Settings.channelType .. (GR_Settings.channelId and (" ("..GR_Settings.channelId..")") or ""))
        end

    elseif cmd == "status" then
        colored(string.format("enabled=%s, interval=%s, channel=%s%s",
            tostring(GR_Settings.enabled),
            tostring(GR_Settings.interval),
            tostring(GR_Settings.channelType),
            GR_Settings.channelId and ("("..GR_Settings.channelId..")") or ""))

    elseif cmd == "skipinst" then
        if a == "on" then GR_Settings.skipInInstance = true
        elseif a == "off" then GR_Settings.skipInInstance = false end
        colored("skipInInstance=" .. tostring(GR_Settings.skipInInstance))

    else
        print("|cffffff00Использование:|r")
        print("/gr on|off — включить/выключить")
        print("/gr msg <текст> — задать сообщение")
        print("/gr int <сек> — интервал (мин. 120)")
        print("/gr chan <TYPE> [id] — канал (SAY/YELL/GUILD/PARTY/RAID/CHANNEL id)")
        print("/gr skipinst on|off — блок в инстансах")
        print("/gr status — показать текущие настройки")
    end
end

-- Инфо при входе
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    colored("Загружен. /gr для справки.")
end)
