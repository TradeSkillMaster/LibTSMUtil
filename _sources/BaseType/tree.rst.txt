Tree
====

The ``Tree`` class provides APIs for a simple tree data structure with a single root node that can
have any number of child nodes. Each child node can then also have children (recursively). Each
node in the tree can data associated with it.

Example
-------

One common use-case for a temp table is for an API which returns a set of values which it needs to
build in an iterative fasion. ::

   local MyModule = select(2, ...).MyModule
   local Tree = MyModule:From("LibTSMUtil"):IncludeClassType("Tree")

   local tree = Tree.Create("strValue", "numValue")
   local nodeA = tree:Insert(nil, "a", 1)
   local nodeAA = tree:Insert(nodeA, "aa", 2)
   local nodeAB = tree:Insert(nodeA, "ab", 3)
   local nodeAAA = tree:Insert(nodeAA, "aaa", 4)

   for _, child in ipairs({tree:GetChildren(nodeA)}) do
      print(tree:GetData(child, "strValue"), tree:GetData(child, "numValue"))
   end
   -- aa   2
   -- ab   3

API
---

.. lua:autoobject:: Tree
   :members:
