-- Run in Studio (execute_luau, Edit context) while `node tools/sync-receiver.js .` is running.
-- Posts every game script to the receiver, which writes it under src/. Briefly enables
-- HttpService.HttpEnabled and always restores the previous value.
local HttpService = game:GetService("HttpService")
local wasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local roots = {
	{ game.ReplicatedStorage:FindFirstChild("Shared"), "src/shared" },
	{ game.ServerScriptService:FindFirstChild("Server"), "src/server" },
	{ game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client"), "src/client" },
}
local suffix = { Script = ".server.luau", LocalScript = ".client.luau", ModuleScript = ".luau" }
local sent, failed = 0, {}
local ok, err = pcall(function()
	for _, pair in roots do
		local rootInst, dir = pair[1], pair[2]
		for _, inst in rootInst:GetDescendants() do
			if inst:IsA("LuaSourceContainer") then
				local parts = {}
				local node = inst
				while node ~= rootInst do
					table.insert(parts, 1, node.Name)
					node = node.Parent
				end
				local rel = dir .. "/" .. table.concat(parts, "/") .. suffix[inst.ClassName]
				local res = HttpService:RequestAsync({
					Url = "http://127.0.0.1:34873/write",
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = HttpService:JSONEncode({ path = rel, source = inst.Source }),
				})
				if res.Success then sent += 1 else table.insert(failed, rel .. ":" .. res.StatusCode) end
			end
		end
	end
	HttpService:RequestAsync({ Url = "http://127.0.0.1:34873/done", Method = "POST", Body = "" })
end)
HttpService.HttpEnabled = wasEnabled
return `ok={ok} err={err} sent={sent} failed={table.concat(failed, "; ")}`
