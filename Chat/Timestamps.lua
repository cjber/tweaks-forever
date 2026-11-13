---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "chatTimestamps"

-- Timestamps are the client's own setting (Settings > Social > Chat Timestamps, the showTimestamps value
-- ChatFrameUtil.GetTimestampFormat reads). Mirroring a format choice here would be a second settings store that can
-- disagree with the game's own, so the Chat page opens that setting instead.
ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Chat timestamps",
	tooltip = "Opens the game's own Chat Timestamps setting, where you pick the format or turn it off. Tweaks "
		.. "Forever does not change timestamps itself.",
	default = false,
	buttonOnly = true,
	buttonText = "Open",
	button = function()
		local id = Settings and Settings.SOCIAL_CATEGORY_ID
		if ForeverCore and ForeverCore.OpenSettingsPanel then
			if id then
				ForeverCore.OpenSettingsPanel(id, TIMESTAMPS_LABEL)
			else
				ForeverCore.OpenSettingsPanel()
			end
		end
	end,
})
