-- luacheck: read globals scenario ADDON
-- #168: with the gamepad interface on, backing out of Options > AddOns > Tweaks Forever was followed by a blocked
-- SetPreferredGamepadInteractTarget. The gamepad action bar makes that protected call after reading
-- InputBindingManager.bindingSetStack, and the settings write that stack as the panel shows and hides, as the cursor
-- lands on a row (OnSmartNavSelect pushes a dropdown's or slider's footer bindings) and as a dropdown's menu opens
-- and closes. A stack entry written while our code has tainted the call stays tainted until /reload.
--
-- A cursor move is one call: SmartNavigation:Navigate scrolls the list (HandleScroll), which builds the rows that
-- scroll into view, then selects the next row, running its enter script (FocusEnter, the row's tooltip) and then its
-- OnSmartNavSelect. This walks every Tweaks page that way, steps each choice row with its slider footer's D-pad
-- bindings, backs out with B and changes target, failing on any binding-stack write made under our taint.
--
-- A on a dropdown row opens a menu, which the client does by running the footer binding's MouseDown/MouseUp; that
-- runs our settings code and then takes the gamepad focus in one call. The sim's generated MouseDown is a stub that
-- does not run the client's C intrinsic, and its Blizzard source opens a menu without hiding SmartNavigation (the
-- client's C click does), so the menu path cannot reproduce the binding-stack write here. A dropdown row is therefore
-- a failure of this scenario on its own: under the gamepad interface every choice row must be a slider, not a
-- dropdown.
--
-- #382: the Options navigation enters only the client's vertical pages, so the Forever addons page is registered as
-- the client's own rows with the gamepad interface on, and every page the cursor lands on must show its first target.
local CHOICES = {
	["Tooltip style"] = { key = "tooltipStyle", values = { "modern", "retail", "forever" } },
	["Mark grouped gear with"] = { key = "gearMark", values = { "strip", "border", "dots", "none" } },
	["Invite keyword"] = { key = "whisperInviteKeyword", values = { "inv", "invite", "group" } },
}

scenario("gamepad through the Tweaks settings leaves the binding stack to the game", function(sim)
	local G = sim.G
	local W = sim.widgets
	-- The client opens the panel itself: a C function that calls SettingsPanel:OpenToCategory.
	sim.impl["C_SettingsUtil.OpenSettingsPanel"] = function(categoryID, scrollTo)
		G.SettingsPanel:OpenToCategory(categoryID, scrollTo)
	end
	-- SmartNavigation runs the cursor target's enter and leave scripts through FocusEnter/FocusExit, native methods
	-- the sim leaves empty. The client runs them as the frame's OnEnter/OnLeave in the caller's execution. A dropdown
	-- or slider row is the cursor target itself, and its tooltip belongs to the hover region over its label (the
	-- row's Tooltip child, which proxies to the row): the cursor on the row shows that tooltip in the same call, the
	-- order the #168 notes describe, so a row tooltip that runs our code is caught here.
	local function hoverRegion(frame)
		local region = frame.Tooltip
		return region and region.smartNavigationProxyTarget == frame and region or nil
	end
	for _, methods in pairs(W.methods) do
		methods.FocusEnter = function(self)
			W.fire(self, "OnEnter", true)
			if hoverRegion(self) then
				W.fire(hoverRegion(self), "OnEnter", true)
			end
		end
		methods.FocusExit = function(self)
			W.fire(self, "OnLeave", false)
			if hoverRegion(self) then
				W.fire(hoverRegion(self), "OnLeave", false)
			end
		end
	end
	-- Natives the gamepad frame manager calls as a panel hides, which the sim does not define.
	G.SpellCanTargetItem = G.SpellCanTargetItem or function()
		return false
	end
	G.SpellStopTargeting = G.SpellStopTargeting or function() end
	-- The gamepad interface is on before the addon loads, as after a reload with it enabled: the settings register
	-- each choice as a slider instead of a dropdown. Invite from whispers starts on so its keyword row is live.
	sim:setGamepad(true)
	sim:login({ savedVariables = { TweaksForeverDB = { whisperInvite = true } } })
	assert(G.InputUtil.IsGamepadUIEnabled(), "the gamepad interface is on")

	-- Every write to the binding stack, and the taint it ran under.
	local IBM = G.GamepadSharedUtility.InputBindingManager
	local writes, tainted, stackTaint = 0, {}, nil
	for _, method in ipairs({ "AddBindingSet", "RemoveSet", "SetCoreBindingSet", "ClearBindings" }) do
		local original = IBM[method]
		IBM[method] = function(self, ...)
			writes = writes + 1
			local by = sim.taint.current
			if by then
				stackTaint = stackTaint or by
				local where = debug.traceback("", 2):match("^[^\n]*\n[^\n]*\n([^\n]*\n[^\n]*\n[^\n]*\n[^\n]*)") or ""
				tainted[#tainted + 1] = method .. " by " .. by .. "\n" .. where
			end
			return original(self, ...)
		end
	end

	local category
	for _, c in ipairs(G.SettingsPanel:GetAllCategories()) do
		if c:GetName() == "Tweaks Forever" then
			category = c
		end
	end
	assert(category, "Tweaks Forever is under Options > AddOns")
	-- The page opens through the addon's own opener, which asks the client's restricted function through its secure
	-- delegate (cjber/forever-core#333), so this path is walked too.
	local ns = sim.loader.addons[ADDON].ns
	assert(ns and ns.OpenSettingsPanel, "the shared settings opener is loaded")
	sim:input(function()
		ns.OpenSettingsPanel(category:GetID())
	end)
	sim:advance(0.2)
	assert(G.SettingsPanel:IsShown(), "the settings panel is open")

	-- The cursor's target on a row: its checkbox or button when it has one, else the row itself.
	local function target(row)
		return row.Tooltip and row.Tooltip.smartNavigationProxyTarget or row
	end

	-- The function a gamepad footer binds to key, as AddFunctionBinding stores it.
	local function FooterBinding(footer, key)
		for _, binding in pairs(footer.bindings.functions) do
			if binding.keys[1] == key then
				return binding
			end
		end
	end

	-- One D-pad press on a slider row: the footer's function binding steps the slider, as the client does.
	local function StepRight()
		local button = FooterBinding(G.SettingsSliderControlMixin.bindingGroup, G.GAMEPAD_DPAD_RIGHT)
		assert(button, "the slider footer binds D-pad right")
		sim:input(function()
			button.func(true)
		end)
		sim:input(function()
			button.func(false)
		end)
		sim:advance(0.05)
	end

	local stepped = {}
	for _, sub in ipairs(category:GetSubcategories()) do
		local page = sub:GetName()
		-- Every Tweaks page, the shared Forever addons one included, is the client's own rows with the gamepad UI on:
		-- the cursor cannot enter a canvas page (#382).
		assert(
			G.SettingsPanel:GetLayout(sub):IsVerticalLayout(),
			page .. " is a canvas page, which the gamepad cursor cannot enter (#382)"
		)
		sim:input(function()
			G.SettingsPanel:SelectCategory(sub)
		end)
		sim:advance(0.1)
		local first = G.SettingsPanel:GetFirstSmartNavFocusableSettingFrame()
		assert(first and first:IsVisible(), page .. ": the cursor's first target is hidden (#382)")
		local box = G.SettingsPanel:GetSettingsList().ScrollBox
		local count = box:GetDataProvider():GetSize()
		assert(count > 0, page .. " has rows")
		for index = 1, count do
			local row
			-- One D-pad press: scroll the next row into view, then select it.
			sim:input(function()
				box:ScrollToElementDataIndex(index, nil, nil, true)
				row = box:FindFrame(box:GetDataProvider():Find(index))
				G.SmartNavigation:SelectButton(target(row))
			end)
			sim:advance(0.05)
			assert(row, page .. ": row " .. index .. " has a frame")
			local label = row.Text and row.Text:GetText()
			local choice = CHOICES[label]
			assert(
				not (row.Control and row.Control.Dropdown),
				page .. ": " .. tostring(label) .. " is still a dropdown under the gamepad UI"
			)
			if choice then
				local before = G.TweaksForeverDB[choice.key]
				StepRight()
				local after = G.TweaksForeverDB[choice.key]
				local nextValue = choice.values[2]
				assert(
					after == nextValue,
					label .. ": D-pad right moved " .. tostring(before) .. " to " .. tostring(after)
				)
				stepped[#stepped + 1] = label
			end
		end
	end
	assert(#stepped == 3, "all three choices stepped: " .. table.concat(stepped, ", "))

	-- B out of the rows, then out of the panel.
	sim:input(function()
		G.SmartNavigation:AttemptClose()
	end)
	sim:input(function()
		G.SettingsPanel:Close()
	end)
	sim:advance(0.2)
	assert(not G.SettingsPanel:IsShown(), "the settings panel closed")

	-- A target change: the action bar reads the binding stack, then makes its protected call. A tainted entry taints
	-- that read, and the client blocks the call.
	sim:input(function()
		if stackTaint then
			sim.taint.set(stackTaint)
		end
		G.SetPreferredGamepadInteractTarget(nil)
	end)
	sim:advance(0.05)

	sim:expectNoErrors(ADDON)
	assert(writes > 0, "the walk reached the binding stack")
	assert(#tainted == 0, "binding stack written under our taint:\n" .. table.concat(tainted, "\n"))
end)
