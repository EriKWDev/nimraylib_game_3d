import std/[strformat, math]

import ./timings, ./utils

import nimraygui_editor

import nimraylib_now
from nimraylib_now/rlgl import enableDepthTest


let
  editor = newEditor("Editor")
  window1 = newEWindow("Lower Box", rect(50, 50, 230, 450))
  window2 = newEWindow("Upper Box", rect(250, 60, 230, 450))
  window3 = newEWindow("Settings", rect(70, 150, 160, 100))
  window4 = newEWindow("Lights", rect(70, 150, 160, 400))

var
  overrideLights {.prop: window4.} = false
  overridenLightsColor {.prop: window4.} = BLUE
  lightsRadius = 20.0

window4.addProp newProp(lightsRadius, "Light Radius").withMinMax(0.01, 100.0)
editor.addWindow window1
editor.addWindow window2
editor.addWindow window3
editor.addWindow window4

const
  maxLights = 30

type
  Entity = object
    position: Vector3
    model: Model
    scale: float
    tint: Color

  LightKind = enum
    lkDirectional, lkPoint, lkSpot

  Light = object
    id: int

    enabled: bool
    enabledLoc: cint

    color: Vector3
    colorLoc: cint

    position: Vector3
    positionLoc: cint

    kindLoc: cint
    case kind: LightKind
    of lkDirectional, lkSpot:
      target: Vector3
      targetLoc: cint

    else: discard

  Game = ref object
    entities: seq[Entity]
    lights: seq[Light]
    lightShader: Shader
    camera: Camera3D


proc newLight(game: Game, kind: LightKind, position, color: Vector3): int {.discardable.} =
  result = len(game.lights)

  let theLight = &"lights[{result}]"
  var light: Light

  case kind
  of lkDirectional, lkSpot:
    light = Light(
      kind: lkDirectional,
      target: vec3(30.0, 0.0, 30.0),
      targetLoc: game.lightShader.getShaderLocation((&"{theLight}.target").cstring)
    )

  of lkPoint:
    light = Light(
      kind: lkPoint,
    )

  light.id = result
  light.kindLoc = game.lightShader.getShaderLocation((&"{theLight}.kind").cstring)
  light.colorLoc = game.lightShader.getShaderLocation((&"{theLight}.color").cstring)
  light.enabledLoc = game.lightShader.getShaderLocation((&"{theLight}.enabled").cstring)
  light.positionLoc = game.lightShader.getShaderLocation((&"{theLight}.position").cstring)

  light.position = position
  light.enabled = true
  light.color = color

  game.lights.add(light)


proc updateShaderValues(game: Game) =
  let t = getTime()

  for i in 0 .. high(game.lights):
    if game.lights[i].kind == lkPoint:
      let
        t0 = i.toFloat() / 5.0
        t1 = ((t0 * 255.0) mod 255.0)/255.0

      game.lights[i].position = vec3(
        sin(t + t0),
        (cos(t) * sin(t + t0*3) + 1)/2.0,
        cos(t + t0)
      ) * lightsRadius

      game.lights[i].color = vec3(
        t1,
        sin(t + t0),
        1.0 - t1
      ).clamp01().normalize()

      if overrideLights:
        game.lights[i].color = overridenLightsColor

    let
      light = game.lights[i]
      en: cint = if light.enabled: 1 else: 0
      k = light.kind.ord().toCint()

    game.lightShader.setShaderValue(light.enabledLoc, en.addr, INT)
    game.lightShader.setShaderValue(light.kindLoc, k.addr, INT)
    game.lightShader.setShaderValue(light.positionLoc, light.position.addr, VEC3)
    game.lightShader.setShaderValue(light.colorLoc, light.color.addr, VEC3)

    case light.kind
    of lkDirectional, lkSpot:
      game.lightShader.setShaderValue(light.targetLoc, light.target.addr, VEC3)

    else: discard


proc newGame(): Game =
  new(result)
  echo "=== Loading lightShader ==="
  withLogLevel(WARNING):
    let
      lightShader = loadShader("assets/shaders/base_lighting.vs", "assets/shaders/base_lighting.fs")

      n = 0.22
      ambient = vec4(n, n, n, 1.0)

    lightShader.setShaderValue(lightShader.getShaderLocation("ambient"), ambient.addr, VEC4)
    lightShader.locs[VECTOR_VIEW.ord()] = lightShader.getShaderLocation("viewPos")
    echo ""

    result.lightShader = lightShader

    for i in high(result.lights) ..< maxLights-1:
      result.newLight(lkPoint, vec3(0, 0, 0), vec3(1, 1, 1))

  result.camera = Camera3D(
    position: vec3(30.0, 10.0, 50.0),
    target: vec3(0.0, 0.0, 0.0),
    up: vec3(0.0, 1.0, 0.0),
    fovy: 96,
    projection: PERSPECTIVE
  )
  result.camera.setCameraMode(THIRD_PERSON)
  result.updateShaderValues()


proc drawLights(game: Game) =
  for light in game.lights:
    drawSphere(light.position, 0.5, clamp01(light.color + vec3(0.3, 0.3, 0.3)))

proc drawModels(game: Game) =
  for entity in game.entities:
    drawModel(entity.model, entity.position, entity.scale, entity.tint)

proc main() =
  var
    width = 800.0
    height = 700.0

  setConfigFlags(WINDOW_RESIZABLE or MSAA_4X_HINT)
  initWindow(width.toInt().toCint(), height.toInt().toCint(), "Raylib test")
  enableDepthTest()

  setTargetFPS 0

  var
    game = newGame()
    paused = false
    target = loadRenderTexture(width.toInt().toCint(), height.toInt().toCint())

    sponza: Model
    roundBox: Model

    doDrawFPS {.prop: window3.} = false

  withLogLevel(WARNING):
    beginDrawing():
      clearBackground(WHITE)
      drawText("Loading...", 100, 100, 20, BLACK)

    sponza = loadModel("assets/sponza/Sponza.gltf")
    roundBox = loadModel("assets/round_box.glb")


  for i in 0 .. sponza.materialCount:
    sponza.materials[i].shader = game.lightShader
  roundBox.materials[0].shader = game.lightShader

  game.entities.add(Entity(
    position: vec3(0.0, -2.0, 0.0),
    model: sponza,
    scale: 0.1,
    tint: WHITE
  ))

  var e = Entity(
    position: vec3(0.0, 4.0, 0.0),
    model: roundBox,
    scale: 5.0,
    tint: WHITE
  )

  let eid = len(game.entities)
  game.entities.add(e)
  window1.addProp newProp(game.entities[eid].position, "Position")
  window1.addProp newProp(game.entities[eid].tint, "Color")
  window1.addProp newProp(game.entities[eid].scale, "Scale").withMinMax(0.01, 50.0)


  let eid2 = len(game.entities)
  game.entities.add(Entity(
    position: vec3(2.0, 18.0, 2.0),
    model: roundBox,
    scale: 3.0,
    tint: WHITE
  ))

  window2.addProp newProp(game.entities[eid2].position, "Position")
  window2.addProp newProp(game.entities[eid2].tint, "Color")
  window2.addProp newProp(game.entities[eid2].scale, "Scale").withMinMax(0.01, 50.0)

  while not windowShouldClose():
    updateEditor(editor)

    let
      newWidth = getScreenWidth()
      newWidthF = newWidth.toFloat()
      newHeight = getScreenHeight()
      newHeightF = newHeight.toFloat()

    if newWidthF != width or newHeightF != height:
      width = newWidthF
      height = newHeightF
      unloadRenderTexture(target)
      target = loadRenderTexture(newWidth, newHeight)


    if isKeyPressed(KeyboardKey.P):
      paused = not paused

      if paused:
        enableCursor()
      else:
        disableCursor()

    if isKeyPressed(KeyboardKey.F10):
      editor.toggleVisibility()

    timeIt "shader update":
      updateShaderValues(game)

    if not paused:
      timeIt "camera update":
        updateCamera(game.camera.addr)

    timeIt "camera pass":
      beginTextureMode(target):
        clearBackground rgba(0, 0, 0, 0)

        beginMode3D(game.camera):
          game.drawLights()
          game.drawModels()

    timeIt "post-processing + gui":
      beginDrawing():
        clearBackground BLACK

        let targetRect = rect(0, 0, target.texture.width.toFloat(), target.texture.height.toFloat())

        beginEditor(editor):
          drawTextureQuad(target.texture, vec2(1.0, -1.0), vec2(0.0, 0.0), targetRect, WHITE)

          if doDrawFPS:
            drawFPS(10, 10)

  closeWindow()


when isMainModule:
  main()
