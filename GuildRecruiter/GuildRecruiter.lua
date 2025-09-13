--[[ GuildRecruiter.lua
   Полный собранный вариант с выводом служебных сообщений в отдельную вкладку чата
   и командой /gru sysframe <name|index|off> для настройки этой вкладки.
]]

-- ==== SavedVariables (per account) ====
GR_Settings = GR_Settings or {
  message       = "Гильдия Местные Деды набирает игроков! Пишите /w для деталей.",
  channelType   = "SAY",     -- SAY, YELL, GUILD, PARTY, RAID, CHANNEL
  channelId     = nil,       -- для CHANNEL (числовой ID)
  randomize     = false,     -- true — брать случайный шаблон
  windowSize    = 3,         -- длина «скользящего окна» по умолчанию
  templates     = {},        -- массив строк для рандомизации
  weights       = {},        -- (опционально) веса для шаблонов (индекс → вес)
  -- Новые поля для служебной вкладки:
  sysFrameName  = nil,       -- имя вкладки для служебных сообщений (приоритетнее индекса)
  sysFrameIndex = nil        -- индекс вкладки (если имя не задано)
}

-- ==== Локализация / Сообщения ====
local MSG = {
  msg_changed            = "Сообщение изменено",
  msg_need_text          = "Укажите текст: /gru msg <текст>",
  channel_set            = "Канал: %s",
  channel_need_input     = "Укажите ID или имя: /gru chan CHANNEL <id|name>",
  channel_not_found      = "Канал '%s' не найден. Сначала: /join %s",
  channel_id_not_found   = "Канал с ID %d не найден.",
  invalid_channel_type   = "Неверный тип: %s. Допустимо: SAY, YELL, GUILD, PARTY, RAID, CHANNEL",
  random_state           = "randomize=%s, шаблонов: %d",
  random_usage           = "Используйте: /gru random on|off",
  tmpl_added             = "Шаблон добавлен. Всего: %d",
  tmpl_need_text         = "Укажите текст шаблона: /gru addtmpl <текст>",
  tmpl_exists            = "Шаблон уже есть, пропущено.",
  tmpl_cleared           = "Шаблоны очищены",
  tmpl_list              = "Список шаблонов (%d):",
  tmpl_deleted           = "Шаблон #%d удалён",
  tmpl_deleted_nf        = "Шаблон с индексом %d не найден",
  tmpl_edited            = "Шаблон #%d изменён",
  tmpl_edit_need         = "Использование: /gru edittmpl <номер> <текст>",
  no_channels            = "Вы не подключены ни к одному кастом-каналу.",
  channels_list          = "Список каналов:",
  no_channel_id          = "Не задан channelId для CHANNEL. /gru chan CHANNEL <id|name>",
  send_done              = "Отправлено в %s",
  random_empty_warn      = "Рандомизация включена, но шаблонов нет — отключено.",
  sysframe_usage         = "Использование: /gru sysframe <name|index|off>",
  sysframe_set_name      = "Служебная вкладка установлена по имени: %s",
  sysframe_set_index     = "Служебная вкладка установлена по индексу: %d",
  sysframe_off           = "Служебная вкладка: выключено (используется общий чат)",
  sysframe_not_found_idx = "Вкладка с индексом %d не найдена",
  sysframe_not_found_nm  = "Вкладка с именем '%s' не найдена"
}

-- ==== Локализация глобальных API / утилит ====
local _G               = _G
local tinsert          = table.insert
local tremove          = table.remove
local wipe             = _G.wipe or function(t) for k in pairs(t) do t[k]=nil end end
local time             = _G.time
local mrandom          = math.random
local mseed            = math.randomseed
local SendChatMessage  = _G.SendChatMessage
local GetChannelList   = _G.GetChannelList
local GetChatWindowInfo= _G.GetChatWindowInfo
local NUM_CHAT_WINDOWS = _G.NUM_CHAT_WINDOWS or 10
local IsInGuild        = _G.IsInGuild
local UnitInParty      = _G.UnitInParty
local UnitInRaid       = _G.UnitInRaid
local tContains        = _G.tContains or function(t, v)
  for i=1,#t do if t[i]==v then return true end end
end

-- ==== Утилиты (должны идти первыми!) ====
local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeChannelName(name)
  local s = tostring(name or "")
  return s:lower()
          :gsub("|c%x%x%x%x%x%x%x%x", "")
          :gsub("|r", "")
          :gsub("^%s+", "")
          :gsub("%s+$", "")
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

-- Резолвер вкладки для служебных сообщений
local function resolveSysChatFrame()
  -- По имени вкладки (приоритет)
  local name = GR_Settings and GR_Settings.sysFrameName
  if name and name ~= "" then
    for i = 1, NUM_CHAT_WINDOWS do
      local title = GetChatWindowInfo(i)
      if title == name then
        local f = _G["ChatFrame"..i]
        if f and f.AddMessage then return f end
      end
    end
  end
  -- По индексу вкладки
  local idx = GR_Settings and tonumber(GR_Settings.sysFrameIndex)
  if idx and idx >= 1 and idx <= NUM_CHAT_WINDOWS then
    local f = _G["ChatFrame"..idx]
    if f and f.AddMessage then return f end
  end
  return nil
end

-- Вывод служебных сообщений (по вкладке или в общий чат)
local function colored(msg)
  local prefix = "|cff00ff00[GR]|r "
  local f = resolveSysChatFrame()
  if f then
    f:AddMessage(prefix .. msg)
  else
    -- Fallback: в общий чат (может быть перехвачен чат-модами, но это ожидаемо)
    print(prefix .. msg)
  end
end

-- ==== Рандомизация (очередь + окно повторений) ====
local _queue        = {}
local _pos          = 1
local _recent       = {}
local _window_size = GR_Settings.windowSize or 3

local function initRNG()
  if mseed and time then
    mseed(time())
    if mrandom then mrandom(); mrandom(); mrandom() end
  end
end

-- Собираем очередь индексов с учётом весов (если заданы)
local function buildQueue()
  wipe(_queue)
  local tcount  = #GR_Settings.templates
  local weights = GR_Settings.weights or {}

  -- если нет весов — кладём каждый индекс один раз
  local hasWeights = false
  for i=1, tcount do
    if (weights[i] or 0) > 1 then hasWeights = true break end
  end

  if hasWeights then
    for i=1, tcount do
      local w = math.max(weights[i] or 1, 1)
      for _=1, w do tinsert(_queue, i) end
    end
  else
    for i=1, tcount do tinsert(_queue, i) end
  end

  -- Fisher–Yates shuffle
  for i=#_queue,2,-1 do
    local j = mrandom(i)
    _queue[i], _queue[j] = _queue[j], _queue[i]
  end

  _pos = 1
  -- wipe(_recent)
end

local function pickMessage()
  if GR_Settings.randomize then
    if #GR_Settings.templates == 0 then
      GR_Settings.randomize = false
      colored(MSG.random_empty_warn)
      return GR_Settings.message
    end

    if #_queue == 0 or _pos > #_queue then
      buildQueue()
    end

    local idx
    repeat
      idx = _queue[_pos]
      _pos = _pos + 1
    until not tContains(_recent, idx) or _pos > #_queue

    tinsert(_recent, idx)
    if #_recent > _window_size then
      tremove(_recent, 1)
    end

    return GR_Settings.templates[idx]
  end

  return GR_Settings.message
end

-- ==== Установка канала ====
local ALLOWED_TYPES = {
  SAY     = true,
  YELL    = true,
  GUILD   = true,
  PARTY   = true,
  RAID    = true,
  CHANNEL = true
}

local function setChannel(ctype, arg)
  ctype = tostring(ctype or ""):upper()

  if ctype == "CHANNEL" then
    local key = trim(arg)
    if key == "" then
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

  elseif ctype == "GUILD" then
    if not IsInGuild or not IsInGuild() then
      return colored("Нельзя установить канал GUILD: вы не в гильдии.")
    end
    GR_Settings.channelType = "GUILD"
    GR_Settings.channelId   = nil
    colored(string.format(MSG.channel_set, "GUILD"))

  elseif ALLOWED_TYPES[ctype] then
    GR_Settings.channelType = ctype
    GR_Settings.channelId   = nil
    colored(string.format(MSG.channel_set, ctype))

  else
    colored(string.format(MSG.invalid_channel_type, ctype))
  end
end

-- ==== Отправка сообщения ====
local function send()
  local msg   = pickMessage()
  local ctype = GR_Settings.channelType

  if ctype == "GUILD" and (not IsInGuild or not IsInGuild()) then
    return colored("Нельзя отправить: вы не в гильдии.")
  elseif ctype == "PARTY" and (not UnitInParty or not UnitInParty("player")) then
    return colored("Нельзя отправить: вы не в группе.")
  elseif ctype == "RAID" and (not UnitInRaid or not UnitInRaid("player")) then
    return colored("Нельзя отправить: вы не в рейде.")
  end

  if ctype == "CHANNEL" then
    if not GR_Settings.channelId then
      return colored(MSG.no_channel_id)
    end
    SendChatMessage(msg, "CHANNEL", nil, GR_Settings.channelId)
    colored(string.format(MSG.send_done, "CHANNEL("..GR_Settings.channelId..")"))
  else
    SendChatMessage(msg, ctype)
    colored(string.format(MSG.send_done, ctype))
  end
end

-- ==== CRUD шаблонов ====
local function printTemplates()
  local count = #GR_Settings.templates
  colored(string.format(MSG.tmpl_list, count))
  for i, text in ipairs(GR_Settings.templates) do
    colored(string.format(" [%d] %s", i, text))
  end
end

local function deleteTemplate(idx)
  idx = tonumber(idx)
  if not idx or idx<1 or idx>#GR_Settings.templates then
    return colored(string.format(MSG.tmpl_deleted_nf, idx or 0))
  end
  tremove(GR_Settings.templates, idx)
  colored(string.format(MSG.tmpl_deleted, idx))
end

local function editTemplate(idx, newText)
  idx = tonumber(idx)
  if not idx or idx<1 or idx>#GR_Settings.templates then
    return colored(string.format(MSG.tmpl_deleted_nf, idx or 0))
  end
  GR_Settings.templates[idx] = newText
  colored(string.format(MSG.tmpl_edited, idx))
end

-- ==== Вывод статуса и помощи ====
local function printStatus()
  colored("|cffffff00Текущие настройки:|r")
  colored(string.format(" Канал: %s%s",
    GR_Settings.channelType,
    GR_Settings.channelId and (" ("..GR_Settings.channelId..")") or ""
  ))
  colored(" Рандомизация: " .. (GR_Settings.randomize and "вкл." or "выкл."))
  colored(" Размер окна: " .. (_window_size or GR_Settings.windowSize))
  colored(" Шаблонов: " .. #GR_Settings.templates)
  colored(" Сообщение: " .. GR_Settings.message)

  local sysLine = "DEFAULT"
  if GR_Settings.sysFrameName and GR_Settings.sysFrameName ~= "" then
    sysLine = "name="..GR_Settings.sysFrameName
  elseif GR_Settings.sysFrameIndex then
    sysLine = "index="..tostring(GR_Settings.sysFrameIndex)
  end
  colored(" Служебная вкладка: " .. sysLine)
end

local function printHelp()
  colored("|cffffff00Использование:|r")
  colored("/gru msg <текст>       — задать сообщение")
  colored("/gru chan <TYPE> [x]   — канал (SAY/YELL/GUILD/PARTY/RAID/CHANNEL)")
  colored("/gru random on|off     — вкл/выкл рандомизацию")
  colored("/gru window <число>    — установить длину скользящего окна")
  colored("/gru addtmpl <текст>   — добавить шаблон")
  colored("/gru clrtmpl           — очистить шаблоны")
  colored("/gru listtmpl          — показать шаблоны")
  colored("/gru deltmpl <номер>   — удалить шаблон")
  colored("/gru edittmpl <номер> <текст> — редактировать шаблон")
  colored("/gru sysframe <name|index|off> — вкладка для служебных сообщений")
  colored("/gru listchannels      — список каналов")
  colored("/gru status            — показать настройки")
  colored("/gru send              — отправить сообщение")
  colored("/gru help              — справка")
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
    if rest=="on" then
      GR_Settings.randomize = true
      wipe(_queue); wipe(_recent)
    elseif rest=="off" then
      GR_Settings.randomize = false
      wipe(_queue); wipe(_recent)
    else
      return colored(MSG.random_usage)
    end
    colored(string.format(MSG.random_state, tostring(GR_Settings.randomize), #GR_Settings.templates))

  elseif cmdName == "window" then
    local n = tonumber(rest)
    if not n or n < 1 then
      return colored("Укажите положительное число: /gru window <число>")
    end
    GR_Settings.windowSize = n
    _window_size = n
    colored("Размер окна рандомизации установлен на " .. n)
      
  elseif cmdName=="addtmpl" then
    local text = trim(rest)
    if text=="" then return colored(MSG.tmpl_need_text) end
    for _,v in ipairs(GR_Settings.templates) do
      if v==text then return colored(MSG.tmpl_exists) end
    end
    tinsert(GR_Settings.templates, text)
    wipe(_queue); wipe(_recent) -- обновим очередь при следующем выборе
    colored(string.format(MSG.tmpl_added, #GR_Settings.templates))

  elseif cmdName=="clrtmpl" then
    GR_Settings.templates = {}
    wipe(_queue); wipe(_recent)
    colored(MSG.tmpl_cleared)

  elseif cmdName=="listtmpl" then
    printTemplates()

  elseif cmdName=="deltmpl" then
    if trim(rest)=="" then
      return colored("Укажите номер: /gru deltmpl <номер>")
    end
    deleteTemplate(rest)
    wipe(_queue); wipe(_recent)

  elseif cmdName=="edittmpl" then
    local idx, text = rest:match("^(%S+)%s+(.+)$")
    if not idx or not text then
      return colored(MSG.tmpl_edit_need)
    end
    editTemplate(idx, text)
    wipe(_queue); 

  elseif cmdName=="sysframe" then
    local arg = trim(rest)
    if arg=="" then
      return colored(MSG.sysframe_usage)
    end
    if arg:lower()=="off" then
      GR_Settings.sysFrameName  = nil
      GR_Settings.sysFrameIndex = nil
      return colored(MSG.sysframe_off)
    end
    local n = tonumber(arg)
    if n then
      if n>=1 and n<=NUM_CHAT_WINDOWS and _G["ChatFrame"..n] then
        GR_Settings.sysFrameName  = nil
        GR_Settings.sysFrameIndex = n
        return colored(string.format(MSG.sysframe_set_index, n))
      else
        return colored(string.format(MSG.sysframe_not_found_idx, n))
      end
    else
      -- по имени вкладки
      local found
      for i=1, NUM_CHAT_WINDOWS do
        local title = GetChatWindowInfo(i)
        if title == arg then found = i break end
      end
      if found then
        GR_Settings.sysFrameName  = arg
        GR_Settings.sysFrameIndex = nil
        return colored(string.format(MSG.sysframe_set_name, arg))
      else
        return colored(string.format(MSG.sysframe_not_found_nm, arg))
      end
    end

  elseif cmdName=="listchannels" then
    local found = false
    iterateChannels(function(id, name)
      if not found then
        colored(MSG.channels_list)
        found = true
      end
      colored(string.format(" [%d] %s", id, name))
    end)
    if not found then colored(MSG.no_channels) end

  elseif cmdName=="status" then
    printStatus()

  elseif cmdName=="send" then
    send()

  else
    printHelp()
  end
end

-- ==== Инициализация (ADDON_LOADED + PLAYER_LOGIN) ====
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addon)
  if event == "ADDON_LOADED" and addon == "GuildRecruiter" then
    initRNG()
    GR_Settings.templates = GR_Settings.templates or {}
    _window_size = GR_Settings.windowSize or 3

-- === GuildRecruiter: пункт в ПКМ для приглашения в гильдию (отладка) ===
if not GR_ContextMenuInitDone then
    GR_ContextMenuInitDone = true
    print("GR DEBUG: инициализация контекстного меню...")

    -- 1) Регистрируем пункт
    if not UnitPopupButtons["GR_GINVITE"] then
        UnitPopupButtons["GR_GINVITE"] = {
            text = "Пригласить в гильдию (GR)",
            dist = 0,
        }
        print("GR DEBUG: зарегистрирован новый пункт GR_GINVITE")
    else
        print("GR DEBUG: пункт GR_GINVITE уже был зарегистрирован")
    end

    -- 2) Добавляем пункт в несколько меню
    local targets = { "PLAYER", "FRIEND", "PARTY", "RAID_PLAYER", "TARGET", "CHAT_ROSTER" }
    for _, menuName in ipairs(targets) do
        local list = UnitPopupMenus and UnitPopupMenus[menuName]
        if list then
            local exists
            for i = 1, #list do
                if list[i] == "GR_GINVITE" then exists = true break end
            end
            if not exists then
                table.insert(list, #list + 1, "GR_GINVITE")
                print("GR DEBUG: пункт добавлен в меню " .. menuName)
            else
                print("GR DEBUG: пункт уже есть в меню " .. menuName)
            end
        else
            print("GR DEBUG: меню " .. menuName .. " не найдено")
        end
    end

    -- 3) Обработка клика по пункту
    hooksecurefunc("UnitPopup_OnClick", function(self)
        if self.value ~= "GR_GINVITE" then return end
        print("GR DEBUG: выбран пункт GR_GINVITE")

        local ctx = UIDROPDOWNMENU_INIT_MENU
        if not ctx then
            print("GR DEBUG: нет контекста меню")
            return
        end

        -- Пытаемся получить имя
        local name = ctx.name
        if (not name or name == "") and ctx.unit and UnitExists(ctx.unit) then
            local unitName, unitRealm = UnitName(ctx.unit)
            name = (unitRealm and unitRealm ~= "") and (unitName .. "-" .. unitRealm) or unitName
        end
        if not name or name == "" then
            print("GR DEBUG: имя не найдено")
            return
        end

        -- Проверка на самого себя
        local me, myRealm = UnitName("player")
        local meFull = (myRealm and myRealm ~= "") and (me .. "-" .. myRealm) or me
        if name == me or name == meFull then
            print("GR DEBUG: попытка пригласить самого себя")
            return
        end

        -- Проверка гильдии
        if IsInGuild and not IsInGuild() then
            colored("Вы не состоите в гильдии, приглашение невозможно.")
            return
        end

        GuildInvite(name)
        colored("Отправлено приглашение в гильдию: " .. name)
    end)
end

         
  elseif event == "PLAYER_LOGIN" then
    colored("GuildRecruiter загружен. Введите /gru help для справки.")
    self:UnregisterEvent("PLAYER_LOGIN")
  end
end)
