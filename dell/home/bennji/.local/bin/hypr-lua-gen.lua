#!/usr/bin/env lua
local home = os.getenv("HOME")
local cfg = assert(loadfile(home .. "/.config/hypr/hyprland.lua"))()
local out = assert(io.open(home .. "/.config/hypr/hyprland.conf", "w"))

out:write("# Auto-generated from hyprland.lua - do not edit directly\n\n")

local function write_list(key, list)
    if not list then return end
    for _, v in ipairs(list) do
        out:write(string.format("%s = %s\n", key, v))
    end
    out:write("\n")
end

local function write_block(name, tbl, indent)
    indent = indent or ""
    out:write(string.format("%s%s {\n", indent, name))
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if #v > 0 then
                for _, item in ipairs(v) do
                    out:write(string.format("%s    %s = %s\n", indent, k, item))
                end
            else
                write_block(k, v, indent .. "    ")
            end
        else
            out:write(string.format("%s    %s = %s\n", indent, k, tostring(v)))
        end
    end
    out:write(string.format("%s}\n\n", indent))
end

write_list("env", cfg.env)
write_list("monitor", cfg.monitor)
write_list("exec-once", cfg.exec_once)

for _, sec in ipairs({ "input", "device", "gestures", "general", "decoration" }) do
    if cfg[sec] then write_block(sec, cfg[sec]) end
end

write_list("bind", cfg.binds)
write_list("bindm", cfg.binds_m)
write_list("bindel", cfg.binds_el)
write_list("bindl", cfg.binds_l)

out:close()
print("Generated ~/.config/hypr/hyprland.conf successfully.")
