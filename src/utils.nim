import nimraylib_now

const defaultLogLevel* = INFO

func rect*(x, y, w, h: float): Rectangle {.inline.} = Rectangle(x: x, y: y, width: w, height: h)
func vec2*(x, y: float): Vector2 {.inline.} = Vector2(x: x, y: y)
func vec3*(x, y, z: float): Vector3 {.inline.} = Vector3(x: x, y: y, z: z)
func vec4*(x, y, z, w: float): Vector4 {.inline.} = Vector4(x: x, y: y, z: z, w: w)
func rgba*(x, y, z, w: uint8): Color {.inline.} = Color(r: x, g: y, b: z, a: w)
func clamp01*(v: Vector3): Vector3 {.inline.} =
  vec3(
    clamp(v.x, 0.0, 1.0),
    clamp(v.y, 0.0, 1.0),
    clamp(v.z, 0.0, 1.0)
  )

converter toColor*(v3: Vector3): Color =
  Color(r: (v3.x*255).uint8, g: (v3.y*255).uint8, b: (v3.z*255).uint8, a: 255)

converter toVector3*(c: Color): Vector3 =
  Vector3(x: c.r.float/255.0,
          y: c.g.float/255.0,
          z: c.b.float/255.0)

template withLogLevel*(logLevel: TraceLogLevel, body) =
  let beforeLevel = defaultLogLevel
  setTraceLogLevel(logLevel)
  block:
    body
  setTraceLogLevel(beforeLevel)
