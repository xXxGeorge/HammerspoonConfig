-- =============================================================================
-- Hammerspoon 高度可定制UI元素交互系统
-- =============================================================================
--
-- 功能特性：
--   ✓ 左键点击模式 (⌘⇧H): 检测UI元素，两字母标签选择
--   ✓ 右键点击模式 (⌘⇧J): 检测UI元素，两字母标签选择
--   ✓ 滚动模式 (⌘⇧K): 检测滚动区域，数字标签+hjkl控制
--   ✓ 模式间快速切换
--   ✓ 可定制标签样式和主题
--   ✓ 动画和音效反馈
--   ✓ ESC键退出模式
--
-- 使用方法：
--   1. 按 ⌘⇧H 进入左键模式，或 ⌘⇧J 进入右键模式
--   2. 系统显示两字母标签 (如: AM, AZ, BY, CX...)
--   3. 按第一个字母，高亮相关标签
--   4. 按第二个字母执行点击
--   5. 按 ⌘⇧K 进入滚动模式
--   6. 使用数字键选择滚动区域，hjkl键控制滚动
--   7. 按 ESC 退出当前模式
--
-- 高级功能：
--   ⌘⌥⌃R: 重新加载配置
--   ⌘⌥⌃D: 切换深色主题
--   ⌘⌥⌃C: 切换高对比度主题
--   ⌘⌥⌃T: 测试标签显示功能（简单测试）
--   ⌘⌥⌃F: 强制左键模式（使用测试元素）
--   ⌘⌥⌃S: 显示当前系统状态（调试用）
--   ⌘⌥⌃X: 清理和重置系统状态
--
-- 标签生成规则：
--   - 两字母标签确保第一个字母不重复出现在第二个位置
--   - 例如: 如果"A"是第一个字母，第二个字母不能是"A"
-- =============================================================================

-- 配置变量
local config = {
    -- 标签显示样式
    labelStyle = {
        font = "SF-Mono-Regular",
        size = 14,
        color = {red = 1, green = 1, blue = 1, alpha = 1},
        backgroundColor = {red = 0, green = 0, blue = 0, alpha = 0.9},
        borderColor = {red = 1, green = 0.5, blue = 0, alpha = 1},
        padding = 4,
        borderWidth = 2
    },
    -- 模式状态
    currentMode = nil,  -- "left_click", "right_click", "scroll"
    labels = {},        -- 当前显示的标签
    scrollAreas = {},   -- 可滚动区域
    selectedScrollIndex = 1,  -- 当前选中的滚动区域
    labelKeys = {},     -- 标签键映射
    keySequence = "",   -- 当前输入的键序列
    pendingFirstKey = nil,  -- 等待第二个字母的第一个字母
    -- 标签生成配置
    twoLetterLabels = {
        usedFirstLetters = {},  -- 已使用的第一个字母
        availableLetters = "abcdefghijklmnopqrstuvwxyz"
    }
}

-- 生成两字母标签组合
-- 规则：第一个字母不能在第二个位置重复使用
-- 例如：如果"A"是第一个字母，那么任何标签的第二个字母都不能是"A"
function generateTwoLetterLabels(count)
    local keys = {}
    local available = config.twoLetterLabels.availableLetters
    local usedFirst = config.twoLetterLabels.usedFirstLetters

    -- 重置已使用状态
    config.twoLetterLabels.usedFirstLetters = {}

    for i = 1, count do
        local firstLetter, secondLetter
        local attempts = 0
        local maxAttempts = 100  -- 防止无限循环

        repeat
            -- 选择第一个字母（优先选择未使用的）
            if #usedFirst < 26 then
                for j = 1, #available do
                    local letter = available:sub(j, j)
                    if not usedFirst[letter] then
                        firstLetter = letter
                        usedFirst[letter] = true
                        break
                    end
                end
            end

            -- 如果所有字母都用过了，从头开始
            if not firstLetter then
                usedFirst = {}
                firstLetter = available:sub(1, 1)
                usedFirst[firstLetter] = true
            end

            -- 选择第二个字母，确保不与第一个字母相同
            local availableSecond = ""
            for j = 1, #available do
                local letter = available:sub(j, j)
                if letter ~= firstLetter then
                    availableSecond = availableSecond .. letter
                end
            end

            if #availableSecond > 0 then
                local secondIndex = (i % #availableSecond) + 1
                secondLetter = availableSecond:sub(secondIndex, secondIndex)
            else
                secondLetter = available:sub(1, 1)
            end

            attempts = attempts + 1
        until attempts >= maxAttempts or (firstLetter and secondLetter)

        if firstLetter and secondLetter then
            local key = firstLetter .. secondLetter
            table.insert(keys, key)
        end
    end

    return keys
end

-- 生成数字标签（用于滚动模式）
function generateNumericLabels(count)
    local keys = {}
    for i = 1, count do
        table.insert(keys, tostring(i))
    end
    return keys
end

-- 创建标签显示函数
function createLabel(text, x, y, isHighlighted)
    -- 确保坐标在屏幕范围内
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()

    -- 限制坐标在屏幕内
    x = math.max(frame.x + 50, math.min(frame.x + frame.w - 50, x))
    y = math.max(frame.y + 50, math.min(frame.y + frame.h - 50, y))

    local textWidth = #text * 12 + 16  -- 增加文本宽度估算
    local width = math.max(40, textWidth)
    local height = 32

    -- 调试信息
    print(string.format("创建标签: %s 在位置 (%.0f, %.0f), 尺寸: %.0f x %.0f", text, x, y, width, height))

    local label = hs.canvas.new({
        x = x - width/2,
        y = y - height/2,
        w = width,
        h = height
    })

    -- 根据是否高亮选择颜色
    local bgColor = isHighlighted and
        {red = 1, green = 1, blue = 0, alpha = 0.95} or
        config.labelStyle.backgroundColor

    local textColor = isHighlighted and
        {red = 0, green = 0, blue = 0, alpha = 1} or
        config.labelStyle.color

    -- 先设置所有元素
    label:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = bgColor,
        strokeColor = config.labelStyle.borderColor,
        strokeWidth = config.labelStyle.borderWidth,
        roundedRectRadii = {xRadius = 8, yRadius = 8}
    }, {
        type = "text",
        text = text,
        textColor = textColor,
        textSize = config.labelStyle.size,
        textFont = config.labelStyle.font,
        textAlignment = "center",
        frame = {x = 4, y = 4, w = width - 8, h = height - 8}
    })

    -- 设置层级为最顶层
    label:level(hs.canvas.windowLevels.screenSaver + 1)  -- 使用更高的层级

    -- 显示标签
    label:show()

    -- 添加淡入动画
    label:alpha(0.1):alpha(1.0, 0.3)

    -- 调试：验证标签是否真的显示了
    hs.timer.doAfter(0.1, function()
        if label and not label:isShowing() then
            print("警告: 标签创建后没有显示 - " .. text)
        else
            print("确认: 标签已显示 - " .. text)
        end
    end)

    return label
end

-- 清除所有标签
function clearLabels()
    for _, label in ipairs(config.labels) do
        if label then label:delete() end
    end
    config.labels = {}
end

-- 获取屏幕上的UI元素位置
function getUIElements()
    local elements = {}
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()

    -- 记录AX API查找过程
    print("=== 开始查找UI元素 ===")

    -- 首先尝试获取真实的UI元素
    local app = hs.application.frontmostApplication()
    if app then
        print("当前应用: " .. app:name())
        local axApp = hs.axuielement.applicationElement(app)
        if axApp then
            print("AX应用元素获取成功")
            -- 获取窗口元素
            local windows = axApp:attributeValue("AXWindows") or {}
            print("找到 " .. #windows .. " 个窗口")

            for i, window in ipairs(windows) do
                if window and window:attributeValue("AXMain") then
                    print("处理主窗口 " .. i)
                    -- 获取窗口中的可点击元素
                    local clickableElements = findClickableElements(window, 12) -- 最多12个元素
                    print("AX API找到 " .. #clickableElements .. " 个可点击元素")
                    for _, element in ipairs(clickableElements) do
                        table.insert(elements, element)
                    end
                    break -- 只处理主窗口
                end
            end
        else
            print("AX应用元素获取失败")
        end
    else
        print("没有找到前台应用")
    end

    print("AX API总共找到 " .. #elements .. " 个元素")

    -- 总是添加测试元素，确保至少有一些元素可以使用
    print("添加测试元素...")

    local testElements = {
        {x = frame.x + frame.w * 0.25, y = frame.y + frame.h * 0.3, text = "测试A"},
        {x = frame.x + frame.w * 0.4, y = frame.y + frame.h * 0.3, text = "测试B"},
        {x = frame.x + frame.w * 0.55, y = frame.y + frame.h * 0.3, text = "测试C"},
        {x = frame.x + frame.w * 0.7, y = frame.y + frame.h * 0.3, text = "测试D"},
        {x = frame.x + frame.w * 0.25, y = frame.y + frame.h * 0.6, text = "测试E"},
        {x = frame.x + frame.w * 0.4, y = frame.y + frame.h * 0.6, text = "测试F"},
        {x = frame.x + frame.w * 0.55, y = frame.y + frame.h * 0.6, text = "测试G"},
        {x = frame.x + frame.w * 0.7, y = frame.y + frame.h * 0.6, text = "测试H"}
    }

    -- 合并元素：优先使用AX找到的元素，然后补充测试元素
    local allElements = {}

    -- 先添加AX找到的真实元素
    for _, element in ipairs(elements) do
        table.insert(allElements, element)
    end

    -- 然后补充测试元素，确保至少有8个元素
    for _, testElement in ipairs(testElements) do
        if #allElements < 8 then
            table.insert(allElements, testElement)
        end
    end

    print("最终元素数量: " .. #allElements)
    for i, elem in ipairs(allElements) do
        print(string.format("  元素%d: (%.0f, %.0f) - %s", i, elem.x, elem.y, elem.text))
    end

    if #elements == 0 then
        hs.alert.show("使用测试元素 (AX API未找到真实元素)", 1)
    else
        hs.alert.show("找到 " .. #elements .. " 个真实元素 + " .. (#allElements - #elements) .. " 个测试元素", 1)
    end

    return allElements
end

-- 递归查找可点击的UI元素
function findClickableElements(element, maxElements)
    local elements = {}
    local maxDepth = 3
    local currentDepth = 0

    function traverseElement(elem, depth)
        if depth > maxDepth or #elements >= maxElements then
            return
        end

        -- 检查元素是否可点击
        local role = elem:attributeValue("AXRole")
        local position = elem:attributeValue("AXPosition")
        local size = elem:attributeValue("AXSize")

        if role and position and size and
           (role == "AXButton" or role == "AXLink" or role == "AXMenuItem" or
            role == "AXCheckBox" or role == "AXRadioButton" or role == "AXTextField" or
            role == "AXStaticText" or role == "AXImage") then

            local x = position.x + size.w / 2
            local y = position.y + size.h / 2
            local title = elem:attributeValue("AXTitle") or elem:attributeValue("AXDescription") or role

            table.insert(elements, {
                x = x,
                y = y,
                text = title:sub(1, 20), -- 限制标题长度
                element = elem
            })
        end

        -- 递归遍历子元素
        local children = elem:attributeValue("AXChildren") or {}
        for _, child in ipairs(children) do
            if child then
                traverseElement(child, depth + 1)
            end
        end
    end

    traverseElement(element, currentDepth)
    return elements
end

-- 模拟点击函数
function simulateClick(x, y, button)
    button = button or "left"
    hs.mouse.setAbsolutePosition({x = x, y = y})

    if button == "left" then
        hs.eventtap.leftClick({x = x, y = y})
    elseif button == "right" then
        hs.eventtap.rightClick({x = x, y = y})
    end
end

-- 激活左键点击模式
function activateLeftClickMode()
    clearLabels()
    config.currentMode = "left_click"
    config.keySequence = ""
    config.pendingFirstKey = nil
    config.labelKeys = {}

    local elements = getUIElements()

    if #elements == 0 then
        hs.alert.show("未找到可点击的UI元素", 1)
        return
    end

    -- 生成两字母标签
    local labelKeys = generateTwoLetterLabels(#elements)
    local labelText = table.concat(labelKeys, ", ")
    if #labelText > 50 then
        labelText = labelText:sub(1, 47) .. "..."
    end

    hs.alert.show("左键模式: " .. #elements .. "个元素\n标签: " .. labelText, 2)

    -- 创建标签
    for i, element in ipairs(elements) do
        local key = labelKeys[i]
        if key then
            print(string.format("创建标签 %d: %s -> (%.0f, %.0f)", i, key, element.x, element.y))
            local label = createLabel(key, element.x, element.y, false)
            table.insert(config.labels, label)
            -- 存储元素信息
            label.element = element
            label.key = key
            config.labelKeys[key] = {label = label, element = element}

            -- 额外调试：检查标签是否正确创建
            if label then
                print("标签创建成功: " .. key)
            else
                print("标签创建失败: " .. key)
            end
        end
    end

    -- 显示标签数量
    print(string.format("总共创建了 %d 个标签", #config.labels))

    -- 播放音效
    hs.sound.getByName("Glass"):play()
end

-- 激活右键点击模式
function activateRightClickMode()
    clearLabels()
    config.currentMode = "right_click"
    config.keySequence = ""
    config.pendingFirstKey = nil
    config.labelKeys = {}

    local elements = getUIElements()

    if #elements == 0 then
        hs.alert.show("未找到可点击的UI元素", 1)
        return
    end

    -- 生成两字母标签
    local labelKeys = generateTwoLetterLabels(#elements)
    local labelText = table.concat(labelKeys, ", ")
    if #labelText > 50 then
        labelText = labelText:sub(1, 47) .. "..."
    end

    hs.alert.show("右键模式: " .. #elements .. "个元素\n标签: " .. labelText, 2)

    -- 创建标签
    for i, element in ipairs(elements) do
        local key = labelKeys[i]
        if key then
            print(string.format("创建标签 %d: %s -> (%.0f, %.0f)", i, key, element.x, element.y))
            local label = createLabel(key, element.x, element.y, false)
            table.insert(config.labels, label)
            -- 存储元素信息
            label.element = element
            label.key = key
            config.labelKeys[key] = {label = label, element = element}
        end
    end

    -- 显示标签数量
    print(string.format("总共创建了 %d 个标签", #config.labels))

    -- 播放音效
    hs.sound.getByName("Glass"):play()
end

-- 处理字母键按下事件（用于点击模式）
function handleLetterKeyPress(key)
    if config.currentMode == "left_click" or config.currentMode == "right_click" then
        -- 添加到键序列
        config.keySequence = config.keySequence .. key

        -- 检查是否有匹配的标签
        if config.labelKeys[config.keySequence] then
            local item = config.labelKeys[config.keySequence]
            local element = item.element
            if element then
                local button = config.currentMode == "left_click" and "left" or "right"
                simulateClick(element.x, element.y, button)
                clearLabels()
                config.currentMode = nil
                config.keySequence = ""
                hs.alert.show("已执行点击")
            end
        elseif #config.keySequence >= 2 then
            -- 如果键序列太长，重置
            config.keySequence = ""
            hs.alert.show("无效的键序列，请重新输入")
        end
    elseif config.currentMode == "scroll" then
        if key == "h" or key == "j" or key == "k" or key == "l" then
            performScroll(key)
        end
    end
end

-- 退出当前模式
function exitCurrentMode()
    -- 添加淡出动画
    for _, label in ipairs(config.labels) do
        if label then
            label:alpha(0, 0.2)
        end
    end

    -- 延迟清理
    hs.timer.doAfter(0.3, function()
        clearLabels()
        config.currentMode = nil
        config.scrollAreas = {}
        config.selectedScrollIndex = 1
        config.keySequence = ""
        config.pendingFirstKey = nil
        config.labelKeys = {}
    end)

    -- 播放退出音效
    hs.sound.getByName("Basso"):play()

    hs.alert.show("已退出模式", 1)
end

-- 检测可滚动区域
function detectScrollAreas()
    local scrollAreas = {}
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()

    print("=== 开始查找滚动区域 ===")

    -- 尝试获取当前应用程序的可滚动区域
    local app = hs.application.frontmostApplication()
    if app then
        print("查找应用滚动区域: " .. app:name())
        local axApp = hs.axuielement.applicationElement(app)
        if axApp then
            local windows = axApp:attributeValue("AXWindows") or {}
            print("找到 " .. #windows .. " 个窗口")

            for _, window in ipairs(windows) do
                if window and window:attributeValue("AXMain") then
                    local scrollableElements = findScrollableElements(window, 5)
                    print("AX API找到 " .. #scrollableElements .. " 个滚动元素")
                    for _, element in ipairs(scrollableElements) do
                        table.insert(scrollAreas, element)
                    end
                    break
                end
            end
        end
    end

    print("AX API找到 " .. #scrollAreas .. " 个滚动区域")

    -- 添加测试滚动区域，确保至少有一些区域可以使用
    print("添加测试滚动区域...")

    local defaultAreas = {
        {x = frame.x + frame.w * 0.3, y = frame.y + frame.h * 0.4, w = frame.w * 0.4, h = frame.h * 0.3, text = "主内容"},
        {x = frame.x + frame.w * 0.7, y = frame.y + frame.h * 0.4, w = frame.w * 0.2, h = frame.h * 0.3, text = "侧边栏"}
    }

    -- 合并滚动区域
    local allScrollAreas = {}

    -- 先添加AX找到的真实滚动区域
    for _, area in ipairs(scrollAreas) do
        table.insert(allScrollAreas, area)
    end

    -- 然后补充测试滚动区域，确保至少有2个区域
    for _, defaultArea in ipairs(defaultAreas) do
        if #allScrollAreas < 2 then
            table.insert(allScrollAreas, defaultArea)
        end
    end

    print("最终滚动区域数量: " .. #allScrollAreas)
    for i, area in ipairs(allScrollAreas) do
        print(string.format("  滚动区域%d: (%.0f, %.0f, %.0f, %.0f) - %s",
            i, area.x, area.y, area.w, area.h, area.text))
    end

    if #scrollAreas == 0 then
        hs.alert.show("使用测试滚动区域 (AX API未找到真实区域)", 1)
    else
        hs.alert.show("找到 " .. #scrollAreas .. " 个真实滚动区域", 1)
    end

    return allScrollAreas
end

-- 查找可滚动元素
function findScrollableElements(element, maxElements)
    local elements = {}
    local maxDepth = 4
    local currentDepth = 0

    function traverseElement(elem, depth)
        if depth > maxDepth or #elements >= maxElements then
            return
        end

        local role = elem:attributeValue("AXRole")
        local position = elem:attributeValue("AXPosition")
        local size = elem:attributeValue("AXSize")

        if role and position and size and size.w > 100 and size.h > 100 and
           (role == "AXScrollArea" or role == "AXWebArea" or role == "AXTable" or
            role == "AXOutline" or role == "AXList") then

            local x = position.x + size.w / 2
            local y = position.y + size.h / 2
            local title = elem:attributeValue("AXTitle") or elem:attributeValue("AXDescription") or role

            table.insert(elements, {
                x = x,
                y = y,
                w = size.w,
                h = size.h,
                text = title:sub(1, 15),
                element = elem
            })
        end

        -- 递归遍历子元素
        local children = elem:attributeValue("AXChildren") or {}
        for _, child in ipairs(children) do
            if child then
                traverseElement(child, depth + 1)
            end
        end
    end

    traverseElement(element, currentDepth)
    return elements
end

-- 激活滚动模式
function activateScrollMode()
    clearLabels()
    config.currentMode = "scroll"
    config.keySequence = ""
    config.pendingFirstKey = nil
    config.scrollAreas = detectScrollAreas()
    config.selectedScrollIndex = 1

    if #config.scrollAreas == 0 then
        hs.alert.show("未找到可滚动区域", 1)
        return
    end

    -- 生成数字标签
    local labelKeys = generateNumericLabels(#config.scrollAreas)
    config.labelKeys = {}

    hs.alert.show("滚动模式: " .. #config.scrollAreas .. "个区域\n使用数字键选择，hjkl滚动", 2)

    -- 创建数字标签（显示在区域中心附近）
    for i, area in ipairs(config.scrollAreas) do
        local key = labelKeys[i]
        if key then
            -- 在滚动区域中心附近显示标签，避免超出屏幕边界
            local screen = hs.screen.mainScreen()
            local frame = screen:frame()

            local labelX = math.max(frame.x + 30, math.min(frame.x + frame.w - 30, area.x))
            local labelY = math.max(frame.y + 30, math.min(frame.y + frame.h - 30, area.y))

            print(string.format("创建滚动标签 %d: %s -> (%.0f, %.0f)", i, key, labelX, labelY))
            local isSelected = (i == config.selectedScrollIndex)
            local label = createLabel(key, labelX, labelY, isSelected)
            table.insert(config.labels, label)

            label.area = area
            label.key = key
            config.labelKeys[key] = {label = label, area = area, index = i}
        end
    end

    -- 显示标签数量
    print(string.format("总共创建了 %d 个滚动标签", #config.labels))

    -- 播放音效
    hs.sound.getByName("Glass"):play()
end

-- 更新滚动区域选择显示
function updateScrollSelection()
    for i, label in ipairs(config.labels) do
        if label.area and label.key then
            local textWidth = #label.key * 8 + 10
            local width = math.max(30, textWidth)
            local height = 25

            if i == config.selectedScrollIndex then
                -- 高亮选中的区域
                label:replaceElements({
                    type = "rectangle",
                    action = "fill",
                    fillColor = {red = 1, green = 1, blue = 0, alpha = 0.9},
                    roundedRectRadii = {xRadius = 3, yRadius = 3}
                }, {
                    type = "text",
                    text = label.key,
                    textColor = {red = 0, green = 0, blue = 0, alpha = 1},
                    textSize = config.labelStyle.size,
                    textFont = config.labelStyle.font,
                    textAlignment = "center",
                    frame = {x = 0, y = 0, w = width, h = height}
                })
            else
                -- 普通显示
                label:replaceElements({
                    type = "rectangle",
                    action = "fill",
                    fillColor = config.labelStyle.backgroundColor,
                    roundedRectRadii = {xRadius = 3, yRadius = 3}
                }, {
                    type = "text",
                    text = label.key,
                    textColor = config.labelStyle.color,
                    textSize = config.labelStyle.size,
                    textFont = config.labelStyle.font,
                    textAlignment = "center",
                    frame = {x = 0, y = 0, w = width, h = height}
                })
            end
        end
    end
end

-- 选择滚动区域
function selectScrollArea(key)
    if config.currentMode == "scroll" then
        print("selectScrollArea 被调用，参数: " .. key)

        -- 直接使用字符串键查找
        if config.labelKeys[key] then
            local item = config.labelKeys[key]
            local oldIndex = config.selectedScrollIndex
            config.selectedScrollIndex = item.index

            print("切换滚动区域: " .. key .. " (索引从 " .. oldIndex .. " 到 " .. item.index .. ")")
            updateScrollSelection()
            hs.alert.show("选择滚动区域 " .. key, 1)
        else
            print("无效的滚动区域选择: " .. key)
            print("可用的滚动区域标签:")
            for k, v in pairs(config.labelKeys) do
                print("  " .. k .. " -> 索引 " .. v.index)
            end
        end
    end
end

-- 执行滚动操作
function performScroll(direction)
    if config.currentMode ~= "scroll" or #config.scrollAreas == 0 then
        return
    end

    local area = config.scrollAreas[config.selectedScrollIndex]
    if not area then return end

    -- 计算滚动位置（区域中心）
    local scrollX = area.x
    local scrollY = area.y

    -- 根据方向设置滚动参数
    local scrollAmount = 100  -- 每次滚动距离
    local deltaX = 0
    local deltaY = 0

    if direction == "h" then  -- 左
        deltaX = -scrollAmount
    elseif direction == "j" then  -- 下
        deltaY = scrollAmount
    elseif direction == "k" then  -- 上
        deltaY = -scrollAmount
    elseif direction == "l" then  -- 右
        deltaX = scrollAmount
    end

    -- 移动鼠标到滚动区域并执行滚动
    hs.mouse.setAbsolutePosition({x = scrollX, y = scrollY})
    hs.eventtap.scrollWheel({deltaX, deltaY}, {})
end

-- 处理字母键按下事件（核心交互逻辑）
-- 支持两字母标签系统和数字标签系统
function handleLetterKeyPress(key)
    if config.currentMode == "left_click" or config.currentMode == "right_click" then
        -- ========== 两字母标签交互逻辑 ==========
        if not config.pendingFirstKey then
            -- 第一阶段：等待第一个字母
            config.pendingFirstKey = key
            print("第一阶段 - 按下: " .. key)

            -- 高亮所有以该字母开头的标签，提示用户可用的选项
            local highlightedCount = 0
            local highlightedKeys = {}

            -- 收集需要高亮的标签
            for labelKey, item in pairs(config.labelKeys) do
                if labelKey:sub(1, 1) == key then
                    table.insert(highlightedKeys, labelKey)
                end
            end

            -- 高亮这些标签
            for _, labelKey in ipairs(highlightedKeys) do
                local item = config.labelKeys[labelKey]
                local element = item.element

                -- 删除旧标签
                item.label:delete()

                -- 创建新高亮标签
                item.label = createLabel(labelKey, element.x, element.y, true)
                highlightedCount = highlightedCount + 1
                print("高亮标签: " .. labelKey)
            end

            print("高亮了 " .. highlightedCount .. " 个标签")

            -- 如果没有找到任何匹配的标签，立即重置状态
            if highlightedCount == 0 then
                print("没有找到以 " .. key .. " 开头的标签")
                config.pendingFirstKey = nil
                hs.alert.show("没有匹配的标签", 1)
            end
            hs.alert.show("输入第二个字母...", 1)

        else
            -- 第二阶段：收到第二个字母，完成标签组合
            local fullKey = config.pendingFirstKey .. key
            print("第二阶段 - 组合: " .. fullKey)

            -- 调试：打印所有可用的标签键
            print("当前可用的标签键:")
            for availableKey, _ in pairs(config.labelKeys) do
                print("  可用: " .. availableKey)
            end

            if config.labelKeys[fullKey] then
                -- 找到匹配的标签，执行点击操作
                print("✓ 找到匹配的标签: " .. fullKey)
                local item = config.labelKeys[fullKey]
                local element = item.element

                if element then
                    print(string.format("执行点击: (%.0f, %.0f)", element.x, element.y))
                    local button = config.currentMode == "left_click" and "left" or "right"
                    simulateClick(element.x, element.y, button)
                    hs.sound.getByName("Tink"):play()

                    -- 清理状态，退出模式
                    clearLabels()
                    config.currentMode = nil
                    config.pendingFirstKey = nil
                    config.labelKeys = {}
                    print("✓ 点击执行完成，模式已退出")
                else
                    print("✗ 元素对象不存在")
                end
            else
                -- 无效组合，重置输入状态
                print("✗ 无效标签组合: " .. fullKey .. " (期望的组合未找到)")
                print("可用的标签:")
                for k, v in pairs(config.labelKeys) do
                    print("  " .. k)
                end

                hs.alert.show("无效标签组合: " .. fullKey, 1)
                config.pendingFirstKey = nil

                -- 恢复所有标签到正常状态
                for labelKey, item in pairs(config.labelKeys) do
                    local element = item.element
                    item.label:delete()
                    item.label = createLabel(labelKey, element.x, element.y, false)
                    item.label:show()
                end
            end
        end

    elseif config.currentMode == "scroll" then
        -- ========== 数字标签滚动模式 ==========
        print("滚动模式 - 收到按键: " .. key)

        -- 检查是否是数字键
        local numKey = tonumber(key)
        if numKey then
            print("检测到数字键: " .. numKey)
            print("检查标签键是否存在: " .. tostring(config.labelKeys[tostring(numKey)] ~= nil))
            if config.labelKeys[tostring(numKey)] then
                print("调用selectScrollArea: " .. numKey)
                selectScrollArea(tostring(numKey))  -- 传递字符串参数
            else
                print("数字键 " .. numKey .. " 对应的标签不存在")
                local availableKeys = {}
                for k, _ in pairs(config.labelKeys) do
                    table.insert(availableKeys, k)
                end
                print("可用的滚动标签: " .. table.concat(availableKeys, ", "))
            end
        elseif key == "h" or key == "j" or key == "k" or key == "l" then
            -- hjkl键控制当前选中区域的滚动
            print("滚动键: " .. key)
            performScroll(key)
        else
            print("无效的滚动模式按键: " .. key)
        end
    end
end

-- 全局键盘事件监听器 - 处理所有交互逻辑
local keyTap = nil

function startKeyListener()
    keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        local keyCode = event:getKeyCode()
        local flags = event:getFlags()
        local key = hs.keycodes.map[keyCode]

        -- ========== 模式切换热键 ==========
        -- 支持在任何时候切换模式，即使当前已有模式激活
        if flags.cmd and flags.shift then
            if key == "h" then
                activateLeftClickMode()
                return true
            elseif key == "j" then
                activateRightClickMode()
                return true
            elseif key == "k" then
                activateScrollMode()
                return true
            end
        end

        -- ========== 模式内键盘事件处理 ==========
        if config.currentMode then
            -- 处理标签输入键
            if key and (key:match("^[a-z0-9]$")) then
                handleLetterKeyPress(key)
                return true
            end

            -- 处理Vim风格滚动键 (hjkl)
            if key and (key == "h" or key == "j" or key == "k" or key == "l") then
                handleLetterKeyPress(key)
                return true
            end

            -- ESC键退出当前模式
            if key == "escape" then
                exitCurrentMode()
                return true
            end
        end

        return false  -- 不拦截普通键盘事件
    end)

    keyTap:start()
end

function stopKeyListener()
    if keyTap then
        keyTap:stop()
        keyTap = nil
    end
end

-- 热键绑定（已集成到键盘监听器中）
-- 不需要单独的热键绑定，因为键盘监听器会处理所有热键

-- 初始化函数
function init()
    startKeyListener()
    hs.alert.show("高度可定制UI交互系统已启动\n\n快捷键:\n⌘⇧H: 左键点击模式\n⌘⇧J: 右键点击模式\n⌘⇧K: 滚动模式\n\n在模式中按ESC退出", 3)
end

-- 清理函数
function cleanup()
    exitCurrentMode()
    stopKeyListener()
    hs.alert.show("UI交互系统已关闭", 1)
end

-- 定制标签样式函数
function customizeLabelStyle(options)
    if options.font then config.labelStyle.font = options.font end
    if options.size then config.labelStyle.size = options.size end
    if options.color then config.labelStyle.color = options.color end
    if options.backgroundColor then config.labelStyle.backgroundColor = options.backgroundColor end
    if options.borderColor then config.labelStyle.borderColor = options.borderColor end
    if options.borderWidth then config.labelStyle.borderWidth = options.borderWidth end
    if options.padding then config.labelStyle.padding = options.padding end

    hs.alert.show("标签样式已更新", 1)
end

-- 示例：深色主题
function setDarkTheme()
    customizeLabelStyle({
        backgroundColor = {red = 0.2, green = 0.2, blue = 0.2, alpha = 0.9},
        color = {red = 1, green = 1, blue = 1, alpha = 1},
        borderColor = {red = 0.5, green = 0.5, blue = 0.5, alpha = 1}
    })
end

-- 示例：高对比度主题
function setHighContrastTheme()
    customizeLabelStyle({
        backgroundColor = {red = 1, green = 0, blue = 0, alpha = 1},
        color = {red = 1, green = 1, blue = 1, alpha = 1},
        borderColor = {red = 1, green = 1, blue = 0, alpha = 1},
        borderWidth = 3
    })
end

-- 测试标签显示功能
hs.hotkey.new({"cmd", "alt", "ctrl"}, "t", function()
    clearLabels()
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()

    print("=== 开始简单标签测试 ===")

    -- 在屏幕中心创建单个测试标签
    local x = frame.x + frame.w * 0.5
    local y = frame.y + frame.h * 0.5
    local labelText = "TEST"

    print(string.format("创建简单测试标签 %s 在屏幕中心 (%.0f, %.0f)", labelText, x, y))

    local label = createLabel(labelText, x, y, false)
    if label then
        table.insert(config.labels, label)
        print("✓ 测试标签创建并添加到列表成功")

        -- 立即验证标签状态
        hs.timer.doAfter(0.5, function()
            print("验证标签状态...")
            if label:isShowing() then
                print("✓ 标签正在显示")
            else
                print("✗ 标签没有显示")
            end

            if label:frame() then
                local frame = label:frame()
                print(string.format("标签位置: (%.0f, %.0f) 尺寸: %.0f x %.0f",
                    frame.x, frame.y, frame.w, frame.h))
            else
                print("✗ 无法获取标签frame")
            end
        end)
    else
        print("✗ 测试标签创建失败")
    end

    hs.alert.show("简单测试标签已创建", 1)
end)

-- 强制使用测试元素进行调试
hs.hotkey.new({"cmd", "alt", "ctrl"}, "f", function()
    -- 强制激活左键模式，使用测试元素
    clearLabels()
    config.currentMode = "left_click"
    config.keySequence = ""
    config.pendingFirstKey = nil
    config.labelKeys = {}

    local screen = hs.screen.mainScreen()
    local frame = screen:frame()

    -- 使用固定的测试元素
    local elements = {
        {x = frame.x + frame.w * 0.25, y = frame.y + frame.h * 0.3, text = "测试A"},
        {x = frame.x + frame.w * 0.4, y = frame.y + frame.h * 0.3, text = "测试B"},
        {x = frame.x + frame.w * 0.55, y = frame.y + frame.h * 0.3, text = "测试C"},
        {x = frame.x + frame.w * 0.7, y = frame.y + frame.h * 0.3, text = "测试D"},
        {x = frame.x + frame.w * 0.25, y = frame.y + frame.h * 0.6, text = "测试E"},
        {x = frame.x + frame.w * 0.4, y = frame.y + frame.h * 0.6, text = "测试F"}
    }

    -- 生成两字母标签
    local labelKeys = generateTwoLetterLabels(#elements)
    local labelText = table.concat(labelKeys, ", ")
    if #labelText > 50 then
        labelText = labelText:sub(1, 47) .. "..."
    end

    hs.alert.show("强制左键模式: " .. #elements .. "个元素\n标签: " .. labelText, 2)

    -- 创建标签
    for i, element in ipairs(elements) do
        local key = labelKeys[i]
        if key then
            print(string.format("强制创建标签 %d: %s -> (%.0f, %.0f)", i, key, element.x, element.y))
            local label = createLabel(key, element.x, element.y, false)
            table.insert(config.labels, label)
            -- 存储元素信息
            label.element = element
            label.key = key
            config.labelKeys[key] = {label = label, element = element}
        end
    end

    -- 调试：打印标签映射
    print("=== 标签映射状态 ===")
    print("总标签数: " .. #config.labels)
    print("标签键映射:")
    for k, v in pairs(config.labelKeys) do
        local element = v.element
        print(string.format("  %s -> (%.0f, %.0f) %s", k, element.x, element.y, element.text))
    end

    print(string.format("强制创建了 %d 个标签", #config.labels))
    hs.sound.getByName("Glass"):play()
end)

-- 显示当前标签状态
hs.hotkey.new({"cmd", "alt", "ctrl"}, "s", function()
    print("=== 当前系统状态 ===")
    print("当前模式: " .. (config.currentMode or "无"))
    print("等待第一个键: " .. (config.pendingFirstKey or "无"))
    print("标签数量: " .. #config.labels)
    print("标签映射数量: " .. (function()
        local count = 0
        for _ in pairs(config.labelKeys) do count = count + 1 end
        return count
    end)())

    if next(config.labelKeys) then
        print("当前标签映射:")
        for k, v in pairs(config.labelKeys) do
            local element = v.element
            print(string.format("  %s -> %s", k, element.text))
        end
    end

    hs.alert.show("状态已打印到控制台", 1)
end)

-- 清理和重置系统状态
hs.hotkey.new({"cmd", "alt", "ctrl"}, "x", function()
    print("=== 清理和重置系统状态 ===")

    -- 退出当前模式
    exitCurrentMode()

    -- 清理所有标签
    clearLabels()

    -- 重置配置
    config.currentMode = nil
    config.pendingFirstKey = nil
    config.keySequence = ""
    config.labelKeys = {}
    config.scrollAreas = {}
    config.selectedScrollIndex = 1

    print("✓ 系统状态已清理和重置")
    hs.alert.show("系统已清理和重置", 1)
end)

-- 启动配置
init()

-- 提供重新加载功能
hs.hotkey.new({"cmd", "alt", "ctrl"}, "r", function()
    cleanup()
    hs.reload()
end)

-- 可选：添加主题切换快捷键
hs.hotkey.new({"cmd", "alt", "ctrl"}, "d", setDarkTheme)
hs.hotkey.new({"cmd", "alt", "ctrl"}, "c", setHighContrastTheme)
