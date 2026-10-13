---@type string, TFNamespace
local _, ns = ...

-- Escape closes one of our panels and every other key reaches the game, so a panel left open never takes movement
-- or action keys. SetPropagateKeyboardInput is blocked for addon code in combat, so propagation is left on and only
-- the Escape that closes a panel out of combat turns it off, for that key alone, and the next frame turns it back on.
-- In combat nothing is set: Escape still closes the panel (and reaches the game too), and a panel shown before its
-- propagation came back closes on its first key, so it never holds the keyboard through a fight.
---@param frame Frame
function ns.EscapeCloses(frame)
	local function Pass()
		if not InCombatLockdown() then
			frame:SetPropagateKeyboardInput(true)
		end
	end
	frame:SetScript("OnKeyDown", function(self, key)
		if InCombatLockdown() then
			if key == "ESCAPE" or not self:GetPropagateKeyboardInput() then
				self:Hide()
			end
		elseif key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			self:Hide()
			C_Timer.After(0, Pass)
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)
	frame:HookScript("OnShow", Pass)
	Pass()
	frame:EnableKeyboard(true)
end
