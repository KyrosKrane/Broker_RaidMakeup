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
	if (BRM.DebugMode) then
		print ("|cff" .. "a00000" .. "BRM Debug:|r", ...)
	end
end -- BRM:DebugPrint


-- Print regular output to the chat frame.
function BRM:ChatPrint(...)
	print ("|cff" .. "0066ff" .. "BRM:|r", ...)
end -- BRM:DebugPrint


--#########################################
--# Constants
--#########################################

-- Get the main app icon based on the player's faction
BRM.Faction, _ = UnitFactionGroup("player")

-- The icons to use when displaying in the broker display
BRM.MainIcon = "Interface\\Icons\\Inv_helm_robe_raidpriest_k_01" -- Default icon to use until we determine the faction later.
BRM.AllianceIcon = "Interface\\Icons\\Inv_tabard_a_78wrynnvanguard"
BRM.HordeIcon = "Interface\\Icons\\Inv_tabard_a_77voljinsspear"
BRM.TankIcon = "Interface\\Icons\\Inv_shield_06.blp"
BRM.HealerIcon = "Interface\\Icons\\spell_chargepositive.blp"
BRM.DPSIcon = "Interface\\Icons\\Inv_sword_27.blp"
BRM.UnknownIcon = "Interface\\Icons\\Inv_misc_questionmark.blp"

-- Icons I considered but didn't like
--BRM.AllianceIcon = "Interface\\Icons\\Inv_misc_head_human_02"
--BRM.HordeIcon = "Interface\\Icons\\Achievement_femalegoblinhead"
--BRM.HealerIcon = "Interface\\Icons\\Spell_holy_flashheal.blp"

-- The strings used by the game to represent the roles. I don't think these are localized in the game.
BRM.ROLE_HEALER = "HEALER"
BRM.ROLE_TANK = "TANK"
BRM.ROLE_DPS = "DAMAGER"
BRM.ROLE_NONE = "NONE"

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
	BRM:ChatPrint("Printing debug statements is now " .. BRM.DebugMode and "on." or "off.")
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

-- The game is firing the ACTIVE_TALENT_GROUP_CHANGED event before the PLAYER_LOGIN event.
-- Since we're not fully in the world yet at that point, the group and raid query functions are returning unexpected results.
-- So, we use this variable to track whether the add-on is loaded and active.
-- We turn it on in the PLAYER_LOGIN event.
BRM.IsActive = false

--#########################################
--# Create string for count display
--#########################################

function BRM:IconString(icon)
	local size = 16
	return string.format("\124T" .. icon .. ":%d:%d\124t", size, size)
end -- BRM:IconString(icon)


function BRM:GetDisplayString()
	local OutputString = string.format("%d %s %d %s %d %s %d", BRM.TotalCount, BRM:IconString(BRM.TankIcon), BRM.TankCount, BRM:IconString(BRM.HealerIcon), BRM.HealerCount, BRM:IconString(BRM.DPSIcon), BRM.DPSCount)
	if BRM.UnknownCount > 0 then
		OutputString = string.format("%s %s %d", OutputString, BRM:IconString(BRM.UnknownIcon), BRM.UnknownCount)
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
	icon = BRM.MainIcon,
	label = "Broker_RaidMakeup",
	OnTooltipShow = function()end,
}) -- BRM.LDO creation


-- Handler for if user clicks on the display
function BRM.LDO:OnClick(...)
	BRM:DebugPrint("Got click on LDB object")

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

-- This event is only for debugging.
function BRM.Events:ADDON_LOADED(addon)
	BRM:DebugPrint("Got ADDON_LOADED for " .. addon)
	if addon == "Broker_RaidMakeup" then
		BRM:DebugPrint("Now processing stuff for this addon")
	end -- if Broker_RaidMakeup
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

	if "Horde" == BRM.Faction then
		BRM:DebugPrint("Faction is Horde")
		BRM.LDO.icon = BRM.HordeIcon
	elseif "Alliance" == BRM.Faction then
		BRM:DebugPrint("Faction is Alliance")
		BRM.LDO.icon = BRM.AllianceIcon
	else
		-- What the hell?
		BRM:DebugPrint("Unknown faction detected - " .. BRM.Faction)
	end

end -- BRM.Events:PLAYER_ENTERING_WORLD()


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
