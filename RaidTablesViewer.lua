-----------------------------------------------------------------------------------------------------------------------
-- Addon Meta Information
-----------------------------------------------------------------------------------------------------------------------
local addonName = "RaidTablesViewer"
local author = "Owleé-Blackmoore (EU)"

-----------------------------------------------------------------------------------------------------------------------
-- Setup Tables And Variables for Easy Access
-----------------------------------------------------------------------------------------------------------------------
local addonDB = {
    Widgets = {
        Setups = {},
        FreeSetups = {},
        FreePlayers = {},
        Dialogs = {},
        Content = nil,
        TabContent = nil,
        Summary = {
            FreeItems = {},
            Items = {},
        },
    },
    Accepted = {},
    Rejected = {},
    Configs = {},
    Options = {
        Scaling = 1.0,
    },
    MsgBuffer = {}
}

-----------------------------------------------------------------------------------------------------------------------
-- Merge Tables
-----------------------------------------------------------------------------------------------------------------------
local function MergeTables(t1, t2)
    local merged = {}
    for k, v in pairs(t1) do
        merged[k] = v
    end
    for k, v in pairs(t2) do
        merged[k] = v
    end
    return merged
end

-----------------------------------------------------------------------------------------------------------------------
-- Get Scale agnostic Width
-----------------------------------------------------------------------------------------------------------------------
local function GetWidth(frame)
    return frame:GetWidth() / addonDB.Options.Scaling
end

-----------------------------------------------------------------------------------------------------------------------
-- Get Scale Agnostic Height
-----------------------------------------------------------------------------------------------------------------------
local function GetHeight(frame)
    return frame:GetHeight() / addonDB.Options.Scaling
end

-----------------------------------------------------------------------------------------------------------------------
-- Agnostic
-----------------------------------------------------------------------------------------------------------------------
local function Agnostic(num)
    if not num then
        return nil
    end
    return num / addonDB.Options.Scaling
end

-----------------------------------------------------------------------------------------------------------------------
-- Apply Scale
-----------------------------------------------------------------------------------------------------------------------
local function Scaled(num)
    if not num then
        return nil
    end
    return num * addonDB.Options.Scaling
end

-----------------------------------------------------------------------------------------------------------------------
-- Set Scale agnostic Width
-----------------------------------------------------------------------------------------------------------------------
local function SetWidth(frame, width)
    frame:SetWidth(Scaled(width))
end

-----------------------------------------------------------------------------------------------------------------------
-- Set Scale agnostic Height 
-----------------------------------------------------------------------------------------------------------------------
local function SetHeight(frame, height)
    frame:SetHeight(Scaled(height))
end

-----------------------------------------------------------------------------------------------------------------------
-- Set Scale agnostic Size 
-----------------------------------------------------------------------------------------------------------------------
local function SetSize(frame, width, height)
    frame:SetSize(Scaled(width), Scaled(height))
end

-----------------------------------------------------------------------------------------------------------------------
-- Set Scale agnostic Position 
-----------------------------------------------------------------------------------------------------------------------
local function SetPoint(frame, point, relativeTo, relativePoint, offsetX, offsetY)
    if relativeTo == nil and relativePoint == nil and offsetX == nil and offsetY == nil then
        frame:SetPoint(point)
    elseif offsetX == nil and offsetY == nil then
        frame:SetPoint(point, Scaled(relativeTo), Scaled(relativePoint))
    else
        frame:SetPoint(point, relativeTo, relativePoint, Scaled(offsetX), Scaled(offsetY))
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Create Whitespace String
-----------------------------------------------------------------------------------------------------------------------
local function Ws(num)
    local s = ""
    for i=0,num do
        s = s .. " "
    end
    return s
end

-----------------------------------------------------------------------------------------------------------------------
-- Dump Table into String
-----------------------------------------------------------------------------------------------------------------------
local function DumpValue(name, value, depth)
    local depth = depth or 0
    if type(value) == "table" then
        print(Ws(2*depth) .. name .. " = " .. "{")
        for k, v in pairs(value) do
            DumpValue(k, v, depth + 1)
        end
        print(Ws(2*depth) .. "}")
    else
        print(Ws(2*depth) .. name .. " = " .. value)
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Load libraries
-----------------------------------------------------------------------------------------------------------------------
local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")

-----------------------------------------------------------------------------------------------------------------------
-- Wrap CreateFrame for Debugging
-----------------------------------------------------------------------------------------------------------------------
local createdFrameCount = 0
local nativeCreateFrame = CreateFrame
local function CreateFrame(frame, name, parent, flags)
    createdFrameCount = createdFrameCount + 1
    local newFrame = nativeCreateFrame(frame, name, parent, flags)
    return newFrame 
end

-----------------------------------------------------------------------------------------------------------------------
-- GUI Color Map
-----------------------------------------------------------------------------------------------------------------------
local color = {
    ["White"] = { ["r"] = 1, ["g"] = 1, ["b"] = 1, ["a"] = 1 },
    ["LightGray"] = { ["r"] = 0.2, ["g"] = 0.2, ["b"] = 0.2, ["a"] = 1 },
    ["MidGray"] = { ["r"] = 0.2, ["g"] = 0.2, ["b"] = 0.2, ["a"] = 1 },
    ["DarkGray"] = { ["r"] = 0.1, ["g"] = 0.1, ["b"] = 0.1, ["a"] = 1 },
    ["Highlight"] = { ["r"] = 0.5, ["g"] = 0, ["b"] = 0.0, ["a"] = 1 },
    ["Active"] = { ["r"] = 0.5, ["g"] = 0, ["b"] = 0.0, ["a"] = 1 },
    ["Attention"] = { ["r"] = 1, ["g"] = 0, ["b"] = 0.0, ["a"] = 1 },
    ["Black"] = { ["r"] = 0, ["g"] = 0, ["b"] = 0, ["a"] = 1 },
    ["Gold"] = { ["r"] = 1, ["g"] = 0.8, ["b"] = 0, ["a"] = 1 },
    ["Green"] = { ["r"] = 0, ["g"] = 0.8, ["b"] = 0, ["a"] = 1 },
    ["Red"] = { ["r"] = 0.8, ["g"] = 0, ["b"] = 0, ["a"] = 1 },
}

-----------------------------------------------------------------------------------------------------------------------
-- Class Color Map
-----------------------------------------------------------------------------------------------------------------------
local classColor = {
    ["DEATHKNIGHT"] = {r = 0.77, g = 0.12, b = 0.23},
    ["DEMONHUNTER"] = {r = 0.64, g = 0.19, b = 0.79},
    ["DRUID"] = {r = 1.00, g = 0.49, b = 0.04},
    ["EVOKER"] = {r = 51/255, g = 147/255, b = 127/255},
    ["HUNTER"] = {r = 0.67, g = 0.83, b = 0.45},
    ["MAGE"] = {r = 0.25, g = 0.78, b = 0.92},
    ["MONK"] = {r = 0.00, g = 1.00, b = 0.59},
    ["PALADIN"] = {r = 0.96, g = 0.55, b = 0.73},
    ["PRIEST"] = {r = 1.00, g = 1.00, b = 1.00},
    ["ROGUE"] = {r = 1.00, g = 0.96, b = 0.41},
    ["SHAMAN"] = {r = 0.00, g = 0.44, b = 0.87},
    ["WARLOCK"] = {r = 0.53, g = 0.53, b = 0.93},
    ["WARRIOR"] = {r = 0.78, g = 0.61, b = 0.43},
}

-----------------------------------------------------------------------------------------------------------------------
-- Order Configuration (Label and Sort-Callback)
-----------------------------------------------------------------------------------------------------------------------
local orderConfigs = { 
    { 
        ["Name"] = "Name A-Z", 
        ["Callback"] = function(a, b) 
            return a.PlayerName < b.PlayerName 
            or (a.PlayerName == b.PlayerName and tonumber(a.RareText:GetText()) <  tonumber(b.RareText:GetText()))
            or (a.PlayerName == b.PlayerName and tonumber(a.RareText:GetText()) == tonumber(b.RareText:GetText()) and tonumber(a.TierText:GetText()) <  tonumber(b.TierText:GetText())) 
            or (a.PlayerName == b.PlayerName and tonumber(a.RareText:GetText()) == tonumber(b.RareText:GetText()) and tonumber(a.TierText:GetText()) == tonumber(b.TierText:GetText()) and (tonumber(a.NormalText:GetText())) < (tonumber(b.NormalText:GetText())))
        end 
    }, 
    { 
        ["Name"] = "Name Z-A", 
        ["Callback"] = function(a, b) 
            return a.PlayerName > b.PlayerName 
            or (a.PlayerName == b.PlayerName and (tonumber(a.RareText:GetText())) > (tonumber(b.RareText:GetText())))
            or (a.PlayerName == b.PlayerName and (tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.TierText:GetText())) > (tonumber(b.TierText:GetText())))
            or (a.PlayerName == b.PlayerName and (tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.NormalText:GetText())) > (tonumber(b.NormalText:GetText())))
        end 
    }, 
    { 
        ["Name"] = "Rare High", 
        ["Callback"] = function(a, b) 
            return (tonumber(a.RareText:GetText()))  > (tonumber(b.RareText:GetText())) 
               or ((tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.TierText:GetText())) >  (tonumber(b.TierText:GetText())))
               or ((tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.NormalText:GetText())) >  (tonumber(b.NormalText:GetText())))
               or ((tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.NormalText:GetText())) == (tonumber(b.NormalText:GetText())) and a.PlayerName > b.PlayerName)
        end 
    }, 
    { 
        ["Name"] = "Rare Low", 
        ["Callback"] = function(a, b) 
            return (tonumber(a.RareText:GetText()))  < (tonumber(b.RareText:GetText())) 
               or ((tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.TierText:GetText())) <  (tonumber(b.TierText:GetText())))
               or ((tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.NormalText:GetText())) <  (tonumber(b.NormalText:GetText())))
               or ((tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.NormalText:GetText())) == (tonumber(b.NormalText:GetText())) and a.PlayerName < b.PlayerName)
        end 
    }, 
    { 
        ["Name"] = "Tier High", 
        ["Callback"] = function(a, b) 
            return (tonumber(a.TierText:GetText()))  > (tonumber(b.TierText:GetText())) 
               or ((tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.RareText:GetText())) >  (tonumber(b.RareText:GetText())))
               or ((tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.NormalText:GetText())) >  (tonumber(b.NormalText:GetText())))
               or ((tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.NormalText:GetText())) == (tonumber(b.NormalText:GetText())) and a.PlayerName > b.PlayerName)
        end 
    }, 
    { 
        ["Name"] = "Tier Low", 
        ["Callback"] = function(a, b) 
            return (tonumber(a.TierText:GetText()))  < (tonumber(b.TierText:GetText())) 
               or ((tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.RareText:GetText())) <  (tonumber(b.RareText:GetText())))
               or ((tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.NormalText:GetText())) <  (tonumber(b.NormalText:GetText())))
               or ((tonumber(a.TierText:GetText())) == (tonumber(b.TierText:GetText())) and (tonumber(a.RareText:GetText())) == (tonumber(b.RareText:GetText())) and (tonumber(a.NormalText:GetText())) == (tonumber(b.NormalText:GetText())) and a.PlayerName < b.PlayerName)
        end 
    }, 
    { 
        ["Name"] = "Normal High", 
        ["Callback"] = function(a, b) 
            return (tonumber(a.NormalText:GetText()))  > (tonumber(b.NormalText:GetText())) 
               or ((tonumber(a.NormalText:GetText())) == (tonumber(b.NormalText:GetText())) and (tonumber(a.RareText:GetText()) + tonumber(a.TierText:GetText())) > (tonumber(b.RareText:GetText()) + tonumber(b.TierText:GetText())))
               or ((tonumber(a.NormalText:GetText())) == (tonumber(b.NormalText:GetText())) and (tonumber(a.RareText:GetText()) + tonumber(a.TierText:GetText())) == (tonumber(b.RareText:GetText()) + tonumber(b.TierText:GetText())) and a.PlayerName > b.PlayerName)
        end 
    }, 
    { 
        ["Name"] = "Normal Low", 
        ["Callback"] = function(a, b) 
            return (tonumber(a.NormalText:GetText()))  < (tonumber(b.NormalText:GetText())) 
               or ((tonumber(a.NormalText:GetText())) == (tonumber(b.NormalText:GetText())) and (tonumber(a.RareText:GetText()) + tonumber(a.TierText:GetText())) < (tonumber(b.RareText:GetText()) + tonumber(b.TierText:GetText())))
               or ((tonumber(a.NormalText:GetText())) == (tonumber(b.NormalText:GetText())) and (tonumber(a.RareText:GetText()) + tonumber(a.TierText:GetText())) == (tonumber(b.RareText:GetText()) + tonumber(b.TierText:GetText())) and a.PlayerName < b.PlayerName)
        end 
    }, 
}

-----------------------------------------------------------------------------------------------------------------------
-- Get Active Configuration
-----------------------------------------------------------------------------------------------------------------------
local function GetActiveConfig() 
    for _, v in pairs(addonDB.Widgets.Setups) do
        if v.Tab.Button.pushed then
            for _, c in pairs(addonDB.Configs) do
                if c.Name == v.Name then
                    return c
                end
            end
            break
        end
    end
    return nil
end

-----------------------------------------------------------------------------------------------------------------------
-- Get Setup By Name
-----------------------------------------------------------------------------------------------------------------------
local function GetSetupByName(name) 
    for k, v in pairs(addonDB.Widgets.Setups) do
        if v.Name == name then
            return k, v
        end
    end
    return nil
end

-----------------------------------------------------------------------------------------------------------------------
-- Get Config By Name
-----------------------------------------------------------------------------------------------------------------------
local function GetConfigByName(name) 
    for k, v in pairs(addonDB.Configs) do
        if v.Name == name then
            return k, v
        end
    end
    return nil
end

-----------------------------------------------------------------------------------------------------------------------
-- Get Active Setup
-----------------------------------------------------------------------------------------------------------------------
local function GetActiveSetup() 
    for _, v in pairs(addonDB.Widgets.Setups) do
        if v.Tab.Button.pushed then
            return v
        end
    end
    return nil
end

-----------------------------------------------------------------------------------------------------------------------
-- Get First Element of Array
-----------------------------------------------------------------------------------------------------------------------
local function GetFirstValue(table)
    for key, value in pairs(table) do
        return key, value
    end
    return nil, nil
end

-----------------------------------------------------------------------------------------------------------------------
-- Remove First Element
-----------------------------------------------------------------------------------------------------------------------
local function RemoveFirstElement(t)
    for key, value in pairs(t) do
        table.remove(t, key)
        return value
    end
    return nil
end

-----------------------------------------------------------------------------------------------------------------------
-- Toggle Frame
-----------------------------------------------------------------------------------------------------------------------
local function ToggleFrame(frame)
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Hide Frame
-----------------------------------------------------------------------------------------------------------------------
local function HideFrame(frame)
    if frame:IsShown() then
        frame:Hide()
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Show Frame
-----------------------------------------------------------------------------------------------------------------------
local function ShowFrame(frame)
    if not frame:IsShown() then
        frame:Show()
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Get All By Filter
-----------------------------------------------------------------------------------------------------------------------
local function GetAllWithFilter(t, filter)
    local collection = {}
    for k, v in pairs(t) do
        if filter(k, v) then
            collection[k] = v
        end
    end
    return collection
end

-----------------------------------------------------------------------------------------------------------------------
-- Get Value By Filter
-----------------------------------------------------------------------------------------------------------------------
local function GetValueByFilter(t, filter)
    for k, v in pairs(t) do
        if filter(k, v) then
            return k, v
        end
    end
    return nil, nil 
end

-----------------------------------------------------------------------------------------------------------------------
-- Add Hover Effect To Button
-----------------------------------------------------------------------------------------------------------------------
local function AddHover(button, withPushed)
    button:SetScript("OnEnter", function(self)
        local c = color.Gold
        self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end)
    if withPushed then
        button:SetScript("OnLeave", function(self)
            if self.pushed then
                local c = color.Gold
                self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
            else
                local c = color.LightGray
                self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
            end
        end)
    else
        button:SetScript("OnLeave", function(self)
            local c = color.LightGray
            self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
        end)
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Apply to each Value
-----------------------------------------------------------------------------------------------------------------------
local function ApplyToEach(t, lambda, ...)
    for k, v in pairs(t) do
        lambda(k, v, ...)
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Rearrange Frames with Offsets
-----------------------------------------------------------------------------------------------------------------------
local function RearrangeFrames(t, anchor, xOffset, yOffset, getFrame, startX, startY)
    local x, y = startX or 0, startY or 0
    for k, v in pairs(t) do
        local frame = getFrame(v)
        frame:ClearAllPoints()
        SetPoint(frame, anchor, x, y)
        x = x + xOffset
        y = y + yOffset
    end
    return x, y
end

-----------------------------------------------------------------------------------------------------------------------
-- Remove Values that fulfill the filter requirement
-----------------------------------------------------------------------------------------------------------------------
local function RemoveWithFilter(t, filter)
    for k, v in pairs(t) do
        if filter(k, v) then
            table.remove(t, k)
            return
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Check if Dialog is Shown
-----------------------------------------------------------------------------------------------------------------------
local function IsDialogShown()
    for k, v in pairs(addonDB.Widgets.Dialogs) do
        if v.Frame:IsShown() then
            return true
        end
    end
    return false
end

-----------------------------------------------------------------------------------------------------------------------
-- Check if value is in Array
-----------------------------------------------------------------------------------------------------------------------
local function IsInArray(array, value)
    for _, v in pairs(array) do
        if (v - value) == 0 then
            return true
        end
    end
    return false
end

-----------------------------------------------------------------------------------------------------------------------
-- Check if Roll is Shown
-----------------------------------------------------------------------------------------------------------------------
local function IsRollShown()
    return addonDB.Widgets.Dialogs.Roll.Frame:IsShown()
end

-----------------------------------------------------------------------------------------------------------------------
-- Split String on Seperator
-----------------------------------------------------------------------------------------------------------------------
local function SplitString(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

-----------------------------------------------------------------------------------------------------------------------
-- Get item id from item link
-----------------------------------------------------------------------------------------------------------------------
local function GetIdFromLink(itemLink)
    local match = SplitString(itemLink, ":")
    return match[2]
end

-----------------------------------------------------------------------------------------------------------------------
-- Set Icon Texture
-----------------------------------------------------------------------------------------------------------------------
local function SetItemTexture(icon, texture, itemLink)
    local itemTexture = select(10, GetItemInfo(itemLink))
    if itemTexture then
        texture:SetTexture(itemTexture)
    else
        local itemId = GetIdFromLink(itemLink)
        icon:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        icon:SetScript("OnEvent", function(self, event, arg)
            if arg == itemId or arg == tonumber(itemId) then
                local itemTexture = select(10, GetItemInfo(itemLink))
                texture:SetTexture(itemTexture)
                self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
            end
        end)
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Check if Player is Already Known
-----------------------------------------------------------------------------------------------------------------------
local function PlayerKnown(player, setup)
    for k, v in pairs(setup.Players) do
        if v.PlayerName == player then
            return true
        end
    end
    return false
end

-----------------------------------------------------------------------------------------------------------------------
-- Create String from Array
-----------------------------------------------------------------------------------------------------------------------
local function ArrayToString(array)
    local first = true
    local str= ""
    for _, v in pairs(array) do
        if not first then
            str = str .. ", "
        end
        str = str .. v 
        first = false
    end
    return str
end

-----------------------------------------------------------------------------------------------------------------------
-- Serialize Configuration
-----------------------------------------------------------------------------------------------------------------------
local function SerializeConfig(config)
    local serialized = LibSerialize:SerializeEx({errorOnUnserializableType = false}, config)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)
    return encoded
end

-----------------------------------------------------------------------------------------------------------------------
-- Deserialize Table
-----------------------------------------------------------------------------------------------------------------------
local function Deserialize(encoded)
    local compressed = LibDeflate:DecodeForPrint(encoded)
    local serialized = LibDeflate:DecompressDeflate(compressed)
    local success, deserialized = LibSerialize:Deserialize(serialized)
    return success, deserialized 
end

-----------------------------------------------------------------------------------------------------------------------
-- Create Button
-----------------------------------------------------------------------------------------------------------------------
local function CreateButton(parent, label, width, height, colorBackground, colorBorder, textColor)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    button:SetBackdropColor(colorBackground.r, colorBackground.g, colorBackground.b, colorBackground.a)
    button:SetBackdropBorderColor(colorBorder.r, colorBorder.g, colorBorder.b, colorBorder.a)

    local buttonText = button:CreateFontString(nil, "ARTWORK")
    SetPoint(buttonText, "CENTER")
    buttonText:SetFont("Interface\\Addons\\RaidTablesViewer\\fonts\\UnicodeFont\\WarSansTT-Bliz-500.ttf", Scaled(12), "BOLD")
    if textColor then
        buttonText:SetTextColor(textColor.r, textColor.g, textColor.b)
    else
        buttonText:SetTextColor(1, 0.8, 0) 
    end
    buttonText:SetText(label)

    SetSize(button, width, height)
    button:SetFontString(buttonText)

    return button, buttonText 
end

-----------------------------------------------------------------------------------------------------------------------
-- Create Line
-----------------------------------------------------------------------------------------------------------------------
local function CreateLine(width, parent, x, y, colour)
    local line = parent:CreateTexture(nil, "OVERLAY")
    local c = colour or color.Gold
    line:SetColorTexture(c.r, c.g, c.b) -- set the color of the line to white
    SetHeight(line, 2) -- set the height of the line
    SetWidth(line, width)
    SetPoint(line, "TOPLEFT", x, y)
    return line
end

-----------------------------------------------------------------------------------------------------------------------
-- Create Label 
-----------------------------------------------------------------------------------------------------------------------
local function CreateLabel(label, parent, x, y, colour, anchor, fontSize)
    local c = colour or color.Gold
    local labelString = parent:CreateFontString(nil, "ARTWORK")
    labelString:SetFont("Interface\\Addons\\RaidTablesViewer\\fonts\\UnicodeFont\\WarSansTT-Bliz-500.ttf", Scaled(fontSize or 12), "NONE")
    labelString:SetTextColor(c.r, c.g, c.b)
    labelString:SetText(label)
    if x ~= nil and y ~= nil then
        SetPoint(labelString, anchor or "TOPLEFT", x, y)
    end
    return labelString
end

-----------------------------------------------------------------------------------------------------------------------
-- Create Heading
-----------------------------------------------------------------------------------------------------------------------
local function CreateHeading(label, width, parent, x, y, noLine, fontSize)
    local labelString = CreateLabel(label, parent, x, y, color.Gold, nil, fontSize)
    local labelWidth = GetWidth(labelString)
    local lineWidth = (width - labelWidth - 10) * 0.5
    local yOffset = ((fontSize or 12) - 12) / 2

    SetPoint(labelString, "TOPLEFT", x + lineWidth + 5, y)

    if not noLine then
        local leftLine = CreateLine(lineWidth, parent, x, y - 5 - yOffset, color.White)
        local rightLine = CreateLine(lineWidth, parent, x + lineWidth + labelWidth + 10, y - 5 - yOffset, color.White)
        return leftLine, labelString, rightLine
    end

    return labelString
end

-----------------------------------------------------------------------------------------------------------------------
-- Function to Create a Player Row Frame for the Table View
-----------------------------------------------------------------------------------------------------------------------
local function CreatePlayerFrame(player, config, setup, parent, playerInfo, width, x, y)
    -------------------------------------------------------------------------------------------------------------------
    -- Setup Locals
    -------------------------------------------------------------------------------------------------------------------
    local colorBackground, colorBorder = color.DarkGray, color.LightGray
    local name, colour, rare, tier, normal = playerInfo.Name, classColor[playerInfo.Class], playerInfo.Rare, playerInfo.Tier, playerInfo.Normal

    -------------------------------------------------------------------------------------------------------------------
    -- Create Player Container (if not reusable)
    -------------------------------------------------------------------------------------------------------------------
    if player.Container == nil then
        player.Container = CreateFrame("Button", nil, parent, "BackdropTemplate")
        SetWidth(player.Container, width)
        SetHeight(player.Container, 34)
        player.Container:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = math.max(1, Scaled(2)),
        })
        player.Container:SetBackdropColor(colorBackground.r, colorBackground.g, colorBackground.b, colorBackground.a)
        player.Container:SetBackdropBorderColor(colorBorder.r, colorBorder.g, colorBorder.b, colorBorder.a)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Update Position and Name
    -------------------------------------------------------------------------------------------------------------------
    SetPoint(player.Container, "TOPLEFT", x, y)
    player.PlayerName = name

    -------------------------------------------------------------------------------------------------------------------
    -- Create Player Name Label 
    -------------------------------------------------------------------------------------------------------------------
    if player.NameText then
        player.NameText:SetText(name)
        player.NameText:SetTextColor(colour.r, colour.g, colour.b)
    else
        player.NameText = CreateLabel(name, player.Container, 20, -10, colour)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Rare Count Label
    -------------------------------------------------------------------------------------------------------------------
    if player.RareText then
        player.RareText:SetText(rare)
    else
        player.RareText = CreateLabel(rare, player.Container, nil, nil, color.White)
        SetPoint(player.RareText, "CENTER", player.Container, "TOPLEFT", 428, -17)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Tier Count Label
    -------------------------------------------------------------------------------------------------------------------
    if player.TierText then
        player.TierText:SetText(tier)
    else
        player.TierText = CreateLabel(tier, player.Container, nil, nil, color.White)
        SetPoint(player.TierText, "CENTER", player.Container, "TOPLEFT", 428 + 149, -17)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Normal Count Label
    -------------------------------------------------------------------------------------------------------------------
    if player.NormalText then
        player.NormalText:SetText(normal)
    else
        player.NormalText = CreateLabel(normal, player.Container, nil, nil, color.White)
        SetPoint(player.NormalText, "CENTER", player.Container, "TOPLEFT", 428 + 298, -17)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Return Player Container
    -------------------------------------------------------------------------------------------------------------------
    return player
end

-----------------------------------------------------------------------------------------------------------------------
-- Function to Create a New Raid Content Frame from Configuration
-----------------------------------------------------------------------------------------------------------------------
local function SetupNewEntry(cfg, show)
    -------------------------------------------------------------------------------------------------------------------
    -- Setup Local
    -------------------------------------------------------------------------------------------------------------------
    local name = cfg.Name
    local characterWidth = 350
    local countWidth = 146

    -------------------------------------------------------------------------------------------------------------------
    -- Create Content Table or Retrieve Previously Freed Table
    -------------------------------------------------------------------------------------------------------------------
    local setup = RemoveFirstElement(addonDB.Widgets.FreeSetups) or {}
    table.insert(addonDB.Widgets.Setups, setup)

    -------------------------------------------------------------------------------------------------------------------
    -- Setup Name
    -------------------------------------------------------------------------------------------------------------------
    setup.Name = name

    -------------------------------------------------------------------------------------------------------------------
    -- Create Content Container
    -------------------------------------------------------------------------------------------------------------------
    if setup.Content == nil then
        setup.Content = CreateFrame("Frame", nil, addonDB.Widgets.Content)
        SetPoint(setup.Content, "TOPLEFT", 0, 0)
        SetPoint(setup.Content, "BOTTOMRIGHT", 0, 0)
    end
    local setupWidth = GetWidth(setup.Content)

    -------------------------------------------------------------------------------------------------------------------
    -- Create Order Heading
    -------------------------------------------------------------------------------------------------------------------
    if setup.OrderHeading == nil then
        setup.OrderHeading = {}
        setup.OrderHeading.LeftLine, setup.OrderHeading.Label, setup.OrderHeading.RightLine = CreateHeading("ORDERING", setupWidth - 20, setup.Content, 10, -10)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create all Order Button
    -------------------------------------------------------------------------------------------------------------------
    setup.Order = setup.Order or {}
    local offsetX = 0
    for orderIdx, orderCfg in pairs(orderConfigs) do
        local orderName = orderCfg.Name

        ---------------------------------------------------------------------------------------------------------------
        -- Create Order Button
        ---------------------------------------------------------------------------------------------------------------
        if setup.Order[orderName] == nil then
            setup.Order[orderName] = {}
            setup.Order[orderName]["Button"], setup.Order[orderName]["Text"] = CreateButton(setup.Content, orderName, 100, 40, color.DarkGray, color.LightGray)
        end

        ---------------------------------------------------------------------------------------------------------------
        -- Update Order Button
        ---------------------------------------------------------------------------------------------------------------
        local orderButton, _ = setup.Order[orderName]["Button"], setup.Order[orderName]["Text"]
        orderButton.pushed = false
        orderButton:Enable()
        orderButton:SetBackdropColor(color.DarkGray.r, color.DarkGray.g, color.DarkGray.b, color.DarkGray.a)
        orderButton:SetBackdropBorderColor(color.LightGray.r, color.LightGray.g, color.LightGray.b, color.LightGray.a)
        SetPoint(orderButton, "TOPLEFT", 10 + offsetX, -30)
        AddHover(orderButton, true)

        ---------------------------------------------------------------------------------------------------------------
        -- Update OnClick
        ---------------------------------------------------------------------------------------------------------------
        orderButton:SetScript("OnClick", function(self)
            if IsDialogShown() and not IsRollShown() then
                return
            end

            -----------------------------------------------------------------------------------------------------------
            -- Update Button
            -----------------------------------------------------------------------------------------------------------
            local c = color.Gold
            self.pushed = true
            self:Disable()
            self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)

            -----------------------------------------------------------------------------------------------------------
            -- Update Order
            -----------------------------------------------------------------------------------------------------------
            local setup = GetActiveSetup()
            local config = GetActiveConfig()

            local vOffset = 0
            local sortedOrder = {}

            -----------------------------------------------------------------------------------------------------------
            -- Sort Players in Setup
            -----------------------------------------------------------------------------------------------------------
            table.sort(setup.Players, orderConfigs[orderIdx].Callback)
            ApplyToEach(setup.Players, function(k, v) 
                sortedOrder[v.PlayerName] = k 
                SetPoint(v.Container, "TOPLEFT", 10, vOffset)
                vOffset = vOffset - 32
            end)
            SetPoint(setup.TableBottomLine, "TOPLEFT", 5, vOffset + 2)

            table.sort(config.PlayerInfos, function(a, b) return sortedOrder[a.Name] < sortedOrder[b.Name] end)

            -----------------------------------------------------------------------------------------------------------
            -- Set all other Button inactive
            -----------------------------------------------------------------------------------------------------------
            for k, v in pairs(setup.Order) do
                if orderName ~= k then
                    local cl = color.LightGray
                    v.Button:SetBackdropBorderColor(cl.r, cl.g, cl.b, cl.a)
                    v.Button.pushed = false
                    v.Button:Enable()
                end
            end
        end)

        ---------------------------------------------------------------------------------------------------------------
        -- Update Offset For Next Button
        ---------------------------------------------------------------------------------------------------------------
        offsetX = offsetX + 105
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Table Scroll Container
    -------------------------------------------------------------------------------------------------------------------
    if setup.TableScrollContainer == nil then
        setup.TableScrollContainer = CreateFrame("Frame", nil, setup.Content, "BackdropTemplate")
        SetPoint(setup.TableScrollContainer, "TOPLEFT", 10, -80)
        SetPoint(setup.TableScrollContainer, "BOTTOMRIGHT", -6, 50)
        setup.TableScrollContainer:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = math.max(1, Scaled(2)),
        })
        setup.TableScrollContainer:SetBackdropColor(0, 0, 0, 1)
        setup.TableScrollContainer:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Character Name Column Heading
    -------------------------------------------------------------------------------------------------------------------
    if setup.CharacterHeading == nil then
        setup.CharacterHeading = {}
        setup.CharacterHeading.LeftLine, setup.CharacterHeading.Label, setup.CharacterHeading.RightLine = CreateHeading("NAME", characterWidth, setup.TableScrollContainer, 10, -10)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Rare Column Heading
    -------------------------------------------------------------------------------------------------------------------
    if setup.RareHeading == nil then
        setup.RareHeading = {}
        setup.RareHeading.LeftLine, setup.RareHeading.Label, setup.RareHeading.RightLine = CreateHeading("RARE", countWidth, setup.TableScrollContainer, 15 + characterWidth, -10)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Tier Column Heading
    -------------------------------------------------------------------------------------------------------------------
    if setup.TierHeading == nil then
        setup.TierHeading = {}
        setup.TierHeading.LeftLine, setup.TierHeading.Label, setup.TierHeading.RightLine = CreateHeading("TIER", countWidth, setup.TableScrollContainer, 20 + countWidth + characterWidth, -10)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Normal Column Heading
    -------------------------------------------------------------------------------------------------------------------
    if setup.NormalHeading == nil then
        setup.NormalHeading = {}
        setup.NormalHeading.LeftLine, setup.NormalHeading.Label, setup.NormalHeading.RightLine = CreateHeading("NORMAL", countWidth, setup.TableScrollContainer, 25 + countWidth * 2 + characterWidth, -10)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Table Scroll Widget
    -------------------------------------------------------------------------------------------------------------------
    if setup.TableScroll == nil then
        setup.TableScroll = CreateFrame("ScrollFrame", nil, setup.TableScrollContainer, "UIPanelScrollFrameTemplate")
        SetPoint(setup.TableScroll, "TOPLEFT", 0, -25)
        SetPoint(setup.TableScroll, "BOTTOMRIGHT", Agnostic(-27), 5)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Table Scroll Content Widget
    -------------------------------------------------------------------------------------------------------------------
    if setup.Table == nil then
        setup.Table = CreateFrame("Frame")
        SetWidth(setup.Table, GetWidth(setup.TableScroll))
        SetHeight(setup.Table, 1)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Player Row Frames for All Existing Players
    -------------------------------------------------------------------------------------------------------------------
    local vOffset = 0
    setup.Players = setup.Players or {}
    for _, playerInfo in pairs(cfg.PlayerInfos or {}) do
        local player = RemoveFirstElement(addonDB.Widgets.FreePlayers) or {}
        if player.Container then
            player.Container:Show()
            player.Container:SetParent(setup.Table)
        end
        CreatePlayerFrame(player, cfg, setup, setup.Table, playerInfo, GetWidth(setup.Table) - 10, 10, vOffset)
        table.insert(setup.Players, player)
        vOffset = vOffset - 32
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Create Bottom Line
    -------------------------------------------------------------------------------------------------------------------
    if setup.TableBottomLine == nil then
        setup.TableBottomLine = CreateLine(GetWidth(setup.Table) - 10, setup.Table, 5, vOffset + 2, color.DarkGray)
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Assign Table to Table Scroll
    -------------------------------------------------------------------------------------------------------------------
    setup.TableScroll:SetScrollChild(setup.Table)
    
    -------------------------------------------------------------------------------------------------------------------
    -- Assign Tab Button
    -------------------------------------------------------------------------------------------------------------------
    if setup.Tab == nil then
        setup.Tab = {}
        setup.Tab.Button, setup.Tab.Text = CreateButton(addonDB.Widgets.TabContent, name, GetWidth(addonDB.Widgets.TabContent), 40, color.DarkGray, color.LightGray)
    else
        setup.Tab.Button:SetText(name)
        setup.Tab.Button:Show()
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Assign Tab Button
    -------------------------------------------------------------------------------------------------------------------
    AddHover(setup.Tab.Button, true)

    setup.Tab.Button:SetScript("OnMouseDown", function(self)
        if IsDialogShown() then
            return 
        end

        -----------------------------------------------------------------------------------------------------------
        -- Activate Tab and Show Its Content
        -----------------------------------------------------------------------------------------------------------
        self.pushed = true
        self:Disable()
        local c = color.Gold
        self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)

        -----------------------------------------------------------------------------------------------------------
        -- Show Content and Hide All Other Content
        -----------------------------------------------------------------------------------------------------------
        for _, s in pairs(addonDB.Widgets.Setups) do
            if s.Name ~= self:GetText() then
                local cl = color.LightGray
                s.Tab.Button:SetBackdropBorderColor(cl.r, cl.g, cl.b, cl.a)
                s.Tab.Button.pushed = false
                s.Tab.Button:Enable()
                s.Content:Hide()
            else
                s.Content:Show()
            end
        end
    end)
    SetPoint(setup.Tab.Button, "TOPLEFT", 3, -3 - 42 * (#addonDB.Widgets.Setups - 1))

    -------------------------------------------------------------------------------------------------------------------
    -- Show Or Hide The Newly Created Frame Based On Argument
    -------------------------------------------------------------------------------------------------------------------
    if show then
        local c = color.Gold
        setup.Tab.Button.pushed = true
        setup.Tab.Button:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
        setup.Content:Show()
    else
        setup.Content:Hide()
    end

    -------------------------------------------------------------------------------------------------------------------
    -- Return Player Table
    -------------------------------------------------------------------------------------------------------------------
    return setup
end

-----------------------------------------------------------------------------------------------------------------------
-- Setup Configuration from Encoded String
-----------------------------------------------------------------------------------------------------------------------
local function ImportConfigFromEncoded(sharer, encoded)
    -----------------------------------------------------------------------------------------------------------------------
    -- Deserialize String
    -----------------------------------------------------------------------------------------------------------------------
    local success, deserialized = Deserialize(encoded)

    -----------------------------------------------------------------------------------------------------------------------
    -- Change to Red to signalize Deserialization error
    -----------------------------------------------------------------------------------------------------------------------
    if not success then
        return false
    end

    -----------------------------------------------------------------------------------------------------------------------
    -- Set Author as Name
    -----------------------------------------------------------------------------------------------------------------------
    deserialized.Name = sharer
    deserialized.Sharer = sharer 

    -----------------------------------------------------------------------------------------------------------------------
    -- Check if Config would Override
    -----------------------------------------------------------------------------------------------------------------------
    if GetValueByFilter(addonDB.Configs, function(k, v) return v.Name == deserialized.Name end) then
        RemoveWithFilter(addonDB.Configs, function(k, v) return v.Name == deserialized.Name end)
        local key, setup = GetValueByFilter(addonDB.Widgets.Setups, function(k, v) return v.Name == deserialized.Name end)

        -------------------------------------------------------------------------------------------------------------------
        -- Free All Player Container
        -------------------------------------------------------------------------------------------------------------------
        for ek, ev in pairs(setup.Players) do 
            HideFrame(ev.Container)
            ev.Container:ClearAllPoints()
            table.insert(addonDB.Widgets.FreePlayers, ev)
        end
        setup.Players = {}

        -------------------------------------------------------------------------------------------------------------------
        -- Hide Tab Button
        -------------------------------------------------------------------------------------------------------------------
        HideFrame(setup.Tab.Button)
        HideFrame(setup.Content)

        -------------------------------------------------------------------------------------------------------------------
        -- Free Setup
        -------------------------------------------------------------------------------------------------------------------
        table.insert(addonDB.Widgets.FreeSetups, setup)
        table.remove(addonDB.Widgets.Setups, key)

        -------------------------------------------------------------------------------------------------------------------
        -- Rearrange and Hide
        -------------------------------------------------------------------------------------------------------------------
        RearrangeFrames(addonDB.Widgets.Setups, "TOPLEFT", 0, -42, function(v) return v.Tab.Button end, 3, -3)
    end

    -----------------------------------------------------------------------------------------------------------------------
    -- Hide All Other Setups
    -----------------------------------------------------------------------------------------------------------------------
    for k, v in pairs(addonDB.Widgets.Setups) do
        if v.Name ~= deserialized.Name then
            v.Content:Hide()
            v.Tab.Button.pushed = false
            local c = color.LightGray
            v.Tab.Button:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
        end
    end

    -----------------------------------------------------------------------------------------------------------------------
    -- Insert and Activate new Setup
    -----------------------------------------------------------------------------------------------------------------------
    table.insert(addonDB.Configs, deserialized)
    SetupNewEntry(deserialized, true)

    return true
end

local function ImportSummaryFromEncoded(sharer, encoded)
    -----------------------------------------------------------------------------------------------------------------------
    -- Deserialize String
    -----------------------------------------------------------------------------------------------------------------------
    local success, itemAssignment = Deserialize(encoded)

    -----------------------------------------------------------------------------------------------------------------------
    -- Change to Red to signalize Deserialization error
    -----------------------------------------------------------------------------------------------------------------------
    if not success then
        return false
    end

    ---------------------------------------------------------------------------------------------------------------
    -- No item was assigned to player, so no summary window necessary
    ---------------------------------------------------------------------------------------------------------------
    if #itemAssignment == 0 then
        return
    end

    ---------------------------------------------------------------------------------------------------------------
    -- For each Assignment create List Item in Summary View
    ---------------------------------------------------------------------------------------------------------------
    for _, assignment in pairs(itemAssignment) do
        -----------------------------------------------------------------------------------------------------------
        -- Check if we can reuse a previous freed frame
        -----------------------------------------------------------------------------------------------------------
        local item = RemoveFirstElement(addonDB.Widgets.Summary.FreeItems)

        -----------------------------------------------------------------------------------------------------------
        -- Create New Frame if necessary
        -----------------------------------------------------------------------------------------------------------
        if not item then
            item = {}
            -- Setup frame
            item.Frame = CreateFrame("Frame", nil, addonDB.Widgets.Summary.Frame, "BackdropTemplate")
            SetSize(item.Frame, GetWidth(addonDB.Widgets.Summary.Frame) - 20, 52)
            item.Frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = math.max(1, Scaled(2)),
            })
            item.Frame:SetBackdropColor(0, 0, 0, 1)
            item.Frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

            -- Setup item icon
            item.ItemIcon = CreateFrame("Frame", nil, item.Frame, "BackdropTemplate")
            SetSize(item.ItemIcon, 32, 32)
            SetPoint(item.ItemIcon, "TOPLEFT", 20, -10)
            item.ItemIcon:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = math.max(1, Scaled(2)),
            })
            item.ItemIcon:SetBackdropColor(0, 0, 0, 1)
            item.ItemIcon:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

            item.ItemTexture = item.ItemIcon:CreateTexture(nil, "ARTWORK")
            item.ItemTexture:SetAllPoints()

            -- Setup Player Label
            item.PlayerLabel = CreateLabel("", item.Frame, 70, 0, color.Gold, "LEFT", 12)
        end

        -- Insert
        table.insert(addonDB.Widgets.Summary.Items, item)

        -----------------------------------------------------------------------------------------------------------
        -- Show Item Frame
        -----------------------------------------------------------------------------------------------------------
        ShowFrame(item.Frame)

        -----------------------------------------------------------------------------------------------------------
        -- Update GameTooltip for Item Icon
        -----------------------------------------------------------------------------------------------------------
        SetItemTexture(item.ItemIcon, item.ItemTexture, assignment.ItemLink)
        item.ItemIcon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(assignment.ItemLink)
            GameTooltip:Show()
        end)
        item.ItemIcon:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -----------------------------------------------------------------------------------------------------------
        -- Update Player Label
        -----------------------------------------------------------------------------------------------------------
        item.PlayerLabel:SetText(assignment.PlayerName)
        local c = classColor[assignment.Class]
        item.PlayerLabel:SetTextColor(c.r, c.g, c.b, c.a)

        -----------------------------------------------------------------------------------------------------------
        -- Update Position in Summary Frame
        -----------------------------------------------------------------------------------------------------------
        SetPoint(item.Frame, "TOPLEFT", 10, -30 - 54 * (#addonDB.Widgets.Summary.Items - 1))
    end

    ---------------------------------------------------------------------------------------------------------------
    -- Update Height to have Space for Close Button (We dont use Scroll view because of 6 items at most)
    ---------------------------------------------------------------------------------------------------------------
    SetHeight(addonDB.Widgets.Summary.Frame, 30 + 54 * #addonDB.Widgets.Summary.Items + 45)
    
    ---------------------------------------------------------------------------------------------------------------
    -- If Addon Frame is shown, move Summary frame to the right of it, else in the center
    ---------------------------------------------------------------------------------------------------------------
    if addonDB.Widgets.Addon:IsShown() then
        addonDB.Widgets.Summary.Frame:ClearAllPoints()
        SetPoint(addonDB.Widgets.Summary.Frame, "TOPLEFT", addonDB.Widgets.Addon, "TOPRIGHT", 10, 0)
    end

    ---------------------------------------------------------------------------------------------------------------
    -- Show Summary Frame
    ---------------------------------------------------------------------------------------------------------------
    ShowFrame(addonDB.Widgets.Summary.Frame)

    return true
end


-----------------------------------------------------------------------------------------------------------------------
-- Create Addon Window
-----------------------------------------------------------------------------------------------------------------------
addonDB.Widgets.Addon = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

-----------------------------------------------------------------------------------------------------------------------
-- Setup User Interfacd
-----------------------------------------------------------------------------------------------------------------------
local function SetupUserInterface()
    -------------------------------------------------------------------------------------------------------------------
    -- Setup Main Frame
    -------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Addon:SetFrameStrata("HIGH")
    SetSize(addonDB.Widgets.Addon, 1090, 700)
    addonDB.Widgets.Addon:SetMovable(true)
    addonDB.Widgets.Addon:EnableMouse(true)
    addonDB.Widgets.Addon:RegisterForDrag("LeftButton")
    addonDB.Widgets.Addon:SetScript("OnDragStart", addonDB.Widgets.Addon.StartMoving)
    addonDB.Widgets.Addon:SetScript("OnDragStop", addonDB.Widgets.Addon.StopMovingOrSizing)
    SetPoint(addonDB.Widgets.Addon, "CENTER")
    addonDB.Widgets.Addon:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    addonDB.Widgets.Addon:SetBackdropColor(0, 0, 0, 1)
    addonDB.Widgets.Addon:SetBackdropBorderColor(0, 0, 0, 1)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Tab Scroll
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.TabScroll = CreateFrame("ScrollFrame", nil, addonDB.Widgets.Addon, "UIPanelScrollFrameTemplate, BackdropTemplate")
    SetPoint(addonDB.Widgets.TabScroll, "TOPLEFT", 6, -6)
    SetPoint(addonDB.Widgets.TabScroll, "BOTTOMRIGHT", addonDB.Widgets.Addon, "BOTTOMLEFT", 195, 6 + 60)
    addonDB.Widgets.TabScroll:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    addonDB.Widgets.TabScroll:SetBackdropColor(0, 0, 0, 1)
    addonDB.Widgets.TabScroll:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Tab Content And Insert Into Tab Scroll
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.TabContent = CreateFrame("Frame", nil, addonDB.Widgets.TabScroll)
    SetWidth(addonDB.Widgets.TabContent, GetWidth(addonDB.Widgets.TabScroll) - 7)
    SetHeight(addonDB.Widgets.TabContent, 1)
    addonDB.Widgets.TabScroll:SetScrollChild(addonDB.Widgets.TabContent)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create CreatedBy Label
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.CreatedBy = addonDB.Widgets.Addon:CreateFontString(nil, "ARTWORK")
    SetPoint(addonDB.Widgets.CreatedBy, "BOTTOMLEFT", 10, 6)
    addonDB.Widgets.CreatedBy:SetFont("Interface\\Addons\\RaidTablesViewer\\fonts\\UnicodeFont\\WarSansTT-Bliz-500.ttf", Scaled(10), "NONE")
    addonDB.Widgets.CreatedBy:SetTextColor(1, 0.8, 0) -- set the color to golden
    addonDB.Widgets.CreatedBy:SetText("Created by " .. author)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Content Frame
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Content = CreateFrame("Frame", nil, addonDB.Widgets.Addon, "BackdropTemplate")
    SetPoint(addonDB.Widgets.Content, "TOPLEFT", 227, -6)
    SetPoint(addonDB.Widgets.Content, "BOTTOMRIGHT", -6, 6)
    addonDB.Widgets.Content:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    addonDB.Widgets.Content:SetBackdropColor(0, 0, 0, 1)
    addonDB.Widgets.Content:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Close Button
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Close = {}
    addonDB.Widgets.Close.Button, addonDB.Widgets.Close.Text = CreateButton(addonDB.Widgets.Content, "Close", 102, 35, color.DarkGray, color.LightGray)
    SetPoint(addonDB.Widgets.Close.Button, "BOTTOMRIGHT", addonDB.Widgets.Content, "BOTTOMRIGHT", -10, 10)
    addonDB.Widgets.Close.Button:SetScript("OnClick", function(self)
        if IsDialogShown() then
            return
        end
        ToggleFrame(addonDB.Widgets.Addon)
    end)
    AddHover(addonDB.Widgets.Close.Button)

    -----------------------------------------------------------------------------------------------------------------------
    -- Options Dialog
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Options = {}
    addonDB.Widgets.Dialogs.Options.Frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    SetSize(addonDB.Widgets.Dialogs.Options.Frame, 650, 180)
    addonDB.Widgets.Dialogs.Options.Frame:SetMovable(true)
    addonDB.Widgets.Dialogs.Options.Frame:EnableMouse(true)
    addonDB.Widgets.Dialogs.Options.Frame:RegisterForDrag("LeftButton")
    addonDB.Widgets.Dialogs.Options.Frame:SetScript("OnDragStart", addonDB.Widgets.Addon.StartMoving)
    addonDB.Widgets.Dialogs.Options.Frame:SetScript("OnDragStop", addonDB.Widgets.Addon.StopMovingOrSizing)
    SetPoint(addonDB.Widgets.Dialogs.Options.Frame, "CENTER", addonDB.Widgets.Addon, "CENTER", 0, 0)
    addonDB.Widgets.Dialogs.Options.Frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    addonDB.Widgets.Dialogs.Options.Frame:SetBackdropColor(0, 0, 0, 1)
    addonDB.Widgets.Dialogs.Options.Frame:SetBackdropBorderColor(color.LightGray.r, color.LightGray.g, color.LightGray.b, 1)
    addonDB.Widgets.Dialogs.Options.Frame:SetFrameStrata("DIALOG")
    addonDB.Widgets.Dialogs.Options.Frame:Hide()

    -----------------------------------------------------------------------------------------------------------------------
    -- Options Dialog: Header
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Options.Header = CreateHeading("OPTIONS", GetWidth(addonDB.Widgets.Dialogs.Options.Frame) - 20, addonDB.Widgets.Dialogs.Options.Frame, 10, -10, false)

    -----------------------------------------------------------------------------------------------------------------------
    -- Options Dialog: Scaling Frame 
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Options.ScalingContainer = CreateFrame("Frame", nil, addonDB.Widgets.Dialogs.Options.Frame, "BackdropTemplate")
    SetWidth(addonDB.Widgets.Dialogs.Options.ScalingContainer, GetWidth(addonDB.Widgets.Dialogs.Options.Frame) - 20)
    SetHeight(addonDB.Widgets.Dialogs.Options.ScalingContainer, 100)
    SetPoint(addonDB.Widgets.Dialogs.Options.ScalingContainer, "TOP", addonDB.Widgets.Dialogs.Options.Frame, "TOP", 0, -30)
    addonDB.Widgets.Dialogs.Options.ScalingContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    addonDB.Widgets.Dialogs.Options.ScalingContainer:SetBackdropColor(color.DarkGray.r, color.DarkGray.g, color.DarkGray.b, color.DarkGray.a)
    addonDB.Widgets.Dialogs.Options.ScalingContainer:SetBackdropBorderColor(color.LightGray.r, color.LightGray.g, color.LightGray.b, color.LightGray.a)

    -----------------------------------------------------------------------------------------------------------------------
    -- Options Dialog: Scaling Inputfield
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Options.ScalingInputField = CreateFrame("EditBox", nil, addonDB.Widgets.Dialogs.Options.ScalingContainer, "InputBoxTemplate")
    SetWidth(addonDB.Widgets.Dialogs.Options.ScalingInputField, (GetWidth(addonDB.Widgets.Dialogs.Options.ScalingContainer) - 90) * 0.25)
    SetHeight(addonDB.Widgets.Dialogs.Options.ScalingInputField, 30)
    SetPoint(addonDB.Widgets.Dialogs.Options.ScalingInputField, "TOPLEFT", addonDB.Widgets.Dialogs.Options.ScalingContainer, "TOPLEFT", 70, -30)
    addonDB.Widgets.Dialogs.Options.ScalingInputField:SetAutoFocus(false)
    addonDB.Widgets.Dialogs.Options.ScalingInputField:SetText(addonDB.Options.Scaling)
    addonDB.Widgets.Dialogs.Options.ScalingInputField:SetMaxLetters(5)
    addonDB.Widgets.Dialogs.Options.ScalingInputField:SetFont("Interface\\Addons\\RaidTablesViewer\\fonts\\UnicodeFont\\WarSansTT-Bliz-500.ttf", Scaled(12), "OUTLINE")
    addonDB.Widgets.Dialogs.Options.ScalingInputField:SetScript("OnTextChanged", function(self) 
        local num = tonumber(addonDB.Widgets.Dialogs.Options.ScalingInputField:GetText())
        if num then
            if num == addonDB.Options.Scaling then
                local c = color.Gold
                self:SetTextColor(c.r, c.g, c.b, c.a)
            else
                local c = color.White
                self:SetTextColor(c.r, c.g, c.b, c.a)
            end
        else
            local c = color.Red
            self:SetTextColor(c.r, c.g, c.b, c.a)
        end
    end)
    addonDB.Widgets.Dialogs.Options.ScalingInputField:SetScript("OnEnterPressed", function(self) 
        local num = tonumber(addonDB.Widgets.Dialogs.Options.ScalingInputField:GetText())
        if num then
            -- Limit to 0.5 <= num <= 1.5
            num = math.max(0.5, math.min(1.5, num))
            addonDB.Widgets.Dialogs.Options.ScalingInputField:SetText(num)
            addonDB.Options.Scaling = num
        else
            local c = color.Red
            addonDB.Widgets.Dialogs.Options.ScalingInputField:SetTextColor(c.r, c.g, c.b, c.a)
        end
    end)
    addonDB.Widgets.Dialogs.Options.ScalingInputField:SetScript("OnEscapePressed", function(self) 
        self:SetText(addonDB.Options.Scaling)
    end)

    -----------------------------------------------------------------------------------------------------------------------
    -- Options Dialog: Scaling Label
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Options.ScalingLabel = CreateLabel("Scaling:", addonDB.Widgets.Dialogs.Options.ScalingContainer, nil, nil, color.Gold)
    SetPoint(addonDB.Widgets.Dialogs.Options.ScalingLabel, "BOTTOMLEFT", addonDB.Widgets.Dialogs.Options.ScalingInputField, "TOPLEFT", 10, 0)

    -----------------------------------------------------------------------------------------------------------------------
    -- Options Dialog: Scaling Description
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Options.ScalingDescription = CreateLabel("Allows to scale the UI up or down. A value of 1.0 is the default. All values between 0.5 and 1.5 are supported.", addonDB.Widgets.Dialogs.Options.ScalingContainer, nil, nil, color.White)
    addonDB.Widgets.Dialogs.Options.ScalingDescription:SetJustifyH("LEFT")
    SetPoint(addonDB.Widgets.Dialogs.Options.ScalingDescription, "TOPLEFT", addonDB.Widgets.Dialogs.Options.ScalingInputField, "TOPRIGHT", 20, 13)
    SetWidth(addonDB.Widgets.Dialogs.Options.ScalingDescription, GetWidth(addonDB.Widgets.Dialogs.Options.ScalingContainer) * 0.5)

    addonDB.Widgets.Dialogs.Options.ScalingWarning = CreateLabel("IMPORTANT: You have to /reload to apply the scaling change.", addonDB.Widgets.Dialogs.Options.ScalingContainer, nil, nil, color.Red)
    addonDB.Widgets.Dialogs.Options.ScalingWarning:SetJustifyH("LEFT")
    SetPoint(addonDB.Widgets.Dialogs.Options.ScalingWarning, "TOPLEFT", addonDB.Widgets.Dialogs.Options.ScalingDescription, "BOTTOMLEFT", 0, -5)
    SetWidth(addonDB.Widgets.Dialogs.Options.ScalingWarning, GetWidth(addonDB.Widgets.Dialogs.Options.ScalingContainer) * 0.5)

    -----------------------------------------------------------------------------------------------------------------------
    -- Options Dialog: Close Button 
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Options.Close = {}
    addonDB.Widgets.Dialogs.Options.Close.Button, addonDB.Widgets.Dialogs.Options.Close.Text = CreateButton(addonDB.Widgets.Dialogs.Options.Frame, "Close", 102, 28, color.DarkGray, color.LightGray)
    SetPoint(addonDB.Widgets.Dialogs.Options.Close.Button, "BOTTOMRIGHT", addonDB.Widgets.Dialogs.Options.Frame, "BOTTOMRIGHT", -10, 10)
    addonDB.Widgets.Dialogs.Options.Close.Button:SetScript("OnClick", function(self)
        local num = tonumber(addonDB.Widgets.Dialogs.Options.ScalingInputField:GetText())
        if num then
            -- Limit to 0.5 <= num <= 1.5
            num = math.max(0.5, math.min(1.5, num))
            addonDB.Widgets.Dialogs.Options.ScalingInputField:SetText(num)
            addonDB.Options.Scaling = num
            addonDB.Widgets.Dialogs.Options.Frame:Hide()
        else
            local c = color.Red
            addonDB.Widgets.Dialogs.Options.ScalingInputField:SetTextColor(c.r, c.g, c.b, c.a)
        end
    end)
    AddHover(addonDB.Widgets.Dialogs.Options.Close.Button)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Accept Sharing Dialog
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.AcceptSharing = {}
    addonDB.Widgets.Dialogs.AcceptSharing.Frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    SetSize(addonDB.Widgets.Dialogs.AcceptSharing.Frame, 350, 120)
    addonDB.Widgets.Dialogs.AcceptSharing.Frame:SetMovable(false)
    SetPoint(addonDB.Widgets.Dialogs.AcceptSharing.Frame, "TOP", 0, -250)
    addonDB.Widgets.Dialogs.AcceptSharing.Frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    addonDB.Widgets.Dialogs.AcceptSharing.Frame:SetBackdropColor(0, 0, 0, 1)
    addonDB.Widgets.Dialogs.AcceptSharing.Frame:SetBackdropBorderColor(color.LightGray.r, color.LightGray.g, color.LightGray.b, 1)
    addonDB.Widgets.Dialogs.AcceptSharing.Frame:SetFrameStrata("DIALOG")
    addonDB.Widgets.Dialogs.AcceptSharing.Frame:Hide()

    -----------------------------------------------------------------------------------------------------------------------
    -- Accept Sharing Dialog: Header
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.AcceptSharing.Header = CreateHeading("RAID TABLES VIEWER", GetWidth(addonDB.Widgets.Dialogs.AcceptSharing.Frame) - 20, addonDB.Widgets.Dialogs.AcceptSharing.Frame, 10, -10, false, 14)

    -----------------------------------------------------------------------------------------------------------------------
    -- Accept Sharing Dialog: Label 
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.AcceptSharing.PlayerLabel = CreateLabel("Player:", addonDB.Widgets.Dialogs.AcceptSharing.Frame, 0, -35, color.Gold, "TOP", 14)
    addonDB.Widgets.Dialogs.AcceptSharing.PlayerName = CreateLabel("", addonDB.Widgets.Dialogs.AcceptSharing.Frame, 0, -35, color.White, "TOP", 14)

    -----------------------------------------------------------------------------------------------------------------------
    -- Accept Sharing Dialog: Label 
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.AcceptSharing.Label = CreateLabel("Accept sharing of RaidTables?", addonDB.Widgets.Dialogs.AcceptSharing.Frame, 0, -60, color.White, "TOP", 14)
    SetWidth(addonDB.Widgets.Dialogs.AcceptSharing.Label, GetWidth(addonDB.Widgets.Dialogs.AcceptSharing.Frame) - 20)

    -----------------------------------------------------------------------------------------------------------------------
    -- Accept Sharing Dialog: Yes Button
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.AcceptSharing.Yes = {}
    addonDB.Widgets.Dialogs.AcceptSharing.Yes.Button, addonDB.Widgets.Dialogs.AcceptSharing.Yes.Text = CreateButton(addonDB.Widgets.Dialogs.AcceptSharing.Frame, "YES", 102, 28, color.DarkGray, color.LightGray)
    SetPoint(addonDB.Widgets.Dialogs.AcceptSharing.Yes.Button, "BOTTOMRIGHT", addonDB.Widgets.Dialogs.AcceptSharing.Frame, "BOTTOMRIGHT", -45, 10)
    addonDB.Widgets.Dialogs.AcceptSharing.Yes.Button:SetScript("OnClick", function(self)
        -- Insert as accepted
        local playerName = addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:GetText()
        table.insert(addonDB.Accepted, playerName)

        -- Check for already finished data
        for prefix, typeBuffer in pairs(addonDB.MsgBuffer) do
            for i, data in pairs(typeBuffer[playerName]) do
                -- Create full payload from parts
                local payload, idx = "", 0
                while idx < data.totalLength do
                    if data[idx + 1] then
                        idx = data[idx + 1].endIndex
                    else
                        break
                    end
                end
                -- Skip if parts are missing
                if idx ~= data.totalLength then
                    -- Drop if too old
                    if (data.LastUpdate + 10) < GetTime() then
                        -- Clear buffer
                        table.remove(typeBuffer[playerName], i)
                    end
                    break
                end
                -- Concatenate payload
                idx = 1
                while idx < data.totalLength do
                    if data[idx] then
                        payload = payload .. data[idx].msgPart
                        idx = data[idx].endIndex + 1
                    else
                        break
                    end
                end
                if prefix == "RTConfig" then
                    -- Import Configuration
                    ImportConfigFromEncoded(playerName, payload)
                elseif prefix == "RTSummary" then
                    -- Import Summary
                    ImportSummaryFromEncoded(playerName, payload)
                end
                -- Clear buffer
                addonDB.MsgBuffer[prefix][playerName][i] = nil
            end
        end

        -- Check next one
        local _, name = RemoveFirstElement(addonDB.Widgets.Dialogs.AcceptSharing.ToAccept)
        if name then
            local realm = select(2, UnitFullName("player"))
            local parts = SplitString(name, '-')
            local class = nil
            if parts[2] and parts[2] == realm then
                class = select(2, UnitClass(parts[1]))
            else 
                class = select(2, name)
            end
            local c = classColor[class]
            addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:SetText(name)
            addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:SetTextColor(c.r, c.g, c.b, c.a)
        else
            HideFrame(addonDB.Widgets.Dialogs.AcceptSharing.Frame)
        end
    end)
    AddHover(addonDB.Widgets.Dialogs.AcceptSharing.Yes.Button)

    -----------------------------------------------------------------------------------------------------------------------
    -- Accept Sharing Dialog: No Button
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.AcceptSharing.No = {}
    addonDB.Widgets.Dialogs.AcceptSharing.No.Button, addonDB.Widgets.Dialogs.AcceptSharing.No.Text = CreateButton(addonDB.Widgets.Dialogs.AcceptSharing.Frame, "NO", 102, 28, color.DarkGray, color.LightGray)
    SetPoint(addonDB.Widgets.Dialogs.AcceptSharing.No.Button, "BOTTOMLEFT", addonDB.Widgets.Dialogs.AcceptSharing.Frame, "BOTTOMLEFT", 45, 10)
    addonDB.Widgets.Dialogs.AcceptSharing.No.Button:SetScript("OnClick", function(self)
        local playerName = addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:GetText()
        table.insert(addonDB.Rejected, playerName)

        -- Remove already stored values
        for prefix, _ in pairs(addonDB.MsgBuffer) do
            addonDB["MsgBuffer"][prefix][playerName] = nil
        end

        -- Check next one
        local _, name = RemoveFirstElement(addonDB.Widgets.Dialogs.AcceptSharing.ToAccept)
        if name then
            local realm = select(2, UnitFullName("player"))
            local parts = SplitString(name, '-')
            local class = nil
            if parts[2] and parts[2] == realm then
                class = select(2, UnitClass(parts[1]))
            else 
                class = select(2, name)
            end
            local c = classColor[class]
            addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:SetText(name)
            addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:SetTextColor(c.r, c.g, c.b, c.a)
        else
            HideFrame(addonDB.Widgets.Dialogs.AcceptSharing.Frame)
        end
    end)
    AddHover(addonDB.Widgets.Dialogs.AcceptSharing.No.Button)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Import Dialog
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Import = {}
    addonDB.Widgets.Dialogs.Import.Frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    SetSize(addonDB.Widgets.Dialogs.Import.Frame, 250, 90)
    addonDB.Widgets.Dialogs.Import.Frame:SetMovable(false)
    SetPoint(addonDB.Widgets.Dialogs.Import.Frame, "CENTER")
    addonDB.Widgets.Dialogs.Import.Frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    addonDB.Widgets.Dialogs.Import.Frame:SetBackdropColor(0, 0, 0, 1)
    addonDB.Widgets.Dialogs.Import.Frame:SetBackdropBorderColor(color.LightGray.r, color.LightGray.g, color.LightGray.b, 1)
    addonDB.Widgets.Dialogs.Import.Frame:SetFrameStrata("DIALOG")
    addonDB.Widgets.Dialogs.Import.Frame:Hide()

    -----------------------------------------------------------------------------------------------------------------------
    -- Import Dialog: Header
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Import.Header = CreateHeading("IMPORT", GetWidth(addonDB.Widgets.Dialogs.Import.Frame) - 10, addonDB.Widgets.Dialogs.Import.Frame, 5, -10, true)

    -----------------------------------------------------------------------------------------------------------------------
    -- Import Dialog: Escape Label
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Import.Escape = CreateLabel("<ESC>: Cancel", addonDB.Widgets.Dialogs.Import.Frame, 10, 10, color.White, "BOTTOMLEFT")

    -----------------------------------------------------------------------------------------------------------------------
    -- Import Dialog: Enter Label
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Import.Enter = CreateLabel("<ENTER>: Confirm", addonDB.Widgets.Dialogs.Import.Frame, -10, 10, color.White, "BOTTOMRIGHT")

    -----------------------------------------------------------------------------------------------------------------------
    -- Import Dialog: InputField
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Dialogs.Import.InputField = CreateFrame("EditBox", nil, addonDB.Widgets.Dialogs.Import.Frame, "InputBoxTemplate")
    SetWidth(addonDB.Widgets.Dialogs.Import.InputField, GetWidth(addonDB.Widgets.Dialogs.Import.Frame) - 30)
    SetHeight(addonDB.Widgets.Dialogs.Import.InputField, 30)
    SetPoint(addonDB.Widgets.Dialogs.Import.InputField, "TOPLEFT", addonDB.Widgets.Dialogs.Import.Frame, "TOPLEFT", 17, -30)
    addonDB.Widgets.Dialogs.Import.InputField:SetAutoFocus(true)
    addonDB.Widgets.Dialogs.Import.InputField:SetMaxLetters(0)
    addonDB.Widgets.Dialogs.Import.InputField:SetFont("Interface\\Addons\\RaidTablesViewer\\fonts\\UnicodeFont\\WarSansTT-Bliz-500.ttf", Scaled(12), "OUTLINE")
    addonDB.Widgets.Dialogs.Import.InputField:SetScript("OnTextChanged", function(self) 
        self:SetTextColor(color.White.r, color.White.g, color.White.b)
    end)
    addonDB.Widgets.Dialogs.Import.InputField:SetScript("OnEnterPressed", function(self) 
        local input = self:GetText()
        if #input == 0 then
            return
        end

        -----------------------------------------------------------------------------------------------------------------------
        -- Deserialize String
        -----------------------------------------------------------------------------------------------------------------------
        local success, deserialized = Deserialize(self:GetText())

        -----------------------------------------------------------------------------------------------------------------------
        -- Change to Red to signalize Deserialization error
        -----------------------------------------------------------------------------------------------------------------------
        if not success then
            self:SetTextColor(color.Red.r, color.Red.g, color.Red.b)
            return
        end

        deserialized.Name = deserialized.Sharer

        -----------------------------------------------------------------------------------------------------------------------
        -- Hide and Reset
        -----------------------------------------------------------------------------------------------------------------------
        addonDB.Widgets.Dialogs.Import.Frame:Hide()
        self:SetText("")

        -----------------------------------------------------------------------------------------------------------------------
        -- Check if Config would Override
        -----------------------------------------------------------------------------------------------------------------------
        if GetValueByFilter(addonDB.Configs, function(k, v) return v.Name == deserialized.Name end) then
            RemoveWithFilter(addonDB.Configs, function(k, v) return v.Name == deserialized.Name end)
            local key, setup = GetValueByFilter(addonDB.Widgets.Setups, function(k, v) return v.Name == deserialized.Name end)

            -------------------------------------------------------------------------------------------------------------------
            -- Free All Player Container
            -------------------------------------------------------------------------------------------------------------------
            for ek, ev in pairs(setup.Players) do 
                HideFrame(ev.Container)
                ev.Container:ClearAllPoints()
                table.insert(addonDB.Widgets.FreePlayers, ev)
            end
            setup.Players = {}

            -------------------------------------------------------------------------------------------------------------------
            -- Hide Tab Button
            -------------------------------------------------------------------------------------------------------------------
            HideFrame(setup.Tab.Button)
            HideFrame(setup.Content)

            -------------------------------------------------------------------------------------------------------------------
            -- Free Setup
            -------------------------------------------------------------------------------------------------------------------
            table.insert(addonDB.Widgets.FreeSetups, setup)
            table.remove(addonDB.Widgets.Setups, key)

            -------------------------------------------------------------------------------------------------------------------
            -- Rearrange and Hide
            -------------------------------------------------------------------------------------------------------------------
            RearrangeFrames(addonDB.Widgets.Setups, "TOPLEFT", 0, -42, function(v) return v.Tab.Button end, 3, -3)
        end

        -----------------------------------------------------------------------------------------------------------------------
        -- Hide All Other Setups
        -----------------------------------------------------------------------------------------------------------------------
        for k, v in pairs(addonDB.Widgets.Setups) do
            if v.Name ~= deserialized.Name then
                v.Content:Hide()
                v.Tab.Button.pushed = false
                local c = color.LightGray
                v.Tab.Button:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
            end
        end

        -----------------------------------------------------------------------------------------------------------------------
        -- Insert and Activate new Setup
        -----------------------------------------------------------------------------------------------------------------------
        table.insert(addonDB.Configs, deserialized)
        SetupNewEntry(deserialized, true)
    end)
    addonDB.Widgets.Dialogs.Import.InputField:SetScript("OnEscapePressed", function(self) 
        if addonDB.Widgets.Dialogs.Import.Frame:IsShown() then
            self:SetText("")
            addonDB.Widgets.Dialogs.Import.Frame:Hide()
        end
    end)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Summary Dialog
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Summary = {}
    addonDB.Widgets.Summary.Items = {}
    addonDB.Widgets.Summary.FreeItems = {}
    addonDB.Widgets.Summary.Frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    SetSize(addonDB.Widgets.Summary.Frame, 280, 430)
    SetPoint(addonDB.Widgets.Summary.Frame, "CENTER", 0, 0)
    addonDB.Widgets.Summary.Frame:SetMovable(true)
    addonDB.Widgets.Summary.Frame:EnableMouse(true)
    addonDB.Widgets.Summary.Frame:RegisterForDrag("LeftButton")
    addonDB.Widgets.Summary.Frame:SetScript("OnDragStart", function(self) 
        addonDB.Widgets.Summary.Frame.Moved = true
        self:StartMoving()
    end)
    addonDB.Widgets.Summary.Frame:SetScript("OnDragStop", addonDB.Widgets.Summary.Frame.StopMovingOrSizing)
    addonDB.Widgets.Summary.Frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, Scaled(2)),
    })
    addonDB.Widgets.Summary.Frame:SetBackdropColor(0, 0, 0, 1)
    addonDB.Widgets.Summary.Frame:SetBackdropBorderColor(color.LightGray.r, color.LightGray.g, color.LightGray.b, 1)
    addonDB.Widgets.Summary.Frame:SetFrameStrata("DIALOG")
    addonDB.Widgets.Summary.Frame:Hide()

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Summary Dialog Header
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Summary.Header = CreateHeading("SUMMARY", GetWidth(addonDB.Widgets.Summary.Frame) - 10, addonDB.Widgets.Summary.Frame, 5, -10, true)

    -----------------------------------------------------------------------------------------------------------------------
    -- Create Summary Dialog Close Button
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Summary.Close = {}
    addonDB.Widgets.Summary.Close.Button, addonDB.Widgets.Summary.Close.Text = CreateButton(addonDB.Widgets.Summary.Frame, "Close", 102, 30, color.DarkGray, color.LightGray, color.Gold)
    SetPoint(addonDB.Widgets.Summary.Close.Button, "BOTTOMRIGHT", addonDB.Widgets.Summary.Frame, "BOTTOMRIGHT", -10, 10)
    addonDB.Widgets.Summary.Close.Button:SetScript("OnEnter", function(self)
        local c = color.Gold
        self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end)
    addonDB.Widgets.Summary.Close.Button:SetScript("OnLeave", function(self)
        local c = color.LightGray
        self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end)
    addonDB.Widgets.Summary.Close.Button:SetScript("OnClick", function(self)
        addonDB.Widgets.Summary.Frame:Hide()
        -- Free all frames
        for _, w in pairs(addonDB.Widgets.Summary.Items) do
            table.insert(addonDB.Widgets.Summary.FreeItems, w)
            w.Frame:Hide()
        end
        addonDB.Widgets.Summary.Items = {}
    end)

    -----------------------------------------------------------------------------------------------------------------------
    -- Setup Import Button
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Import = {}
    addonDB.Widgets.Import.Button, addonDB.Widgets.Import.Text = CreateButton(addonDB.Widgets.Addon, "Import", 102, 35, color.DarkGray, color.LightGray)
    SetPoint(addonDB.Widgets.Import.Button, "BOTTOMLEFT", 6, 25)
    addonDB.Widgets.Import.Button:SetScript("OnEnter", function(self)
        local c = color.Gold
        self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end)
    addonDB.Widgets.Import.Button:SetScript("OnLeave", function(self)
        local c = color.LightGray
        self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end)
    addonDB.Widgets.Import.Button:SetScript("OnClick", function(self)
        if IsDialogShown() then
            return
        end
        addonDB.Widgets.Dialogs.Import.Frame:Show()
    end)

    -----------------------------------------------------------------------------------------------------------------------
    -- Setup Options Button
    -----------------------------------------------------------------------------------------------------------------------
    addonDB.Widgets.Options = {}
    addonDB.Widgets.Options.Button, addonDB.Widgets.Options.Text = CreateButton(addonDB.Widgets.Addon, "Options", 102, 35, color.DarkGray, color.LightGray)
    SetPoint(addonDB.Widgets.Options.Button, "BOTTOMLEFT", 112, 25)
    addonDB.Widgets.Options.Button:SetScript("OnEnter", function(self)
        local c = color.Gold
        self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end)
    addonDB.Widgets.Options.Button:SetScript("OnLeave", function(self)
        local c = color.LightGray
        self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end)
    addonDB.Widgets.Options.Button:SetScript("OnClick", function(self)
        if IsDialogShown() then
            return
        end
        addonDB.Widgets.Dialogs.Options.Frame:ClearAllPoints()
        SetPoint(addonDB.Widgets.Dialogs.Options.Frame, "CENTER", addonDB.Widgets.Addon, "CENTER", 0, 0)
        addonDB.Widgets.Dialogs.Options.ScalingInputField:SetText(addonDB.Options.Scaling)
        addonDB.Widgets.Dialogs.Options.Frame:Show()
    end)
end

-----------------------------------------------------------------------------------------------------------------------
-- Register Addon Events
-----------------------------------------------------------------------------------------------------------------------
addonDB.Widgets.Addon:RegisterEvent("ADDON_LOADED")
addonDB.Widgets.Addon:RegisterEvent("PLAYER_LOGOUT")
addonDB.Widgets.Addon:RegisterEvent("CHAT_MSG_ADDON")

-----------------------------------------------------------------------------------------------------------------------
-- Callback for Event Handling
-----------------------------------------------------------------------------------------------------------------------
addonDB.Widgets.Addon:SetScript("OnEvent", function(self, event, arg1, ...) 
    if event == "ADDON_LOADED" and arg1 == addonName then
        ---------------------------------------------------------------------------------------------------------------
        -- Get SavedVariables
        ---------------------------------------------------------------------------------------------------------------
        local savedVariable = RaidTablesViewerDB or {}
        addonDB.Options = MergeTables(addonDB.Options or {}, savedVariable.Options or {})
        addonDB.Configs = MergeTables(addonDB.Configs or {}, savedVariable.Configs or {})

        ---------------------------------------------------------------------------------------------------------------
        -- Setup User Interface
        ---------------------------------------------------------------------------------------------------------------
        SetupUserInterface()
        
        ---------------------------------------------------------------------------------------------------------------
        -- Registery Addon Message
        ---------------------------------------------------------------------------------------------------------------
        addonDB.ChatMsgRegistered = C_ChatInfo.RegisterAddonMessagePrefix("RTConfig") 
        addonDB.ChatMsgRegistered = addonDB.ChatMsgRegistered and C_ChatInfo.RegisterAddonMessagePrefix("RTSummary") 
        if not addonDB.ChatMsgRegistered then
            print("[ERROR] RaidTables: Addon Chat Message Registration FAILED.")
        end

    elseif event == "PLAYER_LOGOUT" then
        RaidTablesViewerDB = {}
        RaidTablesViewerDB.Options = addonDB.Options

    elseif event == "CHAT_MSG_ADDON" and (arg1 == "RTSummary" or arg1 == "RTConfig") then
        local msg, msgType, sender = ...
        local playerName, realm = UnitFullName("player")
        local fullPlayerName = playerName.."-"..realm

        if sender == fullPlayerName then
            return
        end

        if GetValueByFilter(addonDB.Rejected, function(k, v) return v == sender end) then
            return
        end

        local isAccepted = GetValueByFilter(addonDB.Accepted, function(k, v) return v == sender end)
        if not isAccepted then
            if addonDB.Widgets.Dialogs.AcceptSharing.Frame:IsShown() then
                addonDB.Widgets.Dialogs.AcceptSharing.ToAccept = addonDB.Widgets.Dialogs.AcceptSharing.ToAccept or {}
                if not GetValueByFilter(addonDB.Widgets.Dialogs.AcceptSharing.ToAccept, function(k, v) return v == sender end) then
                    table.insert(addonDB.Widgets.Dialogs.AcceptSharing.ToAccept, sender)
                end
            else
                local parts = SplitString(sender, '-')
                local class = nil
                if parts[2] and parts[2] == realm then
                    class = select(2, UnitClass(parts[1]))
                else 
                    class = select(2, sender)
                end
                local c = (class and classColor[class]) or color.White
                addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:SetText(sender)
                addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:SetTextColor(c.r, c.g, c.b, c.a)
                addonDB.Widgets.Dialogs.AcceptSharing.PlayerName:ClearAllPoints()
                local nameLen = GetWidth(addonDB.Widgets.Dialogs.AcceptSharing.PlayerName)
                local labelLen = GetWidth(addonDB.Widgets.Dialogs.AcceptSharing.PlayerLabel)
                local half = (nameLen + 10 + labelLen) * 0.5
                SetPoint(addonDB.Widgets.Dialogs.AcceptSharing.PlayerLabel, "LEFT", addonDB.Widgets.Dialogs.AcceptSharing.Frame, "TOP", -half, -35)
                SetPoint(addonDB.Widgets.Dialogs.AcceptSharing.PlayerName, "LEFT", addonDB.Widgets.Dialogs.AcceptSharing.PlayerLabel, "RIGHT", 10, 0)
                ShowFrame(addonDB.Widgets.Dialogs.AcceptSharing.Frame)
            end
        end

        addonDB.MsgBuffer = addonDB.MsgBuffer or {}
        addonDB.MsgBuffer[arg1] = addonDB.MsgBuffer[arg1] or {}
        addonDB.MsgBuffer[arg1][sender] = addonDB.MsgBuffer[arg1][sender] or {}
        
        local parts = SplitString(msg, "$|$")
        local id, startIndex, endIndex, totalLength, msgPart = parts[1], parts[2], parts[3], parts[4], parts[5]
        if not startIndex or not endIndex or not msgPart or not totalLength or not id then
            print("[ERROR] RaidTables: Received corrupted message.")
            return
        end

        local now = GetTime()
        addonDB.MsgBuffer[arg1][sender][id] = addonDB.MsgBuffer[arg1][sender][id] or {}
        addonDB.MsgBuffer[arg1][sender][id].totalLength = tonumber(totalLength)
        addonDB.MsgBuffer[arg1][sender][id].LastUpdate = now
        addonDB.MsgBuffer[arg1][sender][id][tonumber(startIndex)] = {
            endIndex = tonumber(endIndex),
            msgPart = msgPart,
        }

        for prefix, typeBuffer in pairs(addonDB.MsgBuffer) do
            for senderName, buffer in pairs(typeBuffer) do
                for i, data in pairs(buffer) do
                    -- Create full payload from parts
                    local payload, idx = "", 0
                    while idx < data.totalLength do
                        if data[idx + 1] then
                            idx = data[idx + 1].endIndex
                        else
                            break
                        end
                    end
                    -- Skip if parts are missing
                    if idx ~= data.totalLength then
                        -- Drop if too old
                        if (data.LastUpdate + 10) < now then
                            -- Clear buffer
                            table.remove(buffer, i)
                        end
                        break
                    end
                    -- Concatenate payload
                    idx = 1
                    while idx < data.totalLength do
                        if data[idx] then
                            payload = payload .. data[idx].msgPart
                            idx = data[idx].endIndex + 1
                        else
                            break
                        end
                    end
                    if isAccepted then
                        if prefix == "RTConfig" then
                            -- Import Configuration
                            ImportConfigFromEncoded(sender, payload)
                        elseif prefix == "RTSummary" then
                            -- Import Summary
                            ImportSummaryFromEncoded(sender, payload)
                        end
                        -- Clear buffer
                        addonDB.MsgBuffer[prefix][senderName][i] = nil
                    end
                end
            end
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------
-- Create Slash Command
-----------------------------------------------------------------------------------------------------------------------
SLASH_RAID_TABLES_VIEWER_COMMAND1 = "/rtviewer"
local function SlashCommandHandler(msg)
    if msg == "stats" then
        print("Created Frames = "..createdFrameCount)
        print("Raid Configs = "..#addonDB.Configs)
        print("Free Raid Entities = "..#addonDB.Widgets.FreeSetups)
        print("Free Player Entities = "..#addonDB.Widgets.FreePlayers)
    else
        if not addonDB.Widgets.Addon:IsShown() then
            addonDB.Widgets.Addon:Show()
        else 
            addonDB.Widgets.Addon:Hide()
        end
    end
end
SlashCmdList.RAID_TABLES_VIEWER_COMMAND = SlashCommandHandler

-----------------------------------------------------------------------------------------------------------------------
-- Add addon to addon compartment frame
-----------------------------------------------------------------------------------------------------------------------
AddonCompartmentFrame:RegisterAddon({
    text = addonName,
    icon = "Interface\\AddOns\\RaidTablesViewer\\img\\RaidTablesViewer.png",
    registerForAnyClick = true,
    notCheckable = true,
    func = function(btn, arg1, arg2, checked, mouseButton)
        if mouseButton == "LeftButton" then
            if addonDB.Widgets.Addon:IsShown() then
                if IsDialogShown() then
                    return
                end
                addonDB.Widgets.Addon:Hide()
            else
                addonDB.Widgets.Addon:Show()
            end
        elseif mouseButton == "MiddleButton" then
        else
        end
    end,
    funcOnEnter = function()
        GameTooltip:SetOwner(AddonCompartmentFrame, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(addonName)
        GameTooltip:AddLine("Click to toggle ".. addonName .. " frame", 1, 1, 1)
        GameTooltip:Show()
    end
})

-----------------------------------------------------------------------------------------------------------------------
-- Hide Addon Frame Initially
-----------------------------------------------------------------------------------------------------------------------
addonDB.Widgets.Addon:Hide()