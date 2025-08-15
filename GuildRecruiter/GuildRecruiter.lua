-- ==============================
-- GuildRecruiter — Версия 2.1
-- ==============================

-- Saved variables (per account)
GR_Settings = GR_Settings or {
  message = "🌟 Гильдия Местные Деды набирает игроков! Пишите /w для деталей.",
  channelType = "SAY", -- SAY, YELL, GUILD, PARTY, RAID, CHANNEL
  channelId = nil, -- для CHANNEL (числовой ID)
  randomize = false, -- true — брать случайный шаблон
  templates = {} -- массив строк для randomize
}

-- ==== Локализация/сообщения ====
local MSG = {
  msg_changed = "Сообщение изменено",
  msg_need_text = "Укажите текст: /gru msg <текст>",
  channel_set = "Канал: %s",
  channel_current = "Текущий канал: %s",
  channel_need_input = "Укажите ID или имя канала: /gru chan CHANNEL <id|name>",
  channel_not_found = "Канал '%s' не найден. Сначала присоединитесь: /join %s",
  channel_id_not_found = "Канал с ID %d не найден.",
  random_state = "randomize=%s, шаблонов: %d",
  tmpl_added = "Шаблон добавлен. Всего: %d",
  tmpl_need_text = "Укажите текст шаблона: /gru addtmpl <текст>",
  tmpl_cleared = "Шаблоны очищены",
  no_channels = "Вы не подключены ни к одному пользовательскому каналу.",
  channels_list = "Список каналов:",
  no_channel_id = "Не задан channelId для CHANNEL. Используйте: /gru chan CHANNEL <id|name>",
  send_done = "Сообщение отправлено в %s",
  random_empty_warn = "Включена рандомизация, но шаблонов нет — отключено.",
}

-- ==== Утилиты ====
local function colored(msg) print("|cff00ff00[GR]|r " .. msg) end
local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end
local function normalizeChannelName(name)
  local s = tostring(name or "")
  return s:lower()
    :gsub("|c%x%x%x%x%x%x%x%x", "")
    :gsub("|r", "")
    :gsub("^%s+", "")
    :gsub("%s+$", "")
end
local function iterateChannels(callback)
  local chanList = { GetChannelList() }
  local i = 1
  while i <= #chanList do
    local chanId, chanName, maybeFlg = chanList[i], chanList[i + 1], chanList[i + 2]
    if type(chanId) == "number" and type(chanName) == "string" then
      if callback(chanId, chanName) then return true end
    end
    i = i + (type(maybeFlg) == "boolean" and 3 or 2)
  end
end

-- Склейка аргументов команды
local function concatArgs(a, b) return trim(table.concat({ a or "", b or "" }, " ")) end

-- Поиск канала по ID или имени (один проход)
local function findChannel(input)
  local searchId = tonumber(input)
  local normInput = normalizeChannelName(input)
  local foundId
  iterateChannels(function(chanId, chanName)
    if (searchId and chanId == searchId) or (not searchId and normalizeChannelName(chanName) == normInput) then
      foundId = chanId
      return true
    end
  end)
  return foundId
end

-- Установка типа канала
local function setChannel(ctype, input)
  if ctype == "CHANNEL" then
    if not input or input == "" then return colored(MSG.channel_need_input) end
    local id = findChannel(input)
    if id then
      GR_Settings.channelType = "CHANNEL"
      GR_Settings.channelId = id
      colored(string.format(MSG.channel_set, "CHANNEL (" .. id .. ")"))
    else
      if tonumber(input) then
        colored(string.format(MSG.channel_id_not_found, tonumber(input)))
      else
        colored(string.format(MSG.channel_not_found, input, input))
      end
    end
  else
    GR_Settings.channelType = ctype
    GR_Settings.channelId = nil
    colored(string.format(MSG.channel_set, ctype))
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
    if not GR_Settings.channelId then return colored(MSG.no_channel_id) end
    SendChatMessage(msg, "CHANNEL", nil, GR_Settings.channelId)
    colored(string.format(MSG.send_done, "CHANNEL(" .. GR_Settings.channelId .. ")"))
  else
    SendChatMessage(msg, GR_Settings.channelType)
    colored(string.format(MSG.send_done, GR_Settings.channelType))
  end
end

local function printStatus()
  print("|cffffff00Текущие настройки:|r")
  print(string.format(" Канал: %s%s", tostring(GR_Settings.channelType), GR_Settings.channelId and (" (" .. GR_Settings.channelId .. ")") or ""))
  print(" Рандомизация:", GR_Settings.randomize and "вкл." or "выкл.")
  print(" Шаблонов:", #GR_Settings.templates)
  print(" Сообщение:", GR_Settings.message)
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

-- ==== Команды ====
SLASH_GUILDRECRUITER1 = "/gru"
SlashCmdList["GUILDRECRUITER"] = function(cmd)
  local a, b = cmd:match("^(%S*)%s*(.-)$")
  a = a:lower()

  if a == "msg" then
    if b == "" then return colored(MSG.msg_need_text) end
    GR_Settings.message = b
    colored(MSG.msg_changed)

  elseif a == "chan" then
    local ctype, rest = b:match("^(%S+)%s*(.-)$")
    if not ctype then return colored(MSG.channel_need_input) end
    setChannel(ctype:upper(), rest)

  elseif a == "random" then
    if b == "on" then
      GR_Settings.randomize = true
    elseif b == "off" then
      GR_Settings.randomize = false
    else
      return colored("Используйте: /gru random on|off")
    end
    colored(string.format(MSG.random_state, tostring(GR_Settings.randomize), #GR_Settings.templates))

  elseif a == "addtmpl" then
    if b == "" then
        return colored(MSG.tmpl_need_text)
    end
    -- проверка на дубликаты
    for _, tmpl in ipairs(GR_Settings.templates) do
        if tmpl == b then
            colored("Шаблон уже есть в списке, добавление пропущено.")
            return
        end
    end
    table.insert(GR_Settings.templates, b)
    colored(string.format(MSG.tmpl_added, #GR_Settings.templates))

  elseif a == "clrtmpl" then
    GR_Settings.templates = {}
    colored(MSG.tmpl_cleared)

  elseif a == "status" then
    printStatus()

  elseif a == "send" then
    send()

  elseif a == "help" then
    printHelp()

  elseif a == "listchannels" then
    local found = false
    iterateChannels(function(id, name)
      if not found then
        colored(MSG.channels_list)
        found = true
      end
      print(string.format("  [%d] %s", id, name))
    end)
    if not found then colored(MSG.no_channels) end

  else
    printHelp()
  end
end

-- ==== Инициализация ====
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
  if addon == "GuildRecruiter" then
    GR_Settings.templates = GR_Settings.templates or {}
    colored("GuildRecruiter загружен. Введите /gru help для помощи.")
  end
end)
