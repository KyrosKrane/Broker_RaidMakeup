-- Broker_RaidMakeup.lua
-- Written by KyrosKrane Sylvanblade (kyros@kyros.info)
-- Copyright (c) 2018-2019 KyrosKrane Sylvanblade
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

-- Get the shared storage area for our namespace
local addonName, BRM = ...


--#########################################
--# Frame for event handling
--#########################################

-- Create the frame to hold our event catcher, and the list of events.
BRM.Frame, BRM.Events = CreateFrame("Frame"), {}


--#########################################
--# Constants
--#########################################

-- The strings that define the addon
BRM.ADDON_NAME = addonName -- the internal addon name for LibStub and other addons
BRM.USER_ADDON_NAME = "Broker_RaidMakeup" -- the name displayed to the user

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
--# Bail out on WoW Classic
--#########################################

-- Roles don't exist on WoW Classic, so if a user runs this on Classic, just give them an error message and exit at once.
-- for Classic: local IsClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
-- For retail: local IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
	BRM.Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	BRM.Frame:SetScript("OnEvent", function(self, event, ...)
		if "PLAYER_ENTERING_WORLD" == event then
			BRM.Frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
			DEFAULT_CHAT_FRAME:AddMessage("|cff0066ffBRM:|r " .. BRM.ADDON_NAME .. " will not run on Classic versions of WoW. It has been disabled. Please remove it from your Classic addon folders.")
		end
	end)
	return
end


--#########################################
--# Slash command options and settings
--#########################################

BRM.OptionsTable = {
	type = "group",
	args = {
		MinimapHeader = {
			name = "Minimap Options",
			type = "header",
			order = 100,
		},
		minimapicon = {
			name = "Show minimap icon",
			desc = "Show a minimap icon for " .. BRM.USER_ADDON_NAME,
			type = "toggle",
			set = function(info,val) BRM:SetMinimapButton(val) end,
			get = function(info) return (not BRM.DB.MinimapSettings.hide) end,
			descStyle = "inline",
			width = "full",
			order = 110,
		}, -- minimapicon
		TooltipHeader = {
			name = "Tooltip Options",
			type = "header",
			order = 200,
		},
		showheader = {
			name = "Show the addon name in tooltip",
			type = "toggle",
			set = function(info,val) BRM.DB.ShowHeaderInTooltip = val end,
			get = function(info) return BRM.DB.ShowHeaderInTooltip end,
			descStyle = "inline",
			width = "full",
			order = 210,
		},
		showcounts = {
			name = "Show the role counts in the tooltip as well as in the main display",
			type = "toggle",
			set = function(info,val) BRM.DB.ShowCountInTooltip = val end,
			get = function(info) return BRM.DB.ShowCountInTooltip end,
			descStyle = "inline",
			width = "full",
			order = 220,
		},
		showhelp = {
			name = "Show an explanation of what clicking and rightclicking does in the tooltip",
			type = "toggle",
			set = function(info,val) BRM.DB.ShowInstructionsInTooltip = val end,
			get = function(info) return BRM.DB.ShowInstructionsInTooltip end,
			descStyle = "inline",
			width = "full",
			order = 230,
		},
		explanation = {
			name = "Unchecking all three options disables the tooltip entirely.",
			type = "description",
			fontSize = "medium",
			order = 290,
		},
		debug = {
			name = "Enable debug output",
			desc = "Prints extensive debugging output about everything " .. BRM.USER_ADDON_NAME .. " does",
			type = "toggle",
			set = function(info,val) BRM:SetDebugMode(val) end,
			get = function(info) return BRM.DebugMode end,
			descStyle = "inline",
			width = "full",
			hidden = true,
		}, -- debug
	} -- args
} -- BRM.OptionsTable


-- Process the options and create the AceConfig options table
BRM.AceConfigReg = LibStub("AceConfigRegistry-3.0")
BRM.AceConfigReg:RegisterOptionsTable(BRM.ADDON_NAME, BRM.OptionsTable)

-- Create the slash command handler
BRM.AceConfigCmd = LibStub("AceConfigCmd-3.0")
BRM.AceConfigCmd:CreateChatCommand("brm", BRM.ADDON_NAME)

-- Create the frame to set the options and add it to the Blizzard settings
BRM.ConfigFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(BRM.ADDON_NAME, BRM.USER_ADDON_NAME)


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
--# Count display and utility functions
--#########################################

function BRM:GetDisplayString()
	local OutputString = string.format("%d %s %d %s %d %s %d", BRM.TotalCount, BRM.TankIcon:GetIconString(), BRM.TankCount, BRM.HealerIcon:GetIconString(), BRM.HealerCount, BRM.DPSIcon:GetIconString(), BRM.DPSCount)
	if BRM.UnknownCount > 0 then
		OutputString = string.format("%s %s %d", OutputString, BRM.UnknownIcon:GetIconString(), BRM.UnknownCount)
	end
	return OutputString
end -- BRM:GetDisplayString()


-- This function increments the count of a particular role. Abstracted out since we have the same logoc in a few different places
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
end -- BRM:IncrementRole()


-- This function does the actual counting of people in the group
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


-- This function handles refreshing the role counts and checking for count errors
function BRM:RefreshCounts()
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
end -- BRM:RefreshCounts()


--#########################################
--# Actual LibDataBroker object
--#########################################

BRM.LDO = LibStub("LibDataBroker-1.1"):NewDataObject(BRM.ADDON_NAME, {
	type = "data source",
	text = BRM:GetDisplayString(),
	value = "0",
	icon = BRM.MainIcon:GetIconString(),
	label = BRM.USER_ADDON_NAME,
	OnTooltipShow = function(tooltip)
		-- make sure we have a real tooltip
		if not tooltip or not tooltip.AddLine then
			BRM:DebugPrint("Got invalid tooltip, exiting OnTooltipShow")
			return
		end
		BRM:DebugPrint("Valid tooltip provided")

		-- Check if the user wants a tooltip
		if not BRM.DB.ShowHeaderInTooltip and not BRM.DB.ShowCountInTooltip and not BRM.DB.ShowInstructionsInTooltip then
			BRM:DebugPrint("User does not want a tooltip")
			return
		end
		BRM:DebugPrint("User wants a tooltip")

		-- delete existing lines
		tooltip:ClearLines()

		-- headline
		if BRM.DB.ShowHeaderInTooltip then
			BRM:DebugPrint("Adding header")
			tooltip:AddLine(BRM.USER_ADDON_NAME)
		end

		-- If the user wants the counts in the tooltip, add them.
		if BRM.DB.ShowCountInTooltip then
			BRM:DebugPrint("Preparing counts")

			local DisplayString = ""

			-- faction handling
			if BRM.FACTION_HORDE == BRM.Faction then
				DisplayString = BRM.HordeIcon:GetIconString()
			elseif BRM.FACTION_ALLIANCE == BRM.Faction then
				DisplayString = BRM.AllianceIcon:GetIconString()
			else
				-- What the hell?
				BRM:DebugPrint("Unknown faction detected - " .. BRM.Faction)
				DisplayString = BRM.MainIcon:GetIconString()
			end

			DisplayString = DisplayString .. BRM:GetDisplayString()

			tooltip:AddLine(DisplayString)
		end

		-- Add instructions
		if BRM.DB.ShowInstructionsInTooltip then
			BRM:DebugPrint("Adding help")
			tooltip:AddLine("Click to refresh")
			tooltip:AddLine("Right click for options")
		end
	end,
}) -- BRM.LDO creation


-- Handler for if user clicks on the display
function BRM.LDO:OnClick(button)
	BRM:DebugPrint("Got click on LDB object")

	if button == "LeftButton" then
		BRM:DebugPrint("Got left button")
		BRM:RefreshCounts()
	elseif button == "RightButton" then
		BRM:DebugPrint("Got right button")
		-- toggle showing the count
		InterfaceOptionsFrame_OpenToCategory(BRM.ConfigFrame)
		InterfaceOptionsFrame_OpenToCategory(BRM.ConfigFrame)
			-- Yes, this should be here twice. Workaround for a Blizzard bug.
			-- When you first open the options panel, it opens to the Game control tab, not the Addons control tab.
			-- Calling this twice bypasses that.
	else
		BRM:DebugPrint("Got some other button")
	end

end -- BRM.LDO:OnClick()


--#########################################
--# Minimap icon handling
--#########################################

function BRM:CreateMinimapButton()
	if not BRM.MinimapIcon then
		BRM:DebugPrint("Creating minimap icon")
		BRM.MinimapIcon = LibStub("LibDBIcon-1.0")
		BRM.MinimapIcon:Register(BRM.ADDON_NAME, BRM.LDO, BRM.DB.MinimapSettings)
	end
end -- BRM:CreateMinimapButton()


function BRM:ShowMinimapButton()
	BRM:DebugPrint("Showing minimap icon")
	BRM.DB.MinimapSettings.hide = false
	BRM.MinimapIcon:Show(BRM.ADDON_NAME)
end -- BRM:ShowMinimapButton()


function BRM:HideMinimapButton()
	BRM:DebugPrint("Hiding minimap icon")
	BRM.DB.MinimapSettings.hide = true
	BRM.MinimapIcon:Hide(BRM.ADDON_NAME)
end -- BRM:HideMinimapButton()

-- This function is for calling from the options panel. Pass in true to show the icon, false to hide it (which matches the values of the checkbox in the config panel)
function BRM:SetMinimapButton(state)
	if true == state then
		BRM:ShowMinimapButton()
	else
		BRM:HideMinimapButton()
	end
end -- BRM:SetMinimapButton()


--#########################################
--# Load saved settings
--#########################################

-- Get existing settings from the DB, or create default settings.
function BRM.LoadSettings()
	BRM:DebugPrint("Loading or creating DB")
	if BRM_DB then
		-- Load the settings saved by the game.
		BRM:DebugPrint ("Restoring existing BRM DB")
		BRM.DB = BRM_DB

		-- These situations should only occur during development or upgrade situations
		if not BRM.DB.MinimapSettings then
			BRM.DB.MinimapSettings = {}
			BRM.DB.MinimapSettings.hide = true
		end
		if not BRM.DB.ShowHeaderInTooltip			and BRM.DB.ShowHeaderInTooltip ~= false			then BRM.DB.ShowHeaderInTooltip = true end
		if not BRM.DB.ShowCountInTooltip			and BRM.DB.ShowCountInTooltip ~= false			then BRM.DB.ShowCountInTooltip = false end
		if not BRM.DB.ShowInstructionsInTooltip		and BRM.DB.ShowInstructionsInTooltip ~= false	then BRM.DB.ShowInstructionsInTooltip = true end
		if not BRM.DB.DebugMode																		then BRM.DB.DebugMode = false end
	else
		-- Initialize settings on first use
		BRM:DebugPrint ("Creating new BRM DB")
		BRM.DB = {}
		BRM.DB.Version = 1
		BRM.DB.MinimapSettings = {}
		BRM.DB.MinimapSettings.hide = true
		BRM.DB.ShowHeaderInTooltip = true
		BRM.DB.ShowCountInTooltip = false
		BRM.DB.ShowInstructionsInTooltip = true
		BRM.DB.DebugMode = false
	end

	-- Load the saved debug mode for use in the addon.
	BRM.DebugMode = BRM.DB.DebugMode

	BRM:DebugPrint ("DB contents follow")
	BRM:DumpTable(BRM.DB)
	BRM:DebugPrint ("End DB contents")

end -- BRM.LoadSettings()


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
	if addon ~= BRM.ADDON_NAME then return end

	-- Load saved settings
	BRM.LoadSettings()

	-- Minimap button for LDB object
	BRM:CreateMinimapButton()
		-- Creating the minimap icon requires somewhere to save the data - namely, the addon DB.
		-- We don't load that until this event.
		-- So, this is the earliest point we can create the minimap icon.
		-- Note that initial state of whether to display the icon is handled auto-magically by the LDBIcon library, based on the variable storage you pass it.

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
	BRM:DebugPrint("Activating " .. BRM.USER_ADDON_NAME)
	BRM.IsActive = true
	BRM:UpdateComposition()

	-- Get the main app icon based on the player's faction
	BRM:DebugPrint("Determining faction")
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
