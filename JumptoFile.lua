-- Finder 快捷跳转功能
-- 只在 Finder 应用中生效的目录快速跳转

-- 检查当前应用是否为 Finder
function isFinderActive()
    local app = hs.application.frontmostApplication()
    return app and app:name() == "Finder"
end

-- 自定义目录映射
local dirs = {
    -- 常用目录
    a= "/Applications",                      -- Applications
    b = "/Users/horatius/.Trash",            -- Bin
    d = "/Users/horatius/Desktop",           -- Desktop
    h = "/Users/horatius",                   -- Home Directory
    l = "/Users/horatius/Downloads",         -- Downloads
    m = "/Users/horatius/Master",            -- Master
    p = "/Users/horatius/Master/Project",     -- Projects
    r = "/Users/horatius/Master/PapLearning/_Reference",  -- Reference
}

-- 创建应用特定的热键绑定
local finderHotkeys = {}

-- 为每个目录创建热键
for key, path in pairs(dirs) do
    -- 创建热键绑定
    local hotkey = hs.hotkey.new({"cmd", "shift"}, key, function()
        -- 再次检查是否在 Finder 中（双重保险）
        if isFinderActive() then
            -- 检查路径是否存在
            if hs.fs.pathToAbsolute(path) then
                -- 使用 AppleScript 让当前 Finder 窗口切换到指定目录
                local appleScript = string.format([[
                    tell application "Finder"
                        if (count of windows) > 0 then
                            set target of front window to POSIX file "%s"
                        else
                            open POSIX file "%s"
                        end if
                        activate
                    end tell
                ]], path, path)

                local success, result = hs.osascript.applescript(appleScript)
                if not success then
                    print("跳转失败: " .. (result or "未知错误"))
                end
            else
                print("路径不存在: " .. path)
            end
        end
    end)

    -- 存储热键引用，以便后续管理
    finderHotkeys[key] = hotkey
end

-- 监听应用切换事件
local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
        if appName == "Finder" then
            -- Finder 激活时，启用所有热键
            for key, hotkey in pairs(finderHotkeys) do
                hotkey:enable()
            end
            print("Finder 快捷跳转已启用")
        else
            -- 其他应用激活时，禁用所有热键
            for key, hotkey in pairs(finderHotkeys) do
                hotkey:disable()
            end
        end
    end
end)

-- 显示可用快捷键的函数
function showFinderShortcuts()
    if isFinderActive() then
        local shortcuts = {}
        for key, path in pairs(dirs) do
            local dirName = hs.fs.pathToName(path)
            table.insert(shortcuts, "⌘⇧" .. key:upper() .. ": " .. dirName)
        end

        local message = "Finder 快捷跳转:\n" .. table.concat(shortcuts, "\n")
        print(message)
    else
        print("请先激活 Finder 应用")
    end
end

-- 添加一个显示快捷键的热键（在 Finder 中）
local showShortcutsHotkey = hs.hotkey.new({"cmd", "shift"}, "/", function()
    if isFinderActive() then
        showFinderShortcuts()
    end
end)

-- 初始化函数
function initFinderShortcuts()
    -- 启动应用监听器
    appWatcher:start()

    -- 检查当前是否在 Finder 中，如果是则启用热键
    if isFinderActive() then
        for key, hotkey in pairs(finderHotkeys) do
            hotkey:enable()
        end
        print("Finder 快捷跳转已启动")
    else
        -- 当前不在 Finder 中，禁用所有热键
        for key, hotkey in pairs(finderHotkeys) do
            hotkey:disable()
        end
    end
end

-- 启动功能
initFinderShortcuts()

-- 可选：添加一个全局热键来显示帮助（无论在哪个应用中）
hs.hotkey.new({"cmd", "alt", "ctrl"}, "f", function()
    showFinderShortcuts()
end)

-- 可选：添加一个静默的全局热键来显示帮助
hs.hotkey.new({"cmd", "alt", "ctrl"}, "g", function()
    if isFinderActive() then
        local shortcuts = {}
        for key, path in pairs(dirs) do
            local dirName = hs.fs.pathToName(path)
            table.insert(shortcuts, "⌘⇧" .. key:upper() .. ": " .. dirName)
        end
        print("Finder 快捷跳转:\n" .. table.concat(shortcuts, "\n"))
    else
        print("请先激活 Finder 应用")
    end
end)

print("Finder 快捷跳转功能已加载")
print("在 Finder 中使用 ⌘⇧ + 字母键跳转到对应目录")
print("使用 ⌘⇧/ 显示所有可用快捷键")
