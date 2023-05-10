import
  nimtest,
  safeseq,
  sequtils,
  hashes

import std/monotimes

const ONE_BILLION = 1_000_000_000

template measureRuntime*(body: untyped): float =
  ## Reports the runtime in seconds.
  let startTimeNanos = getMonoTime().ticks
  body
  let endTimeNanos = getMonoTime().ticks
  float(endTimeNanos - startTimeNanos) / ONE_BILLION

var i: int = 0

type Foo = object

describe "Performance":

  test "remove (order preserved)":
    const size = 10_000
    echo "Calling remove on " & $size & " items..."
    let safeseq = newSafeSeq[Foo](size)
    for i in 0..size:
      safeseq.add(Foo())

    let runtime = measureRuntime:
      for item in safeseq:
        safeseq.remove(item)

    echo "Removal time: " & $runtime & " seconds"

  test "remove (order NOT preserved)":
    const size = 10_000
    echo "Calling remove on " & $size & " items..."
    let safeseq = newSafeSeq[Foo](size, false)
    for i in 0..size:
      safeseq.add(Foo())

    let runtime = measureRuntime:
      for item in safeseq:
        safeseq.remove(item)

    echo "Removal time: " & $runtime & " seconds"

