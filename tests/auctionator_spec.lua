local function noop() end
local function frame()
	return setmetatable({ shown = false, hooks = {} }, {
		__index = {
			Show = function(self)
				if not self.shown then
					self.shown = true
					for _, fn in ipairs(self.hooks) do
						fn(self)
					end
				end
			end,
			Hide = function(self)
				self.shown = false
			end,
			HookScript = function(self, event, fn)
				assert(event == "OnShow")
				self.hooks[#self.hooks + 1] = fn
			end,
			SetScript = noop,
			SetText = noop,
			SetPoint = noop,
			SetSize = noop,
			SetHitRectInsets = noop,
			IsObjectType = function()
				return true
			end,
		},
	})
end
strmatch = string.match
assert(loadfile("LibAHTab/LibStub/LibStub.lua"))()
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
CreateFrame = frame
PanelTemplates_DeselectTab = function(tab)
	tab.selected = false
end
PanelTemplates_SelectTab = function(tab)
	tab.selected = true
end
PanelTemplates_TabResize = noop
hooksecurefunc = function()
	error("must not hook native methods")
end
AuctionHouseFrameDisplayMode = { Buy = { "Buy" }, ItemSell = { "Sell" }, CommoditiesSell = { "Commodities" } }
AuctionHouseFrame = { Tabs = { frame() }, Buy = frame(), Sell = frame(), Commodities = frame(), SetTitle = noop }
local native = function(self, mode)
	for _, name in ipairs({ "Buy", "Sell", "Commodities" }) do
		self[name]:Hide()
	end
	for _, name in ipairs(mode) do
		self[name]:Show()
	end
end
AuctionHouseFrame.SetDisplayMode = native
assert(loadfile("LibAHTab/LibAHTab.lua"))()
local lib = LibStub:GetLibrary("LibAHTab-1-0")
local custom = frame()
lib:CreateTab("addon", custom, "Addon")
for _, mode in pairs(AuctionHouseFrameDisplayMode) do
	lib:SetSelected("addon")
	assert(custom.shown and lib:GetButton("addon").selected)
	AuctionHouseFrame:SetDisplayMode(mode)
	assert(not custom.shown and not lib:GetButton("addon").selected)
	assert(AuctionHouseFrame.SetDisplayMode == native)
end
local create = lib.CreateTab
assert(LibStub:NewLibrary("LibAHTab-1-0", 4) == nil, "embedded revision cannot overwrite compatibility copy")
assert(loadfile("LibAHTab/LibAHTab.lua"))()
assert(lib.CreateTab == create, "reload preserves initialized library")
local upgraded = LibStub:NewLibrary("LibAHTab-1-0", 5)
local future = function() end
upgraded.CreateTab = future
assert(loadfile("LibAHTab/LibAHTab.lua"))()
assert(upgraded.CreateTab == future, "newer upstream revision wins")
print("Auctionator: native method preserved; all native panels hide and deselect addon tabs")
