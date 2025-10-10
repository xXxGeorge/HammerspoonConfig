-- 在 Finder 中打开终端的快捷键功能
-- 按 Command + Enter 在当前文件夹打开终端

-- 检查当前应用是否为 Finder
function isFinderActive()
    local app = hs.application.frontmostApplication()
    return app and app:name() == "Finder"
end

-- 在当前目录打开 Terminal
function openTerminalInCurrentDirectory()
    print("使用完整的 AppleScript 方案...")

    -- 使用用户提供的完整 AppleScript 方案
    local appleScript = [[
        tell application "System Events"
            set frontApp to name of first process whose frontmost is true
        end tell

        if frontApp is "Finder" then
            tell application "Finder"
                if (window 1 exists) then
                    set folderPath to (folder of window 1 as alias)'s POSIX path
                else
                    set folderPath to (path to home folder as alias)'s POSIX path
                end if
            end tell

            tell application "Terminal"
                activate
                delay 0.5
                do script "cd " & quoted form of folderPath
            end tell
        else
            -- 如果不是Finder，打开默认Terminal
            tell application "Terminal"
                activate
            end tell
        end if
    ]]

    -- 使用 osascript 执行完整的 AppleScript
    local success, result = hs.osascript.applescript(appleScript)

    if success then
        print("AppleScript 执行成功")
        return true
    else
        print("AppleScript 执行失败: " .. (result or "未知错误"))

        -- 备用方案：直接打开Terminal
        print("使用备用方案打开 Terminal")
        hs.execute("open -a Terminal")
        return false
    end
end

-- 在 Finder 中打开终端的热键函数
function openTerminalInFinder()
    if isFinderActive() then
        openTerminalInCurrentDirectory()
    else
        print("请先激活 Finder 应用")
    end
end

-- 创建热键绑定 (Command + Enter)
local openTerminalHotkey = hs.hotkey.new({"cmd"}, "return", function()
    openTerminalInFinder()
end)

-- 监听应用切换事件
local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
        if appName == "Finder" then
            -- Finder 激活时，启用热键
            openTerminalHotkey:enable()
            print("Finder 快捷键已启用 (Command + Enter)")
        else
            -- 其他应用激活时，禁用热键
            openTerminalHotkey:disable()
        end
    end
end)

-- 初始化函数
function initOpenTerminalShortcut()
    -- 启动应用监听器
    appWatcher:start()

    -- 检查当前是否在 Finder 中，如果是则启用热键
    if isFinderActive() then
        openTerminalHotkey:enable()
        print("Finder 快捷键已启动 (Command + Enter)")
    else
        -- 当前不在 Finder 中，禁用热键
        openTerminalHotkey:disable()
    end
end

-- 启动功能
initOpenTerminalShortcut()

print("Finder 快捷键功能已加载")
print("在 Finder 中使用 Command + Enter 在当前文件夹打开终端")
