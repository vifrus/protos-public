local balls = {}
local gravity = 500
local damping = 0.8
local colors = {
    {1, 0.3, 0.3},
    {0.3, 1, 0.3},
    {0.3, 0.3, 1},
    {1, 1, 0.3},
    {1, 0.3, 1},
    {0.3, 1, 1},
}

local function newBall(x, y)
    return {
        x = x,
        y = y,
        vx = (math.random() - 0.5) * 400,
        vy = (math.random() - 0.5) * 200,
        radius = math.random(10, 25),
        color = colors[math.random(#colors)],
        trail = {},
    }
end

function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    math.randomseed(os.time())

    -- Start with a few balls
    for i = 1, 3 do
        table.insert(balls, newBall(
            math.random(100, 700),
            math.random(50, 200)
        ))
    end

    font = love.graphics.newFont(16)
end

function love.update(dt)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    for _, ball in ipairs(balls) do
        -- Apply gravity
        ball.vy = ball.vy + gravity * dt

        -- Update position
        ball.x = ball.x + ball.vx * dt
        ball.y = ball.y + ball.vy * dt

        -- Bounce off walls
        if ball.x - ball.radius < 0 then
            ball.x = ball.radius
            ball.vx = -ball.vx * damping
        elseif ball.x + ball.radius > w then
            ball.x = w - ball.radius
            ball.vx = -ball.vx * damping
        end

        -- Bounce off floor and ceiling
        if ball.y + ball.radius > h then
            ball.y = h - ball.radius
            ball.vy = -ball.vy * damping
        elseif ball.y - ball.radius < 0 then
            ball.y = ball.radius
            ball.vy = -ball.vy * damping
        end

        -- Update trail
        table.insert(ball.trail, {x = ball.x, y = ball.y})
        if #ball.trail > 15 then
            table.remove(ball.trail, 1)
        end
    end
end

function love.draw()
    -- Draw trails
    for _, ball in ipairs(balls) do
        for i, pos in ipairs(ball.trail) do
            local alpha = i / #ball.trail * 0.3
            love.graphics.setColor(ball.color[1], ball.color[2], ball.color[3], alpha)
            local r = ball.radius * (i / #ball.trail) * 0.6
            love.graphics.circle("fill", pos.x, pos.y, r)
        end
    end

    -- Draw balls
    for _, ball in ipairs(balls) do
        love.graphics.setColor(ball.color)
        love.graphics.circle("fill", ball.x, ball.y, ball.radius)

        -- Highlight
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.circle("fill", ball.x - ball.radius * 0.3,
                             ball.y - ball.radius * 0.3, ball.radius * 0.4)
    end

    -- Instructions
    love.graphics.setFont(font)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Click to add balls! (" .. #balls .. " balls)",
                         0, 15, love.graphics.getWidth(), "center")
end

function love.mousepressed(x, y, button)
    if button == 1 then
        table.insert(balls, newBall(x, y))
    end
end
