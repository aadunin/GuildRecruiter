-- Saved variables (per account)
GR_Settings = GR_Settings or {
    message = "🌟 Гильдия <Название> набирает игроков! Пишите /w для деталей.",
    channelType = "SAY", -- SAY, YELL, GUILD, PARTY, RAID, CHANNEL
    channelId = nil,     -- для CHANNEL (числовой ID)
    randomize = false,   -- true — брать случайный шаблон
    templates = {}       -- массив строк для randomize
}

local function colored(msg) print("|cff00ff00[GR]|r " .. msg) end
local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

-- 🔹 Нормализация имени канала для сравнения
local function normalizeChannelName(name)
    return string.lower(
        (name or "")
        :gsub("|c%x%x%x%x%x%x%x%x", "") -- убрать цветовые коды
        :gsub("|r", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    )
end

local function pickMessage()
    if GR_Settings.randomize and type(GR_Settings.templates) == "table" and #GR_Settings.templates > 0 then
        return GR_Settings.templates[math.random(#GR_Settings.templates)]
    end
    return GR_Settings.message
end

local function send()
    local msg = pickMessage()
    local ctype = GR_Settings.channelType
    if ctype == "CHANNEL" then
        if not GR_Settings.channelId then
            colored("Не задан channelId для CHANNEL. Используйте: /gru chan CHANNEL <id|name>")
            return
        end
        SendChatMessage(msg, "CHANNEL", nil, GR_Settings.channelId)
    else
        SendChatMessage(msg, ctype)
    end
end

-- Slash-команды
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
            if b ~= "" then
                local id = tonumber(b)
                if id then
                    GR_Settings.channelType = "CHANNEL"
                    GR_Settings.channelId = id
                    colored("Канал: CHANNEL с ID " .. id)
                else
                    local _, name
                    local chanList = {GetChannelList()}
                    for i = 1, #chanList, 2 do
                        local chanId, chanName = chanList[i], chanList[i+1]
                        if chanName and normalizeChannelName(chanName) == normalizeChannelName(b) then
                            id, name = chanId, chanName -- ❗ сохраняем правильное форматирование
                            break
                        end
                    end
                    if id then
                        GR_Settings.channelType = "CHANNEL"
                        GR_Settings.channelId = id
                        colored(string.format("Канал: CHANNEL «%s» с ID %d", name, id))
                    else
                        colored("Канал '" .. b .. "' не найден. Сначала присоединитесь: /join " .. b)
                    end
                end
            else
                colored("Укажите ID или имя канала: /gru chan CHANNEL <id|name>")
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
        colored("randomize=" .. tostring(GR_Settings.randomize))

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

    else
        print("|cffffff00Использование:|r")
        print("/gru msg <текст> — задать сообщение")
        print("/gru chan <TYPE> [id|name] — канал (SAY/YELL/GUILD/PARTY/RAID/CHANNEL)")
        print("/gru random on|off — включить/выключить рандомизацию")
        print("/gru addtmpl <текст> — добавить шаблон")
        print("/gru clrtmpl — очистить шаблоны")
        print("/gru status — текущие настройки")
        print("/gru send — отправить сообщение вручную")
    end
end

-- Инфо при входе
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    colored("Загружен. /gru для справки. Авто-таймеров нет, используйте /gru send.")
end)
