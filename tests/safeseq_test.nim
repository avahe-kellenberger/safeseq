import
  nimtest,
  safeseq,
  sequtils

var i: int = 0

type Foo = object

describe "SafeSeq":

  describe "add":
    it "adds an element to the set":
      let safeseq = newSafeSeq[string]()
      safeseq.add("foobar")
      assertEquals(safeseq.len, 1)

      for item in safeseq:
        assertEquals(item, "foobar")

    it "adds an element to the set during iteration":
      let safeseq = newSafeSeq[string]()
      safeseq.add("foobar")
      assertEquals(safeseq.len, 1)

      for item in safeseq:
        safeseq.add("barbaz")
      
      assertEquals(safeseq.len, 2)

  describe "remove":
    it "removes an element remove the set":
      let safeseq = newSafeSeq[string]()
      safeseq.add("foobar")
      assertEquals(safeseq.len, 1)

      for item in safeseq:
        assertEquals(item, "foobar")

      safeseq.remove("foobar")
      assertEquals(safeseq.len, 0)

    it "removes an element remove the set during iteration":
      let safeseq = newSafeSeq[string]()
      safeseq.add("foobar")
      assertEquals(safeseq.len, 1)

      for item in safeseq:
        safeseq.remove("foobar")

      assertEquals(safeseq.len, 0)

  describe "add and remove during iteration":
    it "remove then add":
      let safeseq = newSafeSeq[string]()
      const elem = "foobar"
      safeseq.add(elem)
      assertEquals(safeseq.len, 1)

      for item in safeseq:
        safeseq.remove(elem)
        safeseq.add(elem)

      assertEquals(safeseq.len, 1)

    it "double loops":
      let safeseq = newSafeSeq[string]()
      const elem = "foobar"
      safeseq.add(elem)
      assertEquals(safeseq.len, 1)

      for i, item in safeseq:
        safeseq.add($i & "aoeu")

      safeseq.add("something")

      for i, item in safeseq:
        safeseq.add($i & "htns")

      let items = safeseq.items.toSeq()
      assertEquals(
        items,
        @["foobar", "0aoeu", "something", "0htns", "1htns", "2htns"]
      )

  describe "contains":

    it "reports when a safeseq contains an element properly":
      let
        foo = Foo()
        safeseq = newSafeSeq[Foo]()

      assertEquals(safeseq.contains(foo), false)
      safeseq.add(foo)
      assertEquals(safeseq.contains(foo), true)

  describe "keepItIf":

    it "keeps elements if the predicate conditions are met":
      let safeseq = newSafeSeq[int]()
      safeseq.add(1)
      safeseq.add(2)
      safeseq.add(3)
      safeseq.add(4)
      safeseq.add(5)

      safeseq.keepItIf(it >= 3)
      assertEquals(safeseq.items.toSeq(), @[3, 4, 5])

    it "will have zero elements none of the predicate conditions are met":
      let safeseq = newSafeSeq[int]()
      safeseq.add(1)
      safeseq.add(2)
      safeseq.add(3)
      safeseq.add(4)
      safeseq.add(5)

      safeseq.keepItIf(it >= 10)
      assertEquals(safeseq.len, 0)

    it "will keep all elements if all of the predicate conditions are met":
      let safeseq = newSafeSeq[int]()
      safeseq.add(1)
      safeseq.add(2)
      safeseq.add(3)
      safeseq.add(4)
      safeseq.add(5)

      safeseq.keepItIf(it >= 0)
      assertEquals(safeseq.items.toSeq(), @[1, 2, 3, 4, 5])

  describe "clear":

    it "clears the elements when no changes are pending":
      let safeseq = newSafeSeq[int]()
      safeseq.add(1)
      safeseq.add(2)
      safeseq.add(3)

      safeseq.clear()
      assertEquals(safeseq.len(), 0)

    it "clears the elements after iteration":
      let safeseq = newSafeSeq[int]()
      safeseq.add(1)
      safeseq.add(2)
      safeseq.add(3)

      for item in safeseq.items:
        safeseq.clear()
        # The clear is pending, so the length should always remain the same.
        assertEquals(safeseq.len(), 3)

      assertEquals(safeseq.len(), 0)

    it "clears the elements existing only before insertion":
      let safeseq = newSafeSeq[int]()
      safeseq.add(1)
      safeseq.add(2)
      safeseq.add(3)

      var firstIteration = true

      for item in safeseq.items:
        safeseq.add(5)
        if firstIteration:
          safeseq.clear()
          firstIteration = false

      assertEquals(safeseq.items.toSeq(), @[ 5, 5 ])

