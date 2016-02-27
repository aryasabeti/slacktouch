print("starting main.lua")

local srv = nil
local button_pin = 6
local pwm_pin = 1
local pwm_timer = 1
local pwm_freq = 500
local pwm_max_bright = 1023
local config = nil -- sensitive data loaded at runtime

function debounce (func)
    local last = 0
    local delay = 200000

    return function (...)
        local now = tmr.now()
        if now - last < delay then return end

        last = now
        return func(...)
    end
end

function jsonify(payload)
  open_brace, close_brace = string.find(payload, '^{.*}')
  return cjson.decode(string.sub(payload, open_brace, close_brace))
end

function on_change()
  debug_message('on_change')
  pwm_fadeout()

  http.post(
    'https://hooks.slack.com/services/' .. config.slack_secret,
    'Content-type: application/json\r\n',
    '{"text": "Fancy a cup of tea?", "icon_emoji": ":tea:", "username": "Tea Time"}',
    function(code, data)
      debug_message("status code: " .. (code or 'nil'))
      debug_message("data: " .. (data or 'nil'))
      debug_message('Tea Time initiated!')
    end
  )
end

function start_server()
  debug_message('server start')
  debug_message(srv)

  if srv then
    srv = nil
  end
  srv = net.createServer(net.TCP, 30)
  srv:listen(80, connect)
  debug_message(srv)
end

function stop_server()
  debug_message('server stop')
  debug_message(srv)
  if srv then
    srv:close()
    srv = nil
  end
  debug_message(srv)
end

function connect(sock)
  sock:on('receive', function(sock, payload)
    if string.match(payload, 'fadeinplease') then
      pwm_fadein()
    end

    if string.match(payload, 'fadeoutplease') then
      pwm_fadeout()
    end
  end)

  sock:on('sent', function(sck)
    sck:close()
  end)
end

function on_start()
  debug_message('on_start')

  debug_message('on_start: reading config')
  file.open('config.json')
  config = cjson.decode(file.read())
  file.close()

  debug_message('on_start: enable pwm')
  pwm.setup(pwm_pin, pwm_freq, 0)
  pwm.start(pwm_pin)

  debug_message('on_start: connecting')
  wifi.sta.config(config.ssid, config.pwd)

  debug_message('on_start: starting server to receive pushes')
  start_server()
end

function pwm_fadein()
  local brightness = pwm.getduty(pwm_pin)

  if brightness >= pwm_max_bright then
    tmr.unregister(pwm_timer)
  else
    pwm.setduty(pwm_pin, brightness + 1)
    tmr.alarm(pwm_timer, 2, tmr.ALARM_SINGLE, pwm_fadein)
  end
end

function pwm_fadeout()
  local brightness = pwm.getduty(pwm_pin)

  if brightness <= 0 then
    tmr.unregister(pwm_timer)
  else
    pwm.setduty(pwm_pin, brightness - 3)
    tmr.alarm(pwm_timer, 2, tmr.ALARM_SINGLE, pwm_fadeout)
  end
end

on_start()
gpio.mode(button_pin, gpio.INT)
gpio.trig(button_pin, 'down', debounce(on_change))
