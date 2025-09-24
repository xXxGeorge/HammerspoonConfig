-- 在 Finder 中打开终端的快捷键功能
-- 按 Command + Enter 在当前文件夹打开终端

-- 检查当前应用是否为 Finder
function isFinderActive()
    local app = hs.application.frontmostApplication()
    return app and app:name() == "Finder"
end

-- 获取 Finder 当前文件夹路径
function getFinderCurrentDirectory()
    local appleScript = [[
        tell application "Finder"
            if (count of windows) > 0 then
                set currentFolder to target of front window
                return POSIX path of currentFolder
            else
                return ""
            end if
        end tell
    ]]

    local success, result = hs.osascript.applescript(appleScript)
    if success and result and result ~= "" then
        -- 去除末尾的斜杠（除非是根目录）
        if result ~= "/" then
            result = result:gsub("/$", "")
        end
        return result
    else
        return nil
    end
end

-- 在当前目录打开 Terminal
function openTerminalInCurrentDirectory()
    local currentDir = getFinderCurrentDirectory()

    if currentDir and currentDir ~= "" then
        -- 使用 AppleScript 在指定目录打开新 Terminal 窗口
        local appleScript = string.format([[
            tell application "Terminal"
                -- 创建新窗口并设置工作目录
                set newWindow to do script ""
                do script "cd \"%s\"" in newWindow
                activate
            end tell
        ]], currentDir)

        local success, result = hs.osascript.applescript(appleScript)
        if success then
            print("在目录打开 Terminal 成功: " .. currentDir)
            return true
        else
            print("打开 Terminal 失败: " .. (result or "未知错误"))
            return false
        end
    else
        -- 如果无法获取当前目录，则打开默认 Terminal
        hs.execute("open -a Terminal")
        print("无法获取当前目录，在默认位置打开 Terminal")
        return true
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
