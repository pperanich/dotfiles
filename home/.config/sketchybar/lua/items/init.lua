local profile = require("lua.profile")

if profile == "pill" then
	require("lua.items.aerospaces_pill")
	require("lua.items.time")
	require("lua.items.widgets")
	require("lua.items.media")
else
	-- i3 profile: workspaces only
	require("lua.items.aerospaces_i3")
end
