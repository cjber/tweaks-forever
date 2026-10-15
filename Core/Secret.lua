---@type string, TFNamespace
local _, ns = ...

-- Secret values. The client can hand an addon a value it may hold but not read: a unit's GUID or name in some
-- combat and instance states. Keep this file free of other addon state so the pattern copies across the Forever
-- addons as is.

-- `value` when this code may read it, nil when the client keeps it secret (a unit's GUID or name in some combat
-- and instance states): comparing, indexing or even testing a secret raises. tools/lint_secret.py sends every
-- such read through here. A client without secret values (no canaccessvalue) reads everything.
---@generic T
---@param value T
---@return T?
function ns.Readable(value)
	if canaccessvalue and not canaccessvalue(value) then
		return nil
	end
	return value
end

-- Whether a tooltip may be read and drawn on: false for nil and for one the client marks forbidden (a secure
-- tooltip), which raises on any method call. Every tooltip hook checks it first (tools/lint_secret.py).
---@param frame? Frame
---@return boolean
function ns.Usable(frame)
	if not frame then
		return false
	end
	return not (frame.IsForbidden and frame:IsForbidden())
end
