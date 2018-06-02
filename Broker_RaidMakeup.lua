-- Broker_RaidMakeup.lua
-- Written by KyrosKrane Sylvanblade (kyros@kyros.info)
-- Copyright (c) 2018 KyrosKrane Sylvanblade
-- Licensed under the MIT License, as below.


--#########################################
--# Description
--#########################################

-- This add-on creates a LibDataBroker object that shows you the makeup of your raid (tanks, healers, and dps).
-- Requires an LDB display to show the info.
-- No configuration or setup.


--#########################################
--# License: MIT License
--#########################################
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.


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
local BRM = { }


--#########################################
--# Frame for event handling
--#########################################

-- Create the frame to hold our event catcher, and the list of events.
BRM.Frame, BRM.Events = CreateFrame("Frame"), {}


--#########################################
--# Debugging setup
--#########################################

-- Debug settings
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


--#########################################
--# Icon class setup
--#########################################

-- The normal way of handling icons is to create a texture, load the icon file into that, set the region you want, and done.
-- However, we need to embed icons into a text string for display in the LDB label.
-- So, we create a custom object to hold icon information, and give it a method to create a text string to display that icon.
-- That text string can then be embedded in the LDB label to show the icon.

-- Create the object class
-- Adapted from http://lua-users.org/wiki/ObjectOrientationTutorial
local IconClass = {}
IconClass.__index = IconClass

setmetatable(IconClass, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})


-- Create the constructor
function IconClass.new(iconfile, IconFileX, IconFileY, StartX, EndX, StartY, EndY)
	local self = setmetatable({}, IconClass)

	-- The caller has to specify an iconfile before actually using the class, or the results will not be what is expected.
	self.IconFile = iconfile or ""	-- the game file that has the icon we want

	-- The initial values are sane defaults, but they should be updated for each icon.

	-- These settings control the display of the icon
	self.SizeOne = 0	-- SizeOne and SizeTwo jointly control the size of the icon. The logic is not intuitive.
	self.SizeTwo = nil	-- For more details on the SizeOne and SizeTwo parameters, see http://wowwiki.wikia.com/wiki/UI_escape_sequences#Textures
						-- For the purposes of our icons, they should always be 0 and nil (indicating a square sized to the height of the text).

	self.OffsetX = 0	-- This moves the image n pixels horizontally in the final display. For our icons, it's always 0.
	self.OffsetY = 0	-- This moves the image n pixels vertically in the final display. For our icons, it's always 0.

	-- These settings control the extraction of the icon from a bigger texture file
	self.IconFileX = IconFileX or 0	-- the total X (horizontal) pixels in the image file - not just the icon we want
	self.IconFileY = IconFileY or 0	-- the total Y (vertical) pixels in the image file
	self.StartX = StartX or 0		-- The starting point in the file where the icon begins, counted from the left border, in pixels
	self.EndX = EndX or 0			-- The ending point in the file where the icon ends, counted from the left border, in pixels
	self.StartY = StartY or 0		-- The starting point in the file where the icon begins, counted from the top border, in pixels
	self.EndY = EndY or 0			-- The ending point in the file where the icon ends, counted from the top border, in pixels

	return self
end -- IconClass.new()


function IconClass:GetIconStringInner()
	-- Icon strings effectively have to be built right to left, since if the rightmost parameters are required, then the ones to the left are also required.

	-- This function constructs the inner part of the icon string, without the control codes to cause it to display as an actual icon.
	-- This is mostly useful for debugging. In actual use, you'd want the GetIconString() function.

	local required = false -- tells us whether the remaining parameters are required

	local OutputString = "";

	if required or self.StartX > 0 or self.StartY > 0 or self.EndX > 0 or self.EndY > 0 then
		required = true
		OutputString = string.format(":%d:%d:%d:%d", self.StartX, self.EndX, self.StartY, self.EndY)
	end

	if required or self.IconFileX > 0 or self.IconFileY > 0 then
		required = true
		OutputString = string.format(":%d:%d%s", self.IconFileX, self.IconFileY, OutputString)
	end

	if required or self.OffsetX > 0 or self.OffsetY > 0 then
		required = true
		OutputString = string.format(":%d:%d%s", self.OffsetX, self.OffsetY, OutputString)
	end

	-- Size2 can be nil, so to avoid comparing or concatenating a nil, we have some special handling
	local localsizetwo = self.SizeTwo or ""
	if required or (self.SizeTwo and self.SizeTwo >= 0) then
		OutputString = string.format(":%s%s", localsizetwo, OutputString)
	end

	-- Size1 and the icon path are required.
	OutputString = string.format("%s:%d%s", self.IconFile, self.SizeOne, OutputString)

	return OutputString
end -- IconClass:GetIconStringInner()


function IconClass:GetIconString()
	-- This function wraps the icon string in the control code that causes it to display as an icon
	return string.format("\124T%s\124t", self:GetIconStringInner())
end -- IconClass:GetIconString()


-- @TODO: Add method to get the TexCoords of an icon for inclusion in the LDB object's iconCoords parameter.
-- See:
--	https://wow.gamepedia.com/API_Texture_SetTexCoord
--	https://github.com/tekkub/libdatabroker-1-1/wiki/Data-Specifications


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

-- Icons I considered but didn't like
--BRM.AllianceIcon = "Interface\\Icons\\Inv_misc_head_human_02"
--BRM.HordeIcon = "Interface\\Icons\\Achievement_femalegoblinhead"
--BRM.HealerIcon = "Interface\\Icons\\Spell_holy_flashheal.blp"
--BRM.AllianceIcon = IconClass("Interface\\Icons\\Inv_tabard_a_78wrynnvanguard")
--BRM.HordeIcon = IconClass("Interface\\Icons\\Inv_tabard_a_77voljinsspear")
--BRM.TankIcon = IconClass("Interface\\Icons\\Inv_shield_06.blp")
--BRM.HealerIcon = IconClass("Interface\\Icons\\spell_chargepositive.blp")
--BRM.DPSIcon = IconClass("Interface\\Icons\\Inv_sword_27.blp")
--BRM.UnknownIcon = IconClass("Interface\\Icons\\Inv_misc_questionmark.blp")

-- These high res icons don't look very good when squished down to a broker display. The low-res ones above are better.
--BRM.TankIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-ROLES.blp", 256, 256, 0, 0+64, 68, 68+64)
--BRM.HealerIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-ROLES.blp", 256, 256, 68, 68+64, 0, 0+64)
--BRM.DPSIcon = IconClass("Interface\\LFGFRAME\\UI-LFG-ICON-ROLES.blp", 256, 256, 68, 68+64, 68, 68+64)


--#########################################
--# Constants
--#########################################

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


--@alpha@
--#########################################
--# Slash command handling - only for testing
--#########################################

SLASH_BRM1 = "/brm"
SlashCmdList.BRM = function (...) BRM:HandleCommandLine(...) end

function BRM:HandleCommandLine()
	BRM.DebugMode = not BRM.DebugMode
	BRM:ChatPrint("Printing debug statements is now " .. (BRM.DebugMode and "on" or "off") .. ".")
end
--@end-alpha@


--#########################################
--# Variables for tracking raid members
--#########################################

BRM.TankCount = 0
BRM.HealerCount = 0
BRM.DPSCount = 0
BRM.UnknownCount = 0
BRM.TotalCount = 0

-- The game is firing the ACTIVE_TALENT_GROUP_CHANGED event before the PLAYER_ENTERING_WORLD event.
-- Since we're not fully in the world yet at that point, the group and raid query functions are returning unexpected results.
-- So, we use this variable to track whether the add-on is loaded and active.
-- We turn it on in the PLAYER_ENTERING_WORLD event.
BRM.IsActive = false

--#########################################
--# Create string for count display
--#########################################

function BRM:GetDisplayString()
	local OutputString = string.format("%d %s %d %s %d %s %d", BRM.TotalCount, BRM.TankIcon:GetIconString(), BRM.TankCount, BRM.HealerIcon:GetIconString(), BRM.HealerCount, BRM.DPSIcon:GetIconString(), BRM.DPSCount)
	if BRM.UnknownCount > 0 then
		OutputString = string.format("%s %s %d", OutputString, BRM.UnknownIcon:GetIconString(), BRM.UnknownCount)
	end
	return OutputString
end -- BRM:GetDisplayString()


function BRM:IncrementRole(role)
	-- Handle case of nil roles - can happen when the game has not fully loaded and we try to do a role check
	if not role then role = "unknown" end

	if BRM.ROLE_HEALER == role then
		BRM.HealerCount = BRM.HealerCount + 1
	elseif BRM.ROLE_TANK == role then
		BRM.TankCount = BRM.TankCount + 1
	elseif BRM.ROLE_DPS == role then
		BRM.DPSCount = BRM.DPSCount + 1
	else
		BRM.UnknownCount = BRM.UnknownCount + 1
	end

	BRM.TotalCount = BRM.TotalCount + 1
end


function BRM:UpdateComposition()
	BRM:DebugPrint("in BRM:UpdateComposition")

	-- If the addon is not yet active, then just exit
	if not BRM.IsActive then
		BRM:DebugPrint("Addon is not active. Exiting without updating.")
		return
	end

	-- Zero out the counts so we can start fresh
	BRM.TankCount = 0
	BRM.HealerCount = 0
	BRM.DPSCount = 0
	BRM.UnknownCount = 0
	BRM.TotalCount = 0

	-- Figure out how many members in our group. Ungrouped returns zero.
	local members = GetNumGroupMembers()
	BRM:DebugPrint("members is " .. members)

	-- Variable for holding the role of each member we check, and a random iterator
	local Role, i

	if members and members > 0 then
		BRM:DebugPrint("I am in some kind of Group.")

		local CheckWord = IsInRaid() and "raid" or "party" -- this probably isn't localized in the game.
		BRM:DebugPrint("CheckWord is " .. CheckWord)

		-- OK, this is bloody screwy.
		-- If I'm in a party, then the addon has to check player and party1 to party4.
		-- But if I'm in a raid, the addon has to check raid1 to raid40, with no need to check player!

		if "raid" == CheckWord then
			-- Raid - iterate and count by role
			for i=1,members do
				Role = UnitGroupRolesAssigned(CheckWord .. i)
				if Role then
					BRM:DebugPrint("Group member " .. CheckWord .. i .. " has role " .. Role)
					BRM:IncrementRole(Role)
				else
					BRM:DebugPrint("Group member " .. CheckWord .. i .. " has no role")
					BRM:IncrementRole("unknown")
				end
			end -- for raid members
		else
			-- Party - iterate and count by role
			for i = 1, members - 1 do
				Role = UnitGroupRolesAssigned(CheckWord .. i)
				if Role then
					BRM:DebugPrint("Group member " .. CheckWord .. i .. " has role " .. Role)
					BRM:IncrementRole(Role)
				else
					BRM:DebugPrint("Group member " .. CheckWord .. i .. " has no role")
					BRM:IncrementRole("unknown")
				end
			end -- for party members

			-- Now repeat all that for the player.
			Role = UnitGroupRolesAssigned("player")
			if Role then
				BRM:DebugPrint("player has role " .. Role)
				BRM:IncrementRole(Role)
			else
				BRM:DebugPrint("player has no role")
				BRM:IncrementRole("unknown")
			end
		end -- if raid/party
	else
		BRM:DebugPrint("I am not in any kind of Group.")

		-- When not grouped, there is no role to check. So instead, we go off the player's specialization.

		-- get player role
		Role = select(5, GetSpecializationInfo(GetSpecialization()))
		-- GetSpecializationInfo returns: id, name, description, icon, background, role.

		if Role then
			BRM:DebugPrint("My role is " .. Role)
			BRM:IncrementRole(Role)
		else
			BRM:DebugPrint("Did not get role from specialization check")
			BRM:IncrementRole("unknown")
		end
	end

	BRM:DebugPrint("At end of role check, tanks = " .. BRM.TankCount .. ", healers = " .. BRM.HealerCount .. ", dps = " .. BRM.DPSCount .. ", other = " .. BRM.UnknownCount)

	BRM.LDO.text = BRM:GetDisplayString()
end -- BRM:UpdateComposition()


--#########################################
--# Actual LibDataBroker object
--#########################################

BRM.LDO = _G.LibStub("LibDataBroker-1.1"):NewDataObject("Broker_RaidMakeup", {
	type = "data source",
	text = BRM:GetDisplayString(),
	value = "0",
	icon = BRM.MainIcon:GetIconString(),
	label = "Broker_RaidMakeup",
	OnTooltipShow = function(tooltip)
		if not tooltip or not tooltip.AddLine then return end
		tooltip:AddLine("Broker_RaidMakeup")
		tooltip:AddLine("Click to refresh")
	end,
}) -- BRM.LDO creation


-- Handler for if user clicks on the display
function BRM.LDO:OnClick(button)
	BRM:DebugPrint("Got click on LDB object")

	if button == "LeftButton" then
		BRM:DebugPrint("Got left button")
	elseif button == "RightButton" then
		BRM:DebugPrint("Got right button")
	else
		BRM:DebugPrint("Got some other button")
	end

	-- I'm trying to capture which situations don't result in an automatic update.
	-- That essentially indicates either an event I missed coding for, or some kind of bug that resulted in invalid role counts.
	local old_TankCount = BRM.TankCount
	local old_HealerCount = BRM.HealerCount
	local old_DPSCount = BRM.DPSCount
	local old_UnknownCount = BRM.UnknownCount
	local old_TotalCount = BRM.TotalCount

	-- Refresh the counts
	BRM:UpdateComposition()

	-- Check if the counts changed, indicating the error above.
	if old_TankCount ~= BRM.TankCount
		or old_HealerCount ~= BRM.HealerCount
		or old_DPSCount ~= BRM.DPSCount
		or old_UnknownCount ~= BRM.UnknownCount
		or old_TotalCount ~= BRM.TotalCount
		then
			BRM:DebugPrint("Counts are different after click.")
			BRM:DebugPrint("old_TankCount is "		.. (old_TankCount		or "nil") .. ", new TankCount is "		.. (BRM.TankCount		or "nil"))
			BRM:DebugPrint("old_HealerCount is "	.. (old_HealerCount		or "nil") .. ", new DPSCount is "		.. (BRM.DPSCount		or "nil"))
			BRM:DebugPrint("old_DPSCount is "		.. (old_DPSCount		or "nil") .. ", new DPSCount is "		.. (BRM.DPSCount		or "nil"))
			BRM:DebugPrint("old_UnknownCount is "	.. (old_UnknownCount	or "nil") .. ", new UnknownCount is "	.. (BRM.UnknownCount	or "nil"))
			BRM:DebugPrint("old_TotalCount is "		.. (old_TotalCount		or "nil") .. ", new TotalCount is "		.. (BRM.TotalCount		or "nil"))

			-- @TODO: Capture some info and give the player a way to report it.

			-- Also schedule an update in five seconds to ensure we capture any additional changes
			C_Timer.After(5, function() BRM:UpdateComposition() end)
	end

end -- BRM.LDO:OnClick()



--#########################################
--# Events to register and handle
--#########################################

-- This event is only for debugging.
-- Note that PLAYER_LOGIN is triggered after all ADDON_LOADED events
function BRM.Events:PLAYER_LOGIN(...)
	BRM:DebugPrint("Got PLAYER_LOGIN event")
end -- BRM.Events:PLAYER_LOGIN()


-- This event is for loading our saved settings.
function BRM.Events:ADDON_LOADED(addon)
	BRM:DebugPrint("Got ADDON_LOADED for " .. addon)
	if addon ~= "Broker_RaidMakeup" then return end


	--#########################################
	--# Load saved settings
	--#########################################

	BRM:DebugPrint("Loading or creating DB")
	if BRM_DB then
		-- Load the settings saved by the game.
		BRM:DebugPrint ("Restoring existing BRM DB")
		BRM.DB = BRM_DB

		-- This situation should only occur during development, but just in case, let's handle it.
		if not BRM.DB.MinimapSettings then BRM.DB.MinimapSettings = {} end
	else
		-- Initialize settings on first use
		BRM:DebugPrint ("Creating new BRM DB")
		BRM.DB = {}
		BRM.DB.Version = 1
		BRM.DB.MinimapSettings = {}
	end

	BRM:DebugPrint ("DB contents follow")
	BRM:DumpTable(BRM.DB)
	BRM:DebugPrint ("End DB contents")

	--#########################################
	--# Minimap button for LDB object
	--#########################################

	-- Creating the minimap icon requires somewhere to save the data.
	-- We don't load that until this event.
	-- So, this is the earliest point we can create the minimap icon.

	BRM.MinimapIcon = LibStub("LibDBIcon-1.0")
	BRM.MinimapIcon:Register("Broker_RaidMakeup", BRM.LDO, BRM.DB.MinimapSettings)
end -- BRM.Events:ADDON_LOADED()


-- This triggers when someone joins or leaves a group, or changes their spec or role in the group.
function BRM.Events:GROUP_ROSTER_UPDATE(...)
	BRM:DebugPrint("Got GROUP_ROSTER_UPDATE")
	BRM:UpdateComposition()
end -- BRM.Events:GROUP_ROSTER_UPDATE()


-- This triggers when the player changes their talent spec.
function BRM.Events:ACTIVE_TALENT_GROUP_CHANGED(...)
	BRM:DebugPrint("Got ACTIVE_TALENT_GROUP_CHANGED")
	BRM:UpdateComposition()
end -- BRM.Events:ACTIVE_TALENT_GROUP_CHANGED()


-- On-load handler for addon initialization.
function BRM.Events:PLAYER_ENTERING_WORLD(...)
	-- Announce our load.
	BRM:DebugPrint("Got PLAYER_ENTERING_WORLD")

	-- It's now safe to turn on the addon and get counts.
	BRM.IsActive = true
	BRM:UpdateComposition()

	-- Get the main app icon based on the player's faction
	BRM.Faction, _ = UnitFactionGroup("player")

	if not BRM.Faction then
		BRM:DebugPrint("Faction is nil")
		return
	end

	if BRM.FACTION_HORDE == BRM.Faction then
		BRM:DebugPrint("Faction is Horde")
		BRM:DebugPrint("Inner string is " .. BRM.HordeIcon:GetIconStringInner())
		BRM.LDO.icon = BRM.HordeIcon.IconFile
	elseif BRM.FACTION_ALLIANCE == BRM.Faction then
		BRM:DebugPrint("Faction is Alliance")
		BRM:DebugPrint("Inner string is " .. BRM.AllianceIcon:GetIconStringInner())
		BRM.LDO.icon = BRM.AllianceIcon.IconFile
	else
		-- What the hell?
		BRM:DebugPrint("Unknown faction detected - " .. BRM.Faction)
	end

end -- BRM.Events:PLAYER_ENTERING_WORLD()


-- Save the db on logout.
function BRM.Events:PLAYER_LOGOUT(...)
	BRM:DebugPrint ("In PLAYER_LOGOUT, saving DB.")
	BRM_DB = BRM.DB
end -- BRM.Events:PLAYER_LOGOUT()


--#########################################
--# Implement the event handlers
--#########################################

-- Create the event handler function.
BRM.Frame:SetScript("OnEvent", function(self, event, ...)
	BRM.Events[event](self, ...) -- call one of the functions above
end)

-- Register all events for which handlers have been defined
for k, v in pairs(BRM.Events) do
	BRM:DebugPrint("Registering event ", k)
	BRM.Frame:RegisterEvent(k)
end
