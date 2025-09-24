-- 在 Finder 中新建文件的快捷键功能
-- 按 Escape + N 在当前文件夹新建文件


-- 检查当前应用是否为 Finder
function isFinderActive()
    local app = hs.application.frontmostApplication()
    return app and app:name() == "Finder"
end

-- 在 Finder 中新建文件（使用纯 AppleScript 实现）
function createNewFileInFinder()
    local appleScript = [[
        tell application "Finder"
            if (count of windows) > 0 then
                set currentFolder to target of front window
                set newFile to make new file at currentFolder
                select newFile
                -- 延迟一小段时间让 Finder 处理选择
                delay 0.1
                return "success"
            else
                return "no_finder_window"
            end if
        end tell
    ]]

    local success, result = hs.osascript.applescript(appleScript)
    if success then
        if result == "success" then
            print("新文件已创建并选中，可以立即重命名")
            -- 尝试自动进入重命名模式
            hs.timer.doAfter(0.2, function()
                hs.osascript.applescript([[
                    tell application "System Events"
                        tell process "Finder"
                            keystroke return
                        end tell
                    end tell
                ]])
            end)
            return true
        elseif result == "no_finder_window" then
            print("没有打开的 Finder 窗口")
            return false
        end
    else
        print("创建文件失败: " .. (result or "未知错误"))
        return false
    end
end

-- 新建文件的热键函数
function newFileInFinder()
    if isFinderActive() then
        createNewFileInFinder()
    else
        print("请先激活 Finder 应用")
    end
end

-- 创建热键绑定
local newFileHotkey = hs.hotkey.new({"escape"}, "n", function()
    newFileInFinder()
end)

-- 监听应用切换事件
local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
        if appName == "Finder" then
            -- Finder 激活时，启用热键
            newFileHotkey:enable()
            print("Finder 新建文件快捷键已启用 (Escape + N)")
        else
            -- 其他应用激活时，禁用热键
            newFileHotkey:disable()
        end
    end
end)

-- 初始化函数
function initNewFileShortcut()
    -- 启动应用监听器
    appWatcher:start()

    -- 检查当前是否在 Finder 中，如果是则启用热键
    if isFinderActive() then
        newFileHotkey:enable()
        print("Finder 新建文件快捷键已启动 (Escape + N)")
    else
        -- 当前不在 Finder 中，禁用热键
        newFileHotkey:disable()
    end
end

-- 启动功能
initNewFileShortcut()

print("Finder 新建文件功能已加载")
print("在 Finder 中使用 Escape + N 在当前文件夹新建文件")

