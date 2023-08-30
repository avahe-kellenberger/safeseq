import std/sequtils

type
  PendingActionKind = enum
    ADD,
    REMOVE,
    CLEAR

  PendingAction[T] = object
    case kind*: PendingActionKind
      of ADD:
        elementToAdd: T
      of REMOVE:
        elementToRemove: T
        preserveOrder: bool
      else:
        discard

  SafeSeq*[T] = ref object
    dummy: T
    elements: seq[T]
    iterationDepth: int
    pendingActions: seq[PendingAction[T]]

proc addElement[T](t: T): PendingAction[T] =
  PendingAction[T](elementToAdd: t, kind: ADD)

proc removeElement[T](t: T, preserveOrder: bool): PendingAction[T] =
  PendingAction[T](elementToRemove: t, kind: REMOVE, preserveOrder: preserveOrder)

proc clearAction[T](dummy: T): PendingAction[T] =
  return PendingAction[T](kind: CLEAR)

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

proc add*[T](this: SafeSeq[T], t: T) =
  ## Adds an item to the seq.
  if this.areElementsLocked():
    this.pendingActions.add(addElement(t))
  else:
    this.addNow(t)

proc remove*[T](this: SafeSeq[T], t: T, preserveOrder: bool) =
  ## Removes an item from the seq.
  if this.areElementsLocked():
    this.pendingActions.add(removeElement(t, preserveOrder))
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
      for action in this.pendingActions:
        case action.kind:
          of ADD:
            this.add(action.elementToAdd)
          of REMOVE:
            this.removeNow(action.elementToRemove, action.preserveOrder)
          of CLEAR:
            this.clearNow()
      this.pendingActions.setLen(0)

iterator pairs*[T](this: SafeSeq[T]): (int, T) =
  var i = 0
  for e in this:
    yield (i, e)
    inc i

proc len*(this: SafeSeq): int =
  ## The number of elements in the seq.
  ## Does not take pending actions into account.
  return this.elements.len

proc clear*[T](this: SafeSeq[T]) =
  if not this.areElementsLocked():
    this.clearNow()
  else:
    this.pendingActions.add(clearAction(this.dummy))

