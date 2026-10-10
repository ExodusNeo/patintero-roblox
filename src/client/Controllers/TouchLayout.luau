--!strict
--[[
    TouchLayout.luau
    Fixed spots for ContextActionService touch buttons so they never overlap each other or the
    jump button. Offsets are inside Roblox's ContextButtonFrame, where the jump button sits at
    about x 130..200, y 70..140. Call place(actionName) right after BindAction.
]]

local ContextActionService = game:GetService("ContextActionService")

local SPOTS: { [string]: UDim2 } = {
    SkillE = UDim2.fromOffset(145, 5),
    SkillQ = UDim2.fromOffset(85, 20),
    SwitchLine = UDim2.fromOffset(30, 5),
    Slide = UDim2.fromOffset(15, 60),
    Sprint = UDim2.fromOffset(70, 95),
    Tag = UDim2.fromOffset(15, 110),
}

-- The core script creates the button shortly after BindAction and gives it a default slot,
-- so wait for the button before moving it. Non-touch devices never get a button; give up after 5s.
local function place(actionName: string)
    local spot = SPOTS[actionName]
    if not spot then return end
    task.spawn(function()
        for _ = 1, 50 do
            if ContextActionService:GetButton(actionName) then
                ContextActionService:SetPosition(actionName, spot)
                return
            end
            task.wait(0.1)
        end
    end)
end

return table.freeze({ place = place })
