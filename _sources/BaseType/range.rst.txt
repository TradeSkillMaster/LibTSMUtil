Range
=====

The ``Range`` class makes it simple to represent and perform operations on a range of numeric
values.

Example
-------

Below is an example which demonstrates how to use the ``Range`` class. ::

   local MyModule = select(2, ...).MyModule
   local Range = MyModule:From("LibTSMUtil"):IncludeClassType("Range")

   do
      local spellRange = Range.AcquireStartEnd(0, 10)
      local enemyStrikeRange = Range.AcquireStartEnd(0, 5)

      local currentDistance = 7
      print(spellRange:Includes(currentDistance)) -- true
      print(enemyStrikeRange:Includes(currentDistance)) -- false

      spellRange:Release()
      enemyStrikeRange:Release()
   end

   do
      local groupLevelRange = Range.AcquireStartEnd(73, 74)
      local zoneLevelRange = Range.AcquireStartEnd(71, 75)

      print(zoneLevelRange:Contains(groupLevelRange)) -- true

      groupLevelRange:Release()
      zoneLevelRange:Release()
   end

Memory Management
-----------------

The lifecycle of range objects is owned by the Range module. They are acquired via the
``Range.Acquire*()`` functions and its up to the caller to ensure they are properly released back
to the Range module for recycling by calling the ``Release()`` method. It's also possible to
create a static ``Range`` object which is owned by the application layer via the
``Range.StaticStartEnd()`` function.

API
---

.. lua:autoobject:: Range
   :members:
