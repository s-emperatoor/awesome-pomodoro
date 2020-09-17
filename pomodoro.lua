local wibox = require("wibox")
-- local watch = require("awful.widget.watch")
local gears = require("gears")
local beautiful = require("beautiful")
local awful = require("awful")

local path = awful.util.getdir("config") .."/pomodoro/"
local pomodoro_image_path = awful.util.getdir("config") ..
                                "/pomodoro/pomodoro.png"
-- bonus timer
local bonus

-- values set by user
local pomo_work_time = 2*60
local pomo_break_time = 1*60
local pomo_long_break_time = 1.5*60
local pomo_long_break_occur = 3

-- the time that we use for caounting
local time_sec = 0

-- timeoutes
local work_timeout
local break_timeout
local long_break_timeout

-- intervals
local started = false
local activated = false
local bonused = false
local pomo_interval_work = 0
local pomo_interval_break = 0
local pomo_interval_long_break = 0

-- state 0 = work , 1 = short break , 2 = long break
local pomo_state = 0
-- setup timers

-- END callbacks ###############################

-- widgets ======================================
-- text widget that show the time counter
local time_txt = wibox.widget {font = "play 7",align  = "center", widget = wibox.widget.textbox}
local text_with_background = wibox.container.background(time_txt)
text_with_background.bg = "#f75c7b"
text_with_background.fg = '#000000'
-- image widget that show the pomodoro icon
local pomodoro = wibox.widget {
    image = pomodoro_image_path,
    widget = wibox.widget.imagebox
}

-- combiner of two widget in a flex layaut
local pomodoro_shape = wibox.widget {
    pomodoro,
    text_with_background,
    forced_width = 40,
    layout = wibox.layout.flex.horizontal
}

local pomodoro_widget = wibox.widget{
    text_with_background,
    bg = "#ffffff",
    colors = {"#025c12"},
    thickness = 3,
    start_angle = 3*math.pi/2,
    forced_height = 40,
    forced_width = 40,
    min_value = 0,
    max_value = pomo_work_time,
    value = time_sec,
    widget = wibox.container.arcchart
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
    gears.debug.print_warning("work run")
    time_sec = 0
    pomo_interval_work = pomo_interval_work + 1
    if (pomo_interval_work % pomo_long_break_occur == 0) then
        if not long_break_timer.started then
            long_break_timer:start()
        else
            long_break_timer:again()
        end
        pomo_state = 2
        pomodoro_widget:set_colors({"#ed05af"})
        pomodoro_widget:set_max_value(pomo_long_break_time)
    else
        if not break_timer.started then
            break_timer:start()
        else
            break_timer:again()
        end
        pomo_state = 1
        pomodoro_widget:set_colors({"#e09e04"})
        pomodoro_widget:set_max_value(pomo_break_time)
    end
    bonused = false
end

-- break timeout
break_timeout = function()
    gears.debug.print_warning("break run")
    time_sec = 0
    pomo_state = 0
    pomo_interval_break = pomo_interval_break + 1
    if not work_timer.started then
        work_timer:start()
    else
        work_timer:again()
    end
    pomodoro_widget:set_colors({"#025c12"})
    pomodoro_widget:set_max_value(pomo_work_time)
    bonused = false
end

-- long break timeout
long_break_timeout = function()
    gears.debug.print_warning("long break run")
    time_sec = 0
    pomo_state = 0
    pomo_interval_long_break = pomo_interval_long_break + 1
    if not work_timer.started then
        work_timer:start()
    else
        work_timer:again()
    end
    pomodoro_widget:set_colors({"#025c12"})
    pomodoro_widget:set_max_value(pomo_work_time)
    bonused = false
end
-- END timeout functions #########################

-- callbacks ==================================
-- working callback
work_timer:connect_signal("timeout",work_timeout)

-- short break callback
break_timer:connect_signal("timeout", break_timeout)

-- long break callback
long_break_timer:connect_signal("timeout", long_break_timeout)

-- interavl cllback
interval:connect_signal("timeout", function()
    time_sec = time_sec + 1
    time_txt:set_markup("<span foreground='black' size='small'>"..math.floor(time_sec/60).."</span>"..":".."<span foreground='blue' size='xx-small'>"..(time_sec%60).."</span>")
    pomodoro_widget.value = (time_sec)
    -- gears.debug.print_warning(time)
end)
-- END callback ##################################

-- pomodoro_shape:buttons(awful.util.table.join(awful.button({}, 1,
pomodoro_widget:buttons(awful.util.table.join(awful.button({}, 1,
    function()
        if not started then
            interval:start()
            work_timer:start()
            started = true
            activated = true
            text_with_background.bg = "#91ff96"
        else
            if activated then
                if not bonused then
                    if pomo_state == 0 then
                        work_timer:stop()
                    elseif pomo_state == 1 then
                        break_timer:stop()
                    elseif pomo_state == 2 then
                        long_break_timer:stop()
                    end
                else
                    bonus:stop()
                    bonused = false
                end
                interval:stop()
                text_with_background.bg = "#f75c7b"
                activated = false
            else
                if pomo_state == 0 then
                    local t = pomo_work_time - time_sec
                    bonus = gears.timer({
                        timeout = t,
                        call_now = false,
                        autostart = false,
                        single_shot = true,
                    })
                    bonus:connect_signal("timeout",work_timeout)
                    bonus:start()
                    gears.debug.print_warning("state = 0 bonus run with time : "..t)
                elseif pomo_state == 1 then
                    local t = pomo_break_time - time_sec
                    bonus = gears.timer({
                        timeout = t,
                        call_now = false,
                        autostart = false,
                        single_shot = true,
                    })
                    bonus:connect_signal("timeout",work_timeout)
                    bonus:start()
                    gears.debug.print_warning("state = 1 bonus run with time : "..t)
                elseif pomo_state == 2 then
                    local t = pomo_long_break_time - time_sec
                    bonus = gears.timer({
                        timeout = t,
                        call_now = false,
                        autostart = false,
                        single_shot = true,
                    })
                    bonus:connect_signal("timeout",work_timeout)
                    bonus:start()
                    gears.debug.print_warning("state = 2 bonus run with time : "..t)
                end
                interval:start()
                text_with_background.bg = "#91ff96"
                activated = true
                bonused = true
            end

        end
    end)))

return pomodoro_widget
