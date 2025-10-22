Ordered Table
=============

Lua's table types which are not numerically-indexed don't define an order for their keys. Iterating
through them using ``pairs()`` will provide the entries in an undefined order. A common wy around
this to preserve the order of key-value tables is also insert the keys into the table as a list and
then iterate over keys of table using ``ipairs()`` (and then looking up the value). The
``OrderedTable`` provides a set of helper functions to make this more ergonamic.

Example
-------

Below is an example which demonstrates how to use the ``OrderedTable`` APIs. ::

   local MyModule = select(2, ...).MyModule
   local OrderedTable = MyModule:From("LibTSMUtil"):Include("BaseType.OrderedTable")

   local tbl = {}
   OrderedTable.Insert(tbl, "b", 2)
   OrderedTable.Insert(tbl, "a", 3)

   for _, k, v in OrderedTable.Iterator(tbl) do
      print(k, v)
   end
   -- b   2
   -- a   3

   OrderedTable.SortByKeys(tbl)

   for _, k, v in OrderedTable.Iterator(tbl) do
      print(k, v)
   end
   -- a   3
   -- b   2

API
---

.. lua:autoobject:: BaseType.OrderedTable
   :members:
