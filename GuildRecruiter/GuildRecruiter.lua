-- ==============================
-- GuildRecruiter — Оптимизированная версия
-- ==============================

-- Saved variables (per account)
GR_Settings = GR_Settings or {
    message     = "🌟 Гильдия <Название> набирает игроков! Пишите /w для деталей.",
    channelType = "SAY",     -- SAY, YELL, GUILD, PARTY, RAID, CHANNEL
    channelId   = nil,       -- для CHANNEL (числовой ID)
    randomize   = false,     -- true — брать случайный шаблон
    templates   = {}         -- массив строк для randomize
}

-- ==== Утилиты ====
local function colored(msg)
    print("|cff00ff00[GR]|r " .. msg)
end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeChannelName(name)
    local s = (name ~= nil) and tostring(name) or ""
    return string.lower(
        s:gsub("|c%x%x%x%x%x%x%x%x", "") -- убрать цветовые коды
         :gsub("|r", "")
         :gsub("^%s+", "")
         :gsub("%s+$", "")
    )
end

-- Универсальный обход каналов
local function iterateChannels(callback)
    local chanList = { GetChannelList() }
    local i = 1
    while i <= #chanList do
        local chanId   = chanList[i]
        local chanName = chanList[i + 1]
        local maybeFlg = chanList[i + 2]
        if type(chanId) == "number" and type(chanName) == "string" then
            if callback(chanId, chanName) then
                return true
            end
        end
        i = i + (type(maybeFlg) == "boolean" and 3 or 2)
    end
end

-- ==== Логика ====
local function pickMessage()
    if GR_Settings.randomize and #GR_Settings.templates > 0 then
        return GR_Settings.templates[math.random(#GR_Settings.templates)]
    end
    return GR_Settings.message
end

local function send()
    local msg = pickMessage()
    if GR_Settings.channelType == "CHANNEL" then
        if not GR_Settings.channelId then
            return colored("Не задан channelId для CHANNEL. Используйте: /gru chan CHANNEL <id|name>")
        end
        SendChatMessage(msg, "CHANNEL", nil, GR_Settings.channelId)
    else
        SendChatMessage(msg, GR_Settings.channelType)
    end
end

local function printHelp()
    print("|cffffff00Использование:|r")
    print("/gru msg <текст> — задать сообщение")
    print("/gru chan <TYPE> [id|name] — канал (SAY/YELL/GUILD/PARTY/RAID/CHANNEL)")
    print("/gru random on|off — включить/выключить рандомизацию")
    print("/gru addtmpl <текст> — добавить шаблон")
    print("/gru clrtmpl — очистить шаблоны")
    print("/gru status — текущие настройки")
    print("/gru send — отправить сообщение вручную")
    print("/gru listchannels — показать список подключённых каналов")
end

-- ==== Обработка команд ====
SLASH_GRU1 = "/gru"
SlashCmdList["GRU"] = function(msg)
    local cmd, a, b = msg:match("^(%S*)%s*(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")

    if cmd == "msg" then
        local text = trim((a or "") .. (b ~= "" and (" " .. b) or ""))
        if text ~= "" then
            GR_Settings.message = text
            colored("Сообщение изменено")
        else
            colored("Укажите текст: /gru msg <текст>")
        end

    elseif cmd == "chan" then
        local ctype = string.upper(a or "")
        if ctype == "CHANNEL" then
            local input = trim(b)
            if input == "" then
                return colored("Укажите ID или имя канала: /gru chan CHANNEL <id|name>")
            end
            local id = tonumber(input)
            if id then
                -- Проверим, есть ли такой канал
                local exists
                iterateChannels(function(chanId)
                    if chanId == id then exists = true return true end
                end)
                if exists then
                    GR_Settings.channelType = "CHANNEL"
                    GR_Settings.channelId = id
                    colored("Канал: CHANNEL с ID " .. id)
                else
                    colored("Канал с ID " .. id .. " не найден.")
                end
            else
                local foundId, foundName
                iterateChannels(function(chanId, chanName)
                    if normalizeChannelName(chanName) == normalizeChannelName(input) then
                        foundId, foundName = chanId, chanName
                        return true
                    end
                end)
                if foundId then
                    GR_Settings.channelType = "CHANNEL"
                    GR_Settings.channelId = foundId
                    colored(string.format("Канал: CHANNEL «%s» с ID %d", foundName, foundId))
                else
                    colored("Канал '" .. input .. "' не найден. Сначала присоединитесь: /join " .. input)
                end
            end
        elseif ctype ~= "" then
            GR_Settings.channelType = ctype
            GR_Settings.channelId = nil
            colored("Канал: " .. ctype)
        else
            colored("Текущий канал: " .. tostring(GR_Settings.channelType) ..
                (GR_Settings.channelId and (" (" .. GR_Settings.channelId .. ")") or ""))
        end

    elseif cmd == "random" then
        if a == "on" then
            GR_Settings.randomize = true
        elseif a == "off" then
            GR_Settings.randomize = false
        end
        colored("randomize=" .. tostring(GR_Settings.randomize) ..
                ", шаблонов: " .. #GR_Settings.templates)

    elseif cmd == "addtmpl" then
        local text = trim((a or "") .. (b ~= "" and (" " .. b) or ""))
        if text ~= "" then
            table.insert(GR_Settings.templates, text)
            colored("Шаблон добавлен. Всего: " .. #GR_Settings.templates)
        else
            colored("Укажите текст шаблона: /gru addtmpl <текст>")
        end

    elseif cmd == "clrtmpl" then
        GR_Settings.templates = {}
        colored("Шаблоны очищены")

    elseif cmd == "status" then
        colored(string.format(
            "channel=%s%s, randomize=%s, templates=%d",
            tostring(GR_Settings.channelType),
            GR_Settings.channelId and ("(" .. GR_Settings.channelId .. ")") or "",
            tostring(GR_Settings.randomize),
            #GR_Settings.templates
        ))

    elseif cmd == "send" then
        send()

    elseif cmd == "listchannels" then
        local empty = true
        iterateChannels(function(chanId, chanName)
            if empty then colored("Список каналов:") empty = false end
            print(string.format("[%d] %s", chanId, chanName))
        end)
        if empty then
            colored("Вы не подключены ни к одному пользовательскому каналу.")
        end

    else
        printHelp()
    end
end

-- ==== При входе в игру ====
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    colored("Загружен. /gru для справки.")
end)
