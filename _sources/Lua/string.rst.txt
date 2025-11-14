String
======

The ``String`` module provides various extensions on the default Lua string library.

Separated Strings
-----------------

One common pattern is to store lists of elements as a string with a fixed separator. The ``String``
module provides two APIs to help facilitate this as demonstrated below. ::

   local MyModule = select(2, ...).MyModule
   local String = MyModule:From("LibTSMUtil"):Include("Lua.String")

   local SEP = ","
   local favoriteClasses = strjoin(SEP, "Rogue", "Mage", "Warrior")

   print(String.SeparatedCount(favoriteClasses, SEP)) -- 3
   print(String.SeparatedContains(favoriteClasses, SEP, "Rogue")) -- true
   print(String.SeparatedContains(favoriteClasses, SEP, "Hunter")) -- false

   for class in String.SplitIterator(favoriteClasses, SEP) do
      print(class)
   end
   -- Rogue
   -- Mage
   -- Warrior

API
---

.. lua:autoobject:: Lua.String
   :members:
