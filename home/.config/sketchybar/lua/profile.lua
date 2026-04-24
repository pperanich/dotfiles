local function read_profile()
	local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
	local f = io.open(state_home .. "/sketchybar/profile", "r")
	if not f then
		return "i3"
	end
	local p = f:read("*l")
	f:close()
	if p then
		p = p:match("^%s*(.-)%s*$")
	end
	if p == "pill" or p == "i3" then
		return p
	end
	return "i3"
end

return read_profile()
