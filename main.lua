-- raytracer, maybe? --

local w, h = term.getSize(2)

local SCALE = jit and 1 or 4

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
local posX, posY, posZ = 5.3, 5, 3
local dirX, dirY, dirZ = 1, 0, 0
local planeX, planeY, planeZ = 0, 0.66, 0.66

local function castRay(x,y,dx,dy,dz,drawBuf)
  local mapX = math.floor(posX + 0.5)
  local mapY = math.floor(posY + 0.5)
  local mapZ = math.floor(posZ + 0.5)
  
  local cameraX = 2 * x / math.floor(w/SCALE) - 1
  local cameraZ = 2 * y / math.floor(h/SCALE) - 1
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

    for i=1, SCALE, 1 do
      drawBuf[y*SCALE+i-1] = drawBuf[y*SCALE+i-1] .. string.char(color):rep(SCALE)
    end
  end

  return perpWallDist, hit
end

local pressed = {}
local moveZ = 0

term.setGraphicsMode(2)
local drawBuf = {}
local oldtime, time = 0
local lastTimerID
while true do
  for i=0, h, 1 do drawBuf[i] = "" end

  for y = 0, math.floor(h/SCALE), 1 do
    for x = 0, math.floor(w/SCALE), 1 do
      castRay(x, y, dirX, dirY, dirZ, drawBuf)
    end
  end
  oldTime = time or os.epoch("utc")
  time = os.epoch("utc")
  local frametime = (time - oldTime) / 1000
  moveSpeed = frametime * 7
  rotSpeed = frametime * 3
  term.drawPixels(0, 0, drawBuf)

  --os.sleep(0.01)
  if not lastTimerID then
    lastTimerID = os.startTimer(0)
  end
  local sig, code, rep = os.pullEventRaw()
  if sig == "terminate" then break end
  if sig == "timer" and code == lastTimerID then
    lastTimerID = nil
  elseif sig == "key" and not rep then
    pressed[code] = true
  elseif sig == "key_up" then
    pressed[code] = false
  end

  local distZ, tile = castRay(math.floor(w*0.5), math.floor(h*0.5), 0, 0, 1)
  local pdistZ, _tile = castRay(math.floor(w*0.5), math.floor(h*0.5), 0, 0, -1)
  local oldMoveZ = moveZ
  if distZ <= 1/SCALE and moveZ < 0 and tile ~= 0xf then
    if pressed[keys.space] then
      moveZ = 0.2
    else
      moveZ = 0
    end
  elseif pdistZ <= 1/SCALE and moveZ > 0 and _tile ~= 0xf then
    moveZ = 0
  elseif distZ > 1 then
    moveZ = math.max(-0.1, moveZ - 0.01*SCALE) --moveZ - moveSpeed
  elseif pressed[keys.space] then
    moveZ = 0.2
  end
  posZ = posZ - moveZ

  if pressed[keys.w] then
    local nposX = posX + dirX * moveSpeed
    local nposY = posY + dirY * moveSpeed
    local dist = math.min(
      castRay(math.floor(w * 0.5), math.floor(h * 0.5), dirX, dirY, 0),
      castRay(math.floor(w * 0.75), math.floor(h * 0.5), dirX, dirY, 0),
      castRay(math.floor(w * 0.25), math.floor(h * 0.5), dirX, dirY, 0))
    if dist > 0.8 then
      posX, posY = nposX, nposY
    end
  end
  if pressed[keys.s] then
    local nposX = posX - dirX * moveSpeed
    local nposY = posY - dirY * moveSpeed
    local dist = math.min(
      castRay(math.floor(w * 0.5), math.floor(h * 0.5), -dirX, -dirY, 0),
      castRay(math.floor(w * 0.75), math.floor(h * 0.5), -dirX, -dirY, 0),
      castRay(math.floor(w * 0.25), math.floor(h * 0.5), -dirX, -dirY, 0))
    if dist > 0.8 then
      posX, posY = nposX, nposY
    end
  end
  --[[
  if pressed[keys.a] then
    local _dirX = dirX * math.cos(-90) - dirY * math.sin(-90)
    local _dirY = dirX * math.sin(-90) + dirY * math.cos(-90)

    local nposX = posX + _dirX * moveSpeed
    local nposY = posY + _dirY * moveSpeed
    
    local dist = math.min(
      castRay(math.floor(w * 0.5), math.floor(h * 0.5), -_dirX, _dirY, 0),
      castRay(math.floor(w * 0.75), math.floor(h * 0.5), -_dirX, _dirY, 0),
      castRay(math.floor(w * 0.25), math.floor(h * 0.5), -_dirX, _dirY, 0))
    if dist >= 0.8 then
      posX, posY = nposX, nposY
    end
  end
  if pressed[keys.d] then
    local _dirX = dirX * math.cos(90) - dirY * math.sin(90)
    local _dirY = dirX * math.sin(90) + dirY * math.cos(90)

    local nposX = posX - _dirX * moveSpeed
    local nposY = posY - _dirY * moveSpeed
    
    local dist = math.min(
      castRay(math.floor(w * 0.5), math.floor(h * 0.5), -_dirX, -_dirY, 0),
      castRay(math.floor(w * 0.75), math.floor(h * 0.5), -_dirX, -_dirY, 0),
      castRay(math.floor(w * 0.25), math.floor(h * 0.5), -_dirX, -_dirY, 0))
    if dist >= 0.8 then
      posX, posY = nposX, nposY
    end
  end
  --]]
  if pressed[keys.left] then
    local oldDirX = dirX
    dirX = dirX * math.cos(-rotSpeed) - dirY * math.sin(-rotSpeed)
    dirY = oldDirX * math.sin(-rotSpeed) + dirY * math.cos(-rotSpeed)
    local oldPlaneX = planeX
    planeX = planeX * math.cos(-rotSpeed) - planeY * math.sin(-rotSpeed)
    planeY = oldPlaneX * math.sin(-rotSpeed) + planeY * math.cos(-rotSpeed)
  end
  if pressed[keys.right] then
    local oldDirX = dirX
    dirX = dirX * math.cos(rotSpeed) - dirY * math.sin(rotSpeed)
    dirY = oldDirX * math.sin(rotSpeed) + dirY * math.cos(rotSpeed)
    local oldPlaneX = planeX
    planeX = planeX * math.cos(rotSpeed) - planeY * math.sin(rotSpeed)
    planeY = oldPlaneX * math.sin(rotSpeed) + planeY * math.cos(rotSpeed)
  end
end
term.setGraphicsMode(0)
