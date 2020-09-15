local wibox = require("wibox")
-- local watch = require("awful.widget.watch")
local gears = require("gears")
local beautiful = require("beautiful")
local awful = require("awful")

local path = awful.util.getdir("config") .."/pomodoro/"
local pomodoro_image_path = awful.util.getdir("config") ..
                                "/pomodoro/pomodoro.png"

-- values set by user
local pomo_work_time = 20
local pomo_break_time = 5
local pomo_long_break_time = 10
local pomo_long_break_occur = 3

-- the time that we use for caounting
local time = 0


-- timeoutes
local work_timeout
local break_timeout
local long_break_timeout

-- intervals
local started = false
local activated = false
local pomo_interval_work = 0
local pomo_interval_break = 0
local pomo_interval_long_break = 0

-- state 0 = work , 1 = short break , 2 = long break
local pomo_state = 0
-- setup timers

-- END callbacks ###############################

-- widgets ======================================
-- text widget that show the time counter
local time_txt = wibox.widget {font = "play 9", widget = wibox.widget.textbox}

-- image widget that show the pomodoro icon
local pomodoro = wibox.widget {
    image = pomodoro_image_path,
    widget = wibox.widget.imagebox
}

-- combiner of two widget in a flex layaut
local pomodoro_shape = wibox.widget {
    pomodoro,
    time_txt,
    forced_width = 40,
    layout = wibox.layout.flex.horizontal
}
-- END widgets ####################################


-- interval for counting seconds in the app
local interval = gears.timer({timeout = 1})

-- timers ===================================
-- working timer
local work_timer = gears.timer({
    timeout = pomo_work_time,
    call_now = false,
    autostart = false,
    single_shot = true
})

-- short break timer
local break_timer = gears.timer({
    timeout = pomo_break_time,
    call_now = false,
    autostart = false,
    single_shot = true
})

-- long break timer
local long_break_timer = gears.timer({
    timeout = pomo_long_break_time,
    call_now = false,
    autostart = false,
    single_shot = true
})
-- END timer ##################################


-- timeout functions ============================
-- work timout
work_timeout = function()
    gears.debug.print_warning("run")
    gears.debug.print_error("run")
    time = 0
    pomo_interval_work = pomo_interval_work + 1
    if (pomo_interval_work % pomo_long_break_occur == 0) then
        long_break_timer:start()
        pomo_state = 2
        pomodoro:set_image(path.."flower.png")
    else
        break_timer:start()
        pomo_state = 1
        pomodoro:set_image(path.."clap.png")
    end
end

-- break timeout
break_timeout = function()
    time = 0
    pomo_state = 0
    pomo_interval_break = pomo_interval_break + 1
    work_timer:start()
    pomodoro:set_image(path.."pomodoro.png")
end

-- long break timeout
long_break_timeout = function()
    time = 0
    pomo_state = 0
    pomo_interval_long_break = pomo_interval_long_break + 1
    work_timer:start()
    pomodoro:set_image(path.."pomodoro.png")
end
-- END timeout functions #########################

-- callbacks ==================================
-- working callback
work_timer:connect_signal("timeout",work_timeout)

-- short break callback 
break_timer:connect_signal("timeout", break_timeout)

-- long break callback
long_break_timer:connect_signal("timeout", long_break_timeout)

interval:connect_signal("timeout", function()
    time = time + 1
    time_txt:set_markup(time)
    -- gears.debug.print_warning(time)
end)
-- END callback ##################################

pomodoro_shape:buttons(awful.util.table.join(awful.button({}, 1,
    function()
        if not started then
            interval:start()
            work_timer:start()
            started = true
            activated = true
        else
            if activated then                
                if pomo_state == 0 then
                    interval:stop()
                    work_timer:stop()
                elseif pomo_state == 1 then
                    interval:stop()
                    break_timer:stop()
                elseif pomo_state == 2 then
                    interval:stop()
                    long_break_timer:stop()
                end
                activated = false
            else
                local bonus
                if pomo_state == 0 then
                    bonus = gears.timer({
                        timeout = pomo_work_time - time,
                        call_now = false,
                        autostart = false,
                        single_shot = true,
                        callback = long_break_timeout
                    })
                    interval:start()
                elseif pomo_state == 1 then
                    bonus = gears.timer({
                        timeout = pomo_break_time - time,
                        call_now = false,
                        autostart = false,
                        single_shot = true,
                        callback = break_timeout
                    })
                    interval:start()
                elseif pomo_state == 2 then
                    bonus = gears.timer({
                        timeout = pomo_long_break_time - time,
                        call_now = false,
                        autostart = false,
                        single_shot = true,
                        callback = long_break_timeout
                    })
                    bonus:start()
                    interval:start()
                end
                bonus:start()
                activated = true
            end
            
        end
    end)))

return pomodoro_shape
