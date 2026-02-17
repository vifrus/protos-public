local timer = 0
local mouseX, mouseY = 400, 300

function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.2)
    font = love.graphics.newFont(32)
    smallFont = love.graphics.newFont(18)
end

function love.update(dt)
    timer = timer + dt
    mouseX, mouseY = love.mouse.getPosition()
end

function love.draw()
    -- Pulsing color text
    local r = (math.sin(timer * 2) + 1) / 2
    local g = (math.sin(timer * 3 + 1) + 1) / 2
    local b = (math.sin(timer * 4 + 2) + 1) / 2

    love.graphics.setFont(font)
    love.graphics.setColor(r, g, b)
    love.graphics.printf("Hello from LOVE!", 0, 100, love.graphics.getWidth(), "center")

    -- Rotating rectangle following mouse
    love.graphics.push()
    love.graphics.translate(mouseX, mouseY)
    love.graphics.rotate(timer)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("fill", -25, -25, 50, 50)
    love.graphics.pop()

    -- Orbiting circles
    for i = 1, 5 do
        local angle = timer * (0.5 + i * 0.3) + i * math.pi * 2 / 5
        local radius = 80 + i * 15
        local cx = mouseX + math.cos(angle) * radius
        local cy = mouseY + math.sin(angle) * radius
        love.graphics.setColor(r, g, b, 0.6)
        love.graphics.circle("fill", cx, cy, 8)
    end

    -- Instructions
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Move your mouse!", 0, love.graphics.getHeight() - 50,
                         love.graphics.getWidth(), "center")
end
