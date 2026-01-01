--=====================================================
-- FISH IT HUB - CORE FISHING ENGINE WITH WINDUI
--=====================================================

--========================
-- SERVICES
--========================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

--========================
-- REMOTES (FISH IT)
--========================
local Remotes = RS:WaitForChild("Remotes")
local FishingRemote = Remotes:WaitForChild("Fishing")
local WeatherRemote = Remotes:WaitForChild("Weather")
local SellRemote = Remotes:WaitForChild("Sell")
local InventoryRemote = Remotes:WaitForChild("Inventory")

--========================
-- CORE TABLE
--========================
local Core = {}

--========================
-- STATE MANAGER
--========================
Core.State = {
    Mode = "None",           -- None | Legit | Instant | Blatant | BlatantBeta
    Busy = false,            -- anti overlap
    LastCast = 0,
    LastReel = 0,
}

--========================
-- DELAY CONTROLLER
--========================
Core.Delay = {
    InstantDelay = 0.25,

    Blatant = {
        Cast = 0.18,
        Reel = 0.12,
        ReelCount = 6,
    },

    Beta = {
        Cast = 0.10,
        Reel = 0.08,
        ReelCount = 12,
    }
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
end

--========================
-- INPUT HELPER (LEGIT)
--========================
function Core:TapMouse()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    task.wait(0.03)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

--========================
-- CAST / REEL ACTIONS
--========================
function Core:Cast()
    FishingRemote:FireServer("Cast")
    Core.State.LastCast = tick()
end

function Core:Reel()
    FishingRemote:FireServer("Reel")
    Core.State.LastReel = tick()
end

--========================
-- LEGIT MODE
--========================
function Core:LegitStep()
    if Core.State.Busy then return end
    Core:TapMouse()
end

--========================
-- INSTANT MODE
--========================
function Core:InstantStep()
    if Core.State.Busy then return end
    Core.State.Busy = true

    Core:Cast()
    task.wait(Core.Delay.InstantDelay)
    Core:Reel()

    Core.State.Busy = false
end

--========================
-- BLATANT STABLE MODE
--========================
function Core:BlatantStep()
    if Core.State.Busy then return end
    Core.State.Busy = true

    Core:Cast()
    task.wait(Core.Delay.Blatant.Cast)

    for i = 1, Core.Delay.Blatant.ReelCount do
        Core:Reel()
        task.wait(Core.Delay.Blatant.Reel)
    end

    Core.State.Busy = false
end

--========================
-- BLATANT BETA MODE
--========================
function Core:BlatantBetaStep()
    if Core.State.Busy then return end
    Core.State.Busy = true

    Core:Cast()
    task.wait(Core.Delay.Beta.Cast)

    for i = 1, Core.Delay.Beta.ReelCount do
        Core:Reel()
        task.wait(Core.Delay.Beta.Reel)
    end

    Core.State.Busy = false
end

--========================
-- NOTIFICATION VISUAL CONTROLLER
--========================
Core.Notif = {
    Active = {},
    HoldTime = {
        Blatant = 2.8,
        Beta = 4.5,
    },
    MaxStack = 12
}

function Core:IsVisualMode()
    return Core.State.Mode == "Blatant" or Core.State.Mode == "BlatantBeta"
end

local CoreGui = game:GetService("CoreGui")

function Core:InitNotifHook()
    for _,gui in ipairs(CoreGui:GetChildren()) do
        self:TryHookNotif(gui)
        self:HideFishIconOnly(gui)
    end

    CoreGui.ChildAdded:Connect(function(gui)
        self:TryHookNotif(gui)
        self:HideFishIconOnly(gui)
    end)
end

function Core:TryHookNotif(gui)
    if not self:IsVisualMode() then return end
    if not gui:IsA("ScreenGui") then return end

    local frame = gui:FindFirstChildWhichIsA("Frame", true)
    local text = gui:FindFirstChildWhichIsA("TextLabel", true)
    local icon = gui:FindFirstChildWhichIsA("ImageLabel", true)

    if not frame or not text or not icon then return end
    if #text.Text < 2 then return end

    self:StackNotif(frame)
end

function Core:StackNotif(frame)
    if #self.Notif.Active >= self.Notif.MaxStack then return end

    local clone = frame:Clone()
    clone.Parent = frame.Parent

    local index = #self.Notif.Active
    clone.Position = clone.Position + UDim2.new(0, 0, 0, index * 58)

    table.insert(self.Notif.Active, clone)

    local hold =
        (self.State.Mode == "BlatantBeta")
        and self.Notif.HoldTime.Beta
        or self.Notif.HoldTime.Blatant

    task.delay(hold, function()
        if clone and clone.Parent then
            clone:Destroy()
        end
    end)
end

task.spawn(function()
    while task.wait(1) do
        for i = #Core.Notif.Active, 1, -1 do
            local gui = Core.Notif.Active[i]
            if not gui or not gui.Parent then
                table.remove(Core.Notif.Active, i)
            end
        end
    end
end)

Core:InitNotifHook()

--========================
-- MISC / PERFORMANCE STATE
--========================
Core.Misc = {
    NoAnimation = false,
    DisableCutscene = false,
    DisableEffects = false,
    HideFishIcon = false,
    BoostFPS = false,
}

function Core:ApplyNoAnimation()
    if not self.Misc.NoAnimation then return end

    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    for _,track in ipairs(hum:GetPlayingAnimationTracks()) do
        track:Stop()
    end
end

function Core:DisableCutsceneHook()
    if not self.Misc.DisableCutscene then return end

    local cam = workspace.CurrentCamera
    if cam.CameraType == Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Custom
    end
end

function Core:DisableFishingEffects()
    if not self.Misc.DisableEffects then return end

    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Enabled = false
        end
    end
end

function Core:HideFishIconOnly(gui)
    if not self.Misc.HideFishIcon then return end

    for _,img in ipairs(gui:GetDescendants()) do
        if img:IsA("ImageLabel") then
            img.ImageTransparency = 1
        end
    end
end

function Core:BoostFPS()
    if not self.Misc.BoostFPS then return end

    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        end
    end
end

--========================
-- WEATHER ENGINE
--========================
Core.Weather = {
    AutoBuyAll = false,
    LoopEnabled = false,
    Selected = {}, -- max 3
    Delay = 0.6
}

function Core:AddWeather(name)
    if #self.Weather.Selected >= 3 then return end
    for _,v in ipairs(self.Weather.Selected) do
        if v == name then return end
    end
    table.insert(self.Weather.Selected, name)
end

function Core:RemoveWeather(name)
    for i,v in ipairs(self.Weather.Selected) do
        if v == name then
            table.remove(self.Weather.Selected, i)
            break
        end
    end
end

task.spawn(function()
    while task.wait(4) do
        if Core.Weather.AutoBuyAll then
            for _,weather in ipairs({"Wind","Cloudy","Frozen","Storm","Radiant"}) do
                WeatherRemote:FireServer("Buy", weather)
                task.wait(Core.Weather.Delay)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(5) do
        if Core.Weather.LoopEnabled and #Core.Weather.Selected == 3 then
            for _,weather in ipairs(Core.Weather.Selected) do
                WeatherRemote:FireServer("Buy", weather)
                task.wait(Core.Weather.Delay)
            end
        end
    end
end)

--========================
-- AUTO SELL ENGINE
--========================
Core.Sell = {
    Threshold = 10,
    Enabled = false,
    Delay = 3
}

task.spawn(function()
    while task.wait(Core.Sell.Delay) do
        if Core.Sell.Enabled and Core.Sell.Threshold > 0 then
            SellRemote:FireServer(Core.Sell.Threshold)
        end
    end
end)

--========================
-- FAVORITE ENGINE
--========================
Core.Favorite = {
    ByRarity = {}, -- ["Legendary"]=true
    ByName = {},   -- ["Golden Tuna"]=true
}

function Core:ShouldFavorite(fish)
    if self.Favorite.ByName[fish.Name] then
        return true
    end
    if self.Favorite.ByRarity[fish.Rarity] then
        return true
    end
    return false
end

InventoryRemote.OnClientEvent:Connect(function(fish)
    if Core:ShouldFavorite(fish) then
        InventoryRemote:FireServer("Favorite", fish.Id)
    end
end)

--========================
-- MAIN ENGINE LOOP
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

RunService.Stepped:Connect(function()
    Core:ApplyNoAnimation()
end)

RunService.RenderStepped:Connect(function()
    Core:DisableCutsceneHook()
end)

task.spawn(function()
    while task.wait(2) do
        Core:DisableFishingEffects()
        if Core.Misc.BoostFPS then
            Core:BoostFPS()
        end
    end
end)

--=====================================================
-- WINDUI INTEGRATION
--=====================================================

-- Load WindUI
local WindUI
do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)
    
    if ok then
        WindUI = result
    else 
        WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end
end

-- Create Main Window
local Window = WindUI:CreateWindow({
    Title = "Fish It Hub",
    Theme = "Dark",
    Size = UDim2.fromScale(0.55, 0.65),
    HasOutline = true,
    OpenButton = {
        Title = "Open Fish It Hub",
        CornerRadius = UDim.new(1,0),
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
    },
    Folder = "FishItHub"
})

-- Create Tabs
local TabFishing  = Window:CreateTab("Fishing","fish")
local TabInstant  = Window:CreateTab("Instant","zap")
local TabBlatant  = Window:CreateTab("Blatant","bomb")
local TabBeta     = Window:CreateTab("Blatant [BETA]","flask")
local TabMisc     = Window:CreateTab("MISC","settings")
local TabWeather  = Window:CreateTab("Weather","cloud")
local TabFav      = Window:CreateTab("Favorite","star")
local TabSell     = Window:CreateTab("Sell","dollar-sign")

-- Fishing Tab
TabFishing:CreateToggle({
    Name = "Auto Legit Fishing",
    Callback = function(v)
        Core:SetMode(v and "Legit" or "None")
    end
})

-- Instant Tab
TabInstant:CreateToggle({
    Flag = "InstantMode",
    Name = "Enable Instant Fishing",
    Callback = function(v)
        Core:SetMode(v and "Instant" or "None")
    end
})

TabInstant:CreateSlider({
    Flag = "InstantDelay",
    Name = "Instant Delay",
    Min = 0.1,
    Max = 1,
    Default = Core.Delay.InstantDelay,
    Increment = 0.05,
    Callback = function(v)
        Core.Delay.InstantDelay = v
    end
})

-- Blatant Tab
TabBlatant:CreateToggle({
    Flag = "BlatantMode",
    Name = "Enable Blatant Mode",
    Callback = function(v)
        Core:SetMode(v and "Blatant" or "None")
    end
})

TabBlatant:CreateSlider({
    Flag = "BlatantCastDelay",
    Name = "Cast / Bait Delay",
    Min = 0.05,
    Max = 0.4,
    Default = Core.Delay.Blatant.Cast,
    Increment = 0.01,
    Callback = function(v)
        Core.Delay.Blatant.Cast = v
    end
})

TabBlatant:CreateSlider({
    Flag = "BlatantReelDelay",
    Name = "Reel Delay",
    Min = 0.05,
    Max = 0.3,
    Default = Core.Delay.Blatant.Reel,
    Increment = 0.01,
    Callback = function(v)
        Core.Delay.Blatant.Reel = v
    end
})

-- Beta Tab
TabBeta:CreateToggle({
    Flag = "BetaMode",
    Name = "Enable Blatant Mode [BETA]",
    Callback = function(v)
        Core:SetMode(v and "BlatantBeta" or "None")
    end
})

TabBeta:CreateSlider({
    Flag = "BetaCastDelay",
    Name = "Cast / Bait Delay",
    Min = 0.03,
    Max = 0.3,
    Default = Core.Delay.Beta.Cast,
    Increment = 0.01,
    Callback = function(v)
        Core.Delay.Beta.Cast = v
    end
})

TabBeta:CreateSlider({
    Flag = "BetaReelDelay",
    Name = "Reel Delay",
    Min = 0.03,
    Max = 0.25,
    Default = Core.Delay.Beta.Reel,
    Increment = 0.01,
    Callback = function(v)
        Core.Delay.Beta.Reel = v
    end
})

-- Favorite Tab
TabFav:CreateToggle({
    Flag = "FavoriteLegendary",
    Name = "Auto Favorite Legendary",
    Callback = function(v) 
        Core.Favorite.ByRarity["Legendary"] = v 
    end
})

TabFav:CreateToggle({
    Flag = "FavoriteMythic",
    Name = "Auto Favorite Mythic",
    Callback = function(v) 
        Core.Favorite.ByRarity["Mythic"] = v 
    end
})

-- Sell Tab
TabSell:CreateToggle({
    Flag = "AutoSell",
    Name = "Enable Auto Sell",
    Callback = function(v) 
        Core.Sell.Enabled = v 
    end
})

TabSell:CreateSlider({
    Flag = "SellThreshold",
    Name = "Auto Sell Threshold",
    Min = 1,
    Max = 100,
    Default = Core.Sell.Threshold,
    Increment = 1,
    Callback = function(v)
        Core.Sell.Threshold = v
    end
})

-- Weather Tab
TabWeather:CreateToggle({
    Flag = "AutoBuyAllWeather",
    Name = "Auto Buy All Weather",
    Callback = function(v)
        Core.Weather.AutoBuyAll = v
    end
})

TabWeather:CreateToggle({
    Flag = "LoopSelectedWeather",
    Name = "Loop Selected Weather (3)",
    Callback = function(v)
        Core.Weather.LoopEnabled = v
    end
})

-- Weather Selection
local weatherList = {"Rain","Storm","Fog","Sunny","Snow","Wind","Cloudy","Frozen","Radiant"}
for _,w in ipairs(weatherList) do
    TabWeather:CreateToggle({
        Flag = "Weather_"..w,
        Name = "Select "..w,
        Callback = function(v)
            if v then
                Core:AddWeather(w)
            else
                Core:RemoveWeather(w)
            end
        end
    })
end

-- Misc Tab
TabMisc:CreateToggle({
    Flag = "NoAnimation",
    Name = "No Fishing Animation",
    Callback = function(v) 
        Core.Misc.NoAnimation = v 
    end
})

TabMisc:CreateToggle({
    Flag = "DisableCutscene",
    Name = "Disable Cutscene",
    Callback = function(v) 
        Core.Misc.DisableCutscene = v 
    end
})

TabMisc:CreateToggle({
    Flag = "DisableEffects",
    Name = "Disable Fishing Effects",
    Callback = function(v) 
        Core.Misc.DisableEffects = v 
    end
})

TabMisc:CreateToggle({
    Flag = "HideFishIcon",
    Name = "Hide Fish Notification Icon",
    Callback = function(v) 
        Core.Misc.HideFishIcon = v 
    end
})

TabMisc:CreateToggle({
    Flag = "BoostFPS",
    Name = "Boost FPS",
    Callback = function(v) 
        Core.Misc.BoostFPS = v 
    end
})

-- About Tab
local AboutTab = Window:CreateTab("About","info-circle")

AboutTab:CreateSection({
    Title = "Fish It Hub",
    TextSize = 24,
    FontWeight = Enum.FontWeight.SemiBold,
})

AboutTab:CreateSection({
    Title = "Advanced Fishing Automation System\nWith WindUI Integration",
    TextSize = 16,
    TextTransparency = .35,
})

AboutTab:CreateButton({
    Title = "Destroy UI",
    Color = Color3.fromHex("#ff4830"),
    Justify = "Center",
    Callback = function()
        Window:Destroy()
    end
})

-- Create notification function
function Core:Notify(title, content, icon)
    WindUI:Notify({
        Title = title,
        Content = content,
        Icon = icon or "bell",
        Duration = 3,
    })
end

-- Initial notification
task.spawn(function()
    task.wait(1)
    Core:Notify("Fish It Hub", "Successfully loaded with WindUI!", "check")
end)

print("Fish It Hub with WindUI loaded successfully!")
