Named Tuple List
================

It's often desirable to be able to store lists of associated values without needing to strongly
define each inner object and encapsulate them within individual tables. The ``NamedTupleList``
class provides an easy-to-use mechanism for this.

API
---

Below is an example which demonstrates how to use a ``NamedTupleList``. ::

   local MyModule = select(2, ...).MyModule
   local NamedTupleList = MyModule:From("LibTSMUtil"):IncludeClassType("NamedTupleList")

   local players = NamedTupleList.New("name", "level", "className")

   players:InsertRow("Bob", 10, "Warrior")
   players:InsertRow("Jeff", 12, "Mage")
   players:InsertRow("Tim", 7, "Mage")

   print(players:GetNumRows()) -- 3

   player:SetRowField(2, "level", row:GetRowField(2, "level") + 1)

   print(players:GetRow(2)) -- Jeff    13    Mage

Memory Management
-----------------

The ``NamedTupleList`` objects are intended to never be GC'd and have a static lifecycle (i.e. one
that's equal to the lifecycle of the application), but there is nothing preventing them from being
GC'd.

.. lua:autoobject:: NamedTupleList
   :members:
