-- 在 Finder 中新建文件的快捷键功能
-- 按 Escape + N 在当前文件夹新建文件

-- 检查当前应用是否为 Finder
function isFinderActive()
    local app = hs.application.frontmostApplication()
    return app and app:name() == "Finder"
end

-- 获取 Finder 当前窗口的路径
function getFinderCurrentPath()
    local appleScript = [[
        tell application "Finder"
            if (count of windows) > 0 then
                return POSIX path of (target of front window as alias)
            else
                return POSIX path of (path to desktop folder)
            end if
        end tell
    ]]

    local success, result = hs.osascript.applescript(appleScript)
    if success and result then
        return result:gsub("%s+$", "") -- 移除末尾空格
    end
    return nil
end

-- 在指定路径创建新文件
function createNewFileAt(path)
    -- 确保路径以 / 结尾
    if not path:match("/$") then
        path = path .. "/"
    end

    -- 生成唯一的文件名
    local baseName = "Untitled"
    local extension = ".txt"
    local fileName = baseName .. extension
    local counter = 1

    while hs.fs.pathToAbsolute(path .. fileName) do
        fileName = baseName .. " " .. counter .. extension
        counter = counter + 1
    end

    local fullPath = path .. fileName

    -- 使用 Lua 创建文件
    local file, err = io.open(fullPath, "w")
    if file then
        file:close()
        print("新文件已创建: " .. fullPath)

        -- 可选：使用 AppleScript 选中新创建的文件
        local selectScript = string.format([[
            tell application "Finder"
                select file "%s"
                activate
            end tell
        ]], fullPath)

        hs.osascript.applescript(selectScript)
        return true
    else
        print("创建文件失败: " .. (err or "未知错误"))
        return false
    end
end

-- 新建文件的热键函数
function newFileInFinder()
    if isFinderActive() then
        local currentPath = getFinderCurrentPath()
        if currentPath then
            createNewFileAt(currentPath)
        else
            print("无法获取 Finder 当前路径")
        end
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

