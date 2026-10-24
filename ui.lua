-- =========================================================================
-- [ GAMESENSE UI LIBRARY + INPUT & CONFIG MANAGER (ui.lua) ]
-- Upload to GitHub and load via: local Library = loadstring(game:HttpGet("RAW_URL"))()
-- =========================================================================

if _G.__GAMESENSE_FULLBUILD_INJECTED__ then
    if _G.__GAMESENSE_FULLBUILD_UNLOAD__ then pcall(_G.__GAMESENSE_FULLBUILD_UNLOAD__) end
    pcall(function()
        for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
            if g.Name == "gamesense" or g.Name == "GS_Chams_Container" then g:Destroy() end
        end
    end)
end
_G.__GAMESENSE_FULLBUILD_INJECTED__ = true

local PH = { alive = true, conns = {}, cleanup = {} }
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local RunService = (function()
    local real = game:GetService("RunService")
    local function wrapSignal(sig)
        return setmetatable({}, {
            __index = function(_, k)
                if k == "Connect" or k == "connect" then
                    return function(_, fn)
                        local c = sig:Connect(fn)
                        PH.conns[#PH.conns + 1] = c
                        return c
                    end
                end
                local v = sig[k]
                if type(v) == "function" then return function(_, ...) return v(sig, ...) end end
                return v
            end,
        })
    end
    return setmetatable({}, {
        __index = function(_, k)
            local v = real[k]
            if typeof(v) == "RBXScriptSignal" then return wrapSignal(v) end
            if type(v) == "function" then return function(_, ...) return v(real, ...) end end
            return v
        end,
        __newindex = function(_, k, v) real[k] = v end,
    })
end)()

local Options, Toggles, Tabs = {}, {}, {}
local SaveManager = {}
local Library = {
    PH = PH,
    RunService = RunService,
    Options = Options,
    Toggles = Toggles,
    Tabs = Tabs,
    SaveManager = SaveManager,
    Font = Enum.Font.Code,
    IsOpen = true,
}

local heldInputs = {}
local function detectSideButton(input)
    local ut, kc = tostring(input.UserInputType), tostring(input.KeyCode)
    if ut:find("MouseButton4") or kc:find("MouseBack") or kc:find("ButtonX1") then return "Mouse4" end
    if ut:find("MouseButton5") or kc:find("MouseForward") or kc:find("ButtonX2") then return "Mouse5" end
    if input.UserInputType == Enum.UserInputType.MouseButton3 then return "Mouse3" end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then return "Mouse2" end
    return nil
end

function Library.IsInputPressed(keyName)
    if not keyName or keyName == "None" or keyName == "" then return false end
    if keyName == "Mouse1" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or (iskeypressed and iskeypressed(0x01)) or false
    elseif keyName == "Mouse2" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or (iskeypressed and iskeypressed(0x02)) or false
    elseif keyName == "Mouse3" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) or (iskeypressed and iskeypressed(0x04)) or false
    elseif keyName == "Mouse4" then
        if iskeypressed then local ok, v = pcall(iskeypressed, 0x05) if ok and v then return true end end
        return heldInputs["Mouse4"] or false
    elseif keyName == "Mouse5" then
        if iskeypressed then local ok, v = pcall(iskeypressed, 0x06) if ok and v then return true end end
        return heldInputs["Mouse5"] or false
    end
    local code = Enum.KeyCode[keyName]
    if code then
        local ok, down = pcall(function() return UserInputService:IsKeyDown(code) end)
        if ok then return down end
    end
    return heldInputs[keyName] or false
end

local GSConfig = { menu_key = 0x2D, MenuColor = { 0, 255, 100, 255 } }
local MenuCol = function() return Color3.fromRGB(GSConfig.MenuColor[1], GSConfig.MenuColor[2], GSConfig.MenuColor[3]) end

local function RGBtoHSV(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local h, s, v = 0, 0, mx
    if mx ~= mn then
        local d = mx - mn
        s = mx == 0 and 0 or (d / mx)
        if mx == r then h = (g - b) / d elseif mx == g then h = 2 + (b - r) / d else h = 4 + (r - g) / d end
        h = (h * 60) % 360 / 360
    end
    return h, s, v
end

local unloaded = false
local menuOpen = { v = true }
local prevCamType = nil
local Connections = {}
local function Track(conn) Connections[#Connections + 1] = conn return conn end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "gamesense"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 100
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then pcall(function() ScreenGui.Parent = LP:WaitForChild("PlayerGui", 5) end) end
Library.DropdownContainer = ScreenGui

local MainFrame = Instance.new("CanvasGroup", ScreenGui)
MainFrame.Name = "Main"
MainFrame.Size = UDim2.new(0, 620, 0, 560)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true

local function isDragType(t) return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch end
local dragState = { on = false, ox = 0, oy = 0 }
Track(UserInputService.InputBegan:Connect(function(input)
    local sb = detectSideButton(input)
    if sb then heldInputs[sb] = true end
    if not isDragType(input.UserInputType) then return end
    if not ScreenGui.Parent or not MainFrame.Parent or MainFrame.GroupTransparency > 0.5 then return end
    local m = input.Position
    local zone = (input.UserInputType == Enum.UserInputType.Touch) and 40 or 18
    if m.X >= MainFrame.AbsolutePosition.X and m.X <= MainFrame.AbsolutePosition.X + MainFrame.AbsoluteSize.X
        and m.Y >= MainFrame.AbsolutePosition.Y and m.Y <= MainFrame.AbsolutePosition.Y + zone then
        dragState.on = true
        dragState.ox = m.X - MainFrame.AbsolutePosition.X
        dragState.oy = m.Y - MainFrame.AbsolutePosition.Y
    end
end))
Track(UserInputService.InputChanged:Connect(function(input)
    if not dragState.on then return end
    local t = input.UserInputType
    if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
    local m, as = input.Position, MainFrame.AbsoluteSize
    MainFrame.Position = UDim2.new(0, (m.X - dragState.ox) + as.X * 0.5, 0, (m.Y - dragState.oy) + as.Y * 0.5)
end))
Track(UserInputService.InputEnded:Connect(function(input)
    local sb = detectSideButton(input)
    if sb then heldInputs[sb] = false end
    if isDragType(input.UserInputType) then dragState.on = false end
end))

for _, c in ipairs({ 12, 61, 43, 43, 43, 61 }) do
    local o = Instance.new("UIStroke", MainFrame)
    o.Color = Color3.fromRGB(c, c, c)
    o.Thickness = 1
end

local AB = Instance.new("Frame", MainFrame)
AB.Size = UDim2.new(1, -14, 0, 2)
AB.Position = UDim2.new(0, 7, 0, 7)
AB.BackgroundTransparency = 1
local AL = Instance.new("Frame", AB)
AL.Size = UDim2.new(0.5, 0, 0, 2)
AL.BorderSizePixel = 0
Instance.new("UIGradient", AL).Color = ColorSequence.new(Color3.fromRGB(76, 204, 112), Color3.fromRGB(204, 227, 53))
local AR = Instance.new("Frame", AB)
AR.Size = UDim2.new(0.5, 0, 0, 2)
AR.Position = UDim2.new(0.5, 0, 0, 0)
AR.BorderSizePixel = 0
Instance.new("UIGradient", AR).Color = ColorSequence.new(Color3.fromRGB(204, 227, 53), Color3.fromRGB(153, 0, 153))

local TabIconArt = {
    "rbxassetid://8547249956", -- 1 AIMBOT
    "rbxassetid://8547254518", -- 2 VISUALS
    "rbxassetid://8547258459", -- 3 SKINS
    "rbxassetid://8547256547", -- 4 MISC
    "floppy",                  -- 5 CONFIG
}
local TabNames = { "legit", "vfx", "skins", "misc", "cfg" }
local TabButtons, TabFrames, TabIconPx = {}, {}, {}
local CurTab = { v = 0 }
local DDStates, KeyPickers = {}, {}
local KeyBindActive, ActivePickerClose = nil, nil

local function CloseAllDDs() for _, state in ipairs(DDStates) do pcall(state.CloseDD) end end
local function CloseAllPickers() if ActivePickerClose then pcall(ActivePickerClose) end ActivePickerClose = nil end

local function BuildTabIcon(parent, art, color)
    if art == "floppy" then
        local holder = Instance.new("Frame", parent)
        holder.Size = UDim2.new(0, 48, 0, 48)
        holder.Position = UDim2.new(0.5, 0, 0.5, 0)
        holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.BackgroundTransparency = 1
        holder.ZIndex = 4
        local body = Instance.new("Frame", holder)
        body.Size = UDim2.new(0.72, 0, 0.72, 0)
        body.Position = UDim2.new(0.5, 0, 0.5, 0)
        body.AnchorPoint = Vector2.new(0.5, 0.5)
        body.BackgroundTransparency = 1
        body.ZIndex = 4
        Instance.new("UICorner", body).CornerRadius = UDim.new(0, 2)
        local bodyS = Instance.new("UIStroke", body)
        bodyS.Color = color
        bodyS.Thickness = 1.4
        local slider = Instance.new("Frame", body)
        slider.Size = UDim2.new(0.45, 0, 0.30, 0)
        slider.Position = UDim2.new(0.5, 0, 0, 0)
        slider.AnchorPoint = Vector2.new(0.5, 0)
        slider.BackgroundTransparency = 1
        slider.ZIndex = 5
        local sliderS = Instance.new("UIStroke", slider)
        sliderS.Color = color
        sliderS.Thickness = 1.2
        local label = Instance.new("Frame", body)
        label.Size = UDim2.new(0.70, 0, 0.50, 0)
        label.Position = UDim2.new(0.5, 0, 0.50, 0)
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.BackgroundTransparency = 1
        label.ZIndex = 5
        local labelS = Instance.new("UIStroke", label)
        labelS.Color = color
        labelS.Thickness = 1.2
        return { bodyS, sliderS, labelS }
    end
    local img = Instance.new("ImageLabel", parent)
    img.Size = UDim2.new(0, 52, 0, 52)
    img.Position = UDim2.new(0.5, 0, 0.5, 0)
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.BackgroundTransparency = 1
    img.Image = art
    img.ImageColor3 = color
    img.ScaleType = Enum.ScaleType.Fit
    img.ZIndex = 4
    return { img }
end

local TAB_W, TAB_H, TAB_STEP = 84, 76, 78
local IconIdle, IconHover = Color3.fromRGB(90, 90, 90), Color3.fromRGB(160, 160, 160)

for i = 1, #TabNames do
    local num, ti = i - 1, i
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0, TAB_W, 0, TAB_H)
    btn.Position = UDim2.new(0, 6, 0, 8 + TAB_STEP * num)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 3
    local iconPx = BuildTabIcon(btn, TabIconArt[i], (num == 0) and Color3.new(1, 1, 1) or IconIdle)
    local fill = Instance.new("Frame", btn)
    fill.Name = "BgFill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    fill.BorderSizePixel = 0
    fill.Visible = (num ~= 0)
    fill.ZIndex = 1
    local rb = Instance.new("Frame", btn)
    rb.Name = "RB"
    rb.Size = UDim2.new(0, 1, 1, 0)
    rb.Position = UDim2.new(1, 0, 0, 0)
    rb.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    rb.BorderSizePixel = 0
    rb.Visible = (num ~= 0)
    rb.ZIndex = 4

    local frame = Instance.new("Frame", MainFrame)
    frame.Size = UDim2.new(1, -104, 1, -24)
    frame.Position = UDim2.new(0, 96, 0, 16)
    frame.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
    frame.BorderSizePixel = 0
    frame.Visible = (num == 0)
    TabButtons[i], TabFrames[i], TabIconPx[i] = btn, frame, iconPx

    local function SetTab(idx, active)
        local b2 = TabButtons[idx]
        local col = active and Color3.new(1, 1, 1) or IconIdle
        for _, p in ipairs(TabIconPx[idx] or {}) do
            if p:IsA("ImageLabel") then p.ImageColor3 = col elseif p:IsA("UIStroke") then p.Color = col else p.BackgroundColor3 = col end
        end
        if b2:FindFirstChild("BgFill") then b2.BgFill.Visible = not active end
        if b2:FindFirstChild("RB") then b2.RB.Visible = not active end
    end
    btn.MouseEnter:Connect(function()
        if CurTab.v ~= num then
            for _, p in ipairs(iconPx) do
                if p:IsA("ImageLabel") then p.ImageColor3 = IconHover elseif p:IsA("UIStroke") then p.Color = IconHover else p.BackgroundColor3 = IconHover end
            end
        end
    end)
    btn.MouseLeave:Connect(function() SetTab(ti, CurTab.v == num) end)
    btn.MouseButton1Click:Connect(function()
        CurTab.v = num
        pcall(CloseAllDDs)
        pcall(CloseAllPickers)
        for j = 1, #TabButtons do TabFrames[j].Visible = (j == ti) SetTab(j, j == ti) end
    end)
end

local TabCols = {}
local function EnsureTabCols(idx)
    if TabCols[idx] then return TabCols[idx] end
    local parent = TabFrames[idx]
    local function makeCol(pos, padL, padR)
        local col = Instance.new("ScrollingFrame", parent)
        col.Size = UDim2.new(0.5, -6, 1, 0)
        col.Position = pos
        col.BackgroundTransparency = 1
        col.BorderSizePixel = 0
        col.ScrollBarThickness = 4
        col.ScrollBarImageColor3 = Color3.fromRGB(65, 65, 65)
        col.AutomaticCanvasSize = Enum.AutomaticSize.Y
        col.CanvasSize = UDim2.new(0, 0, 0, 0)
        local pad = Instance.new("UIPadding", col)
        pad.PaddingTop = UDim.new(0, 14)
        pad.PaddingBottom = UDim.new(0, 10)
        pad.PaddingLeft = UDim.new(0, padL)
        pad.PaddingRight = UDim.new(0, padR)
        local ll = Instance.new("UIListLayout", col)
        ll.Padding = UDim.new(0, 8)
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        return col
    end
    TabCols[idx] = { left = makeCol(UDim2.new(0, 0, 0, 0), 8, 4), right = makeCol(UDim2.new(0.5, 6, 0, 0), 4, 8), leftN = 0, rightN = 0 }
    return TabCols[idx]
end

local function FireCtrl(ctrl, value)
    if ctrl._cb then pcall(ctrl._cb, value) end
    for _, fn in ipairs(ctrl._changed) do pcall(fn, value) end
end

local function MakeColorPickerUI(parent, order, id, opts)
    opts = opts or {}
    local row = opts._reuseRow
    if not row then
        row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order or 0
        row.ZIndex = 2
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = opts.Title or id
        lbl.TextColor3 = Color3.fromRGB(205, 205, 205)
        lbl.Font = Enum.Font.Arial
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 3
    end
    local default = typeof(opts.Default) == "Color3" and opts.Default or Color3.new(1, 1, 1)
    local swatch = Instance.new("TextButton", row)
    swatch.Size = UDim2.new(0, 24, 0, 10)
    swatch.Position = UDim2.new(1, -30, 0.5, -5)
    swatch.BackgroundColor3 = default
    swatch.BorderSizePixel = 0
    swatch.Text = ""
    swatch.ZIndex = 3
    Instance.new("UIStroke", swatch).Color = Color3.fromRGB(12, 12, 12)
    Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 2)

    local popup = Instance.new("Frame", ScreenGui)
    popup.Size = UDim2.new(0, 180, 0, 165)
    popup.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    popup.BorderSizePixel = 0
    popup.ZIndex = 92
    popup.Visible = false
    Instance.new("UIStroke", popup).Color = Color3.fromRGB(12, 12, 12)

    local h, s, v = RGBtoHSV(default.R * 255, default.G * 255, default.B * 255)
    local svArea = Instance.new("Frame", popup)
    svArea.Size = UDim2.new(0, 150, 0, 120)
    svArea.Position = UDim2.new(0, 5, 0, 5)
    svArea.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    svArea.BorderSizePixel = 0
    svArea.ZIndex = 31
    local svTop = Instance.new("UIGradient", svArea)
    svTop.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
    svTop.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    local svBottom = Instance.new("Frame", svArea)
    svBottom.Size = UDim2.new(1, 0, 1, 0)
    svBottom.BackgroundColor3 = Color3.new(0, 0, 0)
    svBottom.BorderSizePixel = 0
    svBottom.ZIndex = 32
    local svBg = Instance.new("UIGradient", svBottom)
    svBg.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0))
    svBg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
    svBg.Rotation = 90
    local svInput = Instance.new("TextButton", svArea)
    svInput.Size = UDim2.new(1, 0, 1, 0)
    svInput.BackgroundTransparency = 1
    svInput.Text = ""
    svInput.ZIndex = 33

    local hueBar = Instance.new("Frame", popup)
    hueBar.Size = UDim2.new(0, 14, 0, 120)
    hueBar.Position = UDim2.new(0, 160, 0, 5)
    hueBar.BorderSizePixel = 0
    hueBar.ZIndex = 31
    local hg = Instance.new("UIGradient", hueBar)
    hg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
        ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
        ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
        ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
    })
    hg.Rotation = 90
    local hueInput = Instance.new("TextButton", hueBar)
    hueInput.Size = UDim2.new(1, 16, 1, 0)
    hueInput.Position = UDim2.new(0, -8, 0, 0)
    hueInput.BackgroundTransparency = 1
    hueInput.Text = ""
    hueInput.ZIndex = 32

    local preview = Instance.new("Frame", popup)
    preview.Size = UDim2.new(0, 170, 0, 22)
    preview.Position = UDim2.new(0, 5, 0, 132)
    preview.BackgroundColor3 = default
    preview.BorderSizePixel = 0
    preview.ZIndex = 31

    local ctrl = { Value = default, _changed = {}, _cb = opts.Callback }
    local function applyVisual()
        local col = Color3.fromHSV(h, s, v)
        ctrl.Value = col
        swatch.BackgroundColor3 = col
        preview.BackgroundColor3 = col
        svArea.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    end
    function ctrl:OnChanged(fn) table.insert(self._changed, fn) return self end
    function ctrl:SetValue(c)
        if typeof(c) ~= "Color3" then return end
        self.Value = c
        h, s, v = RGBtoHSV(c.R * 255, c.G * 255, c.B * 255)
        applyVisual()
        FireCtrl(self, c)
    end

    local function Close() popup.Visible = false ActivePickerClose = nil end
    local held, heldMode = false, "sv"
    local function HandleSV(x, y)
        local ax, ay = svArea.AbsolutePosition.X, svArea.AbsolutePosition.Y
        local aw, ah = svArea.AbsoluteSize.X, svArea.AbsoluteSize.Y
        if aw <= 0 or ah <= 0 then return end
        s = math.clamp((x - ax) / aw, 0, 1)
        v = 1 - math.clamp((y - ay) / ah, 0, 1)
        applyVisual()
    end
    local function HandleHue(_, y)
        local ay, ah = hueBar.AbsolutePosition.Y, hueBar.AbsoluteSize.Y
        if ah <= 0 then return end
        h = math.clamp((y - ay) / ah, 0, 1)
        applyVisual()
    end

    swatch.MouseButton1Click:Connect(function()
        if popup.Visible then Close() return end
        pcall(CloseAllDDs)
        pcall(CloseAllPickers)
        local p = swatch.AbsolutePosition
        popup.Position = UDim2.new(0, p.X - ScreenGui.AbsolutePosition.X, 0, p.Y - ScreenGui.AbsolutePosition.Y + 18)
        popup.Visible = true
        ActivePickerClose = Close
    end)
    svInput.InputBegan:Connect(function(i)
        if isDragType(i.UserInputType) then held = true heldMode = "sv" HandleSV(i.Position.X, i.Position.Y) end
    end)
    hueInput.InputBegan:Connect(function(i)
        if isDragType(i.UserInputType) then held = true heldMode = "hue" HandleHue(i.Position.X, i.Position.Y) end
    end)
    Track(UserInputService.InputEnded:Connect(function(i)
        if isDragType(i.UserInputType) and held then held = false applyVisual() FireCtrl(ctrl, ctrl.Value) end
    end))
    Track(UserInputService.InputChanged:Connect(function(i)
        if not held or not popup.Visible then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            if heldMode == "hue" then HandleHue(i.Position.X, i.Position.Y) else HandleSV(i.Position.X, i.Position.Y) end
        end
    end))
    applyVisual()
    return ctrl, row
end

local function MakeKeyPickerUI(parent, order, id, opts)
    opts = opts or {}
    local row = opts._reuseRow
    if not row then
        row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order or 0
        row.ZIndex = 2
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = opts.Text or id
        lbl.TextColor3 = Color3.fromRGB(205, 205, 205)
        lbl.Font = Enum.Font.Arial
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 3
    end

    local bb = Instance.new("TextButton", row)
    bb.Size = UDim2.new(0.45, 0, 1, 0)
    bb.Position = UDim2.new(0.55, 0, 0, 0)
    bb.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
    bb.BorderSizePixel = 0
    bb.Text = ""
    bb.TextColor3 = Color3.fromRGB(180, 180, 180)
    bb.Font = Enum.Font.Arial
    bb.TextSize = 12
    bb.ZIndex = 3
    Instance.new("UICorner", bb).CornerRadius = UDim.new(0, 2)
    Instance.new("UIStroke", bb).Color = Color3.fromRGB(12, 12, 12)

    local modePopup = Instance.new("Frame", ScreenGui)
    modePopup.Size = UDim2.new(0, 95, 0, 60)
    modePopup.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    modePopup.BorderSizePixel = 0
    modePopup.ZIndex = 80
    modePopup.Visible = false
    Instance.new("UIStroke", modePopup).Color = Color3.fromRGB(12, 12, 12)

    local ctrl = {
        Value = opts.Default or "None",
        Mode = opts.Mode or "Toggle",
        _changed = {},
        _cb = opts.Callback,
        _toggled = false,
        _editing = false,
        _prevSideDown = false,
    }

    local function refreshText()
        if ctrl._editing then
            bb.Text = "Press Key/MB..."
            bb.TextColor3 = Color3.fromRGB(255, 80, 80)
            return
        end
        bb.Text = tostring(ctrl.Value) .. " [" .. tostring(ctrl.Mode) .. "]"
        bb.TextColor3 = Color3.fromRGB(140, 140, 140)
    end

    for idx, mName in ipairs({ "Always", "Toggle", "Hold" }) do
        local ob = Instance.new("TextButton", modePopup)
        ob.Size = UDim2.new(1, 0, 0, 20)
        ob.Position = UDim2.new(0, 0, 0, (idx - 1) * 20)
        ob.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        ob.BorderSizePixel = 0
        ob.Text = "  " .. mName
        ob.TextColor3 = Color3.fromRGB(205, 205, 205)
        ob.Font = Enum.Font.Arial
        ob.TextSize = 12
        ob.TextXAlignment = Enum.TextXAlignment.Left
        ob.ZIndex = 81
        ob.MouseButton1Click:Connect(function()
            ctrl.Mode = mName
            modePopup.Visible = false
            refreshText()
        end)
    end

    function ctrl:OnChanged(fn) table.insert(self._changed, fn) return self end
    function ctrl:SetValue(keyName)
        self.Value = keyName or "None"
        refreshText()
        FireCtrl(self, self.Value)
    end
    function ctrl:GetState()
        local mode = self.Mode or "Toggle"
        if self.Value == "Always" or mode == "Always" then return true end
        if self.Value == "None" or self.Value == "" then return false end
        if mode == "Toggle" then return self._toggled end
        return Library.IsInputPressed(self.Value)
    end

    bb.MouseButton1Click:Connect(function()
        modePopup.Visible = false
        ctrl._editing = true
        KeyBindActive = ctrl
        refreshText()
        task.spawn(function()
            task.wait(0.1)
            while ctrl._editing and PH.alive do
                if iskeypressed then
                    local ok4, m4 = pcall(iskeypressed, 0x05)
                    if ok4 and m4 then
                        ctrl.Value = "Mouse4"
                        ctrl._editing = false
                        KeyBindActive = nil
                        refreshText()
                        FireCtrl(ctrl, ctrl.Value)
                        break
                    end
                    local ok5, m5 = pcall(iskeypressed, 0x06)
                    if ok5 and m5 then
                        ctrl.Value = "Mouse5"
                        ctrl._editing = false
                        KeyBindActive = nil
                        refreshText()
                        FireCtrl(ctrl, ctrl.Value)
                        break
                    end
                end
                task.wait(0.02)
            end
        end)
    end)

    bb.MouseButton2Click:Connect(function()
        if ctrl._editing then return end
        modePopup.Visible = not modePopup.Visible
        if modePopup.Visible then
            local p = bb.AbsolutePosition
            modePopup.Position = UDim2.new(0, p.X - ScreenGui.AbsolutePosition.X, 0, p.Y - ScreenGui.AbsolutePosition.Y + 24)
        end
    end)

    Track(RunService.Heartbeat:Connect(function()
        if ctrl._editing or KeyBindActive then return end
        if ctrl.Value == "Mouse4" or ctrl.Value == "Mouse5" then
            local down = Library.IsInputPressed(ctrl.Value)
            if down and not ctrl._prevSideDown then
                if ctrl.Mode == "Toggle" then
                    ctrl._toggled = not ctrl._toggled
                    FireCtrl(ctrl, ctrl._toggled)
                elseif ctrl.Mode == "Hold" then
                    FireCtrl(ctrl, true)
                end
            elseif not down and ctrl._prevSideDown and ctrl.Mode == "Hold" then
                FireCtrl(ctrl, false)
            end
            ctrl._prevSideDown = down
        end
    end))

    Track(UserInputService.InputBegan:Connect(function(i, gp)
        if ctrl._editing then
            local sb = detectSideButton(i)
            if sb then
                ctrl.Value = sb
                ctrl._editing = false
                KeyBindActive = nil
                refreshText()
                FireCtrl(ctrl, ctrl.Value)
                return
            end
            local kc = i.KeyCode
            if kc ~= Enum.KeyCode.Unknown then
                ctrl.Value = (kc == Enum.KeyCode.Escape) and "None" or tostring(kc):gsub("^Enum%.KeyCode%.", "")
                ctrl._editing = false
                KeyBindActive = nil
                refreshText()
                FireCtrl(ctrl, ctrl.Value)
            end
            return
        end
        if gp or KeyBindActive or ctrl.Value == "Mouse4" or ctrl.Value == "Mouse5" then return end
        local keyName = detectSideButton(i) or (i.KeyCode ~= Enum.KeyCode.Unknown and tostring(i.KeyCode):gsub("^Enum%.KeyCode%.", "")) or nil
        if not keyName or ctrl.Value ~= keyName then return end
        if ctrl.Mode == "Toggle" then
            ctrl._toggled = not ctrl._toggled
            FireCtrl(ctrl, ctrl._toggled)
        elseif ctrl.Mode == "Hold" then
            FireCtrl(ctrl, true)
        end
    end))

    KeyPickers[#KeyPickers + 1] = ctrl
    refreshText()
    return ctrl, row
end

local function BindContainer(frame)
    local n = 0
    local function nextOrder() n = n + 1 return n end
    local api = {}

    function api:AddToggle(id, opts)
        opts = opts or {}
        local row = Instance.new("Frame", frame)
        row.Size = UDim2.new(1, 0, 0, 17)
        row.BackgroundTransparency = 1
        row.LayoutOrder = nextOrder()
        row.ZIndex = 2
        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.ZIndex = 3
        local box = Instance.new("Frame", row)
        box.Size = UDim2.new(0, 9, 0, 9)
        box.Position = UDim2.new(0, 6, 0.5, -4)
        box.BorderSizePixel = 0
        box.ZIndex = 3
        Instance.new("UIStroke", box).Color = Color3.fromRGB(8, 8, 8)
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -60, 1, 0)
        lbl.Position = UDim2.new(0, 24, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = opts.Text or id
        lbl.Font = Enum.Font.Arial
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 3

        local ctrl = { Value = opts.Default and true or false, _changed = {}, _cb = opts.Callback }
        local function sync()
            box.BackgroundColor3 = ctrl.Value and MenuCol() or Color3.fromRGB(56, 56, 56)
            lbl.TextColor3 = ctrl.Value and Color3.fromRGB(225, 225, 225) or Color3.fromRGB(165, 165, 165)
        end
        function ctrl:OnChanged(fn) table.insert(self._changed, fn) return self end
        function ctrl:SetValue(v, skipCb)
            v = v and true or false
            if self.Value == v then return end
            self.Value = v
            sync()
            if not skipCb then FireCtrl(self, v) end
        end
        function ctrl:AddColorPicker(pid, popts)
            popts = popts or {} popts._reuseRow = row
            return api:AddColorPicker(pid, popts)
        end
        function ctrl:AddKeyPicker(pid, popts)
            popts = popts or {} popts._reuseRow = row
            return api:AddKeyPicker(pid, popts)
        end
        btn.MouseButton1Click:Connect(function() ctrl:SetValue(not ctrl.Value) end)
        sync()
        Toggles[id] = ctrl
        return ctrl
    end

    function api:AddSlider(id, opts)
        opts = opts or {}
        local minV, maxV = opts.Min or 0, opts.Max or 100
        if maxV <= minV then maxV = minV + 1 end
        local rounding, suffix = opts.Rounding or 0, opts.Suffix
        local m = 10 ^ rounding
        local def = math.floor(math.clamp(type(opts.Default) == "number" and opts.Default or minV, minV, maxV) * m + 0.5) / m

        local row = Instance.new("Frame", frame)
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundTransparency = 1
        row.LayoutOrder = nextOrder()
        row.ZIndex = 2
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.Position = UDim2.new(0, 3, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = opts.Text or id
        lbl.TextColor3 = Color3.fromRGB(190, 190, 190)
        lbl.Font = Enum.Font.Arial
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 3
        local bar = Instance.new("Frame", row)
        bar.Size = UDim2.new(1, -6, 0, 6)
        bar.Position = UDim2.new(0, 3, 0, 18)
        bar.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
        bar.BorderSizePixel = 0
        bar.ZIndex = 3
        Instance.new("UIStroke", bar).Color = Color3.fromRGB(8, 8, 8)
        local fill = Instance.new("Frame", bar)
        fill.BackgroundColor3 = MenuCol()
        fill.BorderSizePixel = 0
        fill.ZIndex = 4
        local fg = Instance.new("UIGradient", fill)
        fg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
        fg.Rotation = 90
        local val = Instance.new("TextLabel", bar)
        val.Size = UDim2.new(0, 70, 0, 12)
        val.BackgroundTransparency = 1
        val.TextColor3 = Color3.new(1, 1, 1)
        val.Font = Enum.Font.ArialBold
        val.TextSize = 11
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.TextStrokeTransparency = 0.35
        val.ZIndex = 6
        local sliderHit = Instance.new("TextButton", bar)
        sliderHit.Size = UDim2.new(1, 0, 0, 24)
        sliderHit.Position = UDim2.new(0, 0, 0, -12)
        sliderHit.BackgroundTransparency = 1
        sliderHit.Text = ""
        sliderHit.ZIndex = 8

        local ctrl = { Value = def, _changed = {}, _cb = opts.Callback }
        local function snap(v) return math.floor(math.clamp(v, minV, maxV) * m + 0.5) / m end
        local function sync()
            local p = math.clamp((ctrl.Value - minV) / (maxV - minV), 0, 1)
            fill.Size = UDim2.new(p, 0, 1, 0)
            fill.BackgroundColor3 = MenuCol()
            local t = string.format("%." .. tostring(rounding) .. "f", ctrl.Value)
            val.Text = (suffix and suffix ~= "") and (t .. " " .. suffix) or t
            val.Position = UDim2.new(math.max(p, 0.22), -70, 0, -3)
        end
        local function setFromX(x, fire)
            local p = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
            local nv = snap(minV + (maxV - minV) * p)
            if nv == ctrl.Value then sync() return end
            ctrl.Value = nv
            sync()
            if fire then FireCtrl(ctrl, nv) end
        end
        function ctrl:OnChanged(fn) table.insert(self._changed, fn) return self end
        function ctrl:SetValue(v)
            local nv = snap(tonumber(v) or minV)
            if self.Value == nv then sync() return end
            self.Value = nv
            sync()
            FireCtrl(self, nv)
        end

        local dragging = false
        sliderHit.InputBegan:Connect(function(i)
            if isDragType(i.UserInputType) then dragging = true setFromX(i.Position.X, true) end
        end)
        Track(UserInputService.InputEnded:Connect(function(i)
            if isDragType(i.UserInputType) and dragging then dragging = false setFromX(i.Position.X, true) end
        end))
        Track(UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                setFromX(i.Position.X, true)
            end
        end))
        sync()
        Options[id] = ctrl
        return ctrl
    end

    function api:AddDropdown(id, opts)
        opts = opts or {}
        local values = opts.Values or {}
        local default = type(opts.Default) == "number" and values[opts.Default] or (opts.Default or values[1])

        local row = Instance.new("Frame", frame)
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundTransparency = 1
        row.LayoutOrder = nextOrder()
        row.ZIndex = 2
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.Position = UDim2.new(0, 3, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = opts.Text or id
        lbl.TextColor3 = Color3.fromRGB(190, 190, 190)
        lbl.Font = Enum.Font.Arial
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 3
        local dropBtn = Instance.new("TextButton", row)
        dropBtn.Size = UDim2.new(1, -6, 0, 18)
        dropBtn.Position = UDim2.new(0, 3, 0, 17)
        dropBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        dropBtn.BorderSizePixel = 0
        dropBtn.AutoButtonColor = false
        dropBtn.TextColor3 = Color3.fromRGB(205, 205, 205)
        dropBtn.Font = Enum.Font.Arial
        dropBtn.TextSize = 12
        dropBtn.TextXAlignment = Enum.TextXAlignment.Left
        dropBtn.ZIndex = 3
        local dpad = Instance.new("UIPadding", dropBtn)
        dpad.PaddingLeft = UDim.new(0, 7)
        dpad.PaddingRight = UDim.new(0, 18)
        Instance.new("UIStroke", dropBtn).Color = Color3.fromRGB(8, 8, 8)

        local dd = Instance.new("Frame", ScreenGui)
        dd.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        dd.BorderSizePixel = 0
        dd.Visible = false
        dd.ZIndex = 60
        Instance.new("UIStroke", dd).Color = Color3.fromRGB(12, 12, 12)

        local ctrl = { Value = default, Values = values, _changed = {}, _cb = opts.Callback }
        local optionBtns = {}
        local function syncText() dropBtn.Text = tostring(ctrl.Value) end
        local function rebuild()
            for _, b in ipairs(optionBtns) do pcall(function() b:Destroy() end) end
            optionBtns = {}
            local list = ctrl.Values or {}
            dd.Size = UDim2.new(0, math.max(dropBtn.AbsoluteSize.X, 160), 0, #list * 20)
            for i, opt in ipairs(list) do
                local ti = i
                local ob = Instance.new("TextButton", dd)
                ob.Size = UDim2.new(1, 0, 0, 20)
                ob.Position = UDim2.new(0, 0, 0, (i - 1) * 20)
                ob.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                ob.BorderSizePixel = 0
                ob.Text = "  " .. tostring(opt)
                ob.TextColor3 = (ctrl.Value == opt) and Color3.new(1, 1, 1) or Color3.fromRGB(205, 205, 205)
                ob.Font = Enum.Font.Arial
                ob.TextSize = 12
                ob.TextXAlignment = Enum.TextXAlignment.Left
                ob.ZIndex = 61
                ob.MouseButton1Click:Connect(function()
                    ctrl.Value = ctrl.Values[ti]
                    syncText()
                    for j, b in ipairs(optionBtns) do
                        b.TextColor3 = (j == ti) and Color3.new(1, 1, 1) or Color3.fromRGB(205, 205, 205)
                    end
                    dd.Visible = false
                    FireCtrl(ctrl, ctrl.Value)
                end)
                optionBtns[i] = ob
            end
        end

        local ddState = { CloseDD = function() dd.Visible = false end }
        DDStates[#DDStates + 1] = ddState
        dropBtn.MouseButton1Click:Connect(function()
            if dd.Visible then dd.Visible = false return end
            pcall(CloseAllPickers)
            for _, st in ipairs(DDStates) do if st ~= ddState then pcall(st.CloseDD) end end
            local x0 = dropBtn.AbsolutePosition.X - ScreenGui.AbsolutePosition.X
            local y0 = dropBtn.AbsolutePosition.Y - ScreenGui.AbsolutePosition.Y
            dd.Size = UDim2.new(0, math.max(dropBtn.AbsoluteSize.X, 160), 0, #ctrl.Values * 20)
            dd.Position = UDim2.new(0, x0, 0, y0 + 18)
            dd.Visible = true
        end)

        function ctrl:OnChanged(fn) table.insert(self._changed, fn) return self end
        function ctrl:SetValue(v)
            if self.Value == v then return end
            self.Value = v
            syncText()
            rebuild()
            FireCtrl(self, v)
        end
        syncText()
        rebuild()
        Options[id] = ctrl
        return ctrl
    end

    function api:AddColorPicker(id, opts) local ctrl = MakeColorPickerUI(frame, nextOrder(), id, opts) Options[id] = ctrl return ctrl end
    function api:AddKeyPicker(id, opts) local ctrl = MakeKeyPickerUI(frame, nextOrder(), id, opts) Options[id] = ctrl return ctrl end

    function api:AddList(id, opts)
        opts = opts or {}
        local list = Instance.new("ScrollingFrame", frame)
        list.Size = UDim2.new(1, -6, 0, opts.Height or 120)
        list.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
        list.BorderSizePixel = 0
        list.ScrollBarThickness = 3
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.LayoutOrder = nextOrder()
        list.ZIndex = 3
        Instance.new("UIStroke", list).Color = Color3.fromRGB(10, 10, 10)
        Instance.new("UIListLayout", list).SortOrder = Enum.SortOrder.LayoutOrder
        local lp = Instance.new("UIPadding", list)
        lp.PaddingTop = UDim.new(0, 4)
        lp.PaddingLeft = UDim.new(0, 6)

        local ctrl = { Values = opts.Values or {}, Value = opts.Default, _changed = {}, _cb = opts.Callback }
        local rows = {}
        local function paint()
            for name, b in pairs(rows) do
                local on = (name == ctrl.Value)
                b.BackgroundTransparency = on and 0 or 1
                b.TextColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(190, 190, 190)
            end
        end
        local function rebuild()
            for _, b in pairs(rows) do b:Destroy() end
            rows = {}
            for i, name in ipairs(ctrl.Values) do
                local b = Instance.new("TextButton", list)
                b.Size = UDim2.new(1, -6, 0, 16)
                b.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
                b.BorderSizePixel = 0
                b.AutoButtonColor = false
                b.Text = name
                b.Font = Enum.Font.Arial
                b.TextSize = 12
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.LayoutOrder = i
                b.ZIndex = 4
                Instance.new("UIPadding", b).PaddingLeft = UDim.new(0, 4)
                b.MouseButton1Click:Connect(function() ctrl:SetValue(name) end)
                rows[name] = b
            end
            paint()
        end
        function ctrl:OnChanged(fn) table.insert(self._changed, fn) return self end
        function ctrl:SetValues(v) self.Values = v or {} rebuild() end
        function ctrl:SetValue(v)
            if v == nil or self.Value == v then paint() return end
            self.Value = v
            paint()
            FireCtrl(self, v)
        end
        rebuild()
        Options[id] = ctrl
        return ctrl
    end

    function api:AddInput(id, opts)
        opts = opts or {}
        local row = Instance.new("Frame", frame)
        row.Size = UDim2.new(1, 0, 0, 26)
        row.BackgroundTransparency = 1
        row.LayoutOrder = nextOrder()
        row.ZIndex = 2
        local inp = Instance.new("TextBox", row)
        inp.Size = UDim2.new(1, -6, 1, -4)
        inp.Position = UDim2.new(0, 3, 0, 2)
        inp.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        inp.BorderSizePixel = 0
        inp.Text = opts.Default or ""
        inp.PlaceholderText = opts.Placeholder or ""
        inp.TextColor3 = Color3.fromRGB(205, 205, 205)
        inp.Font = Enum.Font.Arial
        inp.TextSize = 12
        inp.ClearTextOnFocus = false
        inp.ZIndex = 3
        Instance.new("UIStroke", inp).Color = Color3.fromRGB(16, 16, 16)
        local ctrl = { Value = opts.Default or "", _changed = {}, _cb = opts.Callback }
        function ctrl:OnChanged(fn) table.insert(self._changed, fn) return self end
        function ctrl:SetValue(v) self.Value = v or "" inp.Text = self.Value FireCtrl(self, self.Value) end
        inp.FocusLost:Connect(function() ctrl.Value = inp.Text FireCtrl(self, ctrl.Value) end)
        Options[id] = ctrl
        return ctrl
    end

    function api:AddButton(text, callback)
        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(1, -6, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Text = ""
        btn.LayoutOrder = nextOrder()
        btn.ZIndex = 2
        Instance.new("UIStroke", btn).Color = Color3.fromRGB(8, 8, 8)
        local lbl = Instance.new("TextLabel", btn)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Arial
        lbl.TextSize = 12
        lbl.ZIndex = 4
        btn.MouseButton1Click:Connect(function() pcall(callback) end)
        return btn
    end

    function api:AddLabel(text)
        local order = nextOrder()
        local row = Instance.new("Frame", frame)
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.ZIndex = 2
        local l = Instance.new("TextLabel", row)
        l.Size = UDim2.new(0.55, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(190, 190, 190)
        l.Font = Enum.Font.Arial
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 3
        local labelApi = {}
        function labelApi:AddColorPicker(id, opts)
            opts = opts or {} opts.Title = opts.Title or text opts._reuseRow = row
            local ctrl = MakeColorPickerUI(frame, order, id, opts)
            Options[id] = ctrl return ctrl
        end
        function labelApi:AddKeyPicker(id, opts)
            opts = opts or {} opts.Text = opts.Text or text opts._reuseRow = row
            local ctrl = MakeKeyPickerUI(frame, order, id, opts)
            Options[id] = ctrl return ctrl
        end
        return labelApi
    end

    function api:AddDivider()
        local row = Instance.new("Frame", frame)
        row.Size = UDim2.new(1, 0, 0, 8)
        row.BackgroundTransparency = 1
        row.LayoutOrder = nextOrder()
        local line = Instance.new("Frame", row)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 0.5, 0)
        line.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        line.BorderSizePixel = 0
        return row
    end
    return api
end

local function MakeTabObj(tabIndex)
    local cols = EnsureTabCols(tabIndex)
    local t = {}
    local function makeGroupbox(colFrame, countKey, name)
        cols[countKey] = cols[countKey] + 1
        local box = Instance.new("Frame", colFrame)
        box.Size = UDim2.new(1, -4, 0, 0)
        box.AutomaticSize = Enum.AutomaticSize.Y
        box.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
        box.BorderSizePixel = 0
        box.LayoutOrder = cols[countKey]
        box.ZIndex = 2
        Instance.new("UIStroke", box).Color = Color3.fromRGB(48, 48, 48)
        local title = Instance.new("TextLabel", box)
        title.AutomaticSize = Enum.AutomaticSize.X
        title.Size = UDim2.new(0, 0, 0, 14)
        title.Position = UDim2.new(0, 10, 0, -8)
        title.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
        title.BorderSizePixel = 0
        title.Text = name
        title.TextColor3 = Color3.fromRGB(240, 240, 240)
        title.Font = Enum.Font.ArialBold
        title.TextSize = 12
        title.ZIndex = 6
        local tpad = Instance.new("UIPadding", title)
        tpad.PaddingLeft = UDim.new(0, 4)
        tpad.PaddingRight = UDim.new(0, 4)
        local content = Instance.new("Frame", box)
        content.Size = UDim2.new(1, -16, 0, 0)
        content.Position = UDim2.new(0, 8, 0, 12)
        content.BackgroundTransparency = 1
        content.AutomaticSize = Enum.AutomaticSize.Y
        content.ZIndex = 2
        local list = Instance.new("UIListLayout", content)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 2)
        Instance.new("UIPadding", content).PaddingBottom = UDim.new(0, 8)
        return BindContainer(content)
    end
    function t:AddLeftGroupbox(name) return makeGroupbox(cols.left, "leftN", name) end
    function t:AddRightGroupbox(name) return makeGroupbox(cols.right, "rightN", name) end
    return t
end

Tabs.Aimbot      = MakeTabObj(1)
Tabs.Visuals     = MakeTabObj(2)
Tabs.SkinChanger = MakeTabObj(3)
Tabs.Misc        = MakeTabObj(4)
Tabs.Settings    = MakeTabObj(5)
Library.TabFrames = TabFrames
Library.TabCols = TabCols

local debounceToggle = 0
function Library:Toggle()
    local now = os.clock()
    if now - debounceToggle < 0.1 then return end
    debounceToggle = now
    KeyBindActive = nil
    menuOpen.v = not menuOpen.v
    Library.IsOpen = menuOpen.v
    pcall(function()
        UserInputService.MouseBehavior = menuOpen.v and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
        local cm = require(LP:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
        if menuOpen.v then cm:Disable() else cm:Enable() end
        local cam = workspace.CurrentCamera
        if cam then
            if menuOpen.v then
                if cam.CameraType ~= Enum.CameraType.Scriptable then
                    prevCamType = cam.CameraType
                    cam.CameraType = Enum.CameraType.Scriptable
                end
            elseif prevCamType ~= nil then
                cam.CameraType = prevCamType
                prevCamType = nil
            end
        end
    end)
    if not menuOpen.v then pcall(CloseAllDDs) pcall(CloseAllPickers) end
end

function Library:Unload()
    if unloaded then return end
    unloaded = true
    _G.__GAMESENSE_FULLBUILD_INJECTED__ = nil
    _G.__GAMESENSE_FULLBUILD_UNLOAD__ = nil
    local wasOpen = menuOpen.v
    PH.alive = false
    menuOpen.v = false
    Library.IsOpen = false
    pcall(function()
        UserInputService.MouseIconEnabled = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        local cam = workspace.CurrentCamera
        if cam and prevCamType ~= nil then cam.CameraType = prevCamType prevCamType = nil end
    end)
    pcall(CloseAllDDs)
    pcall(CloseAllPickers)
    for _, conn in ipairs(Connections) do pcall(function() conn:Disconnect() end) end
    for _, conn in ipairs(PH.conns) do pcall(function() conn:Disconnect() end) end
    for _, fn in ipairs(PH.cleanup) do pcall(fn) end
    if wasOpen then
        pcall(function() require(LP:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls():Enable() end)
    end
    pcall(function() ScreenGui:Destroy() end)
end
_G.__GAMESENSE_FULLBUILD_UNLOAD__ = function() pcall(function() Library:Unload() end) end

local MenuCursor = Instance.new("Frame", ScreenGui)
MenuCursor.Size = UDim2.fromOffset(16, 16)
MenuCursor.BackgroundTransparency = 1
MenuCursor.ZIndex = 50
MenuCursor.Visible = false
local function mkCur(px, py, sx, sy, color, z)
    local f = Instance.new("Frame", MenuCursor)
    f.Size = UDim2.fromOffset(sx, sy)
    f.Position = UDim2.fromOffset(px, py)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = z
end
mkCur(0, 0, 3, 15, Color3.new(0, 0, 0), 49)
mkCur(0, 12, 11, 3, Color3.new(0, 0, 0), 49)
mkCur(1, 1, 1, 13, Color3.new(1, 1, 1), 50)
mkCur(1, 12, 8, 1, Color3.new(1, 1, 1), 50)

Track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape and menuOpen.v then
        KeyBindActive = nil
        Library:Toggle()
        return
    end
    if KeyBindActive then return end
    if input.KeyCode.Value == GSConfig.menu_key and GSConfig.menu_key ~= 0 then
        Library:Toggle()
    end
end))

local animAlpha = { v = 1 }
Track(RunService.RenderStepped:Connect(function(dt)
    if unloaded or not ScreenGui.Parent then return end
    if menuOpen.v then
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        pcall(function()
            local mp = UserInputService:GetMouseLocation()
            local inset = game:GetService("GuiService"):GetGuiInset()
            MenuCursor.Position = UDim2.new(0, mp.X - inset.X, 0, mp.Y - inset.Y)
        end)
    end
    MenuCursor.Visible = menuOpen.v
    local target = menuOpen.v and 1 or 0
    animAlpha.v = animAlpha.v + (target - animAlpha.v) * math.clamp(dt * 12, 0, 1)
    if not menuOpen.v and animAlpha.v < 0.01 then MainFrame.Visible = false return end
    MainFrame.Visible = true
    MainFrame.GroupTransparency = 1 - animAlpha.v
end))

function Library:InitConfigTab()
    local SettingsGroup = Tabs.Settings:AddLeftGroupbox("Interface Settings")
    SettingsGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
        Text = "MenuKeybind", Default = "RightShift", Mode = "Toggle", Callback = function() Library:Toggle() end,
    })
    SettingsGroup:AddLabel("Menu color"):AddColorPicker("MenuColorPicker", {
        Default = Color3.fromRGB(0, 255, 100), Title = "Menu color",
        Callback = function(c)
            GSConfig.MenuColor[1] = math.floor(c.R * 255)
            GSConfig.MenuColor[2] = math.floor(c.G * 255)
            GSConfig.MenuColor[3] = math.floor(c.B * 255)
        end,
    })
    SettingsGroup:AddButton("Unload Menu", function() Library:Unload() end)

    local smFolder, smSubFolder = "gamesense/bloxstrike", "gamesense"
    local smIgnore = { MenuKeybind = true, ConfigName = true, ConfigList = true }
    local function smSanitize(name) return tostring(name or ""):gsub("[%c\\/:*?\"<>|]", ""):gsub("%s+", "_"):gsub("^_+", ""):gsub("_+$", "") end
    local function smPath(name) return smFolder .. "/" .. smSubFolder .. "/" .. name .. ".json" end
    local function smEnsureFolder()
        if not makefolder then return end
        pcall(function()
            local cur = ""
            for segment in (smFolder .. "/" .. smSubFolder):gmatch("[^/\\]+") do
                cur = cur == "" and segment or (cur .. "/" .. segment)
                pcall(function() makefolder(cur) end)
            end
        end)
    end
    local function serializeValue(v)
        if typeof(v) == "Color3" then return { __c3 = true, r = v.R, g = v.G, b = v.B } end
        return v
    end
    local function deserializeValue(v)
        if type(v) == "table" and v.__c3 then return Color3.new(v.r or 1, v.g or 1, v.b or 1) end
        return v
    end
    local function collectState()
        local state = { T = {}, O = {} }
        for id, obj in pairs(Toggles) do if not smIgnore[id] and type(obj) == "table" and obj.Value ~= nil then state.T[id] = serializeValue(obj.Value) end end
        for id, obj in pairs(Options) do if not smIgnore[id] and type(obj) == "table" and obj.Value ~= nil then state.O[id] = serializeValue(obj.Value) end end
        return state
    end
    local function applyState(state)
        if type(state) ~= "table" then return end
        for id, val in pairs(state.T or {}) do local obj = Toggles[id] if obj and obj.SetValue and not smIgnore[id] then pcall(function() obj:SetValue(deserializeValue(val)) end) end end
        for id, val in pairs(state.O or {}) do local obj = Options[id] if obj and obj.SetValue and not smIgnore[id] then pcall(function() obj:SetValue(deserializeValue(val)) end) end end
    end
    function SaveManager:Save(name)
        name = smSanitize(name == nil and "default" or name)
        if name == "" or not writefile then return false end
        smEnsureFolder()
        local ok, encoded = pcall(function() return HttpService:JSONEncode(collectState()) end)
        if not ok then return false end
        pcall(function() writefile(smPath(name), encoded) end)
        return true
    end
    function SaveManager:Load(name)
        name = smSanitize(name == nil and "default" or name)
        if name == "" or not readfile then return false end
        local okR, raw = pcall(function() return readfile(smPath(name)) end)
        if not okR or not raw or raw == "" then return false end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok or type(decoded) ~= "table" then return false end
        applyState(decoded)
        return true
    end
    function SaveManager:Delete(name)
        name = smSanitize(name == nil and "default" or name)
        if name ~= "" and delfile then pcall(function() delfile(smPath(name)) end) end
    end
    function SaveManager:GetConfigs()
        local out = {}
        if listfiles then
            pcall(function()
                for _, f in ipairs(listfiles(smFolder .. "/" .. smSubFolder) or {}) do
                    local n = tostring(f):match("([^/\\]+)%.json$")
                    if n then out[#out + 1] = n end
                end
            end)
        end
        table.sort(out)
        return out
    end

    local box = Tabs.Settings:AddRightGroupbox("Presets")
    local configs = SaveManager:GetConfigs()
    local list = box:AddList("ConfigList", { Values = configs, Default = configs[1], Height = 120 })
    box:AddInput("ConfigName", { Default = configs[1] or "default", Placeholder = "enter name..." })
    list:OnChanged(function(v) if v and Options.ConfigName then Options.ConfigName:SetValue(v) end end)
    local function refreshList(select) local c = SaveManager:GetConfigs() list:SetValues(c) if select then list:SetValue(select) end end
    local function selectedName() return (Options.ConfigList and Options.ConfigList.Value) or (Options.ConfigName and Options.ConfigName.Value) or "default" end
    box:AddButton("Load", function() SaveManager:Load(selectedName()) end)
    box:AddButton("Save", function() local name = (Options.ConfigName and Options.ConfigName.Value) or "default" if SaveManager:Save(name) then refreshList(smSanitize(name)) end end)
    box:AddButton("Delete", function() SaveManager:Delete(selectedName()) refreshList() end)
    box:AddButton("Save as Autoload", function() local name = (Options.ConfigName and Options.ConfigName.Value) or "default" if SaveManager:Save(name) then SaveManager:Save("autoload") refreshList(smSanitize(name)) end end)
    task.delay(1, function() if PH.alive then pcall(function() SaveManager:Load("autoload") end) end end)
end

return Library
