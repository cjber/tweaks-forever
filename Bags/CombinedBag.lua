---@type string, TFNamespace
local _, ns = ...

-- The combined bag's layout after Blizzard's own: one pass, owned here, with two parts behind it. The reagent bag's
-- rows go along the bottom (Reagents.lua) and grouped gear gathers under headings at the top (Sections.lua).
---@class TFCombinedBag
local Model = {}
ns.CombinedBag = Model

-- The grid both parts place on, so they line up. ContainerFrameItemButtonTemplate is 37 square with 5 between
-- buttons; the grid starts 4 above the money frame (ContainerFrameCombinedBagsMixin:GetInitialItemAnchor).
Model.ITEM, Model.STEP, Model.ORIGIN_Y = 37, 42, 4
-- Between the reagent rows, the rest of the bag and the sections.
Model.GAP = 6
-- The smallest scale Blizzard shrinks bags to so they fit on screen (CONTAINER_SCALE in ContainerFrame.lua).
Model.MIN_SCALE = 0.75

---@type ContainerFrameCombinedBags
local bag
-- The bag's height and scale as Blizzard last set them, and the height this addon then gave it.
local base, scale, grown
-- Whether the bag is laid out differently from Blizzard's grid now, so switching both features off undoes it once.
local changed = false

-- Blizzard chose the bags' scale for the bag's own height. Shrink it, never below Blizzard's smallest, so a taller bag
-- stays on screen, with its corner where Blizzard anchored it.
---@param height number
local function Fit(height)
	local want = math.max(Model.MIN_SCALE, math.min(scale, (GetScreenHeight() - CONTAINER_OFFSET_Y) / height))
	local now = bag:GetScale()
	if want ~= now then
		local point, relative, relativePoint, x, y = bag:GetPoint()
		bag:SetScale(want)
		bag:SetPoint(point, relative, relativePoint, x * now / want, y * now / want)
	end
end

-- Lays the whole combined bag out again (points, height, scale, corner cropping): after Blizzard's own
-- layout, which always ends in UpdateContainerFrameAnchors, and whenever its contents or these settings change.
-- Never by calling Blizzard's UpdateFrameSize, UpdateItemLayout or UpdateContainerFrameAnchors: run from addon code
-- they build the bags' cached item and open-bag lists tainted, and Blizzard's bank code is then blocked.
-- The order is the contract between the parts: the reagent bag first says how far its rows lift the rest (from
-- Blizzard's height, not one this addon gave), the items and sections then go above that lift and say how tall the
-- bag is, and only once the bag has that height and scale do the reagent rows and their window go on it.
local function Layout()
	if not bag:IsShown() then
		return
	end
	-- The engine hands a height back a little off what it was given (481 as 481.00003), so the bag counts as grown
	-- by this addon when it is within a pixel of that; only a height Blizzard set is a new base.
	local height = bag:GetHeight()
	if not grown or math.abs(height - grown) > 0.5 then
		base = height
	end
	scale = scale or bag:GetScale()
	local columns = bag:GetColumns()
	local lift = ns.Reagents.Reserve(base, columns)
	if lift == 0 and not ns.Sections.Active() and not changed then
		return
	end
	local total = ns.Sections.Arrange(base + lift, lift, columns)
	grown, changed = total, total ~= base
	bag:SetHeight(total)
	NineSliceUtil.UpdateCornerCropping(bag, total)
	Fit(total)
	ns.Reagents.Placed(lift, columns)
end

-- For a change this addon made (a setting, the gear marks, the reagent bag closing). While equipped weapons are
-- settling, the gear refresh that ends it lays the bag out, so the moved weapons do not show under another section
-- first. Blizzard's own layout is not held back: it has just put every button back on its grid.
function Model.Relayout()
	if not ns.Gear.Settling() then
		Layout()
	end
end

ns.Init(function()
	bag = ContainerFrameCombinedBags
	hooksecurefunc("UpdateContainerFrameAnchors", function()
		scale = bag:GetScale()
		Layout()
	end)
	ns.Gear.OnRefresh(Model.Relayout)
	ns.OnSettingChanged("gearSections", Model.Relayout)
end)
