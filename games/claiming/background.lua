-- ============================================================
-- Background — Procedural colorful image, revealed via stencil
-- ============================================================

local Background = {}
Background.__index = Background

function Background.new(width, height)
    local self = setmetatable({}, Background)
    self.width  = width
    self.height = height
    self.canvas = love.graphics.newCanvas(width, height)
    self:generate()
    return self
end

function Background:generate()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 1)

    local W, H = self.width, self.height
    local cx, cy = W / 2, H / 2

    -- Gradient base (using bigger steps for perf)
    for y = 0, H - 1, 3 do
        for x = 0, W - 1, 3 do
            local dist = math.sqrt((x - cx)^2 + (y - cy)^2)
            local maxD = math.sqrt(cx^2 + cy^2)
            local t = dist / maxD

            local r = 0.1 + 0.55 * (1 - t) + 0.25 * math.sin(t * 4)
            local g = 0.05 + 0.35 * math.sin(t * 3 + 1)
            local b = 0.25 + 0.65 * t

            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", x, y, 3, 3)
        end
    end

    -- Colorful circles
    for i = 1, 20 do
        local rx = math.random(40, W - 40)
        local ry = math.random(40, H - 40)
        local rad = math.random(25, 70)
        local h = math.random() * 360
        local r, g, b = self:hsl(h / 360, 0.8, 0.55)
        love.graphics.setColor(r, g, b, 0.45)
        love.graphics.circle("fill", rx, ry, rad)
        love.graphics.setColor(r, g, b, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", rx, ry, rad * 0.7)
    end

    -- Stars
    for i = 1, 80 do
        love.graphics.setColor(1, 1, 0.9, 0.6 + math.random() * 0.4)
        love.graphics.circle("fill", math.random(0, W), math.random(0, H), math.random(1, 3))
    end

    -- Diagonal stripes
    love.graphics.setLineWidth(2)
    for i = -H, W + H, 35 do
        local h = ((i + H) / (W + 2 * H))
        local r, g, b = self:hsl(h, 0.7, 0.5)
        love.graphics.setColor(r, g, b, 0.12)
        love.graphics.line(i, 0, i + H, H)
    end

    -- Central flower
    for p = 1, 8 do
        local angle = (p / 8) * math.pi * 2
        local px = cx + math.cos(angle) * 90
        local py = cy + math.sin(angle) * 90
        local r, g, b = self:hsl(p / 8, 0.9, 0.55)
        love.graphics.setColor(r, g, b, 0.55)
        love.graphics.circle("fill", px, py, 35)
    end
    love.graphics.setColor(1, 0.95, 0.3, 0.85)
    love.graphics.circle("fill", cx, cy, 25)

    love.graphics.setCanvas()
    love.graphics.setLineWidth(1)
end

-- Draw background only in claimed areas using stencil
function Background:draw(grid)
    love.graphics.stencil(function()
        grid:drawStencil()
    end, "replace", 1)

    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, 0, 0)
    love.graphics.setStencilTest()
end

function Background:hsl(h, s, l)
    if s == 0 then return l, l, l end
    local function f(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return f(p, q, h + 1/3), f(p, q, h), f(p, q, h - 1/3)
end

return Background
