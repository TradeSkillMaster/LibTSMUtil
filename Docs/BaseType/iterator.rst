Iterator
========

Lua's built-in iterator mechanism is clumsy at best, with the `documentation even admitting`_ they
"may be difficult to write, but are easy to use." While they are easy to use when called directly
within a for loop, they are not easy to pass around, explicitly document functions which return
them, or extend the functionality of. The ``Iterator`` module intends to address these shortfalls
and provide some additional functionality.

.. _documentation even admitting: https://www.lua.org/pil/7.1.html

Example
-------

Below is an example which shows all the feature of the iterator objects. ::

   local MyModule = select(2, ...).MyModule
   local Iterator = MyModule:From("LibTSMUtil"):Include("BaseType.Iterator")

   local iter = Iterator.Acquire(ipairs({"a", 23, 17, "c"}))
      :Filter(function(index, value) return type(value) == "string" end)
      :SetMapFunc(function(index, value) return value, string.upper(value) end)
   for i, str, upperStr in iter do
      print(i, str, upperStr)
   end
   -- 1    a    A
   -- 4    c    C

   print(Iterator.Acquire(ipairs({1, 2, 3})):ToJoinedValueString(",")) -- 1,2,3

Memory Management
-----------------

The lifecycle of iterator objects is owned by the Iterator module. They are acquired via the
``Iterator.Acquire()`` function and its up to the caller to ensure they are properly released back
to the Iterator module for recycling. In most cases, this is done automatically by simply running
the iteration all the way to completion. For cases where breaking out of the iterator early is
required, the application must explicitly call the ``:Release()`` method on the iterator object.

API
---

.. lua:autoobject:: BaseType.Iterator
   :members:

.. lua:autoobject:: IteratorObject
   :members:
