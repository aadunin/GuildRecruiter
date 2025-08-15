--[[ 
  GuildRecruiter.lua
  Полностью собранный исправленный вариант
--]]

-- ==== SavedVariables (per account) ====
GR_Settings = GR_Settings or {
  message     = "Гильдия Местные Деды набирает игроков! Пишите /w для деталей.",
  channelType = "SAY",      -- SAY, YELL, GUILD, PARTY, RAID, CHANNEL
  channelId   = nil,        -- для CHANNEL (числовой ID)
  randomize   = false,      -- true — брать случайный шаблон
  templates   = {}          -- массив строк для рандомизации
}

-- ==== Локализация / Сообщения ====
local MSG = {
  msg_changed        = "Сообщение изменено",
  msg_need_text      = "Укажите текст: /gru msg <текст>",
  channel_set        = "Канал: %s",
  channel_need_input = "Укажите ID или имя: /gru chan CHANNEL <id|name>",
  channel_not_found  = "Канал '%s' не найден. Сначала: /join %s",
  channel_id_not_found = "Канал с ID %d не найден.",
  invalid_channel_type = "Неверный тип: %s. Допустимо: SAY, YELL, GUILD, PARTY, RAID, CHANNEL",
  random_state       = "randomize=%s, шаблонов: %d",
  random_usage       = "Используйте: /gru random on|off",
  tmpl_added         = "Шаблон добавлен. Всего: %d",
  tmpl_need_text     = "Укажите текст шаблона: /gru addtmpl <текст>",
  tmpl_exists        = "Шаблон уже есть, пропущено.",
  tmpl_cleared       = "Шаблоны очищены",
  tmpl_list          = "Список шаблонов (%d):",
  tmpl_deleted       = "Шаблон #%d удалён",
  tmpl_deleted_nf    = "Шаблон с индексом %d не найден",
  tmpl_edited        = "Шаблон #%d изменён",
  tmpl_edit_need     = "Использование: /gru edittmpl <номер> <текст>",
  no_channels        = "Вы не подключены ни к одному кастом-каналу.",
  channels_list      = "Список каналов:",
  no_channel_id      = "Не задан channelId для CHANNEL. /gru chan CHANNEL <id|name>",
  send_done          = "Отправлено в %s",
  random_empty_warn  = "Рандомизация включена, но шаблонов нет — отключено."
}

-- ==== Утилиты (должны идти первыми!) ====
local function colored(msg)
  print("|cff00ff00[GR]|r " .. msg)
end

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeChannelName(name)
  local s = tostring(name or "")
  return s:lower()
           :gsub("|c%x%x%x%x%x%x%x%x","")
           :gsub("|r","")
           :gsub("^%s+","")
           :gsub("%s+$","")
end

local function iterateChannels(callback)
  local list = { GetChannelList() }
  local i = 1
  while i <= #list do
    local id, name, flag = list[i], list[i+1], list[i+2]
    if type(id)=="number" and type(name)=="string" then
      if callback(id, name) then return true end
    end
    i = i + (type(flag)=="boolean" and 3 or 2)
  end
end

local function findChannel(input)
  local num  = tonumber(input)
  local norm = normalizeChannelName(input)
  local found
  iterateChannels(function(id, name)
    if (num and id==num) or (not num and normalizeChannelName(name)==norm) then
      found = id
      return true
    end
  end)
  return found
end

-- ==== Рандомизация (очередь + окно повторений) ====
local _queue       = {}
local _pos         = 1
local _recent      = {}
local _window_size = 3

local function initRNG()
  if math.randomseed then
    local seed = time()
    math.randomseed(seed)
    math.random(); math.random(); math.random()
  end
end

local function buildQueue()
  wipe(_queue)
  for i=1,#GR_Settings.templates do
    table.insert(_queue, i)
  end
  -- Фишер–Йейтс
  for i=#_queue,2,-1 do
    local j = math.random(i)
    _queue[i], _queue[j] = _queue[j], _queue[i]
  end
  _pos = 1
  wipe(_recent)
end

local function pickMessage()
  if GR_Settings.randomize then
    if #_queue==0 or _pos>#_queue then
      buildQueue()
    end
    local idx
    repeat
      idx = _queue[_pos]
      _pos = _pos + 1
    until not tContains(_recent, idx) or _pos>#_queue

    table.insert(_recent, idx)
    if #_recent>_window_size then
      table.remove(_recent, 1)
    end
    return GR_Settings.templates[idx]
  end
  return GR_Settings.message
end

-- ==== Установка канала ====
local ALLOWED_TYPES = { SAY=true, YELL=true, GUILD=true, PARTY=true, RAID=true, CHANNEL=true }

local function setChannel(ctype, arg)
  if ctype=="CHANNEL" then
    local key = trim(arg)
    if key=="" then
      return colored(MSG.channel_need_input)
    end
    local id = findChannel(key)
    if id then
      GR_Settings.channelType = "CHANNEL"
      GR_Settings.channelId   = id
      colored(string.format(MSG.channel_set, "CHANNEL("..id..")"))
    else
      if tonumber(key) then
        colored(string.format(MSG.channel_id_not_found, tonumber(key)))
      else
        colored(string.format(MSG.channel_not_found, key, key))
      end
    end
  else
    if not ALLOWED_TYPES[ctype] then
      return colored(string.format(MSG.invalid_channel_type, ctype))
    end
    GR_Settings.channelType = ctype
    GR_Settings.channelId   = nil
    colored(string.format(MSG.channel_set, ctype))
  end
end

-- ==== Отправка сообщения ====
local function send()
  local msg = pickMessage()
  if GR_Settings.channelType=="CHANNEL" then
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

-- ==== CRUD шаблонов ====
local function printTemplates()
  local count = #GR_Settings.templates
  colored(string.format(MSG.tmpl_list, count))
  for i,text in ipairs(GR_Settings.templates) do
    print(string.format(" [%d] %s", i, text))
  end
end

local function deleteTemplate(idx)
  idx = tonumber(idx)
  if not idx or idx<1 or idx>#GR_Settings.templates then
    return colored(string.format(MSG.tmpl_deleted_nf, idx or 0))
  end
  table.remove(GR_Settings.templates, idx)
  colored(string.format(MSG.tmpl_deleted, idx))
end

local function editTemplate(idx,newText)
  idx = tonumber(idx)
  if not idx or idx<1 or idx>#GR_Settings.templates then
    return colored(string.format(MSG.tmpl_deleted_nf, idx or 0))
  end
  GR_Settings.templates[idx] = newText
  colored(string.format(MSG.tmpl_edited, idx))
end

-- ==== Вывод статуса и помощи ====
local function printStatus()
  print("|cffffff00Текущие настройки:|r")
  print(string.format(" Канал: %s%s",
    GR_Settings.channelType,
    GR_Settings.channelId and (" ("..GR_Settings.channelId..")") or ""
  ))
  print(" Рандомизация:", GR_Settings.randomize and "вкл." or "выкл.")
  print(" Шаблонов:", #GR_Settings.templates)
  print(" Сообщение:", GR_Settings.message)
end

local function printHelp()
  print("|cffffff00Использование:|r")
  print("/gru msg <текст> — задать сообщение")
  print("/gru chan <TYPE> [id|name] — канал (SAY/YELL/GUILD/PARTY/RAID/CHANNEL)")
  print("/gru random on|off — вкл/выкл рандомизацию")
  print("/gru addtmpl <текст> — добавить шаблон")
  print("/gru clrtmpl — очистить шаблоны")
  print("/gru listtmpl — показать шаблоны")
  print("/gru deltmpl <номер> — удалить шаблон")
  print("/gru edittmpl <номер> <текст> — редактировать шаблон")
  print("/gru status — показать настройки")
  print("/gru listchannels — список каналов")
  print("/gru send — отправить сообщение")
  print("/gru help — справка")
end

-- ==== Slash-команда ====
SLASH_GUILDRECRUITER1 = "/gru"
SlashCmdList["GUILDRECRUITER"] = function(cmd)
  local cmdName, rest = cmd:match("^(%S*)%s*(.-)$")
  cmdName = (cmdName or ""):lower()

  if cmdName=="msg" then
    rest = trim(rest)
    if rest=="" then return colored(MSG.msg_need_text) end
    GR_Settings.message = rest
    colored(MSG.msg_changed)

  elseif cmdName=="chan" then
    local ctype, arg = rest:match("^(%S+)%s*(.-)$")
    if not ctype or ctype=="" then
      return colored(MSG.channel_need_input)
    end
    setChannel(ctype:upper(), arg)

  elseif cmdName=="random" then
    rest = rest:lower()
    if rest=="on" then GR_Settings.randomize = true
    elseif rest=="off" then GR_Settings.randomize = false
    else return colored(MSG.random_usage) end
    colored(string.format(MSG.random_state, tostring(GR_Settings.randomize), #GR_Settings.templates))

  elseif cmdName=="addtmpl" then
    local text = trim(rest)
    if text=="" then return colored(MSG.tmpl_need_text) end
    for _,v in ipairs(GR_Settings.templates) do
      if v==text then return colored(MSG.tmpl_exists) end
    end
    table.insert(GR_Settings.templates, text)
    colored(string.format(MSG.tmpl_added,#GR_Settings.templates))

  elseif cmdName=="clrtmpl" then
    GR_Settings.templates = {}
    colored(MSG.tmpl_cleared)

  elseif cmdName=="listtmpl" then
    printTemplates()

  elseif cmdName=="deltmpl" then
    if trim(rest)=="" then
      return colored("Укажите номер: /gru deltmpl <номер>")
    end
    deleteTemplate(rest)

  elseif cmdName=="edittmpl" then
    local idx,text = rest:match("^(%S+)%s+(.+)$")
    if not idx or not text then return colored(MSG.tmpl_edit_need) end
    editTemplate(idx,text)

  elseif cmdName=="status" then
    printStatus()

  elseif cmdName=="listchannels" then
    local found = false
    iterateChannels(function(id,name)
      if not found then
        colored(MSG.channels_list)
        found = true
      end
      print(string.format(" [%d] %s", id, name))
    end)
    if not found then colored(MSG.no_channels) end

  elseif cmdName=="send" then
    send()

  else
    printHelp()
  end
end

-- ==== Инициализация (ADDON_LOADED) ====
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
  if addon=="GuildRecruiter" then
    initRNG()
    GR_Settings.templates = GR_Settings.templates or {}
    colored("GuildRecruiter загружен. Введите /gru help для справки.")
  end
end)
