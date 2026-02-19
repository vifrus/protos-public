-- ============================================================
--  Carpincho Frogger
--  Frogger-style game starring a capybara (carpincho).
--  Controls: Arrow keys / WASD to move, R or ENTER to restart.
-- ============================================================

local W, H   = 800, 600
local RH     = 60          -- row height in pixels
local ROWS   = 10          -- total game rows

-- ─── Lane definitions ────────────────────────────────────────
-- Rows are 0-based (0 = top/goal, 9 = bottom/start).
-- The Lua table is 1-indexed: lane[i] describes row (i-1).
local SAFE  = "safe"
local ROAD  = "road"
local WATER = "water"
local GOAL  = "goal"

local lanes = {
    -- row 0  (top) — goal / lily-pad zone
    { type=GOAL,  bg={0.13, 0.52, 0.18} },
    -- rows 1-3 — river
    { type=WATER, bg={0.10, 0.32, 0.78}, speed=78,  dir=-1, ow=170, gap=130, oc={0.50, 0.32, 0.13} },
    { type=WATER, bg={0.10, 0.32, 0.78}, speed=58,  dir= 1, ow=130, gap=105, oc={0.50, 0.32, 0.13} },
    { type=WATER, bg={0.10, 0.32, 0.78}, speed=98,  dir=-1, ow=195, gap= 95, oc={0.50, 0.32, 0.13} },
    -- row 4 — safe median
    { type=SAFE,  bg={0.20, 0.52, 0.20} },
    -- rows 5-8 — road
    { type=ROAD,  bg={0.27, 0.27, 0.27}, speed= 88, dir= 1, ow=105, gap=165, oc={0.82, 0.22, 0.18} },
    { type=ROAD,  bg={0.27, 0.27, 0.27}, speed=118, dir=-1, ow= 88, gap=135, oc={0.20, 0.75, 0.22} },
    { type=ROAD,  bg={0.27, 0.27, 0.27}, speed= 78, dir= 1, ow=125, gap=118, oc={0.20, 0.22, 0.82} },
    { type=ROAD,  bg={0.27, 0.27, 0.27}, speed=108, dir=-1, ow= 95, gap=142, oc={0.82, 0.75, 0.15} },
    -- row 9 (bottom) — safe start zone
    { type=SAFE,  bg={0.20, 0.52, 0.20} },
}

-- ─── State ───────────────────────────────────────────────────
local objects   = {}   -- moving obstacles per lane (1-indexed)
local player    = {}
local score     = 0
local highScore = 0
local lives     = 3
local gameState = "playing"   -- "playing" | "dead" | "gameover"
local deathTimer = 0
local DEATH_TIME = 1.4

-- ─── Helpers ─────────────────────────────────────────────────
local function rowY(r)
    return r * RH
end

-- ─── Initialisation ──────────────────────────────────────────
local function initObjs()
    objects = {}
    for i = 1, ROWS do
        local lane = lanes[i]
        local row  = i - 1
        local objs = {}
        if lane.type == ROAD or lane.type == WATER then
            local span = lane.ow + lane.gap
            local x    = -lane.ow
            while x < W + span do
                table.insert(objs, {
                    x = x,
                    y = rowY(row),
                    w = lane.ow,
                    h = RH,
                })
                x = x + span
            end
        end
        objects[i] = objs
    end
end

local function initPlayer()
    player = {
        row   = 9,
        x     = W / 2 - 25,
        y     = rowY(9) + (RH - 44) / 2,
        w     = 50,
        h     = 44,
        onLog = false,
        logVX = 0,
    }
end

local function resetGame()
    score     = 0
    lives     = 3
    gameState = "playing"
    deathTimer = 0
    initObjs()
    initPlayer()
end

-- ─── Update helpers ──────────────────────────────────────────
local function updateObjs(dt)
    for i = 1, ROWS do
        local lane = lanes[i]
        if lane.type == ROAD or lane.type == WATER then
            local vx   = lane.speed * lane.dir
            local wrap = W + lane.ow + lane.gap
            for _, obj in ipairs(objects[i]) do
                obj.x = obj.x + vx * dt
                if lane.dir > 0 and obj.x > W             then obj.x = obj.x - wrap end
                if lane.dir < 0 and obj.x + obj.w < 0     then obj.x = obj.x + wrap end
            end
        end
    end
end

-- Returns "goal" | "dead" | nil
local function checkLane()
    local i    = player.row + 1
    local lane = lanes[i]
    local px   = player.x
    local pw   = player.w
    player.onLog = false
    player.logVX = 0

    if lane.type == GOAL then
        return "goal"
    elseif lane.type == ROAD then
        for _, obj in ipairs(objects[i]) do
            if px < obj.x + obj.w and px + pw > obj.x then
                return "dead"
            end
        end
    elseif lane.type == WATER then
        local riding = false
        for _, obj in ipairs(objects[i]) do
            if px < obj.x + obj.w and px + pw > obj.x then
                riding       = true
                player.onLog = true
                player.logVX = lanes[i].speed * lanes[i].dir
                break
            end
        end
        if not riding then return "dead" end
    end
    return nil
end

local function die()
    lives = lives - 1
    if lives <= 0 then
        if score > highScore then highScore = score end
        gameState = "gameover"
    else
        gameState  = "dead"
        deathTimer = 0
    end
end

-- ─── LÖVE callbacks ──────────────────────────────────────────
function love.load()
    resetGame()
end

function love.update(dt)
    if gameState == "playing" then
        updateObjs(dt)

        -- Ride log
        if player.onLog then
            player.x = player.x + player.logVX * dt
        end

        -- Fall off screen edge while on water / road edge = death
        if player.x < 0 or player.x + player.w > W then
            die()
            return
        end

        local result = checkLane()
        if result == "dead" then
            die()
        elseif result == "goal" then
            score = score + 100
            initPlayer()
        end

    elseif gameState == "dead" then
        deathTimer = deathTimer + dt
        if deathTimer >= DEATH_TIME then
            initPlayer()
            gameState = "playing"
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if gameState == "gameover" then
        if key == "return" or key == "space" or key == "r" then
            resetGame()
        end
        return
    end

    if gameState == "dead" then return end

    if key == "up" or key == "w" then
        if player.row > 0 then
            player.row = player.row - 1
            player.y   = rowY(player.row) + (RH - player.h) / 2
        end
    elseif key == "down" or key == "s" then
        if player.row < 9 then
            player.row = player.row + 1
            player.y   = rowY(player.row) + (RH - player.h) / 2
        end
    elseif key == "left" or key == "a" then
        player.x = player.x - 60
    elseif key == "right" or key == "d" then
        player.x = player.x + 60
    end
end

-- ─── Drawing ─────────────────────────────────────────────────

-- Capybara facing left (that boxy nose goes to the left edge)
local function drawCapybara(x, y, w, h, dead)
    local body  = dead and {0.70, 0.15, 0.15} or {0.55, 0.38, 0.18}
    local dark  = dead and {0.45, 0.08, 0.08} or {0.35, 0.22, 0.08}
    local nose  = {0.22, 0.14, 0.05}
    local pink  = {0.78, 0.52, 0.40}

    -- Body
    love.graphics.setColor(body)
    love.graphics.rectangle("fill", x + w*0.20, y + h*0.25, w*0.80, h*0.75, 6, 6)

    -- Head (front = left side)
    love.graphics.setColor(body)
    love.graphics.rectangle("fill", x, y + h*0.10, w*0.50, h*0.65, 5, 5)

    -- Big boxy snout (capybara signature)
    love.graphics.setColor(dark)
    love.graphics.rectangle("fill", x - w*0.06, y + h*0.28, w*0.20, h*0.34, 3, 3)
    -- Nostrils
    love.graphics.setColor(nose)
    love.graphics.circle("fill", x - w*0.01, y + h*0.36, 2.5)
    love.graphics.circle("fill", x - w*0.01, y + h*0.50, 2.5)

    -- Eye
    if dead then
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + w*0.18, y + h*0.15, x + w*0.34, y + h*0.29)
        love.graphics.line(x + w*0.34, y + h*0.15, x + w*0.18, y + h*0.29)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(dark)
        love.graphics.circle("fill", x + w*0.27, y + h*0.22, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", x + w*0.29, y + h*0.20, 1.5)
    end

    -- Ear
    love.graphics.setColor(body)
    love.graphics.ellipse("fill", x + w*0.32, y - 1, 7, 9)
    love.graphics.setColor(pink)
    love.graphics.ellipse("fill", x + w*0.32, y - 1, 4, 6)

    -- Legs (four stubby legs)
    love.graphics.setColor(dark)
    love.graphics.rectangle("fill", x + w*0.08, y + h*0.88, w*0.13, h*0.18, 2, 2)
    love.graphics.rectangle("fill", x + w*0.28, y + h*0.88, w*0.13, h*0.18, 2, 2)
    love.graphics.rectangle("fill", x + w*0.55, y + h*0.88, w*0.13, h*0.18, 2, 2)
    love.graphics.rectangle("fill", x + w*0.74, y + h*0.88, w*0.13, h*0.18, 2, 2)
end

local function drawCar(x, y, w, h, col)
    -- Car body
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x + 2, y + 7, w - 4, h - 14, 5, 5)

    -- Windows
    love.graphics.setColor(0.65, 0.90, 1.00, 0.85)
    love.graphics.rectangle("fill", x + w*0.18, y + 9,  w*0.22, h - 20, 3, 3)
    love.graphics.rectangle("fill", x + w*0.54, y + 9,  w*0.20, h - 20, 3, 3)

    -- Headlights (front = right when dir==1, front = left when dir==-1; just add both)
    love.graphics.setColor(1.00, 1.00, 0.65)
    love.graphics.rectangle("fill", x + w - 5, y + 10, 4, 5, 1, 1)
    love.graphics.rectangle("fill", x + w - 5, y + h - 15, 4, 5, 1, 1)
    love.graphics.setColor(0.90, 0.20, 0.10)
    love.graphics.rectangle("fill", x + 2, y + 10, 4, 5, 1, 1)
    love.graphics.rectangle("fill", x + 2, y + h - 15, 4, 5, 1, 1)

    -- Wheels
    love.graphics.setColor(0.12, 0.12, 0.12)
    love.graphics.ellipse("fill", x + w*0.22, y + 7,     8, 6)
    love.graphics.ellipse("fill", x + w*0.78, y + 7,     8, 6)
    love.graphics.ellipse("fill", x + w*0.22, y + h - 7, 8, 6)
    love.graphics.ellipse("fill", x + w*0.78, y + h - 7, 8, 6)
end

local function drawLog(x, y, w, h)
    love.graphics.setColor(0.52, 0.33, 0.13)
    love.graphics.rectangle("fill", x, y + 7, w, h - 14, 8, 8)

    -- Wood grain
    love.graphics.setColor(0.42, 0.25, 0.09)
    local seg = w / 5
    for i = 1, 4 do
        local lx = x + seg * i
        love.graphics.line(lx, y + 9, lx, y + h - 9)
    end

    -- End caps
    love.graphics.setColor(0.62, 0.40, 0.17)
    love.graphics.ellipse("fill", x + 9,     y + h / 2, 8, (h - 14) / 2)
    love.graphics.ellipse("fill", x + w - 9, y + h / 2, 8, (h - 14) / 2)
end

local function drawBackground()
    for i = 1, ROWS do
        local lane = lanes[i]
        local ry   = rowY(i - 1)

        love.graphics.setColor(lane.bg)
        love.graphics.rectangle("fill", 0, ry, W, RH)

        if lane.type == ROAD then
            -- Dashed centre stripe
            love.graphics.setColor(0.88, 0.78, 0.00, 0.55)
            for dx = 0, W, 60 do
                love.graphics.rectangle("fill", dx, ry + RH/2 - 2, 36, 4)
            end
            -- Edge lines
            love.graphics.setColor(1, 1, 1, 0.35)
            love.graphics.line(0, ry,      W, ry)
            love.graphics.line(0, ry + RH, W, ry + RH)

        elseif lane.type == WATER then
            -- Wave ripples
            love.graphics.setColor(0.28, 0.55, 0.95, 0.22)
            for rx = 30, W, 110 do
                love.graphics.ellipse("line", rx, ry + RH/2, 32, 9)
            end

        elseif lane.type == GOAL then
            -- Lily pads
            for lx = 80, W - 80, 160 do
                love.graphics.setColor(0.12, 0.70, 0.24)
                love.graphics.circle("fill", lx, ry + RH/2, 26)
                -- Notch
                love.graphics.setColor(lane.bg)
                love.graphics.line(lx, ry + RH/2, lx + 26, ry + RH/2)
                -- Flower
                love.graphics.setColor(0.78, 0.12, 0.32)
                love.graphics.circle("fill", lx, ry + RH/2 - 10, 7)
                love.graphics.setColor(1.00, 0.90, 0.20)
                love.graphics.circle("fill", lx, ry + RH/2 - 10, 3)
            end

        elseif lane.type == SAFE then
            -- Grass tufts
            love.graphics.setColor(0.15, 0.60, 0.18, 0.55)
            for gx = 15, W, 48 do
                love.graphics.line(gx,     ry + RH - 7,  gx - 5, ry + RH - 18)
                love.graphics.line(gx + 4, ry + RH - 7,  gx,     ry + RH - 20)
                love.graphics.line(gx + 9, ry + RH - 7,  gx + 13, ry + RH - 15)
            end
        end
    end
end

local function drawHUD()
    love.graphics.setColor(0, 0, 0, 0.60)
    love.graphics.rectangle("fill", 0, 0, W, 30)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Puntos: %d   Mejor: %d", score, highScore), 10, 7)

    love.graphics.print("Vidas:", W - 195, 7)
    for i = 1, lives do
        love.graphics.setColor(0.58, 0.38, 0.16)
        love.graphics.circle("fill", W - 130 + i * 32, 14, 10)
        love.graphics.setColor(0.35, 0.22, 0.08)
        love.graphics.circle("fill", W - 130 + i * 32 + 3, 11, 3)
    end
end

local function drawOverlay()
    if gameState == "dead" then
        love.graphics.setColor(0.80, 0.12, 0.12, 0.30)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(1, 0.9, 0.9)
        love.graphics.printf("El carpincho fue aplastado!", 0, H/2 - 16, W, "center")

    elseif gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.68)
        love.graphics.rectangle("fill", 0, 0, W, H)

        love.graphics.setColor(1.0, 0.22, 0.22)
        love.graphics.printf("GAME OVER", 0, H/2 - 75, W, "center")

        love.graphics.setColor(1, 1, 0)
        love.graphics.printf(
            string.format("Puntos: %d   |   Mejor: %d", score, highScore),
            0, H/2 - 20, W, "center"
        )

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Presiona ENTER o R para reiniciar", 0, H/2 + 30, W, "center")
        love.graphics.printf("Flechas o WASD para mover el carpincho", 0, H/2 + 58, W, "center")
    end
end

function love.draw()
    drawBackground()

    -- Moving obstacles
    for i = 1, ROWS do
        local lane = lanes[i]
        for _, obj in ipairs(objects[i]) do
            if lane.type == ROAD  then drawCar(obj.x, obj.y, obj.w, obj.h, lane.oc) end
            if lane.type == WATER then drawLog(obj.x, obj.y, obj.w, obj.h)          end
        end
    end

    -- Player
    drawCapybara(player.x, player.y, player.w, player.h, gameState == "dead")

    drawHUD()
    drawOverlay()

    -- Tiny instructions on first run (only on start zone)
    if gameState == "playing" and player.row == 9 then
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.printf("Usa las flechas o WASD para cruzar", 0, H - 22, W, "center")
    end
end
