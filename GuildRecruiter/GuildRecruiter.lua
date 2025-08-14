-- ==============================
-- GuildRecruiter — Версия 2.0
-- ==============================

-- Saved variables (per account)
GR_Settings = GR_Settings or {
    message     = "🌟 Гильдия <Название> набирает игроков! Пишите /w для деталей.",
    channelType = "SAY",     -- SAY, YELL, GUILD, PARTY, RAID, CHANNEL
    channelId   = nil,       -- для CHANNEL (числовой ID)
    randomize   = false,     -- true — брать случайный шаблон
    templates   = {}         -- массив строк для randomize
}

-- ==== Локализация/сообщения ====
local MSG = {
    msg_changed        = "Сообщение изменено",
    msg_need_text      = "Укажите текст: /gru msg <текст>",
    channel_set        = "Канал: %s",
    channel_current    = "Текущий канал: %s",
    channel_need_input = "Укажите ID или имя канала: /gru chan CHANNEL <id|name>",
    channel_not_found  = "Канал '%s' не найден. Сначала присоединитесь: /join %s",
    channel_id_not_found = "Канал с ID %d не найден.",
    random_state       = "randomize=%s, шаблонов: %d",
    tmpl_added         = "Шаблон добавлен. Всего: %d",
    tmpl_need_text     = "Укажите текст шаблона: /gru addtmpl <текст>",
    tmpl_cleared       = "Шаблоны очищены",
    no_channels        = "Вы не подключены ни к одному пользовательскому каналу.",
    channels_list      = "Список каналов:",
    no_channel_id      = "Не задан channelId для CHANNEL. Используйте: /gru chan CHANNEL <id|name>",
    send_done          = "Сообщение отправлено в %s",
    random_empty_warn  = "Включена рандомизация, но шаблонов нет — отключено.",
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
        s:gsub("|c%x%x%x%x%x%x%x%x", "")
         :gsub("|r", "")
         :gsub("^%s+", "")
         :gsub("%s+$", "")
    )
end

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

-- Конкатенация аргументов команды
local function concatArgs(a, b)
    return trim((a or "") .. (b ~= "" and (" " .. b) or ""))
end

-- Универсальный поиск канала
local function findChannel(input)
    local id = tonumber(input)
    if id then
        local exists
        iterateChannels(function(chanId)
            if chanId == id then exists = true return true end
        end)
        return exists and id or nil
    else
        local foundId
        iterateChannels(function(chanId, chanName)
            if normalizeChannelName(chanName) == normalizeChannelName(input) then
                foundId = chanId return true
            end
        end)
        return foundId
    end
end

-- ==== Логика ====
local function pickMessage()
    if GR_Settings.randomize then
        if #GR_Settings.templates > 0 then
            return GR_Settings.templates[math.random(#GR_Settings.templates)]
        else
            GR_Settings.randomize = false
            colored(MSG.random_empty_warn)
        end
    end
    return GR_Settings.message
end

local function send()
    local msg = pickMessage()
    if GR_Settings.channelType == "CHANNEL" then
        if not GR_Settings.channelId then
            return colored(MSG.no_channel_id)
        end
        SendChatMessage(msg, "CHANNEL", nil, GR_Settings.channelId)
        colored(string.format(MSG.send_done, "CHANNEL("..GR_Settings.channelId..")"))
    else
        SendChatMessage(msg, GR_Settings.channelType)
        colored(string.format(MSG.send_done, GR_Settings.channelType))
    end
end

local function printStatus()
    print("|cffffff00Текущие настройки:|r")
    print(string.format("  Канал: %s%s",
        tostring(GR_Settings.channelType),
        GR_Settings.channelId and (" ("..GR_Settings.channelId..")") or ""))
    print("  Рандомизация:", GR_Settings.randomize and "вкл." or "выкл.")
    print("  Шаблонов:", #GR_Settings.templates)
    print("  Сообщение:", GR_Settings.message)
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
        local text = concatArgs(a, b)
        if text ~= "" then
            GR_Settings.message = text
            colored(MSG.msg_changed)
        else
            colored(MSG.msg_need_text)
        end

    elseif cmd == "chan" then
        local ctype = string.upper(a or "")
        if ctype == "CHANNEL" then
            local input = trim(b)
            if input == "" then
                return colored(MSG.channel_need_input)
            end
            local id = findChannel(input)
            if id then
                GR_Settings.channelType = "CHANNEL"
                GR_Settings.channelId = id
                colored(string.format(MSG.channel_set, "CHANNEL ("..id..")"))
            else
                if tonumber(input) then
                    colored(string.format(MSG.channel_id_not_found, tonumber(input)))
                else
                    colored(string.format(MSG.channel_not_found, input, input))
                end
            end
        elseif ctype ~= "" then
            GR_Settings.channelType = ctype
            GR_Settings.channelId = nil
            colored(string.format(MSG.channel_set, ctype))
        else
            colored(string.format(MSG.channel_current,
                tostring(GR_Settings.channelType) ..
                (GR_Settings.channelId and (" ("..GR_Settings.channelId..")") or "")
            ))
        end

    elseif cmd == "random" then
        if a == "on" then
            GR_Settings.randomize = true
        elseif a == "off" then
            GR_Settings.randomize = false
        end
        colored(string.format(MSG.random_state, tostring(GR_Settings.randomize), #GR_Settings.templates))

    elseif cmd == "addtmpl" then
        local text = concatArgs(a, b)
        if text ~= "" then
            -- защита от дубликатов
            for _, tmpl in ipairs(GR_Settings.templates) do
                if tmpl == text then
                    return colored("Такой шаблон уже есть")
                end
            end
            table.insert(GR_Settings.templates, text)
            colored(string.format(MSG.tmpl_added, #GR_Settings.templates))
        else
            colored(MSG.tmpl_need_text)
        end

    elseif cmd == "clrtmpl" then
        GR_Settings.templates = {}
        colored(MSG.tmpl_cleared)

    elseif cmd == "status" then
        printStatus()

    elseif cmd == "send" then
        send()

    elseif cmd == "listchannels" then
        local empty = true
        iterateChannels(function(chanId, chanName)
            if empty then colored(MSG.channels_list) empty = false end
            print(string.format("[%d] %s", chanId, chanName))
        end)
        if empty then
            colored(MSG.no_channels)
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
