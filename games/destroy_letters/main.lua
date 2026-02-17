local letters = {}
local screenShake = { x = 0, y = 0 }
local allDestroyed = false
local victoryTimer = 0
local font = nil
local smallFont = nil
local hitSound = nil
local destroySound = nil

local function createHitSound()
    local sampleRate = 44100
    local duration = 0.15
    local samples = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)

    for i = 0, samples - 1 do
        local t = i / sampleRate
        local envelope = math.exp(-t * 20.0)
        local noise = (math.random() * 2.0 - 1.0) * 0.3
        local freq = 800.0 - (600.0 * t / duration)
        local pitch = math.sin(2.0 * math.pi * freq * t) * 0.2
        local sample = (noise + pitch) * envelope
        sample = math.max(-1.0, math.min(1.0, sample))
        soundData:setSample(i, sample)
    end

    return love.audio.newSource(soundData, "static")
end

local function createDestroySound()
    local sampleRate = 44100
    local duration = 0.3
    local samples = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)

    for i = 0, samples - 1 do
        local t = i / sampleRate
        local envelope = math.exp(-t * 8.0)
        local noise = (math.random() * 2.0 - 1.0) * 0.4
        local freq = 400.0 - (350.0 * t / duration)
        local pitch = math.sin(2.0 * math.pi * freq * t) * 0.3
        local sample = (noise + pitch) * envelope
        sample = math.max(-1.0, math.min(1.0, sample))
        soundData:setSample(i, sample)
    end

    return love.audio.newSource(soundData, "static")
end

local function createFragment(letter)
    local angle = math.random() * math.pi * 2.0
    local speed = math.random(50, 200)

    local fragment = {
        x = letter.x + (math.random() - 0.5) * letter.width,
        y = letter.y + (math.random() - 0.5) * letter.height,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed - 50.0,
        width = math.random(3, 8),
        height = math.random(3, 8),
        color = { letter.color[1], letter.color[2], letter.color[3] },
        alpha = 1.0,
        lifetime = math.random() * 0.5 + 0.5,
        age = 0,
        rotation = math.random() * math.pi * 2.0,
        rotationSpeed = (math.random() - 0.5) * 8.0,
    }

    table.insert(letter.fragments, fragment)
end

local function checkVictory()
    for _, letter in ipairs(letters) do
        if not letter.destroyed then
            return
        end
    end
    allDestroyed = true
    victoryTimer = 0
end

local function hitLetter(letter)
    letter.health = letter.health - 1

    if letter.health <= 0 then
        letter.destroyed = true
        letter.rotationSpeed = (math.random() - 0.5) * 10.0

        destroySound:stop()
        destroySound:play()

        screenShake.x = (math.random() - 0.5) * 16.0
        screenShake.y = (math.random() - 0.5) * 16.0

        for _ = 1, 12 do
            createFragment(letter)
        end

        checkVictory()
    else
        hitSound:stop()
        hitSound:play()

        letter.shake = 0.3

        screenShake.x = (math.random() - 0.5) * 8.0
        screenShake.y = (math.random() - 0.5) * 8.0

        local damageRatio = letter.health / letter.maxHealth
        letter.color = {
            1.0,
            damageRatio,
            damageRatio * 0.5,
        }

        for _ = 1, 4 do
            createFragment(letter)
        end
    end
end

local function createLettersFromLine(text, y)
    local totalWidth = 0
    local charWidths = {}
    local spacing = 2

    for i = 1, #text do
        local char = text:sub(i, i)
        local w = font:getWidth(char)
        charWidths[i] = w
        totalWidth = totalWidth + w
        if i < #text then
            totalWidth = totalWidth + spacing
        end
    end

    local currentX = 400.0 - totalWidth / 2.0
    local lineHeight = font:getHeight()

    for i = 1, #text do
        local char = text:sub(i, i)
        local w = charWidths[i]
        local health = math.random(3, 4)

        table.insert(letters, {
            char = char,
            x = currentX + w / 2.0,
            y = y,
            width = w,
            height = lineHeight,
            health = health,
            maxHealth = health,
            shake = 0,
            alpha = 1.0,
            destroyed = false,
            color = { 1.0, 1.0, 1.0 },
            rotation = 0,
            rotationSpeed = 0,
            fragments = {},
        })

        currentX = currentX + w + spacing
    end
end

function love.load()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.12)
    math.randomseed(os.time())

    font = love.graphics.newFont(48)
    smallFont = love.graphics.newFont(18)

    hitSound = createHitSound()
    destroySound = createDestroySound()

    letters = {}
    allDestroyed = false
    victoryTimer = 0
    screenShake = { x = 0, y = 0 }

    love.graphics.setFont(font)
    local lineHeight = font:getHeight()
    local centerY = 280.0

    createLettersFromLine("INTELIGENCIA", centerY - lineHeight * 0.6)
    createLettersFromLine("ARTIFICIAL", centerY + lineHeight * 0.6)
end

local function updateFragments(dt)
    for _, letter in ipairs(letters) do
        for i = #letter.fragments, 1, -1 do
            local frag = letter.fragments[i]
            frag.x = frag.x + frag.vx * dt
            frag.y = frag.y + frag.vy * dt
            frag.vy = frag.vy + 300.0 * dt
            frag.rotation = frag.rotation + frag.rotationSpeed * dt
            frag.age = frag.age + dt
            frag.alpha = 1.0 - (frag.age / frag.lifetime)

            if frag.age >= frag.lifetime then
                table.remove(letter.fragments, i)
            end
        end
    end
end

function love.update(dt)
    screenShake.x = screenShake.x * math.max(0, 1.0 - dt * 10.0)
    screenShake.y = screenShake.y * math.max(0, 1.0 - dt * 10.0)

    for _, letter in ipairs(letters) do
        if letter.shake > 0 then
            letter.shake = letter.shake - dt
        end

        if letter.destroyed and letter.alpha > 0 then
            letter.alpha = letter.alpha - dt * 2.0
            letter.rotation = letter.rotation + letter.rotationSpeed * dt
            if letter.alpha < 0 then
                letter.alpha = 0
            end
        end
    end

    updateFragments(dt)

    if allDestroyed then
        victoryTimer = victoryTimer + dt
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(screenShake.x, screenShake.y)

    -- Draw fragments behind letters
    for _, letter in ipairs(letters) do
        for _, frag in ipairs(letter.fragments) do
            love.graphics.push()
            love.graphics.translate(frag.x, frag.y)
            love.graphics.rotate(frag.rotation)
            love.graphics.setColor(frag.color[1], frag.color[2], frag.color[3], frag.alpha)
            love.graphics.rectangle("fill", -frag.width / 2.0, -frag.height / 2.0, frag.width, frag.height)
            love.graphics.pop()
        end
    end

    -- Draw letters
    love.graphics.setFont(font)
    for _, letter in ipairs(letters) do
        if letter.alpha > 0 then
            love.graphics.push()

            local drawX = letter.x
            local drawY = letter.y

            if letter.shake > 0 then
                drawX = drawX + (math.random() - 0.5) * 6.0
                drawY = drawY + (math.random() - 0.5) * 6.0
            end

            love.graphics.translate(drawX, drawY)
            love.graphics.rotate(letter.rotation)
            love.graphics.setColor(letter.color[1], letter.color[2], letter.color[3], letter.alpha)
            love.graphics.print(letter.char, -letter.width / 2.0, -letter.height / 2.0)

            love.graphics.pop()
        end
    end

    love.graphics.pop()

    -- Victory message
    if allDestroyed then
        local pulse = (math.sin(victoryTimer * 3.0) + 1.0) / 2.0

        love.graphics.setFont(font)
        love.graphics.setColor(0.5 + pulse * 0.5, 1.0, 0.5 + pulse * 0.5, math.min(1.0, victoryTimer))
        love.graphics.printf("DESTRUIDO!", 0, 260, 800, "center")

        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.7, 0.7, 0.7, math.min(1.0, victoryTimer - 0.5))
        love.graphics.printf("Click para reiniciar", 0, 330, 800, "center")
    end

    -- Instructions
    if not allDestroyed then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("Haz clic en las letras para destruirlas", 0, 560, 800, "center")
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end

    if allDestroyed then
        love.load()
        return
    end

    -- Adjust click position for screen shake
    local adjX = x - screenShake.x
    local adjY = y - screenShake.y

    for i = #letters, 1, -1 do
        local letter = letters[i]
        if not letter.destroyed then
            local halfW = letter.width / 2.0
            local halfH = letter.height / 2.0

            if adjX >= letter.x - halfW and
               adjX <= letter.x + halfW and
               adjY >= letter.y - halfH and
               adjY <= letter.y + halfH then
                hitLetter(letter)
                return
            end
        end
    end
end
