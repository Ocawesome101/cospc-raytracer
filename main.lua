-- raytracer, maybe? --

local w, h = term.getSize(2)

local texWidth, texHeight = 64, 64

local SCALE = jit and 1 or 4

local world = {}
local textures = {}

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

local lastSetPal = 0
local function loadTexture(id, file)
  textures[id] = {}
  local tex = textures[id]
  local n = 0
  local handle = assert(io.open(shell.dir().."/textures/"..file))
  local palConv = {}
  local palLen = handle:read(1):byte()
  local r = 0
  local eq = 0
  while r < palLen do
    r = r + 4
    local colID = handle:read(1):byte()
    local rgb = string.unpack("<I3", handle:read(3))
    for i=0, lastSetPal, 1 do
      local mr, mg, mb = term.getPaletteColor(i)
      mr, mg, mb = mr * 255, mg * 255, mb * 255
      local r, g, b = bit32.band(rgb, 0xff0000), bit32.band(rgb, 0x00ff00),
        bit32.band(rgb, 0x0000ff)
      if math.floor(r/16) == math.floor(mr/16) and
         math.floor(b/16) == math.floor(mb/16) and
         math.floor(g/16) == math.floor(mg/16) then
        palConv[colID] = i
        eq = eq + 1
        break
      end
    end
    if not palConv[colID] then
      lastSetPal = lastSetPal + 2
      assert(lastSetPal < 256, "too many texture colors!")
      term.setPaletteColor(lastSetPal - 1,
        bit32.band(bit32.rshift(rgb, 1), 8355711))
      term.setPaletteColor(lastSetPal, rgb)
      palConv[colID] = lastSetPal
    end
  end
  repeat
    local byte = handle:read(1)
    if byte then
      tex[n] = palConv[string.byte(byte)]
      n = n + 1
    end
  until not byte
  handle:close()
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
    local color

    local tex = textures[hit]
    if (not tex) or #tex < texWidth*texHeight-2 then
      color = hit + side
      if hit == 0xf then color = 0xf end
      if color > 0xf then color = color - 0xf end
    else
      local wallX, wallY
      if side == 0 then wallX = posY + perpWallDist * rayDirY
        else wallX = posX + perpWallDist * rayDirX end
      wallY = posZ + perpWallDist * rayDirZ

      local texX = math.floor(wallX * texWidth)
      local texY = math.floor(wallY * texHeight)
      --if side == 0 and rayDirX > 0 then texX = texWidth - texX - 1 end
      --if side == 1 and rayDirY < 0 then texX = texWidth - texX - 1 end
      --if side == 2 and rayDirZ > 0 then texY = texHeight - texY - 1 end
      if math.abs(texX) >= texWidth then texX = texX % texWidth end
      if math.abs(texY) >= texHeight then texY = texY % texHeight end
      --print(texX, texY)

      local texPos = texX + (texY * texHeight)

      if side == 2 then color = 2
        else color = tex[math.floor(texPos)] or 0 end
    end

    for i=1, SCALE, 1 do
      drawBuf[y*SCALE+i-1] = drawBuf[y*SCALE+i-1] .. string.char(color):rep(SCALE)
    end
  end

  return perpWallDist, hit
end

local pressed = {}
local moveZ = 0

term.setGraphicsMode(2)

loadTexture(1, "bluestone.tex")
loadTexture(2, "wood.tex")
loadTexture(3, "eagle.tex")
loadTexture(4, "purplestone.tex")
loadTexture(5, "redbrick.tex")
loadTexture(6, "greystone.tex")
loadTexture(7, "colorstone.tex")

local drawBuf = {}
local oldtime, time
local lastTimerID
local ftavg = 0
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
  ftavg = (ftavg + frametime) / (ftavg == 0 and 1 or 2)
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
  elseif distZ > 1/SCALE then
    moveZ = math.max(-0.1*SCALE, moveZ - 0.0075)
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
    if dist > 0.8/SCALE then
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
    if dist > 0.8/SCALE then
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
print(string.format("Average frametime: %.2fms\nAverage FPS: %.2f", ftavg*1000, 1/ftavg))
