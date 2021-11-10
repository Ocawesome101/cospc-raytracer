-- raytracer, maybe? --

local w, h = term.getSize(2)

local world = {}

do
  local _world = {[0]={}}
  local wn, rn = 0, 0
  for line in io.lines(shell.dir().."/world.txt") do
    if line == "" then
      wn = wn + 1
      _world[wn] = {}
      rn = 0
    else
      _world[wn][rn] = {}
      local cn = 0
      for c in line:gmatch(".") do
        _world[wn][rn][cn] = tonumber("0x"..c) or 0
        cn = cn + 1
      end
      rn = rn + 1
    end
  end

  for i=#_world, 0, -1 do
    world[#_world - i] = _world[i]
  end
end

-- x = forward/backward, y=left/right, z=up/down
local posX, posY, posZ = 5, 5, 3
local dirX, dirY, dirZ = -1, 0, 0
local planeX, planeY, planeZ = 0, 0.90, 0.90

local function castRay(x,y,dx,dy,dz,drawBuf)
  local mapX = math.floor(posX + 0.5)
  local mapY = math.floor(posY + 0.5)
  local mapZ = math.floor(posZ + 0.5)
  
  local cameraX = 2 * x / w - 1
  local cameraZ = 2 * y / h - 1
  local rayDirX = dx + planeX * cameraX
  local rayDirY = dy + planeY * cameraX
  local rayDirZ = dz + planeZ * cameraZ

  local sideDistX, sideDistY, sideDistZ

  local deltaDistX = rayDirX == 0 and 1e30 or math.abs(1 / rayDirX)
  local deltaDistY = rayDirY == 0 and 1e30 or math.abs(1 / rayDirY)
  local deltaDistZ = rayDirZ == 0 and 1e30 or math.abs(1 / rayDirZ)
  local perpWallDist

  local stepX, stepY, stepZ

  local hit = false
  local side

  if rayDirX < 0 then
    stepX = -1
    sideDistX = (posX - mapX) * deltaDistX
  else
    stepX = 1
    sideDistX = (mapX + 1 - posX) * deltaDistX
  end
  
  if rayDirY < 0 then
    stepY = -1
    sideDistY = (posY - mapY) * deltaDistY
  else
    stepY = 1
    sideDistY = (mapY + 1 - posY) * deltaDistY
  end
  
  if rayDirZ < 0 then
    stepZ = -1
    sideDistZ = (posZ - mapZ) * deltaDistZ
  else
    stepZ = 1
    sideDistZ = (mapZ + 1 - posZ) * deltaDistZ
  end

  while not hit do
    if sideDistX < sideDistY then
      if sideDistX < sideDistZ then
        sideDistX = sideDistX + deltaDistX
        mapX = mapX + stepX
        side = 0
      else
        sideDistZ = sideDistZ + deltaDistZ
        mapZ = mapZ + stepZ
        side = 2
      end
    elseif sideDistY < sideDistZ then
      sideDistY = sideDistY + deltaDistY
      mapY = mapY + stepY
      side = 1
    else
      sideDistZ = sideDistZ + deltaDistZ
      mapZ = mapZ + stepZ
      side = 2
    end
    
    if not (world[mapZ] and world[mapZ][mapY] and world[mapZ][mapY][mapX]) then
      hit = 0xf
    elseif world[mapZ][mapY][mapX] ~= 0 then
      hit = world[mapZ][mapY][mapX]
    end
  end

  if side == 0 then perpWallDist = (sideDistX - deltaDistX)
  elseif side == 1 then perpWallDist = (sideDistY - deltaDistY)
  else perpWallDist = (sideDistZ - deltaDistZ) end

  if drawBuf then
    local color = hit + side
    if hit == 0xf then color = 0xf end
    if color > 0xf then color = color - 0xf end

    drawBuf[y] = drawBuf[y] .. string.char(color)
  end

  return perpWallDist, hit
end

term.setGraphicsMode(2)
local drawBuf = {}
local oldtime, time = 0
while true do
  for i=0, h, 1 do drawBuf[i] = "" end

  for y = 0, h, 1 do
    for x = 0, w, 1 do
      castRay(x, y, dirX, dirY, dirZ, drawBuf)
    end
  end
  oldTime = time or 0
  time = os.epoch("utc")
  local frametime = (time - oldTime) / 1000
  moveSpeed = frametime
  rotSpeed = frametime / 8
  term.drawPixels(0, 0, drawBuf)

  os.sleep(0.05)

  -- [[
  -- rotate right
  local oldDirX = dirX
  dirX = dirX * math.cos(-rotSpeed) - dirY * math.sin(-rotSpeed)
  dirY = oldDirX * math.sin(-rotSpeed) + dirY * math.cos(-rotSpeed)
  local oldPlaneX = planeX
  planeX = planeX * math.cos(-rotSpeed) - planeY * math.sin(-rotSpeed)
  planeY = oldPlaneX * math.sin(-rotSpeed) + planeY * math.cos(-rotSpeed)
  --]]
  -- move backwards
  --posX = posX - dirX * moveSpeed
  --posY = posY - dirY * moveSpeed
  --posZ = posZ - dirZ * moveSpeed

  -- move up
  --posZ = posZ + moveSpeed

  --[[ rotate down
  local oldDirX = dirX
  local oldPlaneX = planeX
  dirX = dirX * math.cos(-rotSpeed) - dirZ * math.sin(-rotSpeed)
  dirZ = oldDirX * -math.cos(-rotSpeed) + dirZ * math.cos(-rotSpeed)
  planeX = planeX * math.cos(-rotSpeed) - dirZ * math.sin(-rotSpeed)
  planeZ = oldPlaneX * -math.cos(-rotSpeed) + dirZ * math.cos(-rotSpeed)
  --]]
end
term.setGraphicsMode(0)
