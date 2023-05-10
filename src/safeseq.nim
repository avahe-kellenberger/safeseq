import std/sequtils

type
  SafeSeq*[T] = ref object
    elements: seq[T]
    iterationDepth: int
    pendingElements: seq[(T, bool)]
    pendingClear: bool
    preserveOrder: bool

proc newSafeSeq*[T](initialSize = 0, preserveOrder = true): SafeSeq[T] =
  SafeSeq[T](elements: newSeq[T](initialSize), preserveOrder: preserveOrder)

proc areElementsLocked*[T](this: SafeSeq[T]): bool =
  this.iterationDepth > 0

template addNow[T](this: SafeSeq[T], t: T) =
  this.elements.add(t)

template removeNowAt[T](this: SafeSeq[T], i: int) =
  ## Unsafe immediate removal of an element.
  if this.preserveOrder:
    this.elements.delete(i)
  else:
    this.elements.del(i)

template removeNow[T](this: SafeSeq[T], t: T) =
  ## Unsafe immediate removal of an element.
  for i, e in this.elements:
    if e == t:
      removeNowAt(this, i)
      break

template clearNow(this: SafeSeq) =
  this.elements.setLen(0)
  this.pendingElements.setLen(0)
  this.pendingClear = false

proc add*[T](this: SafeSeq[T], t: T) =
  ## Adds an item to the seq.
  if this.areElementsLocked():
    this.pendingElements.add((t, true))
  else:
    this.addNow(t)

proc remove*[T](this: SafeSeq[T], t: T) =
  ## Removes an item from the seq.
  if this.areElementsLocked():
    this.pendingElements.add((t, false))
  else:
    this.removeNow(t)

proc contains*[T](this: SafeSeq[T], t: T): bool =
  ## If the seq currently contains an item, before checking pending elements.
  return this.elements.contains(t)

template keepItIf*[T](this: SafeSeq[T], pred: untyped) =
  this.elements.keepItIf(pred)

iterator items*[T](this: SafeSeq[T]): T =
  ## Safely iterates over the items in the seq.
  ## You may attempt to add and remove items during this iteration;
  ## however, additions/removals will not take effect until the iteration completes.
  try:
    # Lock the elements
    this.iterationDepth += 1
    # Yield all elements currently in the seq.
    for e in this.elements.items:
      yield e
  finally:
    # Finally "unlock" the SafeSeq.
    this.iterationDepth -= 1

    # Process and clear pending elements.
    if not this.areElementsLocked():
      if this.pendingClear:
        this.clearNow()
      else:
        for (element, adding) in this.pendingElements:
          if adding:
            this.addNow(element)
          else:
            this.removeNow(element)
        this.pendingElements.setLen(0)

iterator pairs*[T](this: SafeSeq[T]): (int, T) =
  var i = 0
  for e in this:
    yield (i, e)
    inc i

proc len*(this: SafeSeq): int =
  ## The number of effective elements in the seq.
  if this.pendingClear:
    this.clearNow()
  else:
    result = this.elements.len

    if this.areElementsLocked():
      for (element, adding) in this.pendingElements:
        let isInElements = this.elements.contains(element)
        if adding:
          if not isInElements:
            result += 1
        elif isInElements:
          result -= 1

proc clear*(this: SafeSeq) =
  if not this.areElementsLocked():
    this.clearNow():
  else:
    this.pendingClear = true

