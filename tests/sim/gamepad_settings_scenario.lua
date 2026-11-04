-- luacheck: read globals scenario ADDON
-- #168: with the gamepad interface on, backing out of Options > AddOns > Tweaks Forever was followed by a blocked
-- SetPreferredGamepadInteractTarget. The gamepad action bar makes that protected call after reading
-- InputBindingManager.bindingSetStack, and the settings write that stack as the panel shows and hides, as the cursor
-- lands on a row (OnSmartNavSelect pushes a dropdown's or slider's footer bindings) and as a dropdown's menu opens
-- and closes. A stack entry written while our code has tainted the call stays tainted until /reload.
--
-- A cursor move is one call: SmartNavigation:Navigate scrolls the list (HandleScroll), which builds the rows that
-- scroll into view, then selects the next row, running its enter script (FocusEnter, the row's tooltip) and then its
-- OnSmartNavSelect. This walks every Tweaks page that way, opens and closes the Tooltip style and gear mark dropdowns,
-- backs out with B and changes target, failing on any binding-stack write made under our taint.
local DROPDOWNS = { ["Tooltip style"] = true, ["Mark grouped gear with"] = true }

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
	sim:login()
	sim:setGamepad(true)
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
	sim:input(function()
		G.Settings.OpenToCategory(category:GetID())
	end)
	sim:advance(0.2)
	assert(G.SettingsPanel:IsShown(), "the settings panel is open")

	-- The cursor's target on a row: its checkbox or button when it has one, else the row itself.
	local function target(row)
		return row.Tooltip and row.Tooltip.smartNavigationProxyTarget or row
	end

	local opened = {}
	for _, sub in ipairs(category:GetSubcategories()) do
		local page = sub:GetName()
		-- Every settings page; Forever addons is a canvas of our own frame, not a list of rows.
		if G.SettingsPanel:GetLayout(sub):IsVerticalLayout() then
			sim:input(function()
				G.SettingsPanel:SelectCategory(sub)
			end)
			sim:advance(0.1)
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
				if DROPDOWNS[label] then
					-- A on the row opens its menu (the footer's binding); B closes it.
					sim:input(function()
						row.Control.Dropdown:OpenMenu()
					end)
					sim:advance(0.05)
					assert(row.Control.Dropdown:IsMenuOpen(), label .. " opens")
					opened[#opened + 1] = label
					sim:input(function()
						row.Control.Dropdown:CloseMenu()
					end)
					sim:advance(0.05)
				end
			end
		end
	end
	assert(#opened == 2, "both dropdowns opened: " .. table.concat(opened, ", "))

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
