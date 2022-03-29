
import std/[monotimes, algorithm, times]
export monotimes, algorithm, inMilliseconds

type
  Timing* = tuple
    name: string
    id: int
    startTime: MonoTime
    endTime: MonoTime
    delta: int64

var
  timings*: seq[Timing]
  longestName*: int = -1

template timeIt*(name: string, body) =
  let
    id = len(timings)
    startTime = getMonoTime()

  longestName = max(longestName, len(name))

  block:
    body

  let
    endTime = getMonoTime()
    timing: Timing = (name, id, startTime, endTime, (endTime - startTime).inMilliseconds)

  timings.add(timing)

proc getTimings*: seq[Timing] =
  swap(result, timings)
  result.sort() do (a, b: Timing) -> int:
    (b.delta - a.delta).int


when isMainModule:
  timeIt "test":
    echo "potato"
