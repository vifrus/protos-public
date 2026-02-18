-- ============================================================
-- HUD — Heads-Up Display
-- Shows percentage claimed, lives, and game state messages
-- ============================================================

local HUD = {}
HUD.__index = HUD

function HUD.new()
    local self = setmetatable({}, HUD)
    self.font = love.graphics.newFont(18)
    self.bigFont = love.graphics.newFont(48)
    self.medFont = love.graphics.newFont(24)
    self.messageTimer = 0
    self.message = nil
    return self
end

function HUD:showMessage(msg, duration)
    self.message = msg
    self.messageTimer = duration or 2.0
end

function HUD:update(dt)
    if self.messageTimer > 0 then
        self.messageTimer = self.messageTimer - dt
        if self.messageTimer <= 0 then
            self.message = nil
        end
    end
end

function HUD:draw(percent, lives, gameState)
    local W = love.graphics.getWidth()

    -- Semi-transparent bar at top
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, W, 32)

    -- Percentage
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.3, 1, 0.5, 1)
    love.graphics.print(string.format("Territory: %.1f%%", percent), 10, 6)

    -- Lives (hearts)
    local heartX = W - 30
    for i = 1, 3 do
        if i <= lives then
            love.graphics.setColor(1, 0.3, 0.4, 1)
        else
            love.graphics.setColor(0.3, 0.15, 0.2, 0.5)
        end
        self:drawHeart(heartX, 16, 10)
        heartX = heartX - 28
    end

    -- Center message (temporary)
    if self.message then
        love.graphics.setFont(self.medFont)
        local textW = self.medFont:getWidth(self.message)
        local alpha = math.min(1, self.messageTimer * 2)

        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        love.graphics.rectangle("fill", W/2 - textW/2 - 20, 50, textW + 40, 40, 8, 8)

        love.graphics.setColor(1, 1, 0.5, alpha)
        love.graphics.print(self.message, W/2 - textW/2, 55)
    end

    -- Game state overlays
    if gameState == "win" then
        self:drawOverlay("¡GANASTE!", {0.2, 1, 0.4}, "Has reclamado el territorio")
    elseif gameState == "gameover" then
        self:drawOverlay("GAME OVER", {1, 0.3, 0.2}, "Presioná R para reiniciar")
    end
end

function HUD:drawOverlay(title, color, subtitle)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Title
    love.graphics.setFont(self.bigFont)
    local titleW = self.bigFont:getWidth(title)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.print(title, W/2 - titleW/2, H/2 - 50)

    -- Subtitle
    love.graphics.setFont(self.medFont)
    local subW = self.medFont:getWidth(subtitle)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print(subtitle, W/2 - subW/2, H/2 + 20)

    -- Restart hint
    local hint = "Presioná R para reiniciar"
    local hintW = self.medFont:getWidth(hint)
    love.graphics.setColor(0.6, 0.6, 0.6, 0.7 + math.sin(love.timer.getTime() * 3) * 0.3)
    love.graphics.print(hint, W/2 - hintW/2, H/2 + 60)
end

function HUD:drawHeart(cx, cy, size)
    -- Simple heart shape using circles and a triangle
    local r = size * 0.5
    love.graphics.circle("fill", cx - r * 0.5, cy - r * 0.3, r)
    love.graphics.circle("fill", cx + r * 0.5, cy - r * 0.3, r)
    love.graphics.polygon("fill",
        cx - size * 0.5, cy,
        cx + size * 0.5, cy,
        cx, cy + size * 0.7
    )
end

return HUD
