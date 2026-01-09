Object Pool
===========

The ``ObjectPool`` class provides a simple set of APIs to enable recycling of high-level objects.
This can be very useful to avoid putting extra strain on the garbage collector and improve
performance in cases where it's non-trivial to create an object, but is faster to reset and reuse
the object. This is especially true when dealing with WoW's UI elements which can't be GC'd. This
can also be easily paired with classes to allow for recycling of class objects.

Example
-------

Below is an example which demonstrates how to use an ``ObjectPool``. ::

   -- MyClass.lua
   local MyModule = select(2, ...).MyModule
   local ObjectPool = MyModule:From("LibTSMUtil"):IncludeClassType("ObjectPool")
   local MyClass = MyModule:DefineClassType("MyClass")
   local pool = ObjectPool.New("MY_CLASS", MyClass)

   function MyClass.__static.Acquire()
      local obj = pool:Get()
      obj:_Acquire()
      return obj
   end

   function MyClass.__private:__init()
      self._value = nil
   end

   function MyClass:Release()
      self._value = nil
      pool:Recycle(self)
   end

   function MyClass:SetValue(value)
      self._value = value
   end

   function MyClass:GetValue()
      return self._value
   end

   -- Main.lua
   local MyModule = select(2, ...).MyModule
   local MyClass = MyModule:IncludeClassType("MyClass")

   local obj = MyClass.Acquire()
   obj:SetValue(42)
   print(obj:GetValue()) -- 42
   obj:Release()

   local obj2 = MyClass.Acquire()
   print(obj2:GetValue()) -- nil
   obj2:Release()

API
---

.. lua:autoobject:: ObjectPool
   :members:
