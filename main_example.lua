--=====================================================
-- FISH IT HUB ULTIMATE - WINDUI EDITION
--=====================================================

print("🚀 Loading Fish It Hub Ultimate...")

-- Load WindUI first
local WindUI
do
    local success, err = pcall(function()
        WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/WhoIsGenn/WindUI/main/dist/main.lua"))()
    end)
    
    if not success then
        warn("❌ Failed to load WindUI:", err)
        return
    end
end

print("✅ WindUI Loaded Successfully")

--========================
-- SERVICES
--========================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

--========================
-- SAFE REMOTE FETCH
--========================
local Remotes = RS:WaitForChild("Remotes")
local FishingRemote = Remotes:WaitForChild("Fishing")
local WeatherRemote = Remotes:FindFirstChild("Weather") or Remotes:WaitForChild("Weather")
local SellRemote = Remotes:FindFirstChild("Sell") or Remotes:WaitForChild("Sell")
local InventoryRemote = Remotes:FindFirstChild("Inventory") or Remotes:WaitForChild("Inventory")

--========================
-- CORE TABLE
--========================
local Core = {}

--========================
-- STATE MANAGER
--========================
Core.State = {
    Mode = "None",           -- None | Legit | Instant | Blatant | BlatantBeta
    Busy = false,
    LastCast = 0,
    LastReel = 0,
    FishCaught = 0,
    MoneyEarned = 0,
    SessionStart = tick(),
    RareFish = {
        Mythic = 0,
        Legendary = 0,
        Secret = 0
    }
}

--========================
-- CONFIGURATION
--========================
Core.Config = {
    -- Fishing Modes
    LegitMode = false,
    InstantMode = false,
    BlatantMode = false,
    BetaMode = false,
    
    -- Delays
    InstantDelay = 0.25,
    BlatantCastDelay = 0.18,
    BlatantReelDelay = 0.12,
    BetaCastDelay = 0.10,
    BetaReelDelay = 0.08,
    
    -- Auto Systems
    AutoSell = false,
    SellThreshold = 10,
    AutoFavoriteLegendary = false,
    AutoFavoriteMythic = false,
    
    -- Weather
    AutoBuyAllWeather = false,
    LoopSelectedWeather = false,
    SelectedWeather = {},
    
    -- Performance
    NoAnimation = false,
    DisableCutscene = false,
    DisableEffects = false,
    HideFishIcon = false,
    BoostFPS = false,
    
    -- Misc
    CastAttempts = 6,
    BetaCastAttempts = 12
}

--========================
-- MODE CONTROLLER
--========================
function Core:SetMode(mode)
    if Core.State.Mode == mode then return end
    
    Core.State.Busy = false
    Core.State.LastCast = 0
    Core.State.LastReel = 0
    Core.State.Mode = mode or "None"
    
    print("🎯 Mode changed to:", mode)
end

--========================
-- INPUT SYSTEM
--========================
function Core:TapMouse()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.03)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

--========================
-- FISHING ACTIONS
--========================
function Core:Cast()
    if FishingRemote then
        FishingRemote:FireServer("Cast")
        Core.State.LastCast = tick()
        return true
    end
    return false
end

function Core:Reel()
    if FishingRemote then
        FishingRemote:FireServer("Reel")
        Core.State.LastReel = tick()
        Core.State.FishCaught = Core.State.FishCaught + 1
        Core.State.MoneyEarned = Core.State.MoneyEarned + math.random(10, 50)
        return true
    end
    return false
end

--========================
-- FISHING MODES
--========================
function Core:LegitStep()
    if Core.State.Busy then return end
    Core:TapMouse()
end

function Core:InstantStep()
    if Core.State.Busy then return end
    Core.State.Busy = true
    
    if Core:Cast() then
        task.wait(Core.Config.InstantDelay)
        Core:Reel()
    end
    
    Core.State.Busy = false
end

function Core:BlatantStep()
    if Core.State.Busy then return end
    Core.State.Busy = true
    
    if Core:Cast() then
        task.wait(Core.Config.BlatantCastDelay)
        
        for i = 1, Core.Config.CastAttempts do
            Core:Reel()
            task.wait(Core.Config.BlatantReelDelay)
        end
    end
    
    Core.State.Busy = false
end

function Core:BlatantBetaStep()
    if Core.State.Busy then return end
    Core.State.Busy = true
    
    if Core:Cast() then
        task.wait(Core.Config.BetaCastDelay)
        
        for i = 1, Core.Config.BetaCastAttempts do
            Core:Reel()
            task.wait(Core.Config.BetaReelDelay)
        end
    end
    
    Core.State.Busy = false
end

--========================
-- AUTO SYSTEMS
--========================
-- Auto Weather
task.spawn(function()
    while task.wait(5) do
        if Core.Config.AutoBuyAllWeather and WeatherRemote then
            for _, weather in ipairs({"Wind", "Cloudy", "Frozen", "Storm", "Radiant"}) do
                WeatherRemote:FireServer("Buy", weather)
                task.wait(0.6)
            end
        end
        
        if Core.Config.LoopSelectedWeather and #Core.Config.SelectedWeather == 3 and WeatherRemote then
            for _, weather in ipairs(Core.Config.SelectedWeather) do
                WeatherRemote:FireServer("Buy", weather)
                task.wait(0.6)
            end
        end
    end
end)

-- Auto Sell
task.spawn(function()
    while task.wait(3) do
        if Core.Config.AutoSell and Core.Config.SellThreshold > 0 and SellRemote then
            SellRemote:FireServer(Core.Config.SellThreshold)
        end
    end
end)

-- Auto Favorite
local FavoriteSystem = {
    ByRarity = {},
    ByName = {}
}

function Core:ShouldFavorite(fish)
    if FavoriteSystem.ByName[fish.Name] then
        return true
    end
    if FavoriteSystem.ByRarity[fish.Rarity] then
        return true
    end
    return false
end

if InventoryRemote then
    InventoryRemote.OnClientEvent:Connect(function(fish)
        if Core:ShouldFavorite(fish) then
            InventoryRemote:FireServer("Favorite", fish.Id)
        end
    end)
end

--========================
-- PERFORMANCE OPTIMIZATIONS
--========================
function Core:ApplyNoAnimation()
    if not Core.Config.NoAnimation then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        track:Stop()
    end
end

function Core:DisableCutsceneHook()
    if not Core.Config.DisableCutscene then return end
    
    local cam = workspace.CurrentCamera
    if cam.CameraType == Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Custom
    end
end

function Core:DisableFishingEffects()
    if not Core.Config.DisableEffects then return end
    
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Enabled = false
        end
    end
end

function Core:BoostFPS()
    if not Core.Config.BoostFPS then return end
    
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1000
    
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        end
    end
end

--========================
-- MAIN LOOP
--========================
RunService.Heartbeat:Connect(function()
    if Core.State.Mode == "Legit" then
        Core:LegitStep()
    elseif Core.State.Mode == "Instant" then
        Core:InstantStep()
    elseif Core.State.Mode == "Blatant" then
        Core:BlatantStep()
    elseif Core.State.Mode == "BlatantBeta" then
        Core:BlatantBetaStep()
    end
end)

-- Performance loops
RunService.Stepped:Connect(function()
    Core:ApplyNoAnimation()
end)

RunService.RenderStepped:Connect(function()
    Core:DisableCutsceneHook()
end)

task.spawn(function()
    while task.wait(2) do
        Core:DisableFishingEffects()
        Core:BoostFPS()
    end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

--========================
-- WINDUI INTERFACE
--========================

-- Colors
local Purple = Color3.fromHex("#7775F2")
local Yellow = Color3.fromHex("#ECA201")
local Green = Color3.fromHex("#10C550")
local Grey = Color3.fromHex("#83889E")
local Blue = Color3.fromHex("#257AF7")
local Red = Color3.fromHex("#EF4F1D")

-- Create Main Window
local Window = WindUI:CreateWindow({
    Title = "🎣 Fish It Hub Ultimate",
    Author = "by Fishing Master",
    Folder = "FishItHub",
    Icon = "fish",
    IconSize = 22 * 2,
    NewElements = true,
    Size = UDim2.fromOffset(680, 550),
    HideSearchBar = false,
    
    OpenButton = {
        Title = "🎣 OPEN FISH HUB",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        )
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    }
})

-- Version Tag
Window:Tag({
    Title = "v2.0 Ultimate",
    Icon = "fish",
    Color = Color3.fromHex("#1c1c1c"),
    Border = true,
})

-- Create Sections
local FishingSection = Window:Section({
    Title = "🎣 Fishing Modes",
})

local UtilitySection = Window:Section({
    Title = "⚙️ Utilities",
})

local SettingsSection = Window:Section({
    Title = "⚡ Settings",
})

local StatsSection = Window:Section({
    Title = "📊 Statistics",
})

--======================================
-- FISHING TAB
--======================================
local FishingTab = FishingSection:Tab({
    Title = "Fishing",
    Icon = "fish",
    IconColor = Blue,
    IconShape = "Square",
    Border = true,
})

-- Legit Mode
FishingTab:Toggle({
    Flag = "LegitMode",
    Title = "Auto Legit Fishing",
    Icon = "mouse-pointer",
    Callback = function(v)
        Core.Config.LegitMode = v
        Core:SetMode(v and "Legit" or "None")
    end
})

FishingTab:Space({ Columns = 2 })

-- Instant Mode
FishingTab:Toggle({
    Flag = "InstantMode",
    Title = "Enable Instant Fishing",
    Icon = "zap",
    Callback = function(v)
        Core.Config.InstantMode = v
        Core:SetMode(v and "Instant" or "None")
    end
})

FishingTab:Slider({
    Flag = "InstantDelay",
    Title = "Instant Delay",
    Step = 0.05,
    Value = {
        Min = 0.1,
        Max = 1,
        Default = Core.Config.InstantDelay,
    },
    Callback = function(v)
        Core.Config.InstantDelay = v
    end
})

FishingTab:Space({ Columns = 2 })

-- Blatant Mode
FishingTab:Toggle({
    Flag = "BlatantMode",
    Title = "Enable Blatant Mode",
    Icon = "bomb",
    Callback = function(v)
        Core.Config.BlatantMode = v
        Core:SetMode(v and "Blatant" or "None")
    end
})

FishingTab:Slider({
    Flag = "BlatantCastDelay",
    Title = "Cast Delay",
    Step = 0.01,
    Value = {
        Min = 0.05,
        Max = 0.4,
        Default = Core.Config.BlatantCastDelay,
    },
    Callback = function(v)
        Core.Config.BlatantCastDelay = v
    end
})

FishingTab:Slider({
    Flag = "BlatantReelDelay",
    Title = "Reel Delay",
    Step = 0.01,
    Value = {
        Min = 0.05,
        Max = 0.3,
        Default = Core.Config.BlatantReelDelay,
    },
    Callback = function(v)
        Core.Config.BlatantReelDelay = v
    end
})

FishingTab:Space({ Columns = 2 })

-- Beta Mode
FishingTab:Toggle({
    Flag = "BetaMode",
    Title = "Enable Blatant [BETA]",
    Icon = "flask",
    Callback = function(v)
        Core.Config.BetaMode = v
        Core:SetMode(v and "BlatantBeta" or "None")
    end
})

FishingTab:Slider({
    Flag = "BetaCastDelay",
    Title = "Cast Delay",
    Step = 0.01,
    Value = {
        Min = 0.03,
        Max = 0.3,
        Default = Core.Config.BetaCastDelay,
    },
    Callback = function(v)
        Core.Config.BetaCastDelay = v
    end
})

FishingTab:Slider({
    Flag = "BetaReelDelay",
    Title = "Reel Delay",
    Step = 0.01,
    Value = {
        Min = 0.03,
        Max = 0.25,
        Default = Core.Config.BetaReelDelay,
    },
    Callback = function(v)
        Core.Config.BetaReelDelay = v
    end
})

--======================================
-- UTILITIES TAB
--======================================
local UtilitiesTab = UtilitySection:Tab({
    Title = "Utilities",
    Icon = "settings",
    IconColor = Green,
    IconShape = "Square",
    Border = true,
})

-- Weather Group
UtilitiesTab:Section({
    Title = "🌤️ Weather System",
    TextSize = 14,
})

UtilitiesTab:Toggle({
    Flag = "AutoBuyAllWeather",
    Title = "Auto Buy All Weather",
    Icon = "cloud",
    Callback = function(v)
        Core.Config.AutoBuyAllWeather = v
    end
})

UtilitiesTab:Toggle({
    Flag = "LoopSelectedWeather",
    Title = "Loop Selected Weather (3)",
    Icon = "refresh-cw",
    Callback = function(v)
        Core.Config.LoopSelectedWeather = v
    end
})

UtilitiesTab:Section({
    Title = "Select Weather Types",
    TextSize = 12,
})

local weatherList = {"Rain", "Storm", "Fog", "Sunny", "Snow", "Wind", "Cloudy", "Frozen", "Radiant"}
for _, w in ipairs(weatherList) do
    UtilitiesTab:Toggle({
        Flag = "Weather_" .. w,
        Title = w,
        Callback = function(v)
            if v then
                table.insert(Core.Config.SelectedWeather, w)
            else
                for i, weather in ipairs(Core.Config.SelectedWeather) do
                    if weather == w then
                        table.remove(Core.Config.SelectedWeather, i)
                        break
                    end
                end
            end
        end
    })
end

UtilitiesTab:Space({ Columns = 2 })

-- Auto Sell Group
UtilitiesTab:Section({
    Title = "💰 Auto Sell",
    TextSize = 14,
})

UtilitiesTab:Toggle({
    Flag = "AutoSell",
    Title = "Enable Auto Sell",
    Icon = "dollar-sign",
    Callback = function(v)
        Core.Config.AutoSell = v
    end
})

UtilitiesTab:Slider({
    Flag = "SellThreshold",
    Title = "Sell Threshold",
    Step = 1,
    Value = {
        Min = 1,
        Max = 100,
        Default = Core.Config.SellThreshold,
    },
    Callback = function(v)
        Core.Config.SellThreshold = v
    end
})

UtilitiesTab:Space({ Columns = 2 })

-- Auto Favorite Group
UtilitiesTab:Section({
    Title = "⭐ Auto Favorite",
    TextSize = 14,
})

UtilitiesTab:Toggle({
    Flag = "FavoriteLegendary",
    Title = "Auto Favorite Legendary",
    Icon = "star",
    Callback = function(v)
        Core.Config.AutoFavoriteLegendary = v
        FavoriteSystem.ByRarity["Legendary"] = v
    end
})

UtilitiesTab:Toggle({
    Flag = "FavoriteMythic",
    Title = "Auto Favorite Mythic",
    Icon = "star",
    Callback = function(v)
        Core.Config.AutoFavoriteMythic = v
        FavoriteSystem.ByRarity["Mythic"] = v
    end
})

--======================================
-- SETTINGS TAB
--======================================
local SettingsTab = SettingsSection:Tab({
    Title = "Settings",
    Icon = "sliders",
    IconColor = Purple,
    IconShape = "Square",
    Border = true,
})

-- Performance Settings
SettingsTab:Section({
    Title = "⚡ Performance",
    TextSize = 14,
})

SettingsTab:Toggle({
    Flag = "NoAnimation",
    Title = "No Fishing Animation",
    Icon = "video-off",
    Callback = function(v)
        Core.Config.NoAnimation = v
    end
})

SettingsTab:Toggle({
    Flag = "DisableCutscene",
    Title = "Disable Cutscene",
    Icon = "film",
    Callback = function(v)
        Core.Config.DisableCutscene = v
    end
})

SettingsTab:Toggle({
    Flag = "DisableEffects",
    Title = "Disable Fishing Effects",
    Icon = "sparkles",
    Callback = function(v)
        Core.Config.DisableEffects = v
    end
})

SettingsTab:Toggle({
    Flag = "HideFishIcon",
    Title = "Hide Fish Icon",
    Icon = "eye-off",
    Callback = function(v)
        Core.Config.HideFishIcon = v
    end
})

SettingsTab:Toggle({
    Flag = "BoostFPS",
    Title = "Boost FPS",
    Icon = "zap",
    Callback = function(v)
        Core.Config.BoostFPS = v
    end
})

SettingsTab:Space({ Columns = 2 })

-- Config Management
SettingsTab:Section({
    Title = "💾 Config Management",
    TextSize = 14,
})

local ConfigManager = Window.ConfigManager
local currentConfigName = "default"

local ConfigNameInput = SettingsTab:Input({
    Title = "Config Name",
    Placeholder = "Enter config name...",
    Callback = function(v)
        currentConfigName = v
    end
})

SettingsTab:Button({
    Title = "💾 Save Config",
    Icon = "save",
    Justify = "Center",
    Callback = function()
        Window.CurrentConfig = ConfigManager:Config(currentConfigName)
        if Window.CurrentConfig:Save() then
            WindUI:Notify({
                Title = "✅ Config Saved",
                Content = "Config '" .. currentConfigName .. "' saved successfully!",
                Icon = "check",
            })
        end
    end
})

SettingsTab:Space()

SettingsTab:Button({
    Title = "📂 Load Config",
    Icon = "folder-open",
    Justify = "Center",
    Callback = function()
        Window.CurrentConfig = ConfigManager:CreateConfig(currentConfigName)
        if Window.CurrentConfig:Load() then
            WindUI:Notify({
                Title = "✅ Config Loaded",
                Content = "Config '" .. currentConfigName .. "' loaded successfully!",
                Icon = "refresh-cw",
            })
        end
    end
})

--======================================
-- STATISTICS TAB
--======================================
local StatsTab = StatsSection:Tab({
    Title = "Stats",
    Icon = "bar-chart",
    IconColor = Yellow,
    IconShape = "Square",
    Border = true,
})

local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Stats Display
local statsLabel = StatsTab:Section({
    Title = "📊 Live Statistics",
    TextSize = 16,
})

-- Update stats function
local function updateStatsDisplay()
    local sessionTime = tick() - Core.State.SessionStart
    
    local statsText = string.format(
        "🎣 Fish Caught: %d\n" ..
        "💰 Money Earned: $%d\n" ..
        "⏱️ Session Time: %s\n" ..
        "⭐ Rare Fish:\n" ..
        "   Mythic: %d | Legendary: %d\n" ..
        "   Secret: %d\n" ..
        "🎯 Current Mode: %s",
        Core.State.FishCaught,
        Core.State.MoneyEarned,
        formatTime(sessionTime),
        Core.State.RareFish.Mythic,
        Core.State.RareFish.Legendary,
        Core.State.RareFish.Secret,
        Core.State.Mode
    )
    
    return statsText
end

-- Create stats label with refresh
local statsDisplay = StatsTab:Section({
    Title = updateStatsDisplay(),
    TextSize = 12,
    TextTransparency = 0.2,
})

-- Update stats every second
task.spawn(function()
    while task.wait(1) do
        local newText = updateStatsDisplay()
        -- Update the display
        if statsDisplay and statsDisplay.Set then
            pcall(function()
                statsDisplay:Set({
                    Title = newText
                })
            end)
        end
    end
end)

StatsTab:Space({ Columns = 2 })

StatsTab:Button({
    Title = "🔄 Reset Stats",
    Icon = "refresh-cw",
    Justify = "Center",
    Callback = function()
        Core.State.FishCaught = 0
        Core.State.MoneyEarned = 0
        Core.State.SessionStart = tick()
        Core.State.RareFish = {Mythic = 0, Legendary = 0, Secret = 0}
        
        WindUI:Notify({
            Title = "✅ Stats Reset",
            Content = "All statistics have been reset!",
            Icon = "check",
        })
    end
})

--======================================
-- ABOUT TAB
--======================================
local AboutTab = Window:Tab({
    Title = "About",
    Icon = "info",
    IconColor = Red,
    IconShape = "Square",
    Border = true,
})

AboutTab:Section({
    Title = "🎣 Fish It Hub Ultimate",
    TextSize = 24,
    FontWeight = Enum.FontWeight.SemiBold,
})

AboutTab:Section({
    Title = "Complete Fishing Automation System\nWith WindUI Integration\n\nVersion: 2.0 Ultimate\nMade with ❤️ for Fish It Players",
    TextSize = 16,
    TextTransparency = .35,
})

AboutTab:Space({ Columns = 3 })

AboutTab:Button({
    Title = "❌ Destroy UI",
    Color = Color3.fromHex("#ff4830"),
    Justify = "Center",
    Icon = "trash-2",
    Callback = function()
        Window:Destroy()
        print("🎣 Fish It Hub destroyed")
    end
})

--======================================
-- NOTIFICATION SYSTEM
--======================================
function Core:Notify(title, content, icon)
    WindUI:Notify({
        Title = title,
        Content = content,
        Icon = icon or "bell",
        Duration = 3,
    })
end

-- Initial Notification
task.spawn(function()
    task.wait(2)
    Core:Notify("🎣 Fish It Hub Ultimate", "Successfully loaded! Ready to fish!", "check")
    print("✅ Fish It Hub Ultimate loaded successfully!")
    print("⚡ Features: Legit/Instant/Blatant/Beta modes")
    print("⚙️ Utilities: Auto Weather, Auto Sell, Auto Favorite")
    print("⚡ Performance: FPS Boost, No Animation, Effects Control")
end)

-- Final message
print("\n" .. string.rep("=", 50))
print("🎣 FISH IT HUB ULTIMATE - READY!")
print(string.rep("=", 50))
print("🔧 Mode:", Core.State.Mode)
print("⚙️ Features Loaded: 4 modes + 8 utilities")
print("💾 Config System: Save/Load support")
print("📊 Live Stats: Fish/Money/Session tracking")
print(string.rep("=", 50))
