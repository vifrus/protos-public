-- ============================================================
-- Enemy — Bouncing enemies in unclaimed territory
-- ============================================================

local Grid = require("grid")

local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(grid, x, y, color)
    local self = setmetatable({}, Enemy)
    self.grid = grid
    self.x = x
    self.y = y
    self.radius = grid.cellSize * 1.5

    -- Random direction
    local angle = math.random() * math.pi * 2
    self.speed = 90 + math.random() * 50
    self.vx = math.cos(angle) * self.speed
    self.vy = math.sin(angle) * self.speed

    self.color = color or {1, 0.3, 0.5}
    self.pulseTimer = math.random() * math.pi * 2

    return self
end

function Enemy:update(dt)
    self.pulseTimer = self.pulseTimer + dt * 3

    local newX = self.x + self.vx * dt
    local newY = self.y + self.vy * dt

    local gx, gy = self.grid:pixelToGrid(newX, newY)
    local cell = self.grid:getCell(gx, gy)

    if cell == Grid.CLAIMED then
        -- Bounce: test each axis independently
        local gxH = self.grid:pixelToGrid(newX, self.y)
        local gyV = select(2, self.grid:pixelToGrid(self.x, newY))

        local hitH = (self.grid:getCell(gxH, select(2, self.grid:pixelToGrid(self.x, self.y))) == Grid.CLAIMED)
        local hitV = (self.grid:getCell(select(1, self.grid:pixelToGrid(self.x, self.y)), gyV) == Grid.CLAIMED)

        if hitH then self.vx = -self.vx; newX = self.x end
        if hitV then self.vy = -self.vy; newY = self.y end

        -- Still stuck? reverse both
        local fg, fgy2 = self.grid:pixelToGrid(newX, newY)
        if self.grid:getCell(fg, fgy2) == Grid.CLAIMED then
            self.vx = -self.vx
            self.vy = -self.vy
            newX = self.x
            newY = self.y
        end
    end

    self.x = newX
    self.y = newY
end

function Enemy:checkTrailCollision(grid)
    local gx, gy = grid:pixelToGrid(self.x, self.y)
    for dy = -1, 1 do
        for dx = -1, 1 do
            if grid:getCell(gx + dx, gy + dy) == Grid.TRAIL then
                return true
            end
        end
    end
    return false
end

function Enemy:checkPlayerCollision(player)
    local dist = math.sqrt((self.x - player.x)^2 + (self.y - player.y)^2)
    return dist < (self.radius + player.size)
end

function Enemy:draw()
    local r, g, b = self.color[1], self.color[2], self.color[3]
    local glow = math.sin(self.pulseTimer) * 2 + 4

    -- Glow
    love.graphics.setColor(r, g, b, 0.12)
    love.graphics.circle("fill", self.x, self.y, self.radius + glow + 6)
    love.graphics.setColor(r, g, b, 0.25)
    love.graphics.circle("fill", self.x, self.y, self.radius + glow)

    -- Body
    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle("fill", self.x, self.y, self.radius)

    -- Eye
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.circle("fill", self.x, self.y, self.radius * 0.4)
    love.graphics.setColor(0.1, 0.05, 0.15, 1)
    love.graphics.circle("fill",
        self.x + self.vx * 0.012,
        self.y + self.vy * 0.012,
        self.radius * 0.2)
end

return Enemy
