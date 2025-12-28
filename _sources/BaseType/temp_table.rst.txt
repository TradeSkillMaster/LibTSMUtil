Temp Table
==========

There are ocasionally cases where a lot of tables need to be created for use within a tight loop
and relying on Lua's GC to clean them up afterwards can result in a noticeable performance hit.
For these situations, the ``TempTable`` module provides a set of APIs for manually managing the
lifecycle of Lua tables. Some common use-cases are below.

Example
-------

One common use-case for a temp table is for an API which returns a set of values which it needs to
build in an iterative fasion. ::

   local MyModule = select(2, ...).MyModule
   local TempTable = MyModule:From("LibTSMUtil"):Include("BaseType.TempTable")

   function PrintLettersSortedSingleLine(str)
      local letters = TempTable.Acquire()
      for i = 1, #str do
         local c = strsub(str, i, i)
         if not letters[c] then
            letters[c] = true
            tinsert(letters, c)
         end
      end
      sort(letters)
      print(TempTable.UnpackAndRelease(letters))
   end

   function PrintLettersSortedMultipleLines(str)
      local letters = TempTable.Acquire()
      for i = 1, #str do
         local c = strsub(str, i, i)
         if not letters[c] then
            letters[c] = true
            tinsert(letters, c)
         end
      end
      sort(letters)
      for _, letter in TempTable.Iterator(letters) do
         print(letter)
      end
   end

API
---

.. lua:autoobject:: BaseType.TempTable
   :members:
