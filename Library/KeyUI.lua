--!nonstrict
--[[
    ========================================================================
    ⚡ NO-LAG KEY SYSTEM (Monochrome Edition)
    ========================================================================
    Sistem Key Roblox modern, ringan, dan mudah dibaca.
    
    Fitur Utama:
    - Modular UI Library (validasi via callback Validate / OnSubmit)
    - Desain Monochrome Black & White modern dan elegan
    - Tombol Discord & Tutorial berbentuk teks bersih di bagian bawah
    - Keluar / Tutup UI kapan saja dengan perintah: _G.Exit = true
    - Smooth dragging (Mendukung PC mouse & Mobile touch)
    - Animasi input error shake & status loading spinner
    - Penyimpanan key otomatis (SaveKey)
    ========================================================================
]]

-- ============================================================================
-- 1. PENGATURAN / CONFIGURATION (Ubah pengaturan di sini)
-- ============================================================================
local CONFIG = {
    -- Judul & Teks Tampilan UI
    Title       = "No-Lag",
    Subtitle    = "Enter your key to unlock",
    Footer      = "high performance • zero overhead",
    Placeholder = "Enter your key here...",

    -- Tautan / Links
    GetKeyLink    = "https://nolag.wtf/GetKey",
    DiscordInvite = "https://discord.gg/Ndzk9kPZmT",
    TutorialLink  = "https://nolag.wtf/GetKey",

    -- Auto-Save Kunci (Menyimpan key ke file JSON di perangkat executor)
    SaveKey      = true,
    SaveFileName = "NoLagKey.json",

    -- Callback saat Kunci Berhasil Diverifikasi
    OnSuccess = function(keyData)
        print("⚡ [No-Lag] Key Validated Successfully! Loading main script...")
    end,

    -- Callback saat UI Ditutup
    OnClose = function()
        print("⚡ [No-Lag] Key System UI closed.")
    end,
}

-- ============================================================================
-- 2. CORE SERVICES & ROBLOX UTILITIES
-- ============================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function defaultParent(): Instance
    if gethui then
        local ok, hiddenUi = pcall(gethui)
        if ok and typeof(hiddenUi) == "Instance" then
            return hiddenUi
        end
    end
    return CoreGui
end

local ICONS = {
    Key           = "rbxassetid://10723416652",
    ShieldCheck   = "rbxassetid://10734951367",
    Loader        = "rbxassetid://10723434070",
    Check         = "rbxassetid://10709790644",
}

local Theme = {
    -- Backgrounds & Surfaces (Monochrome)
    Background       = Color3.fromRGB(15, 15, 15),
    Surface          = Color3.fromRGB(24, 24, 24),
    SurfaceRaised    = Color3.fromRGB(32, 32, 32),
    SurfaceHover     = Color3.fromRGB(42, 42, 42),
    SurfaceHighlight = Color3.fromRGB(54, 54, 54),

    -- Accent Colors
    Accent           = Color3.fromRGB(255, 255, 255),
    AccentHover      = Color3.fromRGB(230, 230, 230),
    AccentLight      = Color3.fromRGB(200, 200, 200),
    AccentText       = Color3.fromRGB(15, 15, 15),

    -- Strokes & Borders
    Stroke           = Color3.fromRGB(45, 45, 45),
    StrokeFocused    = Color3.fromRGB(230, 230, 230),
    StrokeLight      = Color3.fromRGB(65, 65, 65),

    -- Indicators
    Success          = Color3.fromRGB(80, 220, 140),
    Error            = Color3.fromRGB(245, 85, 95),

    -- Typography
    Text             = Color3.fromRGB(245, 245, 245),
    TextMuted        = Color3.fromRGB(160, 160, 160),
    TextDark         = Color3.fromRGB(105, 105, 105),

    -- Fonts
    FontNormal       = Enum.Font.Gotham,
    FontMedium       = Enum.Font.GothamMedium,
    FontBold         = Enum.Font.GothamBold,

    -- Geometry
    RadiusWindow     = UDim.new(0, 16),
    RadiusControl    = UDim.new(0, 10),
    RadiusSmall      = UDim.new(0, 8),
}

local function Create(className: string, properties: {[string]: any}?, parent: Instance?): Instance
    local instance = Instance.new(className)
    if properties then
        for prop, val in pairs(properties) do
            if prop ~= "Parent" then
                (instance :: any)[prop] = val
            end
        end
    end
    instance.Parent = parent or (properties and properties.Parent) or nil
    return instance
end

local function Tween(instance: Instance, goals: {[string]: any}, duration: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
    local info = TweenInfo.new(
        duration or 0.22,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local anim = TweenService:Create(instance, info, goals)
    anim:Play()
    return anim
end

-- ============================================================================
-- 4. KEY SYSTEM CLASS
-- ============================================================================
local KeySystem = {}
KeySystem.__index = KeySystem

function KeySystem.new(configOverride: {[string]: any}?)
    local config = table.clone(CONFIG)
    if configOverride then
        for k, v in pairs(configOverride) do
            config[k] = v
        end
    end

    local self = setmetatable({
        _config = config,
        _theme = Theme,
        _isOpen = false,
        _isValidating = false,
        _destroyed = false,
        _connections = {},
    }, KeySystem)

    self:_BuildUI()
    self:_LoadSavedKey()

    if config.AutoShow == true then
        self:Show()
    end

    return self
end

function KeySystem:_BuildUI()
    local theme = self._theme
    local config = self._config
    local container = config.Parent or defaultParent()

    -- Hapus instance lama jika ada
    local oldGui = container:FindFirstChild("NoLag_KeySystem_Window")
    if oldGui then
        oldGui:Destroy()
    end

    -- ScreenGui (starts hidden until :Show() is called)
    local screenGui = Create("ScreenGui", {
        Name = "NoLag_KeySystem_Window",
        ResetOnSpawn = false,
        DisplayOrder = 1000,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Enabled = false,
    }, container)
    self.ScreenGui = screenGui

    -- Background Overlay Blur / Dark Dimmer
    local overlay = Create("TextButton", {
        Name = "Overlay",
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.5,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        ZIndex = 1,
    }, screenGui)
    self.Overlay = overlay

    -- Main Card Container
    local mainCard = Create("Frame", {
        Name = "MainCard",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(390, 360),
        ClipsDescendants = false,
        ZIndex = 10,
    }, screenGui)
    self.MainCard = mainCard

    Create("UICorner", { CornerRadius = theme.RadiusWindow }, mainCard)
    local cardStroke = Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = theme.Stroke,
        Thickness = 1.5,
        Transparency = 0.2,
    }, mainCard)
    self.CardStroke = cardStroke

    -- Ambient Shadow Glow
    Create("ImageLabel", {
        Name = "AmbientShadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 80, 1, 80),
        Image = "rbxassetid://6015897843",
        ImageColor3 = theme.Accent,
        ImageTransparency = 0.90,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 9,
    }, mainCard)

    -- Header Area: Title & Subtitle
    local headerArea = Create("Frame", {
        Name = "HeaderArea",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 32),
        Size = UDim2.new(1, 0, 0, 75),
        ZIndex = 12,
    }, mainCard)

    self.TitleLabel = Create("TextLabel", {
        Name = "Title",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Font = theme.FontBold,
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(1, -60, 0, 26),
        Text = config.Title or "No-Lag",
        TextColor3 = theme.Text,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 13,
    }, headerArea)

    -- Divider Horizontal
    local dividerContainer = Create("Frame", {
        Name = "Divider",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, 32),
        Size = UDim2.new(0, 220, 0, 6),
        ZIndex = 13,
    }, headerArea)

    local leftLine = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = theme.StrokeLight,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, -7, 0.5, 0),
        Size = UDim2.new(0.5, -10, 0, 1),
        ZIndex = 13,
    }, dividerContainer)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, leftLine)

    local centerDot = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(5, 5),
        ZIndex = 14,
    }, dividerContainer)
    Create("UICorner", { CornerRadius = UDim.new(1, 0) }, centerDot)

    local rightLine = Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = theme.StrokeLight,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 7, 0.5, 0),
        Size = UDim2.new(0.5, -10, 0, 1),
        ZIndex = 13,
    }, dividerContainer)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, rightLine)

    -- Subtitle
    self.SubtitleLabel = Create("TextLabel", {
        Name = "Subtitle",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Font = theme.FontNormal,
        Position = UDim2.new(0.5, 0, 0, 46),
        Size = UDim2.new(1, -40, 0, 20),
        Text = config.Subtitle or "Enter your key to unlock",
        TextColor3 = theme.TextMuted,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 14,
    }, headerArea)

    -- Key Input Card
    local inputCard = Create("Frame", {
        Name = "InputCard",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = theme.Surface,
        Position = UDim2.new(0.5, 0, 0, 114),
        Size = UDim2.new(1, -36, 0, 56),
        ZIndex = 12,
    }, mainCard)
    self.InputCard = inputCard
    Create("UICorner", { CornerRadius = theme.RadiusControl }, inputCard)
    local inputStroke = Create("UIStroke", {
        Color = theme.Stroke,
        Thickness = 1.2,
        Transparency = 0.3,
    }, inputCard)
    self.InputStroke = inputStroke

    -- Left Glowing Accent Bar
    local accentBar = Create("Frame", {
        Name = "AccentBar",
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = theme.AccentLight,
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.new(0, 4, 0, 36),
        ZIndex = 14,
    }, inputCard)
    Create("UICorner", { CornerRadius = UDim.new(1, 0) }, accentBar)
    self.AccentBar = accentBar

    -- TextBox Input
    local textBox = Create("TextBox", {
        Name = "KeyTextBox",
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        Font = theme.FontNormal,
        PlaceholderColor3 = theme.TextDark,
        PlaceholderText = config.Placeholder or "Enter your key here...",
        Position = UDim2.new(0, 20, 0.5, 0),
        Size = UDim2.new(1, -28, 0, 40),
        Text = "",
        TextColor3 = theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, inputCard)
    self.TextBox = textBox

    -- Dots Separator Row
    local dotsRow = Create("Frame", {
        Name = "DotsRow",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, 182),
        Size = UDim2.new(1, -40, 0, 12),
        ZIndex = 12,
    }, mainCard)
    local dotsLayout = Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 32),
    }, dotsRow)
    for i = 1, 5 do
        local dot = Create("Frame", {
            BackgroundColor3 = (i == 3) and theme.Accent or theme.StrokeLight,
            BackgroundTransparency = (i == 3) and 0.2 or 0.5,
            Size = (i == 3) and UDim2.fromOffset(5, 5) or UDim2.fromOffset(4, 4),
            ZIndex = 13,
        }, dotsRow)
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    end

    -- Action Buttons Row (Get Key & Redeem Key)
    local buttonRow = Create("Frame", {
        Name = "ButtonRow",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, 206),
        Size = UDim2.new(1, -36, 0, 44),
        ZIndex = 12,
    }, mainCard)

    -- Get Key Button
    local getKeyBtn = Create("TextButton", {
        Name = "GetKeyBtn",
        AutoButtonColor = false,
        BackgroundColor3 = theme.SurfaceRaised,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.48, 0, 1, 0),
        Text = "",
        ZIndex = 13,
    }, buttonRow)
    Create("UICorner", { CornerRadius = theme.RadiusControl }, getKeyBtn)
    local getKeyStroke = Create("UIStroke", {
        Color = theme.Stroke,
        Thickness = 1.2,
        Transparency = 0.4,
    }, getKeyBtn)
    local getKeyContent = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 14,
    }, getKeyBtn)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
    }, getKeyContent)
    local getKeyIcon = Create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Image = ICONS.Key,
        ImageColor3 = theme.Text,
        ZIndex = 15,
    }, getKeyContent)
    local getKeyText = Create("TextLabel", {
        BackgroundTransparency = 1,
        Font = theme.FontMedium,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "Get Key",
        TextColor3 = theme.Text,
        TextSize = 13,
        ZIndex = 15,
    }, getKeyContent)

    -- Redeem Key Button
    local redeemKeyBtn = Create("TextButton", {
        Name = "RedeemKeyBtn",
        AutoButtonColor = false,
        BackgroundColor3 = theme.Accent,
        Position = UDim2.new(0.52, 0, 0, 0),
        Size = UDim2.new(0.48, 0, 1, 0),
        Text = "",
        ZIndex = 13,
    }, buttonRow)
    Create("UICorner", { CornerRadius = theme.RadiusControl }, redeemKeyBtn)
    local redeemStroke = Create("UIStroke", {
        Color = theme.AccentHover,
        Thickness = 1,
        Transparency = 0.8,
    }, redeemKeyBtn)
    local redeemContent = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 14,
    }, redeemKeyBtn)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
    }, redeemContent)
    local redeemIcon = Create("ImageLabel", {
        Name = "RedeemIcon",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Image = ICONS.ShieldCheck,
        ImageColor3 = theme.AccentText,
        ZIndex = 15,
    }, redeemContent)
    local redeemText = Create("TextLabel", {
        Name = "RedeemText",
        BackgroundTransparency = 1,
        Font = theme.FontBold,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "Redeem Key",
        TextColor3 = theme.AccentText,
        TextSize = 13,
        ZIndex = 15,
    }, redeemContent)

    -- Bottom Text Buttons Row (Discord & Tutorial)
    local bottomRow = Create("Frame", {
        Name = "BottomRow",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, 260),
        Size = UDim2.new(1, -36, 0, 36),
        ZIndex = 12,
    }, mainCard)

    local discordBtn = Create("TextButton", {
        Name = "DiscordBtn",
        AutoButtonColor = false,
        BackgroundColor3 = theme.Surface,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.48, 0, 1, 0),
        Font = theme.FontMedium,
        Text = "Discord",
        TextColor3 = theme.TextMuted,
        TextSize = 13,
        ZIndex = 13,
    }, bottomRow)
    Create("UICorner", { CornerRadius = theme.RadiusControl }, discordBtn)
    local discordStroke = Create("UIStroke", {
        Color = theme.Stroke,
        Thickness = 1.2,
        Transparency = 0.3,
    }, discordBtn)

    local tutorialBtn = Create("TextButton", {
        Name = "TutorialBtn",
        AutoButtonColor = false,
        BackgroundColor3 = theme.Surface,
        Position = UDim2.new(0.52, 0, 0, 0),
        Size = UDim2.new(0.48, 0, 1, 0),
        Font = theme.FontMedium,
        Text = "Tutorial",
        TextColor3 = theme.TextMuted,
        TextSize = 13,
        ZIndex = 13,
    }, bottomRow)
    Create("UICorner", { CornerRadius = theme.RadiusControl }, tutorialBtn)
    local tutorialStroke = Create("UIStroke", {
        Color = theme.Stroke,
        Thickness = 1.2,
        Transparency = 0.3,
    }, tutorialBtn)

    -- Footer Quote Text
    local footerLabel = Create("TextLabel", {
        Name = "FooterText",
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundTransparency = 1,
        Font = theme.FontMedium,
        Position = UDim2.new(0.5, 0, 1, -12),
        Size = UDim2.new(1, -40, 0, 16),
        Text = config.Footer or "high performance • zero overhead",
        TextColor3 = theme.TextDark,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 13,
    }, mainCard)
    self.FooterLabel = footerLabel

    -- Toast Notification Overlay
    local toast = Create("Frame", {
        Name = "ToastNotification",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = theme.SurfaceHighlight,
        Position = UDim2.new(0.5, 0, 0, -50),
        Size = UDim2.new(0.9, 0, 0, 36),
        Visible = false,
        ZIndex = 30,
    }, mainCard)
    Create("UICorner", { CornerRadius = theme.RadiusSmall }, toast)
    local toastStroke = Create("UIStroke", {
        Color = theme.Accent,
        Thickness = 1,
    }, toast)
    local toastText = Create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Font = theme.FontMedium,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -20, 1, 0),
        Text = "Notification",
        TextColor3 = theme.Text,
        TextSize = 12,
        ZIndex = 31,
    }, toast)
    self.Toast = toast
    self.ToastText = toastText
    self.ToastStroke = toastStroke

    -- Simpan referensi elemen
    self._elements = {
        MainCard       = mainCard,
        InputCard      = inputCard,
        InputStroke    = inputStroke,
        AccentBar      = accentBar,
        TextBox        = textBox,
        GetKeyBtn      = getKeyBtn,
        GetKeyStroke   = getKeyStroke,
        GetKeyText     = getKeyText,
        GetKeyIcon     = getKeyIcon,
        RedeemKeyBtn   = redeemKeyBtn,
        RedeemStroke   = redeemStroke,
        RedeemText     = redeemText,
        RedeemIcon     = redeemIcon,
        DiscordBtn     = discordBtn,
        DiscordStroke  = discordStroke,
        TutorialBtn    = tutorialBtn,
        TutorialStroke = tutorialStroke,
    }

    self:_SetupEvents()
    self:_SetupDragging()
end

function KeySystem:_SetupEvents()
    local el = self._elements
    local theme = self._theme
    local config = self._config

    -- Global Exit Trigger: Menutup UI ketika _G.Exit = true
    _G.Exit = false
    local exitConnection
    exitConnection = RunService.Heartbeat:Connect(function()
        if _G.Exit == true then
            _G.Exit = false
            if exitConnection then
                exitConnection:Disconnect()
                exitConnection = nil
            end
            self:Close()
        end
    end)
    table.insert(self._connections, exitConnection)

    -- Hover Animation Helper untuk Tombol Standard
    local function bindHover(button: TextButton, stroke: UIStroke?, normalBg: Color3, hoverBg: Color3, normalStroke: Color3?, hoverStroke: Color3?)
        button.MouseEnter:Connect(function()
            Tween(button, { BackgroundColor3 = hoverBg }, 0.15)
            if stroke and hoverStroke then
                Tween(stroke, { Color = hoverStroke }, 0.15)
            end
        end)
        button.MouseLeave:Connect(function()
            Tween(button, { BackgroundColor3 = normalBg }, 0.15)
            if stroke and normalStroke then
                Tween(stroke, { Color = normalStroke }, 0.15)
            end
        end)
    end

    -- Hover Animation Helper untuk Tombol Berisi Teks Murni (Discord / Tutorial)
    local function bindTextHover(button: TextButton, stroke: UIStroke?, normalBg: Color3, hoverBg: Color3, normalText: Color3, hoverText: Color3, normalStroke: Color3?, hoverStroke: Color3?)
        button.MouseEnter:Connect(function()
            Tween(button, { BackgroundColor3 = hoverBg, TextColor3 = hoverText }, 0.15)
            if stroke and hoverStroke then
                Tween(stroke, { Color = hoverStroke }, 0.15)
            end
        end)
        button.MouseLeave:Connect(function()
            Tween(button, { BackgroundColor3 = normalBg, TextColor3 = normalText }, 0.15)
            if stroke and normalStroke then
                Tween(stroke, { Color = normalStroke }, 0.15)
            end
        end)
    end

    -- TextBox Focus Effect
    el.TextBox.Focused:Connect(function()
        Tween(el.InputStroke, { Color = theme.StrokeFocused, Transparency = 0 }, 0.2)
        Tween(el.AccentBar, { Size = UDim2.new(0, 4, 0, 44), BackgroundColor3 = theme.Accent }, 0.2)
    end)

    el.TextBox.FocusLost:Connect(function(enterPressed)
        Tween(el.InputStroke, { Color = theme.Stroke, Transparency = 0.3 }, 0.2)
        Tween(el.AccentBar, { Size = UDim2.new(0, 4, 0, 36), BackgroundColor3 = theme.AccentLight }, 0.2)
        if enterPressed then
            self:RedeemKey()
        end
    end)

    -- Get Key Button Click
    bindHover(el.GetKeyBtn, el.GetKeyStroke, theme.SurfaceRaised, theme.SurfaceHover, theme.Stroke, theme.StrokeFocused)
    el.GetKeyBtn.Activated:Connect(function()
        self:_OnGetKey()
    end)

    -- Redeem Key Button Click
    bindHover(el.RedeemKeyBtn, el.RedeemStroke, theme.Accent, theme.AccentHover, theme.AccentHover, theme.AccentLight)
    el.RedeemKeyBtn.Activated:Connect(function()
        self:RedeemKey()
    end)

    -- Discord Button Click
    bindTextHover(el.DiscordBtn, el.DiscordStroke, theme.Surface, theme.SurfaceHover, theme.TextMuted, theme.Text, theme.Stroke, theme.StrokeFocused)
    el.DiscordBtn.Activated:Connect(function()
        self:_OnDiscord()
    end)

    -- Tutorial Button Click
    bindTextHover(el.TutorialBtn, el.TutorialStroke, theme.Surface, theme.SurfaceHover, theme.TextMuted, theme.Text, theme.Stroke, theme.StrokeFocused)
    el.TutorialBtn.Activated:Connect(function()
        self:_OnTutorial()
    end)
end

function KeySystem:_SetupDragging()
    local mainCard = self.MainCard
    local dragging = false
    local dragInput, dragStart, startPos

    local function update(input)
        local delta = input.Position - dragStart
        mainCard.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    mainCard.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local target = input.Target
            if target and (target:IsA("TextBox") or target:IsA("TextButton")) then
                return
            end

            dragging = true
            dragStart = input.Position
            startPos = mainCard.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    mainCard.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

function KeySystem:_AnimateEntrance()
    local mainCard = self.MainCard
    local overlay = self.Overlay

    mainCard.Position = UDim2.new(0.5, 0, 0.45, 0)
    mainCard.Size = UDim2.fromOffset(360, 330)
    overlay.BackgroundTransparency = 1

    Tween(overlay, { BackgroundTransparency = 0.5 }, 0.3)
    Tween(mainCard, {
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(390, 360),
    }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function KeySystem:Show()
    if self._destroyed then return self end
    self._isOpen = true
    if self.ScreenGui then
        self.ScreenGui.Enabled = true
    end
    self:_AnimateEntrance()
    return self
end

function KeySystem:Hide()
    if self.ScreenGui then
        self.ScreenGui.Enabled = false
    end
    self._isOpen = false
    return self
end

function KeySystem:Close()
    if not self._isOpen then return end
    self._isOpen = false

    local mainCard = self.MainCard
    local overlay = self.Overlay

    Tween(overlay, { BackgroundTransparency = 1 }, 0.25)
    local anim = Tween(mainCard, {
        Position = UDim2.new(0.5, 0, 0.55, 0),
        Size = UDim2.fromOffset(340, 310),
    }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

    anim.Completed:Connect(function()
        if self._config.OnClose then
            pcall(self._config.OnClose)
        end
        self:Destroy()
    end)
end

function KeySystem:Notify(message: string, duration: number?, isError: boolean?)
    local toast = self.Toast
    local toastText = self.ToastText
    local toastStroke = self.ToastStroke
    local theme = self._theme

    toastText.Text = message
    toastStroke.Color = isError and theme.Error or theme.Accent
    toast.Visible = true
    toast.Position = UDim2.new(0.5, 0, 0, -20)
    toast.BackgroundTransparency = 1
    toastText.TextTransparency = 1

    Tween(toast, {
        Position = UDim2.new(0.5, 0, 0, 12),
        BackgroundTransparency = 0.05,
    }, 0.25, Enum.EasingStyle.Back)
    Tween(toastText, { TextTransparency = 0 }, 0.25)

    task.delay(duration or 2.2, function()
        if toast and toast.Parent then
            Tween(toast, {
                Position = UDim2.new(0.5, 0, 0, -20),
                BackgroundTransparency = 1,
            }, 0.2)
            Tween(toastText, { TextTransparency = 1 }, 0.2)
            task.wait(0.25)
            if toast then toast.Visible = false end
        end
    end)
end

function KeySystem:RedeemKey()
    if self._isValidating then return end
    local enteredKey = (self.TextBox.Text or ""):gsub("^%s*(.-)%s*$", "%1")

    if enteredKey == "" then
        self:ShakeInput()
        self:Notify("Please enter your license key!", 2, true)
        return
    end

    self._isValidating = true
    local el = self._elements
    local theme = self._theme

    -- Set Button to Checking status
    el.RedeemText.Text = "Checking..."
    el.RedeemIcon.Image = ICONS.Loader
    el.RedeemText.TextColor3 = theme.AccentText
    el.RedeemIcon.ImageColor3 = theme.AccentText

    local spinning = true
    task.spawn(function()
        while spinning and el.RedeemIcon and el.RedeemIcon.Parent do
            el.RedeemIcon.Rotation = (el.RedeemIcon.Rotation + 12) % 360
            task.wait(0.02)
        end
        if el.RedeemIcon then el.RedeemIcon.Rotation = 0 end
    end)

    task.delay(0.4, function()
        local isValid = false
        local responseMsg = nil
        local keyData = nil

        -- Validation Hook: Dijalankan melalui callback Validate atau OnSubmit dari loader
        local validateFn = self._config.Validate or self._config.OnSubmit
        if type(validateFn) == "function" then
            local success, res, msg, extra = pcall(validateFn, enteredKey)
            if success then
                isValid = (res == true)
                responseMsg = msg
                keyData = extra
            else
                isValid = false
                responseMsg = tostring(res)
            end
        else
            isValid = true
            responseMsg = "Access Granted!"
        end

        spinning = false

        if isValid then
            -- Key Valid State
            el.RedeemText.Text = "Key Valid!"
            el.RedeemIcon.Image = ICONS.Check
            el.RedeemText.TextColor3 = Color3.fromRGB(255, 255, 255)
            el.RedeemIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
            Tween(el.RedeemKeyBtn, { BackgroundColor3 = theme.Success }, 0.2)
            Tween(self.InputStroke, { Color = theme.Success }, 0.2)
            self:Notify(responseMsg or "Access Granted! Loading script...", 2)

            self:_SaveKey(enteredKey)

            task.delay(0.85, function()
                if self._config.OnSuccess then
                    pcall(self._config.OnSuccess, keyData, enteredKey)
                end
                self:Close()
            end)
        else
            -- Key Invalid State
            self._isValidating = false
            el.RedeemText.Text = "Redeem Key"
            el.RedeemIcon.Image = ICONS.ShieldCheck
            el.RedeemText.TextColor3 = theme.AccentText
            el.RedeemIcon.ImageColor3 = theme.AccentText
            Tween(el.RedeemKeyBtn, { BackgroundColor3 = theme.Accent }, 0.2)
            self:ShakeInput()
            self:Notify(responseMsg or "Invalid Key! Please try again.", 2.5, true)
        end
    end)
end

function KeySystem:_OnGetKey()
    local link = self._config.GetKeyLink or "https://nolag.wtf/GetKey"
    local copied = false
    
    if setclipboard then
        pcall(function()
            setclipboard(link)
            copied = true
        end)
    end

    if copied then
        self:Notify("Key link copied to clipboard!", 2.5)
    else
        self:Notify("Link: " .. link:sub(1, 30) .. "...", 3)
    end
end

function KeySystem:_OnDiscord()
    if self._config.OnDiscord then
        local ok, err = pcall(self._config.OnDiscord)
        if not ok then warn("[No-Lag] OnDiscord error:", err) end
        return
    end

    local invite = self._config.DiscordInvite or "https://discord.gg/Ndzk9kPZmT"
    local copied = false

    if setclipboard then
        pcall(function()
            setclipboard(invite)
            copied = true
        end)
    end

    if copied then
        self:Notify("Discord link copied to clipboard!", 2.5)
    else
        self:Notify("Discord: " .. invite, 3)
    end
end

function KeySystem:_OnTutorial()
    if self._config.OnTutorial then
        local ok, err = pcall(self._config.OnTutorial)
        if not ok then warn("[No-Lag] OnTutorial error:", err) end
        return
    end

    local link = self._config.TutorialLink or "https://nolag.wtf/GetKey"
    local copied = false

    if setclipboard then
        pcall(function()
            setclipboard(link)
            copied = true
        end)
    end

    if copied then
        self:Notify("Tutorial link copied to clipboard!", 2.5)
    else
        self:Notify("Tutorial: " .. link:sub(1, 30) .. "...", 3)
    end
end

function KeySystem:ShakeInput()
    local card = self.InputCard
    local stroke = self.InputStroke
    local theme = self._theme
    local origPos = card.Position

    Tween(stroke, { Color = theme.Error, Transparency = 0 }, 0.1)

    task.spawn(function()
        for i = 1, 5 do
            local offset = (i % 2 == 0 and 6 or -6) * (1 - i/6)
            card.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset + offset, origPos.Y.Scale, origPos.Y.Offset)
            task.wait(0.04)
        end
        card.Position = origPos
        task.wait(0.5)
        Tween(stroke, { Color = theme.Stroke, Transparency = 0.3 }, 0.3)
    end)
end

function KeySystem:_SaveKey(key: string)
    if self._config.SaveKey == false then return end
    local filename = self._config.SaveFileName or "NoLagKey.json"

    pcall(function()
        if writefile then
            local data = HttpService:JSONEncode({ Key = key, Date = os.time() })
            writefile(filename, data)
        end
    end)
end

function KeySystem:_LoadSavedKey()
    if self._config.SaveKey == false then return end
    local filename = self._config.SaveFileName or "NoLagKey.json"

    pcall(function()
        if readfile and isfile and isfile(filename) then
            local raw = readfile(filename)
            local data = HttpService:JSONDecode(raw)
            if data and data.Key and self.TextBox then
                self.TextBox.Text = tostring(data.Key)
            end
        end
    end)
end

function KeySystem:Destroy()
    if self._destroyed then return end
    self._destroyed = true

    _G.Exit = nil

    for _, conn in ipairs(self._connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(self._connections)

    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
end

-- ============================================================================
-- 5. EXPORT LIBRARY
-- ============================================================================
KeySystem.DefaultConfig = CONFIG
return KeySystem
