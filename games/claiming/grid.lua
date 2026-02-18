-- ============================================================
-- Grid / Territory System  (canvas-cached, high performance)
-- Cell values: 0=unclaimed, 1=claimed, 2=trail
-- ============================================================

local Grid = {}
Grid.__index = Grid

local CELL_SIZE = 5
local UNCLAIMED = 0
local CLAIMED   = 1
local TRAIL     = 2

function Grid.new(screenW, screenH)
    local self = setmetatable({}, Grid)
    self.cellSize = CELL_SIZE
    self.cols = math.floor(screenW / CELL_SIZE)
    self.rows = math.floor(screenH / CELL_SIZE)
    self.cells = {}
    self.dirty = true -- needs canvas redraw

    -- Initialize all cells as unclaimed
    for y = 1, self.rows do
        self.cells[y] = {}
        for x = 1, self.cols do
            self.cells[y][x] = UNCLAIMED
        end
    end

    -- Claim the border (outer 2-cell frame)
    for y = 1, self.rows do
        for x = 1, self.cols do
            if x <= 2 or x > self.cols - 2
                or y <= 2 or y > self.rows - 2 then
                self.cells[y][x] = CLAIMED
            end
        end
    end

    self.totalCells = self.cols * self.rows
    self:recalcClaimed()

    -- Canvas for unclaimed area (dark overlay)
    self.unclaimedCanvas = love.graphics.newCanvas(screenW, screenH)
    -- Canvas for stencil mask (claimed area)
    self.stencilCanvas = love.graphics.newCanvas(screenW, screenH)

    self:rebuildCanvas()
    return self
end

function Grid:recalcClaimed()
    local count = 0
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.cells[y][x] == CLAIMED then
                count = count + 1
            end
        end
    end
    self.claimedCount = count
end

function Grid:getPercentClaimed()
    return (self.claimedCount / self.totalCells) * 100
end

function Grid:getCell(gx, gy)
    if gx < 1 or gx > self.cols or gy < 1 or gy > self.rows then
        return CLAIMED
    end
    return self.cells[gy][gx]
end

function Grid:setCell(gx, gy, value)
    if gx >= 1 and gx <= self.cols and gy >= 1 and gy <= self.rows then
        self.cells[gy][gx] = value
        self.dirty = true
    end
end

function Grid:pixelToGrid(px, py)
    local gx = math.floor(px / self.cellSize) + 1
    local gy = math.floor(py / self.cellSize) + 1
    return math.max(1, math.min(self.cols, gx)), math.max(1, math.min(self.rows, gy))
end

function Grid:gridToPixel(gx, gy)
    return (gx - 1) * self.cellSize, (gy - 1) * self.cellSize
end

function Grid:gridToCenter(gx, gy)
    return (gx - 1) * self.cellSize + self.cellSize * 0.5,
           (gy - 1) * self.cellSize + self.cellSize * 0.5
end

function Grid:isBorder(gx, gy)
    if self:getCell(gx, gy) ~= CLAIMED then return false end
    if self:getCell(gx - 1, gy) == UNCLAIMED or self:getCell(gx - 1, gy) == TRAIL then return true end
    if self:getCell(gx + 1, gy) == UNCLAIMED or self:getCell(gx + 1, gy) == TRAIL then return true end
    if self:getCell(gx, gy - 1) == UNCLAIMED or self:getCell(gx, gy - 1) == TRAIL then return true end
    if self:getCell(gx, gy + 1) == UNCLAIMED or self:getCell(gx, gy + 1) == TRAIL then return true end
    return false
end

function Grid:clearTrail()
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.cells[y][x] == TRAIL then
                self.cells[y][x] = UNCLAIMED
            end
        end
    end
    self.dirty = true
end

-- Complete trail: convert trail→claimed, flood fill to claim the
-- smaller region (or the one without enemies)
function Grid:completeTrail(enemies)
    -- Trail → claimed
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.cells[y][x] == TRAIL then
                self.cells[y][x] = CLAIMED
            end
        end
    end

    -- Find all separate unclaimed regions
    local visited = {}
    for y = 1, self.rows do
        visited[y] = {}
    end

    local regions = {}

    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.cells[y][x] == UNCLAIMED and not visited[y][x] then
                local region = {}
                local hasEnemy = false
                local queue = {{x, y}}
                local head = 1
                visited[y][x] = true

                while head <= #queue do
                    local cx, cy = queue[head][1], queue[head][2]
                    head = head + 1
                    region[#region + 1] = {cx, cy}

                    -- Check enemies
                    if enemies then
                        for _, e in ipairs(enemies) do
                            local ex, ey = self:pixelToGrid(e.x, e.y)
                            if ex == cx and ey == cy then
                                hasEnemy = true
                            end
                        end
                    end

                    local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
                    for _, d in ipairs(dirs) do
                        local nx, ny = cx + d[1], cy + d[2]
                        if nx >= 1 and nx <= self.cols and ny >= 1 and ny <= self.rows then
                            if self.cells[ny][nx] == UNCLAIMED and not visited[ny][nx] then
                                visited[ny][nx] = true
                                queue[#queue + 1] = {nx, ny}
                            end
                        end
                    end
                end

                regions[#regions + 1] = {cells = region, hasEnemy = hasEnemy}
            end
        end
    end

    -- Claim regions without enemies
    local allHaveEnemies = true
    for _, r in ipairs(regions) do
        if not r.hasEnemy then allHaveEnemies = false; break end
    end

    if allHaveEnemies and #regions > 0 then
        table.sort(regions, function(a, b) return #a.cells < #b.cells end)
        for _, cell in ipairs(regions[1].cells) do
            self.cells[cell[2]][cell[1]] = CLAIMED
        end
    else
        for _, r in ipairs(regions) do
            if not r.hasEnemy then
                for _, cell in ipairs(r.cells) do
                    self.cells[cell[2]][cell[1]] = CLAIMED
                end
            end
        end
    end

    self:recalcClaimed()
    self.dirty = true
    self:rebuildCanvas()
end

-- Rebuild cached canvases (only when territory changes)
function Grid:rebuildCanvas()
    local cs = self.cellSize

    -- Unclaimed overlay canvas
    love.graphics.setCanvas(self.unclaimedCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(0.06, 0.06, 0.10, 1)
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.cells[y][x] == UNCLAIMED then
                love.graphics.rectangle("fill", (x-1)*cs, (y-1)*cs, cs, cs)
            end
        end
    end
    love.graphics.setCanvas()

    -- Stencil canvas (white where claimed)
    love.graphics.setCanvas(self.stencilCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.cells[y][x] == CLAIMED then
                love.graphics.rectangle("fill", (x-1)*cs, (y-1)*cs, cs, cs)
            end
        end
    end
    love.graphics.setCanvas()

    self.dirty = false
end

function Grid:draw()
    -- Draw unclaimed area (cached canvas)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.unclaimedCanvas, 0, 0)

    -- Draw trail cells (these change often, draw directly)
    love.graphics.setColor(1, 0.85, 0.1, 0.9)
    local cs = self.cellSize
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.cells[y][x] == TRAIL then
                love.graphics.rectangle("fill", (x-1)*cs, (y-1)*cs, cs, cs)
            end
        end
    end
end

function Grid:drawStencil()
    -- Used by background to mask claimed area
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.stencilCanvas, 0, 0)
end

Grid.UNCLAIMED = UNCLAIMED
Grid.CLAIMED   = CLAIMED
Grid.TRAIL     = TRAIL
Grid.CELL_SIZE = CELL_SIZE

return Grid
