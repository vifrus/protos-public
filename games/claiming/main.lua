-- ============================================================
-- GALS PANIC — Territory Claiming Game
-- Main entry point
-- ============================================================

local Grid       = require("grid")
local Player     = require("player")
local Enemy      = require("enemy")
local Background = require("background")
local HUD        = require("hud")

local grid, player, enemies, background, hud
local gameState = "playing"
local WIN_PERCENT = 80
local screenW, screenH

-- Simple particle effects
local particles = {}

local function spawnParticles(x, y, n)
    for i = 1, (n or 8) do
        particles[#particles + 1] = {
            x = x, y = y,
            vx = (math.random() - 0.5) * 200,
            vy = (math.random() - 0.5) * 200,
            life = 0.4 + math.random() * 0.4,
            maxLife = 0.4 + math.random() * 0.4,
            r = 0.3 + math.random() * 0.7,
            g = 0.7 + math.random() * 0.3,
            b = 0.3 + math.random() * 0.7,
            size = 2 + math.random() * 3,
        }
    end
end

local function resetGame()
    screenW = love.graphics.getWidth()
    screenH = love.graphics.getHeight()

    grid       = Grid.new(screenW, screenH)
    player     = Player.new(grid)
    background = Background.new(screenW, screenH)
    hud        = HUD.new()
    particles  = {}

    local colors = {
        {1.0, 0.2, 0.5},
        {0.5, 0.2, 1.0},
    }
    enemies = {}
    for i = 1, 2 do
        local ex, ey
        for attempt = 1, 200 do
            local gx = math.random(6, grid.cols - 6)
            local gy = math.random(6, grid.rows - 6)
            if grid:getCell(gx, gy) == Grid.UNCLAIMED then
                ex, ey = grid:gridToCenter(gx, gy)
                break
            end
        end
        if ex then
            enemies[#enemies + 1] = Enemy.new(grid, ex, ey, colors[i])
        end
    end

    gameState = "playing"
    hud:showMessage("¡Reclamá el territorio!", 3)
end

function love.load()
    love.window.setTitle("Gals Panic")
    math.randomseed(os.time())
    love.graphics.setBackgroundColor(0.05, 0.05, 0.1)
    resetGame()
end

function love.update(dt)
    dt = math.min(dt, 0.05)
    hud:update(dt)

    -- Particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end

    if gameState ~= "playing" then return end

    -- Player
    local result = player:update(dt)

    if result == "complete" then
        grid:completeTrail(enemies)
        spawnParticles(player.x, player.y, 15)
        local pct = grid:getPercentClaimed()
        hud:showMessage(string.format("%.0f%% reclamado!", pct), 1.5)
        if pct >= WIN_PERCENT then
            gameState = "win"
        end
    end

    -- Enemies
    for _, e in ipairs(enemies) do
        e:update(dt)

        if player.cutting then
            if e:checkTrailCollision(grid) or e:checkPlayerCollision(player) then
                local over = player:die()
                if over then
                    gameState = "gameover"
                else
                    hud:showMessage("¡Perdiste una vida!", 1.5)
                end
            end
        end
    end
end

function love.draw()
    -- 1. Background (visible only in claimed areas)
    background:draw(grid)

    -- 2. Grid overlay (unclaimed + trail)
    grid:draw()

    -- 3. Enemies
    for _, e in ipairs(enemies) do
        e:draw()
    end

    -- 5. Player
    player:draw()

    -- 6. Particles
    for _, p in ipairs(particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.r, p.g, p.b, alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * alpha)
    end

    -- 7. HUD
    hud:draw(grid:getPercentClaimed(), player.lives, gameState)
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    if key == "r" then resetGame() end
end
