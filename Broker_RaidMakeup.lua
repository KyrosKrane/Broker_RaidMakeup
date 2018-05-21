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
--# Constants
--#########################################

local TankIcon = "Interface\\Icons\\Inv_shield_06.blp"
local HealerIcon = "Interface\\Icons\\Spell_holy_flashheal.blp"
local DPSIcon = "Interface\\Icons\\Inv_sword_110.blp"


--#########################################
--# Globals and utilities
--#########################################

-- Get a local reference to speed up execution.
local _G = _G
local string = string
local print = print

-- Define a global for our namespace
local BRM = { }

-- Debug settings
BRM.DebugMode = true

-- Print debug output to the chat frame.
function BRM:DebugPrint(...)
	if (BRM.DebugMode) then
		print ("|cff" .. "a00000" .. "BRM Debug:|r", ...)
	end
end -- BRM:DebugPrint


--#########################################
--# Frame for event handling
--#########################################

-- Create the frame to hold our event catcher, and the list of events.
BRM.Frame, BRM.Events = CreateFrame("Frame"), {}


--#########################################
--# Variables for tracking raid members
--#########################################

BRM.TankCount = 1
BRM.HealerCount = 2
BRM.DPSCount = 3


--#########################################
--# Create string for count display
--#########################################

function BRM:IconString(icon)
	local size = 16
	return string.format("\124T" .. icon .. ":%d:%d\124t", size, size)
end -- BRM:IconString(icon)


function BRM:GetDisplayString()
	return string.format("%s %d %s %d %s %d", BRM:IconString(TankIcon), BRM.TankCount, BRM:IconString(HealerIcon), BRM.HealerCount, BRM:IconString(DPSIcon), BRM.DPSCount)
end -- BRM:GetDisplayString()


function BRM:UpdateComposition()
	BRM:DebugPrint  ("in BRM:UpdateComposition")

	BRM.TankCount = 0
	BRM.HealerCount = 0
	BRM.DPSCount = 0

	-- if in group
		-- get count of group members
		-- iterate and count by role
	-- else
		-- get player role
	-- end

	-- Placeholder for testing
	BRM.TankCount = 2
	BRM.HealerCount = 4
	BRM.DPSCount = 6

	BRM.LDO.text = BRM:GetDisplayString()
end -- BRM:UpdateComposition()


--#########################################
--# Actual LibDataBroker object
--#########################################

BRM.LDO = _G.LibStub("LibDataBroker-1.1"):NewDataObject("Broker_RaidMakeup", {
	type = "data source",
	--text = "BRM Initializing" .. HealerIcon,
	--text = string.format("%s \124T" .. HealerIcon .. ":%d:%d\124t", "my text here", size, size),
	text = BRM:GetDisplayString(),
	value = "0",
	icon = TankIcon,
	label = "Broker_RaidMakeup",
	OnTooltipShow = function()end,
}) -- BRM.LDO creation


--#########################################
--# Events to register and handle
--#########################################

-- On-load handler for addon initialization.
-- Note that PLAYER_LOGIN is triggered after all ADDON_LOADED events
function BRM.Events:PLAYER_LOGIN(...)
	-- Announce our load.
	BRM:DebugPrint ("Got PLAYER_LOGIN event")
	BRM:UpdateComposition()

end -- BRM.Events:PLAYER_LOGIN()


function BRM.Events:ADDON_LOADED(addon)
	BRM:DebugPrint ("Got ADDON_LOADED for " .. addon)
	if addon == "Broker_RaidMakeup" then
		BRM:DebugPrint ("Now processing stuff for this addon")
	end -- if Broker_RaidMakeup
end -- BRM.Events:PLAYER_LOGIN()


--#########################################
--# Implement the event handlers
--#########################################

-- Create the event handler function.
BRM.Frame:SetScript("OnEvent", function(self, event, ...)
	BRM.Events[event](self, ...) -- call one of the functions above
end)

-- Register all events for which handlers have been defined
for k, v in pairs(BRM.Events) do
	BRM:DebugPrint ("Registering event ", k)
	BRM.Frame:RegisterEvent(k)
end
