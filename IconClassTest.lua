-- Broker_RaidMakeup.lua
-- Written by KyrosKrane Sylvanblade (kyros@kyros.info)
-- Copyright (c) 2018 KyrosKrane Sylvanblade
-- Licensed under the MIT License, as per the included file.

-- File revision: @file-abbreviated-hash@
-- File last updated: @file-date-iso@


--#########################################
--# Description
--#########################################

-- This add-on creates a LibDataBroker object that shows you the makeup of your raid (tanks, healers, and dps).
-- Requires an LDB display to show the info.
-- Configuration is handled through the standard Blizzard addons config window.


--#########################################
--# Globals and utilities
--#########################################

-- Get a local reference to speed up execution.
local _G = _G
local string = string
local print = print
local setmetatable = setmetatable
local select = select
local type = type
local pairs = pairs

-- Define a global for our namespace
local BRM = {}


--#########################################
--# Frame for event handling
--#########################################

-- Create the frame to hold our event catcher, and the list of events.
BRM.Frame, BRM.Events = CreateFrame("Frame"), {}


--#########################################
--# Constants
--#########################################

-- The strings that define the addon
BRM.ADDON_NAME="Broker_RaidMakeup" -- the internal addon name for LibStub and other addons
BRM.USER_ADDON_NAME="Broker_RaidMakeup" -- the name displayed to the user

-- The strings used by the game to represent the roles. I don't think these are localized in the game.
BRM.ROLE_HEALER = "HEALER"
BRM.ROLE_TANK = "TANK"
BRM.ROLE_DPS = "DAMAGER"
BRM.ROLE_NONE = "NONE"

-- The faction strings. Again, probably not localized
BRM.FACTION_ALLIANCE = "Alliance"
BRM.FACTION_HORDE = "Horde"

-- The version of this add-on
BRM.Version = "@project-version@"





--#########################################
--# Debugging setup
--#########################################

-- Debug settings
-- This is needed to debug stuff before the addon loads. After the addon loads, the permanent value is stored in BRM.DB.DebugMode
BRM.DebugMode = false

--@alpha@
BRM.DebugMode = true
--@end-alpha@


-- Print debug output to the chat frame.
function BRM:DebugPrint(...)
	if not BRM.DebugMode then return end

	print ("|cff" .. "a00000" .. "BRM Debug:|r", ...)
end -- BRM:DebugPrint


-- Print regular output to the chat frame.
function BRM:ChatPrint(...)
	print ("|cff" .. "0066ff" .. "BRM:|r", ...)
end -- BRM:DebugPrint


-- Debugging code to see what the hell is being passed in...
function BRM:PrintVarArgs(...)
	if not BRM.DebugMode then return end

	local n = select('#', ...)
	BRM:DebugPrint ("There are ", n, " items in varargs.")
	local msg
	for i = 1, n do
		msg = select(i, ...)
		BRM:DebugPrint ("Item ", i, " is ", msg)
	end
end -- BRM:PrintVarArgs()


-- Dumps a table into chat. Not intended for production use.
function BRM:DumpTable(tab, indent)
	if not BRM.DebugMode then return end

	if not indent then indent = 0 end
	if indent > 10 then
		BRM:DebugPrint("Recursion is at 11 already; aborting.")
		return
	end
	for k, v in pairs(tab) do
		local s = ""
		if indent > 0 then
			for i = 0, indent do
				s = s .. "    "
			end
		end
		if "table" == type(v) then
			s = s .. "Item " .. k .. " is sub-table."
			BRM:DebugPrint(s)
			indent = indent + 1
			BRM:DumpTable(v, indent)
			indent = indent - 1
		else
			s = s .. "Item " .. k .. " is " .. tostring(v)
			BRM:DebugPrint(s)
		end
	end
end -- BRM:DumpTable()


-- Sets the debug mode and writes the setting to the DB
function BRM:SetDebugMode(setting)
	BRM.DebugMode = setting
	BRM.DB.DebugMode = setting
end


--#########################################
--# Select the actual icons used
--#########################################

-- The icons to use when displaying in the broker display
BRM.MainIcon = IconClass("Interface\\Icons\\Inv_helm_robe_raidpriest_k_01") -- Placeholder icon to use until we determine the faction later.
BRM.AllianceIcon = IconClass("Interface\\Calendar\\UI-Calendar-Event-PVP02")
BRM.HordeIcon = IconClass("Interface\\Calendar\\UI-Calendar-Event-PVP01")

-- Role icons
BRM.TankIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES.blp", 64, 64, 0, 0+19, 22, 22+19)
BRM.HealerIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES.blp", 64, 64, 19, 19+19, 1, 1+19)
BRM.DPSIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES.blp", 64, 64, 19, 19+19, 22, 22+19)
BRM.UnknownIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-ROLES.blp", 256, 256, 135, 135+64, 67, 67+64)


-- These high res icons don't look very good when squished down to a broker display. The low-res ones above are better.
--BRM.TankIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-ROLES.blp", 256, 256, 0, 0+64, 68, 68+64)
--BRM.HealerIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-ROLES.blp", 256, 256, 68, 68+64, 0, 0+64)
--BRM.DPSIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-ROLES.blp", 256, 256, 68, 68+64, 68, 68+64)




--#########################################
--# Actual LibDataBroker object
--#########################################

BRM.LDO = _G.LibStub("LibDataBroker-1.1"):NewDataObject(BRM.ADDON_NAME, {
	type = "data source",
	text = "IconClassTest",
	value = "0",
	icon = BRM.TankIcon.IconFile,
	iconCoords = BRM.TankIcon:GetTexCoords4(),
	label = "IconClassTest",
}) -- BRM.LDO creation



