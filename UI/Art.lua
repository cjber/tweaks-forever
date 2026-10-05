---@type string, TFNamespace
local _, ns = ...

-- Art at its native aspect (AGENTS.md: never stretch art): an atlas takes its shape from C_Texture.GetAtlasInfo,
-- as a texture fitted inside its box or as markup in a line of text.

---@class TFArt
local Art = {}
ns.Art = Art

-- The atlas's width over its height; square when the client doesn't know it.
---@param atlas string
---@return number
local function Aspect(atlas)
	local info = C_Texture.GetAtlasInfo(atlas)
	if info and info.width > 0 and info.height > 0 then
		return info.width / info.height
	end
	return 1
end

-- `atlas` at the largest size inside `width` by `height` at its own aspect. The caller anchors it by one point.
---@param texture Texture
---@param atlas string
---@param width number
---@param height number
---@return number width
---@return number height
function Art.Fit(texture, atlas, width, height)
	texture:SetAtlas(atlas)
	local aspect = Aspect(atlas)
	local w, h = width, width / aspect
	if h > height then
		w, h = height * aspect, height
	end
	texture:SetSize(w, h)
	return w, h
end

-- `|A:atlas:height:width|a` with the width from the atlas's aspect.
---@param atlas string
---@param height number
---@return string
function Art.Markup(atlas, height)
	return ("|A:%s:%d:%d|a"):format(atlas, height, math.floor(height * Aspect(atlas) + 0.5))
end
