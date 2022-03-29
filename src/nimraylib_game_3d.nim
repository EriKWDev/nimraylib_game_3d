
import std/[random, math, strformat]

import timings

import nimraylib_now as raylib
import easyess


func vec3(x, y, z: float): Vector3 {.inline.} = Vector3(x: x, y: y, z: z)
func vec2(x, y: float): Vector2 {.inline.} = Vector2(x: x, y: y)
func rect(x, y, w, h: float): Rectangle {.inline.} = Rectangle(x: x, y: y, width: w, height: h)
func rgba(r, g, b, a: uint8): Color{.inline.} = Color(r: r, g: g, b: b, a: a)
func clamp01(a: Vector3): Vector3 {.inline.} = vec3(a.x.clamp(0.0, 1.0), a.y.clamp(0.0, 1.0), a.z.clamp(0.0, 1.0))



converter toColor(vec: Vector3): Color =
  let tmp = vec * 255
  rgba(tmp.x.uint8, tmp.y.uint8, tmp.z.uint8, 255)

type
  Game = ref object
    camera: Camera3D
    deltaTime: float

  RenderableMode = enum
    rmNormal, rmWireframe

  LightKind = enum
    lkPoint, lkDirectional

comp:
  type
    Position = Vector3

    Velocity = Vector3

    Light = object
      id: int
      color: Vector3
      shader: Shader

      colorLoc: cint
      viewLoc: cint

      case kind: LightKind
      of lkPoint:
        positionLoc: cint
      of lkDirectional:
        direction: Vector3
        directionLoc: cint

    Sphere = object
      radius: float
      tint: Color

    Renderable = object
      model: Model
      mode: RenderableMode
      tint: Color
      scale: float

    CameraData = object
      target: Vector3
      up: Vector3
      fovy: float
      projection: CameraProjection


sys [Position, Velocity], "logicSystems":
  proc moveSystem(item: Item, game: Game) =
    position += velocity * game.deltaTime * 10.0
    velocity *= max(min(1.0, game.deltaTime * 8.0), 0.98)

    if abs(velocity.x) < 0.1 and abs(velocity.y) < 0.1 and abs(velocity.z) < 0.1:
      velocity = vec3(rand(-1.0 .. 1.0), rand(-1.0 .. 1.0), rand(-1.0 .. 1.0))

sys [Position, Light], "logicSystems":
  proc moveLight(item: Item) =
    case light.kind
    of lkPoint:
      let
        t0 = light.id.toFloat() * 1.3
        t1 = (sin(getTime()*0.4+t0) + 1.0)/2.0
        t2 = (cos(getTime()*0.3+t0) + 1.0)/2.0
        t5 = ((getTime() + t0 * 8.0) mod 255.0)/255.0
        imod3 = light.id mod 3

      if imod3 == 0:
        light.color = vec3(t5, t2, 1.0 - t5) * 2.0
        position = vec3(1.0-t1, t2, t1) * 28.0
      else:
        light.color = vec3(t5, t2*t1*t5, 1.0-t5) * 2.0
        position = vec3(1.0-t1, t2*t1, 1.0-t1) * 25.0

    else: discard

var sunDirection = vec3(-0.4, -1.0, 0.2)

sys [Light], "renderSystems":
  proc setLightValues(item: Item) =
    light.shader.setShaderValue(light.colorLoc, light.color.addr, VEC3)

    case light.kind
    of lkDirectional:
      light.direction = vec3(sunDirection.x, -sunDirection.y, sunDirection.z)
      light.shader.setShaderValue(light.directionLoc, light.direction.addr, VEC3)
    else: discard

sys [Position, Light], "renderSystems":
  proc renderLight(item: Item) =
    case light.kind
    of lkPoint:
      light.shader.setShaderValue(light.positionLoc, position.addr, VEC3)

      let tmp = (light.color + vec3(1.0, 1.0, 1.0) * 0.3).clamp01()
      drawSphere(position, 0.4, tmp)
    else: discard

sys [Position, Sphere], "renderSystems":
  proc renderSphereSystem(item: Item) =
    drawSphereWires(position, sphere.radius, 5, 5, sphere.tint)

sys [Position, Renderable], "renderSystems":
  proc renderRenderableSystem(item: Item) =
    case renderable.mode
    of rmNormal: renderable.model.drawModel(position, renderable.scale, renderable.tint)
    of rmWireframe: renderable.model.drawModel(position, renderable.scale, renderable.tint)

createECS(ECSConfig(maxEntities: 5000))

var
  mouseAngles = vec2(0.0, 0.0)
  cameraAngles = mouseAngles
  mouseDistance = 10.0
  cameraDistance = mouseDistance
  inputTargetPos = vec3(0.0, 0.0, 0.0)
  paused = false

proc update(camera: var Camera) =
  if paused:
    if isKeyPressed(KeyboardKey.P):
      paused = false
      disableCursor()
    else:
      return
  else:
    if isKeyPressed(KeyboardKey.P):
      paused = true
      enableCursor()
      return

  mouseAngles += getMouseDelta() * 0.005
  mouseAngles.y = clamp(mouseAngles.y, 0.5 * PI, 1.5 * PI)

  # x = cos(yaw)*cos(pitch)`
  # y = sin(yaw)*cos(pitch)
  # z = sin(pitch`)

  let t = getFrameTime() * 8.0

  cameraAngles = cameraAngles * (1.0 - t) + mouseAngles * t

  let
    direction = vec3(
      sin(-cameraAngles.x),
      sin(cameraAngles.y),
      cos(-cameraAngles.x)
    )

  # drawLine(vec3(0.0, 0.0, 0.0), direction * cameraDistance, BLUE)

  mouseDistance -= getMouseWheelMove()

  if mouseDistance < 1.0:
    mouseDistance = 1.0

  if isKeyDown(KeyboardKey.W):
    inputTargetPos += direction * 0.5

  if isKeyDown(KeyboardKey.S):
    inputTargetPos -= direction * 0.5


  if isKeyDown(KeyboardKey.E): inputTargetPos += vec3(0.0, 1.0, 0.0)
  if isKeyDown(KeyboardKey.Q): inputTargetPos -= vec3(0.0, 1.0, 0.0)

  cameraDistance = cameraDistance * (1.0 - t) + mouseDistance * t

  camera.target = camera.target * (1.0 - t) + inputTargetPos * t
  camera.position = camera.target + vec3(1.0, 1.0, 1.0) * -direction * cameraDistance


const
  n = 100
  maxLights = 40
  maxDirectionalLights = 1

proc main() =
  setConfigFlags(MSAA_4X_HINT or WINDOW_RESIZABLE)

  initWindow(800, 800, "3D game")
  setTargetFPS 120

  let
    ecs = newECS()
    box = loadModel("assets/round_box.glb")
    worldModel = loadModel("assets/sponza/Sponza.gltf")
    # waterBottle = loadModel("assets/waterbottle/WaterBottle.gltf")

    lightShader = loadShader("assets/shaders/base_lighting.vs", "assets/shaders/base_lighting.fs")
    lightViewLoc = lightShader.getShaderLocation("viewPos")
    lightDepthLoc = lightShader.getShaderLocation("lightDepth")
    lightMatrixLoc = lightShader.getShaderLocation("lightSpaceMatrix")

    depthShader = loadShader("", "assets/shaders/depth.fs")

    postProcessShader = loadShader("", "assets/shaders/bloom.fs")
    bufferSizeLocation = getShaderLocation(postProcessShader, "bufferSize")

  lightShader.locs[VECTOR_VIEW.ord()] = lightViewLoc
  lightShader.locs[MATRIX_MODEL.ord()] = lightShader.getShaderLocation("matModel")
  lightShader.locs[MAP_ALBEDO.ord()] = lightShader.getShaderLocation("texture0")

  var
    width = getScreenWidth()
    height = getScreenHeight()
    target = loadRenderTexture(width, height)
    sunlightTexture = loadRenderTexture(600, 600)
    size = vec2(width.toFloat(), height.toFloat())

    sun: Entity

  postProcessShader.setShaderValue(bufferSizeLocation, size.addr, VEC2)

  # loadTextureCubemap()

  for i in 0 ..< maxDirectionalLights:
    let
      lightDirectionLoc = lightShader.getShaderLocation(&"directionalLights[{i}].direction")
      lightColorLoc = lightShader.getShaderLocation(&"directionalLights[{i}].color")

    discard ecs.createEntity("Sun"): (
      Light(
        kind: lkDirectional,
        id: i,
        color: vec3(1.0, 1.0, 1.0),
        direction: vec3(0.0, 1.0, 0.0),
        shader: lightShader,
        colorLoc: lightColorLoc,
        directionLoc: lightDirectionLoc
      )
    )

  for i in 0 ..< maxLights:
    let
      lightPositionLoc = lightShader.getShaderLocation(&"lights[{i}].position")
      lightColorLoc = lightShader.getShaderLocation(&"lights[{i}].color")

    sun = ecs.createEntity("Light"): (
      Light(
        kind: lkPoint,
        id: i,
        color: vec3(1.0, 1.0, 1.0),
        shader: lightShader,
        colorLoc: lightColorLoc,
        positionLoc: lightPositionLoc,
        viewLoc: lightViewLoc
      ),
      [Position]vec3(0.0, 0.0, 0.0),
    )

  box.materials[0].shader = lightShader

  for i in 0 .. worldModel.materialCount:
    worldModel.materials[i].shader = lightShader

  discard ecs.createEntity("World Model"): (
    Renderable(
      model: worldModel,
      tint: WHITE,
      mode: rmNormal,
      scale: 0.035
    ),
    [Position]vec3(10, -5, 10),
  )

  for i in 0 .. n:
    discard ecs.createEntity("Model"): (
      Renderable(
        model: box,
        tint: WHITE,
        mode: rmNormal,
        scale: rand(0.1 .. 1.2)
      # tint: rgba(rand(80..255).uint8, rand(80..255).uint8, rand(80..255).uint8, 255),
    ),
      [Position]vec3(rand(-1.0..1.0), rand(-1.0..1.0), rand(-1.0..1.0)) * 3.0,
      [Velocity]vec3(0.0, 0.0, 0.0)
    )

  let game = Game.new()

  game.camera = Camera3D(
    position: vec3(10.0, 15.0, 10.0),
    target: vec3(10.0, 5.0, 10.0),
    up: vec3(0.0, 1.0, 0.0),
    fovy: 95.0,
    projection: PERSPECTIVE
  )
  disableCursor()

  var
    targetRect = rect(0, 0, target.texture.width.toFloat(), -target.texture.height.toFloat())
    extraRect = rect(0, 0, sunlightTexture.texture.width.toFloat(), sunlightTexture.texture.height.toFloat())

  while not windowShouldClose():
    let
      newWidth = getScreenWidth()
      newHeight = getScreenHeight()


    if newWidth != width or newHeight != height:
      width = newWidth
      height = newHeight
      size = Vector2(x: width.toFloat(), y: height.toFloat())
      postProcessShader.setShaderValue(bufferSizeLocation, size.addr, VEC2)

      unloadRenderTexture(target)
      target = loadRenderTexture(width, height)
      targetRect = rect(0, 0, target.texture.width.toFloat(), -target.texture.height.toFloat())

    game.camera.update()

    game.deltaTime = getFrameTime()

    timeIt "logic systems":
      ecs.runLogicSystems(game)

    var sunlightMatrix: Matrix

    timeIt "sunlight pass":
      let oldCamera = game.camera

      game.camera.projection = ORTHOGRAPHIC
      game.camera.position = -sunDirection * 100.0
      game.camera.target = game.camera.position + sunDirection
      game.camera.fovy = 120

      sunlightMatrix = game.camera.getCameraMatrix()

      beginTextureMode(sunlightTexture):
        clearBackground(BLACK)

        beginMode3D(game.camera):
          ecs.runRenderSystems()

      game.camera = oldCamera

    lightShader.setShaderValue(lightDepthLoc, sunlightTexture.depth.addr, SAMPLER2D)
    lightShader.setShaderValueMatrix(lightMatrixLoc, sunlightMatrix)

    timeIt "camera pass":
      beginTextureMode(target):
        clearBackground(BLACK)

        beginMode3D(game.camera):
          ecs.runRenderSystems()

    timeIt "post-processing + gui pass":
      beginDrawing():
        clearBackground(BLACK)

        # beginShaderMode(postProcessShader):
        drawTextureRec(target.texture, targetRect, vec2(0, 0), WHITE)

        let sunRect = rect(0, 0, extraRect.width, -extraRect.height)

        beginShaderMode(depthShader):
          drawTextureRec(sunlightTexture.texture, sunRect, vec2(0.0, 0.0), WHITE)

        drawFPS 10, 5

        sunDirection = vec3(
          slider(rect(20, 30, 300, 15), "x", "", sunDirection.x, -1.0, 1.0),
          slider(rect(20, 50, 300, 15), "y", "", sunDirection.y, -1.0, 1.0),
          slider(rect(20, 70, 300, 15), "z", "", sunDirection.z, -1.0, 1.0)
        )

        for i, timing in getTimings():
          let
            theDelta = $timing.delta & " ms"
            y = 100 + i * 20

          drawText(timing.name, 10, y, 20, WHITE)
          drawText(theDelta, 12 * longestName, y, 20, WHITE)


  unloadRenderTexture(target)
  unloadShader(postProcessShader)
  unloadShader(lightShader)
  closeWindow()


when isMainModule:
  main()
