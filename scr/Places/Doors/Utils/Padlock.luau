local Toggles = shared.Toggles
local Options = shared.Options
local Script = shared.Script

function Script.Functions.GetPadlockCode(paper)
    if not paper or not paper:FindFirstChild("UI") then return "____" end
    local code = ""
    for _, x in pairs(paper.UI:GetChildren()) do
        if tonumber(x.Name) then
            for _, y in pairs(game.Players.LocalPlayer.PlayerGui.PermUI.Hints:GetChildren()) do
                if y.Name == "Icon" then
                    if y.ImageRectOffset == x.ImageRectOffset then
                        code = code .. y.TextLabel.Text
                    end
                end
            end
        end
        if #code == 5 then break end
    end
    while #code < 5 do code = code .. "_" end
    return code
end

function Script.Functions.SolvePadlock(code)
    if not code or not tonumber(code) then return end
    pcall(function()
        Script.RemotesFolder.PL:FireServer(code)
    end)
end
