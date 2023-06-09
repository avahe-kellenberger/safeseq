import std/sequtils

type
  PendingElement[T] = object
    t: T
    inserting: bool
    preserveOrder: bool

  SafeSeq*[T] = ref object
    elements: seq[T]
    iterationDepth: int
    pendingElements: seq[PendingElement[T]]
    pendingClear: bool

proc pendingElement[T](t: T, inserting, preserveOrder: bool): PendingElement[T] =
  PendingElement[T](t: t, inserting: inserting, preserveOrder: preserveOrder)

proc newSafeSeq*[T](initialSize = 0): SafeSeq[T] =
  SafeSeq[T](elements: newSeq[T](initialSize))

proc areElementsLocked*[T](this: SafeSeq[T]): bool =
  ## If the elements are currently being iterated over.
  this.iterationDepth > 0

template addNow[T](this: SafeSeq[T], t: T) =
  this.elements.add(t)

template removeNowAt[T](this: SafeSeq[T], i: int, preserveOrder: bool) =
  ## Unsafe immediate removal of an element.
  if preserveOrder:
    this.elements.delete(i)
  else:
    this.elements.del(i)

template removeNow[T](this: SafeSeq[T], t: T, preserveOrder: bool) =
  ## Unsafe immediate removal of an element.
  for i, e in this.elements:
    if e == t:
      removeNowAt(this, i, preserveOrder)
      break

template clearNow(this: SafeSeq) =
  this.elements.setLen(0)
  this.pendingElements.setLen(0)
  this.pendingClear = false

proc add*[T](this: SafeSeq[T], t: T) =
  ## Adds an item to the seq.
  if this.areElementsLocked():
    this.pendingElements.add(pendingElement(t, true, true))
  else:
    this.addNow(t)

proc remove*[T](this: SafeSeq[T], t: T, preserveOrder: bool) =
  ## Removes an item from the seq.
  if this.areElementsLocked():
    this.pendingElements.add(pendingElement(t, false, preserveOrder))
  else:
    this.removeNow(t, preserveOrder)

template remove*[T](this: SafeSeq[T], t: T) =
  ## Removes an item from the seq.
  ## This does NOT preserve the insertion order of elements.
  this.remove(t, false)

template removePreserveOrder*[T](this: SafeSeq[T], t: T) =
  ## Removes an item from the seq.
  ## This preserves the insertion order of elements,
  ## at the cost of some speed.
  this.remove(t, true)

proc contains*[T](this: SafeSeq[T], t: T): bool =
  ## If the seq currently contains an item, before checking pending elements.
  return this.elements.contains(t)

template keepItIf*[T](this: SafeSeq[T], pred: untyped) =
  ## Invokes sequtils.keepItIf on the underlying data structure.
  ## WARNING: You should ensure that this.areElementsLocked is false before performing this operation.
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
        for element in this.pendingElements:
          if element.inserting:
            this.addNow(element.t)
          else:
            this.removeNow(element.t, element.preserveOrder)
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
      for element in this.pendingElements:
        let isInElements = this.elements.contains(element.t)
        if element.inserting:
          if not isInElements:
            result += 1
        elif isInElements:
          result -= 1

proc clear*(this: SafeSeq) =
  if not this.areElementsLocked():
    this.clearNow():
  else:
    this.pendingClear = true

