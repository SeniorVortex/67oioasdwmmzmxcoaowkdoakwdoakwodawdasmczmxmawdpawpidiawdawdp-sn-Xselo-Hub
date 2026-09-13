--[[
    RESENHA BATTLES • SLAP FARM
    Native Roblox LocalScript for Debug Battles / private testing.

    Place in:
    StarterPlayer > StarterPlayerScripts

    This build intentionally removes the old giant menu, glove-acquisition tools,
    anti-cheat bypasses, executor-only APIs, badge farms, mastery farms, etc.
    Kept: Slap Farm, Clone Help, Slap Aura, Fly, Jump, Bed safe teleport.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    Title = "RESENHA BATTLES",
    Subtitle = "SLAP FARM • SATORI BUILD",

    -- rbxthumb accepts the uploaded asset/decal ID directly and avoids the
    -- annoying Decal ID vs Image ID conversion when the image is set by script.
    LauncherImage = "rbxthumb://type=Asset&id=103820753794350&w=420&h=420", -- Messi
    BackgroundImage = "rbxthumb://type=Asset&id=41873477&w=768&h=432", -- Satori background
    Discord = "discord.gg/Mdbn6QW7",

    -- Satori Komeiji-ish palette: deep plum, dusty rose and third-eye magenta.
    Purple = Color3.fromRGB(218, 91, 160),
    Purple2 = Color3.fromRGB(172, 72, 137),
    Purple3 = Color3.fromRGB(104, 55, 101),
    Background = Color3.fromRGB(21, 9, 24),
    Surface = Color3.fromRGB(39, 19, 40),
    Surface2 = Color3.fromRGB(53, 26, 54),
    Surface3 = Color3.fromRGB(72, 35, 72),
    Text = Color3.fromRGB(255, 239, 249),
    Muted = Color3.fromRGB(210, 168, 200),
    Success = Color3.fromRGB(182, 242, 216),
    Danger = Color3.fromRGB(255, 103, 151),

    SlapDelay = 1.35, -- conservative default: one valid slap per recovery cycle
    AuraDelay = 0.75, -- same default from the old Slap Aura
    AuraRange = 25,   -- same default reach from the old Slap Aura
    CloneReturnDelay = 0.35,
}

local state = {
    MenuOpen = true,
    ActiveAccountTab = "Main",

    CloneUsername = "",
    MainUsername = "",

    MainFarmEnabled = false,
    CloneHelpEnabled = false,
    MainFarmReady = false,
    CloneHelpReady = false,
    SlapDelay = CONFIG.SlapDelay,

    AuraEnabled = false,
    AuraRange = CONFIG.AuraRange,
    AuraDelay = CONFIG.AuraDelay,
    AuraStatus = "Press H to toggle",

    FlyEnabled = false,
    FlySpeed = 50,
    JumpPower = 50,

    MainStatus = "Waiting for setup",
    CloneStatus = "Waiting for setup",
}

-- ============================================================
-- Utilities
-- ============================================================

local function new(className, props, parent)
    local obj = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            obj[k] = v
        end
    end
    if parent then
        obj.Parent = parent
    end
    return obj
end

local function corner(parent, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, parent)
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or CONFIG.Purple,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function padding(parent, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or l or 0),
        PaddingTop = UDim.new(0, t or l or 0),
        PaddingBottom = UDim.new(0, b or t or l or 0),
    }, parent)
end

local function tween(instance, duration, properties, style, direction)
    local tw = TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        properties
    )
    tw:Play()
    return tw
end

local function trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$")
end

local function getCharacter(player)
    player = player or LocalPlayer
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return nil end
    return char, root, humanoid
end

local function findPlayer(name)
    name = trim(name)
    if name == "" then return nil end
    local lower = name:lower()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower() == lower then
            return plr
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower():sub(1, #lower) == lower then
            return plr
        end
    end

    return nil
end

local function setRootCFrame(cf)
    local char, root = getCharacter(LocalPlayer)
    if not char then return false end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = cf
    return true
end

-- ============================================================
-- Safe bed, based on the old Bed safe teleport
-- ============================================================

local SAFE_BED_NAME = "ResenhaSafeBed"
local BED_CENTER = Vector3.new(-100019, 104, -1500)
local bedModel
local bedTop

local function ensureSafeBed()
    if bedModel and bedModel.Parent and bedTop and bedTop.Parent then
        return bedTop
    end

    local oldBed = workspace:FindFirstChild("Bed")
    if oldBed and oldBed:FindFirstChild("Bed3") and oldBed.Bed3:IsA("BasePart") then
        bedModel = oldBed
        bedTop = oldBed.Bed3
        return bedTop
    end

    local existing = workspace:FindFirstChild(SAFE_BED_NAME)
    if existing and existing:FindFirstChild("Bed3") then
        bedModel = existing
        bedTop = existing.Bed3
        return bedTop
    end

    bedModel = new("Model", {Name = SAFE_BED_NAME}, workspace)

    local function bedPart(name, size, pos, color)
        local p = new("Part", {
            Name = name,
            Anchored = true,
            CanCollide = true,
            CanTouch = true,
            CanQuery = true,
            Material = Enum.Material.SmoothPlastic,
            Color = color,
            Size = size,
            Position = pos,
        }, bedModel)
        return p
    end

    bedPart("Bed1", Vector3.new(1, 6, 7), Vector3.new(-100025, 104, -1500), Color3.fromRGB(83, 48, 34))
    bedPart("Bed2", Vector3.new(2, 1, 6), Vector3.new(-100023, 104.5, -1500), Color3.fromRGB(92, 86, 103))
    bedTop = bedPart("Bed3", Vector3.new(11, 1, 7), BED_CENTER, Color3.fromRGB(100, 53, 160))
    bedPart("Bed4", Vector3.new(1, 6, 7), Vector3.new(-100013, 104, -1500), Color3.fromRGB(83, 48, 34))
    bedPart("Bed5", Vector3.new(11, 1, 7), Vector3.new(-100019, 103, -1500), Color3.fromRGB(56, 33, 86))

    return bedTop
end

local function bedBaseCFrame()
    local top = ensureSafeBed()
    return top.CFrame * CFrame.new(0, 3.2, -1)
end

local function mainFarmCFrame()
    local base = bedBaseCFrame()
    -- Bus Mastery pattern: keep both accounts 6.5 studs apart.
    return base * CFrame.new(-3.25, 0, 0)
end

local function cloneFarmCFrame()
    local base = bedBaseCFrame()
    return base * CFrame.new(3.25, 0, 0)
end

local function teleportToBed(role)
    if role == "Main" then
        return setRootCFrame(mainFarmCFrame())
    elseif role == "Clone" then
        return setRootCFrame(cloneFarmCFrame())
    end
    return setRootCFrame(bedBaseCFrame())
end

local function ensureArenaThenTeleport(role)
    if role == "Main" then
        state.MainFarmReady = false
    elseif role == "Clone" then
        state.CloneHelpReady = false
    end

    task.spawn(function()
        local char, root, humanoid = getCharacter(LocalPlayer)
        if not char then return end

        if not char:FindFirstChild("entered") then
            local lobby = workspace:FindFirstChild("Lobby")
            local tele = lobby and lobby:FindFirstChild("Teleport1")
            if tele and tele:IsA("BasePart") then
                root.CFrame = tele.CFrame * CFrame.new(0, 2, 0)
                local started = os.clock()
                repeat
                    task.wait(0.1)
                    char = LocalPlayer.Character
                until not char or char:FindFirstChild("entered") or os.clock() - started > 4
            end
        end

        task.wait(0.15)
        teleportToBed(role)
        if role == "Main" then
            state.MainFarmReady = true
        elseif role == "Clone" then
            state.CloneHelpReady = true
        end
    end)
end

-- ============================================================
-- Slap handling
-- ============================================================

local GLOVE_REMOTE_NAMES = {
    ["Default"] = "b", ["Extended"] = "b", ["Ketchup Default"] = "b", ["Default but Bad"] = "dbb",
    ["ZZZZZZZ"] = "ZZZZZZZHit", ["Dual"] = "DualHit", ["Brick"] = "BrickHit", ["Snow"] = "SnowHit",
    ["Pull"] = "PullHit", ["Flash"] = "FlashHit", ["Spring"] = "springhit", ["Swapper"] = "HitSwapper",
    ["Bull"] = "BullHit", ["Dice"] = "DiceHit", ["Ghost"] = "GhostHit", ["Stun"] = "HtStun",
    ["Za Hando"] = "zhramt", ["Fort"] = "Fort", ["Magnet"] = "MagnetHIT", ["Pusher"] = "PusherHit",
    ["Anchor"] = "hitAnchor", ["Space"] = "HtSpace", ["Boomerang"] = "BoomerangH", ["Speedrun"] = "Speedrunhit",
    ["Mail"] = "MailHit", ["Golden"] = "GoldenHit", ["MR"] = "MisterHit", ["Reaper"] = "ReaperHit",
    ["Replica"] = "ReplicaHit", ["Defense"] = "DefenseHit", ["Killstreak"] = "KSHit", ["Reverse"] = "ReverseHit",
    ["Shukuchi"] = "ShukuchiHit", ["Duelist"] = "DuelistHit", ["woah"] = "woahHit", ["Ice"] = "IceHit",
    ["Adios"] = "hitAdios", ["Blocked"] = "BlockedHit", ["Engineer"] = "engiehit", ["Rocky"] = "RockyHit",
    ["Conveyor"] = "ConvHit", ["STOP"] = "STOP", ["Phantom"] = "PhantomHit", ["Wormhole"] = "WormHit",
    ["Acrobat"] = "AcHit", ["Plague"] = "PlagueHit", ["[REDACTED]"] = "ReHit", ["bus"] = "hitbus",
    ["Phase"] = "PhaseH", ["Warp"] = "WarpHt", ["Bomb"] = "BombHit", ["Bubble"] = "BubbleHit",
    ["Jet"] = "JetHit", ["Shard"] = "ShardHIT", ["potato"] = "potatohit", ["CULT"] = "CULTHit",
    ["bob"] = "bobhit", ["Buddies"] = "buddiesHIT", ["Spy"] = "SpyHit", ["Detonator"] = "DetonatorHit",
    ["Rage"] = "GRRRR", ["Trap"] = "traphi", ["Orbit"] = "Orbihit", ["Hybrid"] = "HybridCLAP",
    ["Slapple"] = "SlappleHit", ["Disarm"] = "DisarmH", ["Dominance"] = "DominanceHit", ["Link"] = "LinkHit",
    ["Rojo"] = "RojoHit", ["rob"] = "robhit", ["Rhythm"] = "rhythmhit", ["Nightmare"] = "nightmarehit",
    ["Hitman"] = "HitmanHit", ["Thor"] = "ThorHit", ["Retro"] = "RetroHit", ["Cloud"] = "CloudHit",
    ["Null"] = "NullHit", ["spin"] = "spinhit", ["Pylon"] = "PylonHit", ["Leafblower"] = "LeafblowerHit",
    ["Poltergeist"] = "UTGHit", ["Clock"] = "UTGHit", ["Untitled Tag Glove"] = "UTGHit",
    ["Kinetic"] = "HtStun", ["Recall"] = "HtStun", ["Balloony"] = "HtStun", ["Sparky"] = "HtStun",
    ["Boogie"] = "HtStun", ["Coil"] = "HtStun", ["Diamond"] = "DiamondHit", ["Megarock"] = "DiamondHit",
    ["Moon"] = "CelestialHit", ["Jupiter"] = "CelestialHit", ["Mitten"] = "MittenHit", ["Hallow Jack"] = "HallowHIT",
    ["OVERKILL"] = "Overkillhit", ["The Flex"] = "FlexHit", ["Custom"] = "CustomHit", ["God's Hand"] = "Godshand",
    ["Error"] = "Errorhit",
}

local function getCurrentGlove()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local glove = leaderstats and leaderstats:FindFirstChild("Glove")
    if glove then
        return tostring(glove.Value)
    end
    return nil
end

local function equipCurrentTool()
    local char = LocalPlayer.Character
    if not char then return nil end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then return nil end

    local gloveName = getCurrentGlove()
    for _, candidate in ipairs(backpack:GetChildren()) do
        if candidate:IsA("Tool") then
            if candidate:FindFirstChild("Glove") or candidate.Name == gloveName then
                candidate.Parent = char
                return candidate
            end
        end
    end

    return nil
end

local function getSlapRemote()
    local current = getCurrentGlove()
    local remoteName = current and GLOVE_REMOTE_NAMES[current]
    local remote

    if remoteName then
        remote = ReplicatedStorage:FindFirstChild(remoteName, true)
    end

    if not remote then
        remote = ReplicatedStorage:FindFirstChild("GeneralHit", true)
    end

    if remote and remote:IsA("RemoteEvent") then
        return remote, current
    end

    return nil, current
end

local lastSlapFire = 0
local GLOBAL_SLAP_INTERVAL = 1.05

local function fireSlap(targetRoot)
    if not targetRoot or not targetRoot.Parent then return false end

    -- Global rate limit shared by Farm + Aura. This is intentionally boring.
    -- One clean remote call is better than two overlapping activation paths.
    local now = os.clock()
    if now - lastSlapFire < GLOBAL_SLAP_INTERVAL then
        return false
    end

    local tool = equipCurrentTool()
    local remote, current = getSlapRemote()
    if not remote then
        -- Do not combine Tool:Activate() with a remote call. If the game has no
        -- supported slap remote, fail closed instead of generating duplicate hits.
        return false
    end

    local ok = pcall(function()
        if current and current:lower() == "stalker" then
            remote:FireServer(targetRoot, false, 45)
        elseif current and (current:lower() == "glovel" or current:lower() == "mutation") then
            remote:FireServer(targetRoot, true)
        elseif current and current:lower() == "mace" then
            remote:FireServer(targetRoot, 100)
        else
            remote:FireServer(targetRoot)
        end
    end)

    if ok then
        lastSlapFire = now
    end
    return ok
end

local runBusStyleSlapFarm
local busFarmGeneration = 0

-- ============================================================
-- GUI
-- ============================================================

local oldGui = PlayerGui:FindFirstChild("ResenhaSlapFarm")
if oldGui then oldGui:Destroy() end

local gui = new("ScreenGui", {
    Name = "ResenhaSlapFarm",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 1000,
}, PlayerGui)

local notificationHolder = new("Frame", {
    Name = "Notifications",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -24, 0, 22),
    Size = UDim2.new(0, 320, 1, -44),
    ZIndex = 100,
}, gui)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, notificationHolder)

local function notify(title, message, accent)
    local card = new("CanvasGroup", {
        BackgroundColor3 = CONFIG.Surface2,
        BackgroundTransparency = 0.06,
        Size = UDim2.new(1, 0, 0, 76),
        GroupTransparency = 1,
        ZIndex = 101,
    }, notificationHolder)
    corner(card, 14)
    stroke(card, accent or CONFIG.Purple, 1, 0.35)

    new("Frame", {
        BackgroundColor3 = accent or CONFIG.Purple,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 12),
        Size = UDim2.new(0, 3, 1, -24),
        ZIndex = 102,
    }, card)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 10),
        Size = UDim2.new(1, -28, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = CONFIG.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 102,
    }, card)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 32),
        Size = UDim2.new(1, -28, 0, 34),
        Font = Enum.Font.Gotham,
        Text = message,
        TextColor3 = CONFIG.Muted,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 102,
    }, card)

    tween(card, 0.22, {GroupTransparency = 0})
    task.delay(3.5, function()
        if card.Parent then
            tween(card, 0.18, {GroupTransparency = 1})
            task.wait(0.2)
            if card.Parent then card:Destroy() end
        end
    end)
end

-- Launcher
local launcherShadow = new("Frame", {
    Name = "LauncherShadow",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 22, 0.5, 0),
    Size = UDim2.new(0, 64, 0, 64),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.45,
    ZIndex = 19,
}, gui)
corner(launcherShadow, 17)

local launcher = new("ImageButton", {
    Name = "Launcher",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 18, 0.5, -4),
    Size = UDim2.new(0, 58, 0, 58),
    BackgroundColor3 = CONFIG.Surface2,
    AutoButtonColor = false,
    Image = CONFIG.LauncherImage,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 20,
}, gui)
corner(launcher, 15)
stroke(launcher, CONFIG.Purple, 2, 0.08)

local launcherGlow = new("Frame", {
    BackgroundColor3 = CONFIG.Purple,
    BackgroundTransparency = 0.7,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 10, 1, 10),
    ZIndex = 18,
}, launcher)
corner(launcherGlow, 18)
launcherGlow.Parent = launcher

-- Main window
local window = new("CanvasGroup", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0, 790, 0, 500),
    BackgroundColor3 = CONFIG.Background,
    BackgroundTransparency = 0.02,
    GroupTransparency = 0,
    ClipsDescendants = true,
    ZIndex = 10,
}, gui)
corner(window, 18)
stroke(window, CONFIG.Purple, 1.2, 0.35)

local windowScale = new("UIScale", {Scale = 1}, window)

local bgImage = new("ImageLabel", {
    Name = "BackgroundImage",
    BackgroundTransparency = 1,
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    Image = CONFIG.BackgroundImage,
    ImageTransparency = 0.62,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 10,
}, window)

local bgTint = new("Frame", {
    BackgroundColor3 = Color3.fromRGB(48, 20, 46),
    BackgroundTransparency = 0.28,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 11,
}, window)

local topGlow = new("Frame", {
    BackgroundColor3 = CONFIG.Purple,
    BackgroundTransparency = 0.82,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 90),
    ZIndex = 12,
}, window)
local grad = new("UIGradient", {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, topGlow)

-- Sidebar
local sidebar = new("Frame", {
    BackgroundColor3 = Color3.fromRGB(27, 11, 30),
    BackgroundTransparency = 0.16,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, 188, 1, 0),
    ZIndex = 14,
}, window)

new("Frame", {
    BackgroundColor3 = CONFIG.Purple,
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    ZIndex = 15,
}, sidebar)

local brandIcon = new("ImageLabel", {
    BackgroundColor3 = CONFIG.Surface2,
    BackgroundTransparency = 0.08,
    Position = UDim2.new(0, 18, 0, 18),
    Size = UDim2.new(0, 42, 0, 42),
    Image = CONFIG.LauncherImage,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 16,
}, sidebar)
corner(brandIcon, 11)
stroke(brandIcon, CONFIG.Purple, 1, 0.25)

new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 70, 0, 19),
    Size = UDim2.new(1, -80, 0, 20),
    Font = Enum.Font.GothamBold,
    Text = "RESENHA",
    TextColor3 = CONFIG.Text,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 16,
}, sidebar)

new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 70, 0, 39),
    Size = UDim2.new(1, -80, 0, 16),
    Font = Enum.Font.Gotham,
    Text = "debug battles",
    TextColor3 = CONFIG.Muted,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 16,
}, sidebar)

local navButton = new("TextButton", {
    BackgroundColor3 = CONFIG.Purple,
    BackgroundTransparency = 0.82,
    Position = UDim2.new(0, 12, 0, 86),
    Size = UDim2.new(1, -24, 0, 44),
    AutoButtonColor = false,
    Font = Enum.Font.GothamSemibold,
    Text = "   ✦  Slap Farm",
    TextColor3 = CONFIG.Text,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 16,
}, sidebar)
corner(navButton, 12)
stroke(navButton, CONFIG.Purple, 1, 0.55)

local discordButton = new("TextButton", {
    BackgroundColor3 = CONFIG.Surface2,
    BackgroundTransparency = 0.20,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 12, 1, -56),
    Size = UDim2.new(1, -24, 0, 44),
    AutoButtonColor = false,
    Font = Enum.Font.GothamSemibold,
    Text = "   ◇  Discord Link",
    TextColor3 = CONFIG.Text,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 16,
}, sidebar)
corner(discordButton, 12)
stroke(discordButton, CONFIG.Purple, 1, 0.72)

new("TextLabel", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 18, 1, -10),
    Size = UDim2.new(1, -36, 0, 18),
    Font = Enum.Font.Gotham,
    Text = CONFIG.Discord,
    TextColor3 = CONFIG.Muted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 16,
}, sidebar)

-- Main content
local content = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 188, 0, 0),
    Size = UDim2.new(1, -188, 1, 0),
    ZIndex = 14,
}, window)

local header = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 22, 0, 18),
    Size = UDim2.new(1, -44, 0, 58),
    ZIndex = 15,
}, content)

new("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -50, 0, 27),
    Font = Enum.Font.GothamBold,
    Text = "Slap Farm",
    TextColor3 = CONFIG.Text,
    TextSize = 24,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 16,
}, header)

new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 30),
    Size = UDim2.new(1, -50, 0, 20),
    Font = Enum.Font.Gotham,
    Text = "Pair your main and clone accounts, farm slaps, then vanish into the bed dimension.",
    TextColor3 = CONFIG.Muted,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 16,
}, header)

local closeButton = new("TextButton", {
    BackgroundColor3 = CONFIG.Surface2,
    BackgroundTransparency = 0.22,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 36, 0, 36),
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "×",
    TextColor3 = CONFIG.Muted,
    TextSize = 22,
    ZIndex = 17,
}, header)
corner(closeButton, 10)

local scroll = new("ScrollingFrame", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 22, 0, 86),
    Size = UDim2.new(1, -44, 1, -104),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = CONFIG.Purple,
    ScrollBarImageTransparency = 0.32,
    ZIndex = 15,
}, content)
new("UIListLayout", {
    Padding = UDim.new(0, 12),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, scroll)
padding(scroll, 0, 6, 0, 10)

local function makeCard(height)
    local card = new("Frame", {
        BackgroundColor3 = CONFIG.Surface,
        BackgroundTransparency = 0.17,
        Size = UDim2.new(1, -6, 0, height),
        ZIndex = 16,
    }, scroll)
    corner(card, 15)
    stroke(card, CONFIG.Purple3, 1, 0.42)
    return card
end

local accountCard = makeCard(310)

local tabBar = new("Frame", {
    BackgroundColor3 = CONFIG.Surface2,
    BackgroundTransparency = 0.18,
    Position = UDim2.new(0, 14, 0, 14),
    Size = UDim2.new(1, -28, 0, 42),
    ZIndex = 17,
}, accountCard)
corner(tabBar, 12)

local mainTabButton = new("TextButton", {
    BackgroundColor3 = CONFIG.Purple,
    BackgroundTransparency = 0.20,
    Position = UDim2.new(0, 4, 0, 4),
    Size = UDim2.new(0.5, -6, 1, -8),
    AutoButtonColor = false,
    Font = Enum.Font.GothamSemibold,
    Text = "Main Account",
    TextColor3 = CONFIG.Text,
    TextSize = 13,
    ZIndex = 18,
}, tabBar)
corner(mainTabButton, 9)

local cloneTabButton = new("TextButton", {
    BackgroundColor3 = CONFIG.Surface3,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.5, 2, 0, 4),
    Size = UDim2.new(0.5, -6, 1, -8),
    AutoButtonColor = false,
    Font = Enum.Font.GothamSemibold,
    Text = "Clone Account",
    TextColor3 = CONFIG.Muted,
    TextSize = 13,
    ZIndex = 18,
}, tabBar)
corner(cloneTabButton, 9)

local mainPage = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 14, 0, 66),
    Size = UDim2.new(1, -28, 1, -80),
    Visible = true,
    ZIndex = 17,
}, accountCard)

local clonePage = mainPage:Clone()
clonePage.Name = "ClonePage"
clonePage.Visible = false
clonePage.Parent = accountCard
for _, child in ipairs(clonePage:GetChildren()) do child:Destroy() end

local function makeLabel(parent, text, y, size, muted)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, y),
        Size = UDim2.new(1, 0, 0, size or 18),
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = muted and CONFIG.Muted or CONFIG.Text,
        TextSize = muted and 11 or 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 18,
    }, parent)
end

local function makeInput(parent, placeholder, y, onChanged)
    local shell = new("Frame", {
        BackgroundColor3 = CONFIG.Surface2,
        BackgroundTransparency = 0.08,
        Position = UDim2.new(0, 0, 0, y),
        Size = UDim2.new(1, 0, 0, 40),
        ZIndex = 18,
    }, parent)
    corner(shell, 10)
    stroke(shell, CONFIG.Purple3, 1, 0.55)

    local box = new("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderText = placeholder,
        PlaceholderColor3 = CONFIG.Muted,
        Text = "",
        TextColor3 = CONFIG.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 19,
    }, shell)

    box.FocusLost:Connect(function()
        onChanged(trim(box.Text))
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        onChanged(trim(box.Text))
    end)

    return box
end

local function makeButton(parent, text, y, callback)
    local b = new("TextButton", {
        BackgroundColor3 = CONFIG.Surface2,
        BackgroundTransparency = 0.14,
        Position = UDim2.new(0, 0, 0, y),
        Size = UDim2.new(1, 0, 0, 38),
        AutoButtonColor = false,
        Font = Enum.Font.GothamSemibold,
        Text = text,
        TextColor3 = CONFIG.Text,
        TextSize = 12,
        ZIndex = 18,
    }, parent)
    corner(b, 10)
    stroke(b, CONFIG.Purple, 1, 0.66)

    b.MouseEnter:Connect(function()
        tween(b, 0.12, {BackgroundColor3 = CONFIG.Surface3, BackgroundTransparency = 0.08})
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.12, {BackgroundColor3 = CONFIG.Surface2, BackgroundTransparency = 0.14})
    end)
    b.MouseButton1Click:Connect(function()
        tween(b, 0.07, {Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, y + 1)})
        task.delay(0.08, function()
            if b.Parent then tween(b, 0.12, {Size = UDim2.new(1, 0, 0, 38), Position = UDim2.new(0, 0, 0, y)}) end
        end)
        callback()
    end)

    return b
end

local toggleObjects = {}
local function makeToggle(parent, id, text, y, defaultValue, callback)
    local row = new("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, y),
        Size = UDim2.new(1, 0, 0, 36),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 18,
    }, parent)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -58, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = CONFIG.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 19,
    }, row)

    local track = new("Frame", {
        BackgroundColor3 = CONFIG.Surface3,
        BackgroundTransparency = 0.05,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 46, 0, 24),
        ZIndex = 19,
    }, row)
    corner(track, 99)

    local knob = new("Frame", {
        BackgroundColor3 = CONFIG.Text,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.new(0, 18, 0, 18),
        ZIndex = 20,
    }, track)
    corner(knob, 99)

    local object = {Value = defaultValue == true}

    function object:SetValue(v, silent)
        v = v == true
        self.Value = v
        tween(track, 0.16, {BackgroundColor3 = v and CONFIG.Purple or CONFIG.Surface3})
        tween(knob, 0.16, {Position = v and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)})
        if not silent then callback(v) end
    end

    row.MouseButton1Click:Connect(function()
        object:SetValue(not object.Value)
    end)

    toggleObjects[id] = object
    object:SetValue(object.Value, true)
    return object
end

local function makeSlider(parent, text, y, minValue, maxValue, defaultValue, step, callback)
    local holder = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, y),
        Size = UDim2.new(1, 0, 0, 52),
        ZIndex = 18,
    }, parent)

    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.7, 0, 0, 18),
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = CONFIG.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 19,
    }, holder)

    local valueLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0.3, 0, 0, 18),
        Font = Enum.Font.Gotham,
        TextColor3 = CONFIG.Muted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 19,
    }, holder)

    local bar = new("TextButton", {
        BackgroundColor3 = CONFIG.Surface3,
        BackgroundTransparency = 0.08,
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, 0, 0, 8),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 19,
    }, holder)
    corner(bar, 99)

    local fill = new("Frame", {
        BackgroundColor3 = CONFIG.Purple,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 20,
    }, bar)
    corner(fill, 99)

    local knob = new("Frame", {
        BackgroundColor3 = CONFIG.Text,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 15, 0, 15),
        ZIndex = 21,
    }, bar)
    corner(knob, 99)
    stroke(knob, CONFIG.Purple, 2, 0.1)

    local value = defaultValue
    local dragging = false

    local function roundToStep(v)
        if not step or step <= 0 then return v end
        return math.floor((v / step) + 0.5) * step
    end

    local function setValue(v, fire)
        v = math.clamp(roundToStep(v), minValue, maxValue)
        value = v
        local alpha = (v - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = step and step < 1 and string.format("%.2f", v) or tostring(math.floor(v + 0.5))
        if fire then callback(v) end
    end

    local function setFromX(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        setValue(minValue + (maxValue - minValue) * alpha, true)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)

    setValue(defaultValue, false)

    return {
        SetValue = function(_, v) setValue(v, true) end,
        GetValue = function() return value end,
    }
end

-- Main page contents
makeLabel(mainPage, "Clone username", 0, 18, false)
local cloneInput = makeInput(mainPage, "Type the Clone Account username", 22, function(v)
    state.CloneUsername = v
end)

local mainFarmToggle = makeToggle(mainPage, "MainFarm", "Farm Slap", 68, false, function(v)
    if v and state.CloneHelpEnabled then
        state.CloneHelpEnabled = false
        if toggleObjects.CloneHelp then toggleObjects.CloneHelp:SetValue(false, true) end
    end

    state.MainFarmEnabled = v
    if v then
        ensureArenaThenTeleport("Main")
        task.delay(0.25, function()
            if runBusStyleSlapFarm then runBusStyleSlapFarm() end
        end)
        notify("Slap Farm", "Safe farm enabled: one slap per recovery cycle.", CONFIG.Success)
    else
        busFarmGeneration += 1
        state.MainStatus = "Disabled"
        notify("Slap Farm", "Main Account farm disabled.", CONFIG.Purple)
    end
end)

makeSlider(mainPage, "Safe slap delay", 104, 1.10, 2.50, CONFIG.SlapDelay, 0.05, function(v)
    state.SlapDelay = v
end)

local mainStatusLabel = makeLabel(mainPage, "Status: waiting", 158, 18, true)
makeButton(mainPage, "TP to Safe Box  •  Bed", 188, function()
    ensureArenaThenTeleport("Main")
    notify("Safe Box", "Teleporting Main Account to the Bed safe spot.", CONFIG.Purple)
end)

-- Clone page contents
makeLabel(clonePage, "Main username", 0, 18, false)
local mainInput = makeInput(clonePage, "Type the Main Account username", 22, function(v)
    state.MainUsername = v
end)

local cloneHelpToggle = makeToggle(clonePage, "CloneHelp", "Enabled Account Clone Help", 68, false, function(v)
    if v and state.MainFarmEnabled then
        state.MainFarmEnabled = false
        if toggleObjects.MainFarm then toggleObjects.MainFarm:SetValue(false, true) end
    end

    state.CloneHelpEnabled = v
    if v then
        ensureArenaThenTeleport("Clone")
        notify("Clone Help", "Clone return-on-slap enabled.", CONFIG.Success)
    else
        notify("Clone Help", "Clone helper disabled.", CONFIG.Purple)
    end
end)

makeLabel(clonePage, "After each slap, the clone is returned to its Bed farm position automatically.", 108, 34, true)
local cloneStatusLabel = makeLabel(clonePage, "Status: waiting", 148, 18, true)
makeButton(clonePage, "TP to Safe Box  •  Bed", 188, function()
    ensureArenaThenTeleport("Clone")
    notify("Safe Box", "Teleporting Clone Account to the Bed safe spot.", CONFIG.Purple)
end)

-- Slap Aura card (ported from the old menu's normal aura behavior)
local auraCard = makeCard(240)
makeLabel(auraCard, "Slap Aura  •  H", 14, 20, false)
makeLabel(auraCard, "H toggles the aura. It uses your currently equipped glove.", 34, 18, true)

local auraInner = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 14, 0, 56),
    Size = UDim2.new(1, -28, 1, -66),
    ZIndex = 17,
}, auraCard)

local auraToggle = makeToggle(auraInner, "SlapAura", "Slap Aura", 0, false, function(v)
    state.AuraEnabled = v
    state.AuraStatus = v and "Armed • scanning nearby players" or "Press H to toggle"
    notify("Slap Aura", v and "Aura enabled [H]." or "Aura disabled [H].", v and CONFIG.Success or CONFIG.Purple)
end)

makeSlider(auraInner, "Reach", 38, 10, 50, CONFIG.AuraRange, 1, function(v)
    state.AuraRange = v
end)

makeSlider(auraInner, "Aura delay", 88, 0.35, 1.00, CONFIG.AuraDelay, 0.05, function(v)
    state.AuraDelay = v
end)

local auraStatusLabel = makeLabel(auraInner, "Status: press H to toggle", 142, 18, true)

-- Movement card
local movementCard = makeCard(186)
makeLabel(movementCard, "Movement", 14, 20, false)
makeLabel(movementCard, "Only the two old movement utilities survived the purge.", 34, 18, true)

local movementInner = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 14, 0, 56),
    Size = UDim2.new(1, -28, 1, -66),
    ZIndex = 17,
}, movementCard)

local flyToggle = makeToggle(movementInner, "Fly", "Fly", 0, false, function(v)
    state.FlyEnabled = v
    notify("Fly", v and "Fly enabled. WASD + Space/Ctrl." or "Fly disabled.", CONFIG.Purple)
end)

makeSlider(movementInner, "Fly speed", 38, 20, 150, 50, 5, function(v)
    state.FlySpeed = v
end)

makeSlider(movementInner, "Jump", 88, 50, 200, 50, 5, function(v)
    state.JumpPower = v
    local _, _, humanoid = getCharacter(LocalPlayer)
    if humanoid then
        pcall(function()
            humanoid.UseJumpPower = true
            humanoid.JumpPower = v
        end)
    end
end)

-- Small information card
local infoCard = makeCard(76)
new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 14, 0, 12),
    Size = UDim2.new(1, -28, 0, 52),
    Font = Enum.Font.Gotham,
    Text = "Setup: Main Account enters the clone username. Clone Account enters the main username. Enable the matching toggle on each client. Both accounts should be in the same server.",
    TextColor3 = CONFIG.Muted,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 17,
}, infoCard)

local function setAccountTab(which)
    state.ActiveAccountTab = which
    local main = which == "Main"
    mainPage.Visible = main
    clonePage.Visible = not main

    tween(mainTabButton, 0.16, {
        BackgroundTransparency = main and 0.12 or 1,
        BackgroundColor3 = main and CONFIG.Purple or CONFIG.Surface3,
        TextColor3 = main and CONFIG.Text or CONFIG.Muted,
    })
    tween(cloneTabButton, 0.16, {
        BackgroundTransparency = main and 1 or 0.12,
        BackgroundColor3 = main and CONFIG.Surface3 or CONFIG.Purple,
        TextColor3 = main and CONFIG.Muted or CONFIG.Text,
    })
end

mainTabButton.MouseButton1Click:Connect(function() setAccountTab("Main") end)
cloneTabButton.MouseButton1Click:Connect(function() setAccountTab("Clone") end)

-- Discord link card-like behavior
local discordPopup
local function showDiscord()
    if discordPopup and discordPopup.Parent then
        discordPopup:Destroy()
    end

    discordPopup = new("Frame", {
        BackgroundColor3 = CONFIG.Surface2,
        BackgroundTransparency = 0.02,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 390, 0, 150),
        ZIndex = 80,
    }, gui)
    corner(discordPopup, 16)
    stroke(discordPopup, CONFIG.Purple, 1.2, 0.25)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 14),
        Size = UDim2.new(1, -32, 0, 22),
        Font = Enum.Font.GothamBold,
        Text = "Discord do jogo",
        TextColor3 = CONFIG.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 81,
    }, discordPopup)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 40),
        Size = UDim2.new(1, -32, 0, 18),
        Font = Enum.Font.Gotham,
        Text = "Select the link below and copy it manually:",
        TextColor3 = CONFIG.Muted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 81,
    }, discordPopup)

    local linkBox = new("TextBox", {
        BackgroundColor3 = CONFIG.Surface3,
        BackgroundTransparency = 0.04,
        Position = UDim2.new(0, 16, 0, 68),
        Size = UDim2.new(1, -32, 0, 38),
        ClearTextOnFocus = false,
        Font = Enum.Font.Code,
        Text = CONFIG.Discord,
        TextColor3 = CONFIG.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 81,
    }, discordPopup)
    corner(linkBox, 10)

    local close = new("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, -10),
        Size = UDim2.new(0, 80, 0, 26),
        AutoButtonColor = false,
        Font = Enum.Font.GothamSemibold,
        Text = "Close",
        TextColor3 = CONFIG.Muted,
        TextSize = 11,
        ZIndex = 81,
    }, discordPopup)

    close.MouseButton1Click:Connect(function()
        if discordPopup then discordPopup:Destroy() end
    end)

    task.defer(function()
        linkBox:CaptureFocus()
        linkBox.CursorPosition = #linkBox.Text + 1
        linkBox.SelectionStart = 1
    end)
end

discordButton.MouseButton1Click:Connect(showDiscord)

-- Open/close animation
local function setMenuOpen(open)
    state.MenuOpen = open
    if open then
        window.Visible = true
        window.GroupTransparency = 1
        windowScale.Scale = 0.94
        tween(window, 0.18, {GroupTransparency = 0})
        tween(windowScale, 0.22, {Scale = 1}, Enum.EasingStyle.Back)
    else
        tween(window, 0.14, {GroupTransparency = 1})
        tween(windowScale, 0.14, {Scale = 0.96})
        task.delay(0.15, function()
            if not state.MenuOpen then
                window.Visible = false
            end
        end)
    end
end

closeButton.MouseButton1Click:Connect(function()
    setMenuOpen(false)
end)

-- Launcher drag + click
local launcherDragging = false
local launcherDragStart
local launcherStartPos
local launcherMoved = false

launcher.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        launcherDragging = true
        launcherMoved = false
        launcherDragStart = input.Position
        launcherStartPos = launcher.Position
        tween(launcher, 0.12, {Size = UDim2.new(0, 54, 0, 54)})
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if launcherDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - launcherDragStart
        if delta.Magnitude > 6 then launcherMoved = true end
        launcher.Position = UDim2.new(
            launcherStartPos.X.Scale,
            launcherStartPos.X.Offset + delta.X,
            launcherStartPos.Y.Scale,
            launcherStartPos.Y.Offset + delta.Y
        )
        launcherShadow.Position = launcher.Position + UDim2.fromOffset(4, 4)
    end
end)

launcher.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        launcherDragging = false
        tween(launcher, 0.14, {Size = UDim2.new(0, 58, 0, 58)})
        if not launcherMoved then
            setMenuOpen(not state.MenuOpen)
        end
    end
end)

-- Window drag from header
local windowDragging = false
local windowDragStart
local windowStartPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        windowDragging = true
        windowDragStart = input.Position
        windowStartPos = window.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if windowDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - windowDragStart
        window.Position = UDim2.new(
            windowStartPos.X.Scale,
            windowStartPos.X.Offset + delta.X,
            windowStartPos.Y.Scale,
            windowStartPos.Y.Offset + delta.Y
        )
    end
end)

header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        windowDragging = false
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end

    if input.KeyCode == Enum.KeyCode.RightShift then
        setMenuOpen(not state.MenuOpen)
    elseif input.KeyCode == Enum.KeyCode.H then
        local toggle = toggleObjects.SlapAura
        if toggle then
            toggle:SetValue(not toggle.Value)
        else
            state.AuraEnabled = not state.AuraEnabled
        end
    end
end)

-- ============================================================
-- Slap Aura loop
-- Based on the old menu's Normal Slap Aura defaults: 25-stud reach,
-- 0.75-second delay, current-glove hit remote, H as the toggle key.
-- ============================================================

local lastAuraPulse = 0

local function isAuraTarget(player)
    if player == LocalPlayer then return false end

    local char, root, humanoid = getCharacter(player)
    if not char or not root or not humanoid or humanoid.Health <= 0 then
        return false
    end

    -- Old Slap Battles clones commonly mark players inside the arena with "entered".
    -- If the marker exists in this build, respect it. If the clone omits it, stay compatible.
    local entered = char:FindFirstChild("entered")
    if entered and entered:IsA("BoolValue") and not entered.Value then
        return false
    end

    if root.BrickColor == BrickColor.new("New Yeller") then
        return false
    end

    local ragdolled = char:FindFirstChild("Ragdolled")
    if ragdolled and ragdolled:IsA("BoolValue") and ragdolled.Value and state.AuraDelay <= 0.70 then
        return false
    end

    local head = char:FindFirstChild("Head")
    local glove = getCurrentGlove()
    if head and head:FindFirstChild("UnoReverseCard") and glove ~= "Error" then
        return false
    end

    return true, char, root
end

RunService.Heartbeat:Connect(function()
    if not state.AuraEnabled then
        state.AuraStatus = "Press H to toggle"
        return
    end

    if state.MainFarmEnabled then
        state.AuraStatus = "Paused while Farm Slap is active"
        return
    end

    if os.clock() - lastAuraPulse < state.AuraDelay then
        return
    end
    lastAuraPulse = os.clock()

    local myChar, myRoot = getCharacter(LocalPlayer)
    if not myChar or not myRoot then
        state.AuraStatus = "Waiting for character"
        return
    end

    local hits = 0
    local nearest = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        local ok, _, targetRoot = isAuraTarget(player)
        if ok and targetRoot then
            local distance = (myRoot.Position - targetRoot.Position).Magnitude
            if distance <= state.AuraRange then
                nearest = math.min(nearest, distance)
                if fireSlap(targetRoot) then
                    hits += 1
                end
            end
        end
    end

    if hits > 0 then
        state.AuraStatus = string.format("Active • %d hit(s) • nearest %.1f studs", hits, nearest)
    else
        state.AuraStatus = string.format("Active • no targets inside %.0f studs", state.AuraRange)
    end
end)

-- ============================================================
-- Main Slap Farm loop
-- Conservative mode: one slap per target recovery cycle.
-- This avoids burst-firing the hit remote while the clone is already ragdolled.
-- ============================================================

local function targetRagdolled(character)
    local flag = character and character:FindFirstChild("Ragdolled")
    return flag and flag:IsA("BoolValue") and flag.Value or false
end

local function waitForTargetRecovery(character, generation)
    local started = os.clock()
    while state.MainFarmEnabled and generation == busFarmGeneration do
        if not character or not character.Parent then return false end
        local flag = character:FindFirstChild("Ragdolled")
        if not flag or not flag.Value then return true end
        if os.clock() - started > 8 then return false end
        task.wait(0.05)
    end
    return false
end

runBusStyleSlapFarm = function()
    busFarmGeneration += 1
    local generation = busFarmGeneration

    task.spawn(function()
        while state.MainFarmEnabled and generation == busFarmGeneration do
            if not state.MainFarmReady then
                state.MainStatus = "Entering arena / preparing Bed..."
                task.wait(0.25)
                continue
            end

            local clonePlayer = findPlayer(state.CloneUsername)
            if not clonePlayer then
                state.MainStatus = state.CloneUsername == "" and "Enter the Clone username" or "Clone account not found in this server"
                task.wait(0.5)
                continue
            end

            local myChar, myRoot = getCharacter(LocalPlayer)
            local cloneChar, cloneRoot = getCharacter(clonePlayer)
            if not myChar or not myRoot or not cloneChar or not cloneRoot then
                state.MainStatus = "Waiting for both characters"
                task.wait(0.4)
                continue
            end

            if not myChar:FindFirstChild("entered") or not cloneChar:FindFirstChild("entered") then
                state.MainStatus = "Both accounts must be in arena"
                task.wait(0.5)
                continue
            end

            -- Do not keep correcting CFrame every loop. If Main gets moved far away,
            -- pause the farm instead of fighting the server continuously.
            local mainCF = mainFarmCFrame()
            local mainDrift = (myRoot.Position - mainCF.Position).Magnitude
            if mainDrift > 14 then
                state.MainStatus = string.format("Paused • Main drifted %.1f studs • use TP Bed", mainDrift)
                task.wait(0.75)
                continue
            end

            local distance = (myRoot.Position - cloneRoot.Position).Magnitude
            if distance > 10 then
                state.MainStatus = string.format("Paused • clone too far (%.1f studs)", distance)
                task.wait(0.6)
                continue
            end

            if targetRagdolled(cloneChar) then
                state.MainStatus = "Safe farm • waiting clone recovery"
                waitForTargetRecovery(cloneChar, generation)
                task.wait(0.45)
                continue
            end

            -- Face once immediately before the slap. No per-frame CFrame writes.
            local lookAt = Vector3.new(cloneRoot.Position.X, myRoot.Position.Y, cloneRoot.Position.Z)
            if (lookAt - myRoot.Position).Magnitude > 0.1 then
                myRoot.CFrame = CFrame.new(myRoot.Position, lookAt)
            end

            if fireSlap(cloneRoot) then
                state.MainStatus = string.format("Safe farm • slapped once • %.2fs cooldown", state.SlapDelay)

                -- Give replication a moment to expose Ragdolled, then wait for the
                -- recovery if it happened. We never send extra slaps during ragdoll.
                task.wait(0.18)
                cloneChar = clonePlayer.Character
                if cloneChar and targetRagdolled(cloneChar) then
                    waitForTargetRecovery(cloneChar, generation)
                end

                task.wait(state.SlapDelay)
            else
                state.MainStatus = "Safe farm • waiting global slap cooldown"
                task.wait(0.35)
            end
        end
    end)
end

-- ============================================================
-- Clone helper: return to Bed after being slapped
-- ============================================================

local cloneReturnPending = false
local lastCloneReturn = 0
local ragdollConnection
local watchedCharacter

local function scheduleCloneReturn(reason)
    if not state.CloneHelpEnabled or cloneReturnPending then return end
    cloneReturnPending = true

    task.spawn(function()
        -- Never snap the clone back while it is still ragdolled / flying.
        -- Wait for the physics state to settle first, then perform one correction.
        local started = os.clock()
        while state.CloneHelpEnabled do
            local char, root = getCharacter(LocalPlayer)
            if not char or not root then break end

            local ragdolled = char:FindFirstChild("Ragdolled")
            local stillRagdolled = ragdolled and ragdolled:IsA("BoolValue") and ragdolled.Value
            local movingFast = root.AssemblyLinearVelocity.Magnitude > 10

            if not stillRagdolled and not movingFast then
                break
            end
            if os.clock() - started > 8 then
                break
            end
            task.wait(0.08)
        end

        task.wait(CONFIG.CloneReturnDelay)
        if state.CloneHelpEnabled then
            teleportToBed("Clone")
            lastCloneReturn = os.clock()
            state.CloneStatus = "Returned to Bed after " .. (reason or "slap")
        end
        cloneReturnPending = false
    end)
end

local function watchCloneCharacter(char)
    if ragdollConnection then
        ragdollConnection:Disconnect()
        ragdollConnection = nil
    end
    watchedCharacter = char

    if not char then return end
    local ragdolled = char:FindFirstChild("Ragdolled")
    if ragdolled and ragdolled:IsA("BoolValue") then
        ragdollConnection = ragdolled:GetPropertyChangedSignal("Value"):Connect(function()
            if state.CloneHelpEnabled and ragdolled.Value then
                scheduleCloneReturn("slap")
            end
        end)
    end
end

if LocalPlayer.Character then watchCloneCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    watchCloneCharacter(char)
    local _, _, humanoid = getCharacter(LocalPlayer)
    if humanoid then
        pcall(function()
            humanoid.UseJumpPower = true
            humanoid.JumpPower = state.JumpPower
        end)
    end
    if state.CloneHelpEnabled then
        ensureArenaThenTeleport("Clone")
    elseif state.MainFarmEnabled then
        ensureArenaThenTeleport("Main")
    end
end)

RunService.Heartbeat:Connect(function()
    if not state.CloneHelpEnabled then
        state.CloneStatus = "Disabled"
        return
    end

    if not state.CloneHelpReady then
        state.CloneStatus = "Entering arena / preparing Bed..."
        return
    end

    local mainPlayer = findPlayer(state.MainUsername)
    if not mainPlayer then
        state.CloneStatus = state.MainUsername == "" and "Enter the Main username" or "Main account not found in this server"
        return
    end

    local char, root, humanoid = getCharacter(LocalPlayer)
    local mainChar, mainRoot = getCharacter(mainPlayer)
    if not char or not mainChar then
        state.CloneStatus = "Waiting for both characters"
        return
    end

    if watchedCharacter ~= char then
        watchCloneCharacter(char)
    end

    local anchor = cloneFarmCFrame()
    local displacement = (root.Position - anchor.Position).Magnitude
    local velocity = root.AssemblyLinearVelocity.Magnitude

    state.CloneStatus = string.format("Main found • %.1f studs • return armed", (root.Position - mainRoot.Position).Magnitude)

    -- Fallback for games without a Ragdolled BoolValue: only return after the
    -- clone has actually settled. No teleport while it is still being launched.
    if displacement > 18 and velocity < 8 and os.clock() - lastCloneReturn > 1.25 then
        scheduleCloneReturn("displacement")
    end
end)

-- ============================================================
-- Fly + Jump
-- ============================================================

local flyBV
local flyBG

local function destroyFlyObjects()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local _, _, humanoid = getCharacter(LocalPlayer)
    if humanoid then humanoid.PlatformStand = false end
end

RunService.RenderStepped:Connect(function()
    local char, root, humanoid = getCharacter(LocalPlayer)
    if not char then
        destroyFlyObjects()
        return
    end

    if not state.FlyEnabled then
        if flyBV or flyBG then destroyFlyObjects() end
        return
    end

    if not flyBV or flyBV.Parent ~= root then
        if flyBV then flyBV:Destroy() end
        flyBV = new("BodyVelocity", {
            Name = "ResenhaFlyVelocity",
            MaxForce = Vector3.new(9e9, 9e9, 9e9),
            Velocity = Vector3.zero,
            P = 1250,
        }, root)
    end

    if not flyBG or flyBG.Parent ~= root then
        if flyBG then flyBG:Destroy() end
        flyBG = new("BodyGyro", {
            Name = "ResenhaFlyGyro",
            MaxTorque = Vector3.new(9e9, 9e9, 9e9),
            P = 1500,
            D = 60,
        }, root)
    end

    humanoid.PlatformStand = true

    local camera = workspace.CurrentCamera
    local move = humanoid.MoveDirection
    local vertical = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical += 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vertical -= 1 end

    local horizontal = move
    if horizontal.Magnitude > 1 then horizontal = horizontal.Unit end

    flyBV.Velocity = horizontal * state.FlySpeed + Vector3.new(0, vertical * state.FlySpeed, 0)
    flyBG.CFrame = CFrame.new(root.Position, root.Position + camera.CFrame.LookVector)
end)

-- Keep jump value after game scripts try to restore it.
task.spawn(function()
    while gui.Parent do
        local _, _, humanoid = getCharacter(LocalPlayer)
        if humanoid then
            pcall(function()
                humanoid.UseJumpPower = true
                humanoid.JumpPower = state.JumpPower
            end)
        end
        task.wait(0.45)
    end
end)

-- UI status updater
RunService.RenderStepped:Connect(function()
    if mainStatusLabel and mainStatusLabel.Parent then
        mainStatusLabel.Text = "Status: " .. state.MainStatus
        mainStatusLabel.TextColor3 = state.MainFarmEnabled and CONFIG.Success or CONFIG.Muted
    end
    if cloneStatusLabel and cloneStatusLabel.Parent then
        cloneStatusLabel.Text = "Status: " .. state.CloneStatus
        cloneStatusLabel.TextColor3 = state.CloneHelpEnabled and CONFIG.Success or CONFIG.Muted
    end
    if auraStatusLabel and auraStatusLabel.Parent then
        auraStatusLabel.Text = "Status: " .. state.AuraStatus
        auraStatusLabel.TextColor3 = state.AuraEnabled and CONFIG.Success or CONFIG.Muted
    end
end)

-- Initial setup
ensureSafeBed()
setAccountTab("Main")
notify("Resenha Battles", "Satori build loaded. H toggles Slap Aura. Main + Clone farm ready.", CONFIG.Purple)

