-- ============================================================
-- Player — Grid-snapped movement, trail cutting
-- Moves cell-by-cell for precise control
-- ============================================================

local Grid = require("grid")

local Player = {}
Player.__index = Player

local MOVE_INTERVAL_BORDER = 0.028  -- seconds between moves on border
local MOVE_INTERVAL_CUT    = 0.022  -- seconds between moves while cutting

function Player.new(grid)
    local self = setmetatable({}, Player)
    self.grid = grid

    -- Start on top border, centered
    self.gx = math.floor(grid.cols / 2)
    self.gy = 2
    self.x, self.y = grid:gridToCenter(self.gx, self.gy)

    self.size = grid.cellSize * 2
    self.cutting = false
    self.trail = {}
    self.lives = 3
    self.alive = true

    -- Movement timing (cell-by-cell with key repeat)
    self.moveTimer = 0
    self.dirX = 0
    self.dirY = 0

    -- Visual
    self.pulseTimer = 0
    self.invincible = false
    self.invincibleTimer = 0

    return self
end

function Player:update(dt)
    if not self.alive then return end

    self.pulseTimer = self.pulseTimer + dt * 4

    if self.invincible then
        self.invincibleTimer = self.invincibleTimer - dt
        if self.invincibleTimer <= 0 then
            self.invincible = false
        end
    end

    -- Read directional input
    local dx, dy = 0, 0
    if love.keyboard.isDown("left", "a")  then dx = -1 end
    if love.keyboard.isDown("right", "d") then dx = 1  end
    if love.keyboard.isDown("up", "w")    then dy = -1 end
    if love.keyboard.isDown("down", "s")  then dy = 1  end

    -- Only one axis at a time
    if dx ~= 0 and dy ~= 0 then dy = 0 end

    if dx == 0 and dy == 0 then
        self.moveTimer = 0
        return nil
    end

    -- Throttled movement: move one cell per interval
    self.moveTimer = self.moveTimer + dt
    local interval = self.cutting and MOVE_INTERVAL_CUT or MOVE_INTERVAL_BORDER

    if self.moveTimer < interval then return nil end
    self.moveTimer = self.moveTimer - interval

    -- Target cell
    local ngx = self.gx + dx
    local ngy = self.gy + dy

    -- Bounds check
    if ngx < 1 or ngx > self.grid.cols or ngy < 1 or ngy > self.grid.rows then
        return nil
    end

    local cellType = self.grid:getCell(ngx, ngy)

    if self.cutting then
        if cellType == Grid.CLAIMED then
            -- Completed the cut! Return to border
            self.gx, self.gy = ngx, ngy
            self.x, self.y = self.grid:gridToCenter(self.gx, self.gy)
            self.cutting = false
            return "complete"
        elseif cellType == Grid.TRAIL then
            -- Can't cross own trail
            return nil
        else
            -- Continue drawing trail into unclaimed territory
            self.gx, self.gy = ngx, ngy
            self.x, self.y = self.grid:gridToCenter(self.gx, self.gy)
            self.grid:setCell(ngx, ngy, Grid.TRAIL)
            self.trail[#self.trail + 1] = {ngx, ngy}
        end
    else
        -- On border / claimed territory
        if cellType == Grid.UNCLAIMED then
            -- Start cutting!
            self.cutting = true
            self.trail = {}
            self.gx, self.gy = ngx, ngy
            self.x, self.y = self.grid:gridToCenter(self.gx, self.gy)
            self.grid:setCell(ngx, ngy, Grid.TRAIL)
            self.trail[#self.trail + 1] = {ngx, ngy}
        elseif cellType == Grid.CLAIMED then
            -- Normal movement on claimed territory
            self.gx, self.gy = ngx, ngy
            self.x, self.y = self.grid:gridToCenter(self.gx, self.gy)
        end
    end

    return nil
end

function Player:die()
    if self.invincible then return false end

    self.lives = self.lives - 1
    self.cutting = false
    self.grid:clearTrail()
    self.trail = {}

    if self.lives <= 0 then
        self.alive = false
        return true
    end

    -- Respawn on top border
    self.gx = math.floor(self.grid.cols / 2)
    self.gy = 2
    self.x, self.y = self.grid:gridToCenter(self.gx, self.gy)
    self.invincible = true
    self.invincibleTimer = 2.0

    -- Rebuild canvas since trail was cleared
    self.grid:rebuildCanvas()

    return false
end

function Player:draw()
    if not self.alive then return end
    if self.invincible and math.floor(self.invincibleTimer * 10) % 2 == 0 then
        return
    end

    local pulse = math.sin(self.pulseTimer) * 0.15 + 1.0
    local s = self.size * pulse

    -- Glow
    love.graphics.setColor(0.2, 0.8, 1.0, 0.25)
    love.graphics.circle("fill", self.x, self.y, s * 1.6)

    -- Body
    if self.cutting then
        love.graphics.setColor(1.0, 0.4, 0.15, 1)
    else
        love.graphics.setColor(0.1, 0.85, 1.0, 1)
    end
    love.graphics.circle("fill", self.x, self.y, s)

    -- Highlight
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", self.x - s*0.2, self.y - s*0.2, s * 0.35)
end

return Player
