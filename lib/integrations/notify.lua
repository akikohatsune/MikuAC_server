local util = require("lib.core.util")

local notify = {}

local function safe_require(name)
  local ok, mod = pcall(require, name)
  if ok then return mod end
  return nil
end

local json = safe_require("dkjson") or safe_require("cjson")

local function curl_post(url, data)
  local cmd = "curl -s -X POST -H 'Content-Type: application/json' -d " .. util.shell_quote(data) .. " " .. util.shell_quote(url) .. " >/dev/null 2>&1"
  os.execute(cmd)
end

local function nonempty(s)
  return s ~= nil and s ~= ""
end

local function load_discord_bot_config(path)
  if not nonempty(path) then return nil end
  if not json or not json.decode then return nil end
  local raw = util.read_file(path)
  if not raw or raw == "" then return nil end
  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then return nil end
  return data
end

local function discord_bot_post(bot_token, channel_id, payload)
  local url = "https://discord.com/api/v10/channels/" .. channel_id .. "/messages"
  local cmd = "curl -s -X POST" ..
    " -H " .. util.shell_quote("Content-Type: application/json") ..
    " -H " .. util.shell_quote("Authorization: Bot " .. bot_token) ..
    " -d " .. util.shell_quote(payload) .. " " .. util.shell_quote(url) .. " >/dev/null 2>&1"
  os.execute(cmd)
end

function notify.send(config, msg)
  if not config.notification or not config.notification.enabled then return end

  if config.notification.telegram and config.notification.telegram.enabled then
    local t = config.notification.telegram
    if t.bot_token ~= "" and t.chat_id ~= "" then
      local url = "https://api.telegram.org/bot" .. t.bot_token .. "/sendMessage"
      local payload = string.format('{"chat_id":"%s","text":%s}', t.chat_id, string.format("%q", msg))
      curl_post(url, payload)
    end
  end

  if config.notification.discord and config.notification.discord.enabled then
    local d = config.notification.discord
    local payload = string.format('{"content":%s}', string.format("%q", msg))
    if nonempty(d.webhook_url) then
      curl_post(d.webhook_url, payload)
      return
    end

    local token = d.bot_token
    local channel_id = d.channel_id
    if (not nonempty(token) or not nonempty(channel_id)) and nonempty(d.config_path) then
      local cfg = load_discord_bot_config(d.config_path)
      if cfg then
        if not nonempty(token) then token = cfg.token end
        if not nonempty(channel_id) then channel_id = cfg.channel_id end
      end
    end

    if nonempty(token) and nonempty(channel_id) then
      discord_bot_post(token, channel_id, payload)
    end
  end
end

function notify.webhook(url, payload)
  if not url or url == "" then return end
  local data
  if type(payload) == "string" then
    data = payload
  elseif json then
    data = json.encode(payload)
  else
    data = string.format("{\"text\":%q}", tostring(payload))
  end
  curl_post(url, data)
end

return notify
