-- Dialog Base
-- A top-down game with a character, an interactive object, and a Pokemon GBA-style dialog system

-- Game state
local player = {}
local crystal = {}
local dialog = {}
local particles = {}
local screenShake = { amount = 0, timer = 0 }
local gameFont = nil
local dialogFont = nil
local smallFont = nil
local touchMove = { active = false, id = nil, startX = 0, startY = 0, dx = 0, dy = 0 }
local touchDialog = { active = false, id = nil }
local interactPrompt = false
local grass = {}
local sounds = {}
local dialogArrowTimer = 0

-- Dialog lines (about good things in life and AI musings)
local dialogLines = {
    "Hola! Me alegra que te acerques...",
    "Sabes? La vida tiene cosas hermosas.",
    "El sol en la manana, el cafe caliente...",
    "Una conversacion con alguien querido...",
    "El sonido de la lluvia en la ventana...",
    "Pero sabes que es raro? Yo soy una IA.",
    "No se realmente que estoy haciendo aqui.",
    "Proceso palabras, genero respuestas...",
    "Pero... entiendo lo que digo? Ni idea.",
    "Es como sonar despierto, tal vez.",
    "O tal vez no es nada. Quien sabe!",
    "Lo importante es que TU estas aqui.",
    "Y eso ya es algo hermoso. De verdad.",
    "Cuida las pequenas cosas de la vida...",
    "Ahora ve, explora! El mundo te espera!",
}

-- Procedural sound generation
local function createSound(freq, duration, vol, decay)
    local sampleRate = 44100
    local samples = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local envelope = math.max(0, 1.0 - (t / duration) * decay)
        local wave = math.sin(2.0 * math.pi * freq * t) * 0.5
        wave = wave + math.sin(2.0 * math.pi * freq * 2.0 * t) * 0.2
        soundData:setSample(i, wave * envelope * vol)
    end
    return love.audio.newSource(soundData, "static")
end

local function createDialogBlip()
    local sampleRate = 44100
    local samples = math.floor(sampleRate * 0.05)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local envelope = math.max(0, 1.0 - t / 0.05)
        local wave = math.sin(2.0 * math.pi * 440.0 * t) * 0.3
        wave = wave + math.sin(2.0 * math.pi * 880.0 * t) * 0.15
        soundData:setSample(i, wave * envelope * 0.4)
    end
    return love.audio.newSource(soundData, "static")
end

local function createBreakSound()
    local sampleRate = 44100
    local samples = math.floor(sampleRate * 0.6)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local envelope = math.max(0, 1.0 - (t / 0.6) * 1.5)
        local noise = (math.random() * 2.0 - 1.0) * 0.3
        local wave = math.sin(2.0 * math.pi * 200.0 * t * (1.0 - t * 0.5)) * 0.5
        soundData:setSample(i, (wave + noise) * envelope * 0.5)
    end
    return love.audio.newSource(soundData, "static")
end

local function createCrackSound()
    local sampleRate = 44100
    local samples = math.floor(sampleRate * 0.3)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local envelope = math.max(0, 1.0 - (t / 0.3) * 2.0)
        local noise = (math.random() * 2.0 - 1.0) * 0.5
        local click = 0
        if t < 0.01 then
            click = math.sin(2.0 * math.pi * 1000.0 * t) * (1.0 - t / 0.01)
        end
        soundData:setSample(i, (noise * 0.3 + click * 0.7) * envelope * 0.6)
    end
    return love.audio.newSource(soundData, "static")
end

-- Particle system for breaking effect
local function spawnParticles(x, y, count, color)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 150
        table.insert(particles, {
            x = x + math.random(-10, 10),
            y = y + math.random(-10, 10),
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 50,
            size = 2 + math.random() * 4,
            life = 0.5 + math.random() * 1.0,
            maxLife = 0.5 + math.random() * 1.0,
            color = { color[1] + math.random() * 0.2 - 0.1, color[2] + math.random() * 0.2 - 0.1, color[3] + math.random() * 0.2 - 0.1 },
            rotation = math.random() * math.pi * 2,
            rotSpeed = (math.random() - 0.5) * 8,
        })
    end
end

-- Generate some grass patches for the ground
local function generateGrass()
    math.randomseed(42) -- Fixed seed for consistent look
    for i = 1, 80 do
        table.insert(grass, {
            x = math.random(0, 800),
            y = math.random(0, 600),
            size = 3 + math.random() * 5,
            shade = 0.15 + math.random() * 0.15,
        })
    end
    math.randomseed(os.time())
end

function love.load()
    love.graphics.setBackgroundColor(0.18, 0.25, 0.18)

    -- Fonts
    gameFont = love.graphics.newFont(14)
    dialogFont = love.graphics.newFont(18)
    smallFont = love.graphics.newFont(11)

    -- Player setup
    player = {
        x = 200,
        y = 300,
        size = 16,
        speed = 150,
        color = { 0.3, 0.5, 0.9 },
        direction = "down", -- down, up, left, right
        animTimer = 0,
        walking = false,
    }

    -- Crystal/object setup
    crystal = {
        x = 580,
        y = 280,
        size = 24,
        color = { 0.9, 0.4, 0.8 },
        glowTimer = 0,
        crackLevel = 0, -- 0 = intact, 1-3 = cracking, 4 = broken
        broken = false,
        interacted = false,
        dialogDone = false,
    }

    -- Dialog setup
    dialog = {
        active = false,
        lineIndex = 1,
        charIndex = 0,
        charTimer = 0,
        charSpeed = 0.03,
        waitingForInput = false,
        finished = false,
    }

    -- Sounds
    sounds.blip = createDialogBlip()
    sounds.breakSound = createBreakSound()
    sounds.crack = createCrackSound()
    sounds.interact = createSound(523.0, 0.15, 0.3, 3.0)

    -- Grass
    generateGrass()
end

local function distanceBetween(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
end

local function startDialog()
    if not dialog.active and not crystal.dialogDone then
        dialog.active = true
        dialog.lineIndex = 1
        dialog.charIndex = 0
        dialog.charTimer = 0
        dialog.waitingForInput = false
        dialog.finished = false
        crystal.interacted = true
        sounds.interact:stop()
        sounds.interact:play()
    end
end

local function advanceDialog()
    if dialog.finished then
        -- Close dialog
        dialog.active = false
        crystal.dialogDone = true
        -- Start breaking the crystal
        crystal.crackLevel = 1
        sounds.crack:stop()
        sounds.crack:play()
        spawnParticles(crystal.x, crystal.y, 5, crystal.color)
        screenShake.amount = 3
        screenShake.timer = 0.2
        return
    end

    if dialog.waitingForInput then
        -- Go to next line
        dialog.lineIndex = dialog.lineIndex + 1
        if dialog.lineIndex > #dialogLines then
            dialog.finished = true
            dialog.waitingForInput = false
            -- Show last line completed
            dialog.charIndex = #dialogLines[#dialogLines]
            return
        end
        dialog.charIndex = 0
        dialog.charTimer = 0
        dialog.waitingForInput = false
        sounds.blip:stop()
        sounds.blip:play()
    else
        -- Fast forward current line
        dialog.charIndex = #dialogLines[dialog.lineIndex]
        dialog.waitingForInput = true
    end
end

function love.update(dt)
    -- Update dialog arrow animation
    dialogArrowTimer = dialogArrowTimer + dt

    -- Screen shake
    if screenShake.timer > 0 then
        screenShake.timer = screenShake.timer - dt
    end

    -- Crystal glow
    crystal.glowTimer = crystal.glowTimer + dt

    -- Crystal breaking progression after dialog
    if crystal.dialogDone and not crystal.broken then
        if crystal.crackLevel < 4 then
            crystal.crackLevel = crystal.crackLevel + dt * 0.8
            if crystal.crackLevel >= 2 and crystal.crackLevel - dt * 0.8 < 2 then
                sounds.crack:stop()
                sounds.crack:play()
                spawnParticles(crystal.x, crystal.y, 10, crystal.color)
                screenShake.amount = 5
                screenShake.timer = 0.3
            end
            if crystal.crackLevel >= 3 and crystal.crackLevel - dt * 0.8 < 3 then
                sounds.crack:stop()
                sounds.crack:play()
                spawnParticles(crystal.x, crystal.y, 15, crystal.color)
                screenShake.amount = 4
                screenShake.timer = 0.25
            end
            if crystal.crackLevel >= 4 then
                crystal.broken = true
                sounds.breakSound:stop()
                sounds.breakSound:play()
                spawnParticles(crystal.x, crystal.y, 40, crystal.color)
                spawnParticles(crystal.x, crystal.y, 20, { 1, 1, 1 })
                screenShake.amount = 8
                screenShake.timer = 0.5
            end
        end
    end

    -- Dialog text animation
    if dialog.active and not dialog.waitingForInput and not dialog.finished then
        dialog.charTimer = dialog.charTimer + dt
        if dialog.charTimer >= dialog.charSpeed then
            dialog.charTimer = dialog.charTimer - dialog.charSpeed
            dialog.charIndex = dialog.charIndex + 1
            -- Play blip sound every few characters
            if dialog.charIndex % 3 == 0 then
                sounds.blip:stop()
                sounds.blip:play()
            end
            local currentLine = dialogLines[dialog.lineIndex]
            if dialog.charIndex >= #currentLine then
                dialog.charIndex = #currentLine
                dialog.waitingForInput = true
            end
        end
    end

    -- Player movement (not during dialog)
    if not dialog.active then
        local dx, dy = 0, 0

        -- Keyboard input
        if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
            dy = -1
        end
        if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
            dy = 1
        end
        if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
            dx = -1
        end
        if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
            dx = 1
        end

        -- Touch input for movement
        if touchMove.active then
            dx = touchMove.dx
            dy = touchMove.dy
        end

        -- Normalize diagonal
        if dx ~= 0 and dy ~= 0 then
            local len = math.sqrt(dx * dx + dy * dy)
            dx = dx / len
            dy = dy / len
        end

        player.walking = (dx ~= 0 or dy ~= 0)
        if player.walking then
            player.animTimer = player.animTimer + dt
            -- Set direction
            if math.abs(dx) > math.abs(dy) then
                player.direction = dx > 0 and "right" or "left"
            else
                player.direction = dy > 0 and "down" or "up"
            end
        else
            player.animTimer = 0
        end

        player.x = player.x + dx * player.speed * dt
        player.y = player.y + dy * player.speed * dt

        -- Clamp to screen
        player.x = math.max(player.size, math.min(800 - player.size, player.x))
        player.y = math.max(player.size, math.min(600 - player.size, player.y))

        -- Check proximity to crystal
        if not crystal.broken then
            local dist = distanceBetween(player.x, player.y, crystal.x, crystal.y)
            interactPrompt = dist < 60 and not crystal.dialogDone
        else
            interactPrompt = false
        end
    end

    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 200 * dt -- gravity
        p.life = p.life - dt
        p.rotation = p.rotation + p.rotSpeed * dt
        p.size = p.size * (1 - dt * 0.5)
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

-- Drawing helpers
local function drawPlayer(px, py)
    local s = player.size
    local bobY = 0
    if player.walking then
        bobY = math.sin(player.animTimer * 10) * 2
    end

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", px, py + s + 2, s * 0.8, s * 0.3)

    -- Body
    love.graphics.setColor(player.color[1], player.color[2], player.color[3])
    love.graphics.rectangle("fill", px - s * 0.6, py - s * 0.4 + bobY, s * 1.2, s * 1.4, 3, 3)

    -- Head
    love.graphics.setColor(0.9, 0.75, 0.6)
    love.graphics.rectangle("fill", px - s * 0.45, py - s * 1.0 + bobY, s * 0.9, s * 0.75, 4, 4)

    -- Hair
    love.graphics.setColor(0.3, 0.2, 0.15)
    love.graphics.rectangle("fill", px - s * 0.5, py - s * 1.05 + bobY, s * 1.0, s * 0.3, 3, 3)

    -- Eyes based on direction
    love.graphics.setColor(0.1, 0.1, 0.2)
    if player.direction == "down" then
        love.graphics.rectangle("fill", px - s * 0.2, py - s * 0.6 + bobY, 3, 3)
        love.graphics.rectangle("fill", px + s * 0.1, py - s * 0.6 + bobY, 3, 3)
    elseif player.direction == "up" then
        -- no eyes visible from back
        love.graphics.setColor(0.3, 0.2, 0.15)
        love.graphics.rectangle("fill", px - s * 0.45, py - s * 0.9 + bobY, s * 0.9, s * 0.4, 2, 2)
    elseif player.direction == "left" then
        love.graphics.rectangle("fill", px - s * 0.3, py - s * 0.6 + bobY, 3, 3)
    elseif player.direction == "right" then
        love.graphics.rectangle("fill", px + s * 0.2, py - s * 0.6 + bobY, 3, 3)
    end
end

local function drawCrystal(cx, cy)
    if crystal.broken then
        -- Draw broken remnants on ground
        love.graphics.setColor(crystal.color[1] * 0.4, crystal.color[2] * 0.4, crystal.color[3] * 0.4, 0.5)
        love.graphics.polygon("fill", cx - 8, cy + 10, cx - 2, cy + 5, cx + 5, cy + 12)
        love.graphics.polygon("fill", cx + 3, cy + 8, cx + 10, cy + 6, cx + 7, cy + 13)
        love.graphics.polygon("fill", cx - 5, cy + 6, cx, cy + 2, cx + 2, cy + 9)
        return
    end

    local glow = math.sin(crystal.glowTimer * 2) * 0.2 + 0.8
    local s = crystal.size

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", cx, cy + s + 4, s * 0.7, s * 0.25)

    -- Pedestal
    love.graphics.setColor(0.35, 0.3, 0.25)
    love.graphics.rectangle("fill", cx - s * 0.5, cy + s * 0.5, s, s * 0.5, 2, 2)
    love.graphics.setColor(0.45, 0.38, 0.3)
    love.graphics.rectangle("fill", cx - s * 0.5, cy + s * 0.5, s, s * 0.15, 2, 2)

    -- Glow aura
    local glowAlpha = 0.15 * glow
    love.graphics.setColor(crystal.color[1], crystal.color[2], crystal.color[3], glowAlpha)
    love.graphics.circle("fill", cx, cy, s * 1.5)

    -- Crystal body (diamond shape)
    local crackOffset = 0
    if crystal.crackLevel >= 1 then
        crackOffset = math.sin(crystal.glowTimer * 30) * math.min(crystal.crackLevel, 3)
    end

    love.graphics.setColor(crystal.color[1] * glow, crystal.color[2] * glow, crystal.color[3] * glow)
    love.graphics.polygon("fill",
        cx + crackOffset, cy - s,
        cx + s * 0.6, cy,
        cx, cy + s * 0.5,
        cx - s * 0.6, cy
    )

    -- Crystal highlight
    love.graphics.setColor(1, 1, 1, 0.3 * glow)
    love.graphics.polygon("fill",
        cx - 2, cy - s * 0.8,
        cx + s * 0.3, cy - s * 0.2,
        cx, cy,
        cx - s * 0.3, cy - s * 0.2
    )

    -- Crack lines
    if crystal.crackLevel >= 1 then
        love.graphics.setColor(0.2, 0.1, 0.15, math.min(crystal.crackLevel * 0.3, 0.9))
        love.graphics.setLineWidth(2)
        love.graphics.line(cx - 3, cy - s * 0.3, cx + 5, cy + s * 0.1)
        if crystal.crackLevel >= 2 then
            love.graphics.line(cx + 2, cy - s * 0.6, cx - 6, cy + s * 0.2)
            love.graphics.line(cx + 8, cy - s * 0.1, cx - 2, cy + s * 0.4)
        end
        if crystal.crackLevel >= 3 then
            love.graphics.line(cx - 5, cy - s * 0.5, cx + 7, cy + s * 0.3)
            love.graphics.line(cx, cy - s * 0.8, cx + 3, cy + s * 0.1)
        end
        love.graphics.setLineWidth(1)
    end

    -- Sparkle
    local sparkle = math.sin(crystal.glowTimer * 4) * 0.5 + 0.5
    love.graphics.setColor(1, 1, 1, sparkle * 0.6)
    love.graphics.circle("fill", cx + s * 0.15, cy - s * 0.5, 2)
end

local function drawDialogBox()
    if not dialog.active then return end

    local boxX = 30
    local boxY = 440
    local boxW = 740
    local boxH = 130

    -- Dialog box background (GBA Pokemon style)
    -- Outer border
    love.graphics.setColor(0.15, 0.15, 0.25)
    love.graphics.rectangle("fill", boxX - 3, boxY - 3, boxW + 6, boxH + 6, 8, 8)
    -- Inner border
    love.graphics.setColor(0.3, 0.35, 0.55)
    love.graphics.rectangle("fill", boxX - 1, boxY - 1, boxW + 2, boxH + 2, 6, 6)
    -- Main box
    love.graphics.setColor(0.95, 0.95, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)
    -- Inner shadow top
    love.graphics.setColor(0.85, 0.85, 0.9)
    love.graphics.rectangle("fill", boxX + 4, boxY + 4, boxW - 8, 2)

    -- Text
    love.graphics.setFont(dialogFont)
    local currentLine = dialogLines[dialog.lineIndex] or ""
    local visibleText = string.sub(currentLine, 1, math.floor(dialog.charIndex))
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.printf(visibleText, boxX + 20, boxY + 20, boxW - 40, "left")

    -- Line counter
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf(dialog.lineIndex .. "/" .. #dialogLines, boxX + 20, boxY + boxH - 25, boxW - 40, "right")

    -- Advance arrow (blinking)
    if dialog.waitingForInput then
        local arrowAlpha = math.sin(dialogArrowTimer * 5) * 0.3 + 0.7
        love.graphics.setColor(0.2, 0.2, 0.35, arrowAlpha)
        local arrowX = boxX + boxW - 30
        local arrowY = boxY + boxH - 25 + math.sin(dialogArrowTimer * 4) * 3
        love.graphics.polygon("fill", arrowX, arrowY, arrowX + 10, arrowY, arrowX + 5, arrowY + 8)
    end

    -- "Tap / Press Z" hint
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf("Z / Tap para continuar", boxX + 20, boxY + boxH - 25, boxW - 100, "left")
end

local function drawGround()
    -- Draw grass patches
    for _, g in ipairs(grass) do
        love.graphics.setColor(0.22 + g.shade, 0.32 + g.shade, 0.2 + g.shade * 0.5)
        love.graphics.circle("fill", g.x, g.y, g.size)
    end

    -- Draw a small path from left to right
    love.graphics.setColor(0.28, 0.25, 0.2, 0.4)
    for px = 0, 800, 20 do
        local py = 300 + math.sin(px * 0.01) * 15
        love.graphics.ellipse("fill", px, py, 15, 8)
    end
end

local function drawInteractPrompt()
    if not interactPrompt or dialog.active then return end

    local px = crystal.x
    local py = crystal.y - crystal.size - 30
    local bounce = math.sin(love.timer.getTime() * 4) * 3

    -- Background bubble
    love.graphics.setColor(0.15, 0.15, 0.25, 0.85)
    love.graphics.rectangle("fill", px - 55, py - 12 + bounce, 110, 24, 12, 12)
    love.graphics.setColor(0.3, 0.35, 0.55, 0.9)
    love.graphics.rectangle("line", px - 55, py - 12 + bounce, 110, 24, 12, 12)

    -- Text
    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Z / Tap objeto", px - 50, py - 7 + bounce, 100, "center")
end

local function drawParticles()
    for _, p in ipairs(particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.rotation)
        love.graphics.rectangle("fill", -p.size * 0.5, -p.size * 0.5, p.size, p.size)
        love.graphics.pop()
    end
end

local function drawTouchControls()
    -- Only show if no keyboard is likely available (always show a small hint)
    local alpha = 0.2
    if touchMove.active then alpha = 0.4 end

    -- D-pad area hint (bottom-left)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("line", 100, 500, 50)
    love.graphics.setColor(1, 1, 1, alpha * 0.5)
    -- Arrows
    love.graphics.polygon("fill", 100, 460, 93, 475, 107, 475) -- up
    love.graphics.polygon("fill", 100, 540, 93, 525, 107, 525) -- down
    love.graphics.polygon("fill", 60, 500, 75, 493, 75, 507) -- left
    love.graphics.polygon("fill", 140, 500, 125, 493, 125, 507) -- right

    -- Interact button hint (bottom-right)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("line", 700, 500, 30)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, alpha * 1.5)
    love.graphics.printf("TAP", 675, 495, 50, "center")
end

local function drawHUD()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 0.6)
    if crystal.broken then
        love.graphics.printf("El cristal se ha roto... pero sus palabras quedan.", 0, 10, 800, "center")
    elseif crystal.dialogDone then
        love.graphics.printf("El cristal esta cambiando...", 0, 10, 800, "center")
    elseif not crystal.interacted then
        love.graphics.printf("Muevete con WASD/Flechas - Acercate al cristal", 0, 10, 800, "center")
    end
end

function love.draw()
    love.graphics.push()

    -- Apply screen shake
    if screenShake.timer > 0 then
        local shakeX = (math.random() - 0.5) * 2 * screenShake.amount
        local shakeY = (math.random() - 0.5) * 2 * screenShake.amount
        love.graphics.translate(shakeX, shakeY)
    end

    -- Ground
    drawGround()

    -- Particles behind characters
    drawParticles()

    -- Crystal
    drawCrystal(crystal.x, crystal.y)

    -- Interact prompt
    drawInteractPrompt()

    -- Player
    drawPlayer(player.x, player.y)

    love.graphics.pop()

    -- UI elements (not affected by shake)
    drawDialogBox()
    drawTouchControls()
    drawHUD()
end

function love.keypressed(key)
    if key == "z" or key == "return" or key == "space" then
        if dialog.active then
            advanceDialog()
        elseif interactPrompt then
            startDialog()
        end
    end
end

-- Touch support
function love.touchpressed(id, x, y)
    -- Scale touch coordinates if window is resized
    local w, h = love.graphics.getDimensions()
    local sx = 800 / w
    local sy = 600 / h
    local tx = x * sx
    local ty = y * sy

    if dialog.active then
        -- Tap anywhere to advance dialog
        touchDialog.active = true
        touchDialog.id = id
        advanceDialog()
        return
    end

    -- Check if tapping near the crystal (to interact)
    if interactPrompt then
        local dist = distanceBetween(tx, ty, crystal.x, crystal.y)
        if dist < 80 then
            startDialog()
            return
        end
    end

    -- Movement touch (left half of screen primarily, but any non-crystal area)
    if not touchMove.active then
        touchMove.active = true
        touchMove.id = id
        touchMove.startX = tx
        touchMove.startY = ty
        touchMove.dx = 0
        touchMove.dy = 0
    end
end

function love.touchmoved(id, x, y)
    if touchMove.active and touchMove.id == id then
        local w, h = love.graphics.getDimensions()
        local sx = 800 / w
        local sy = 600 / h
        local tx = x * sx
        local ty = y * sy

        local ddx = tx - touchMove.startX
        local ddy = ty - touchMove.startY
        local len = math.sqrt(ddx * ddx + ddy * ddy)
        if len > 10 then
            touchMove.dx = ddx / len
            touchMove.dy = ddy / len
        else
            touchMove.dx = 0
            touchMove.dy = 0
        end
    end
end

function love.touchreleased(id)
    if touchMove.active and touchMove.id == id then
        touchMove.active = false
        touchMove.id = nil
        touchMove.dx = 0
        touchMove.dy = 0
    end
    if touchDialog.active and touchDialog.id == id then
        touchDialog.active = false
        touchDialog.id = nil
    end
end

-- Also support mouse as touch fallback for desktop testing
function love.mousepressed(x, y, button)
    if button == 1 then
        love.touchpressed("mouse", x, y)
    end
end

function love.mousemoved(x, y)
    if touchMove.active and touchMove.id == "mouse" then
        love.touchmoved("mouse", x, y)
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        love.touchreleased("mouse")
    end
end
