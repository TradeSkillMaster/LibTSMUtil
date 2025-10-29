Future
======

The ``Future`` class can be used to defer the result of a calculation and keep track of
asynchronous work. The behavior is very similar to futures in other languages like Javascript.

Example
-------

Futures are often helpful when the result of an action will come via an event at some later point
in time. ::

   local MyModule = select(2, ...).MyModule
   local Future = MyModule:From("LibTSMUtil"):IncludeClassType("Future")

   local ItemPurchaser = {
      futureObj = Future.New("ITEM_PURCHASER"),
      pendingFuture = nil,
   }

   function ItemPurchaser:Init()
      self.futureObj:SetScript("OnCleanup", function()
         self.pendingFuture = nil
      end)
      -- Assume `RegisterScript()` is defined elsewhere
      RegisterScript("PURCHASE_SUCCESS", function()
         if self.pendingFuture then
            self.pendingFuture:Done(true)
         end
      end)
      RegisterScript("PURCHASE_FAILURE", function()
         if self.pendingFuture then
            self.pendingFuture:Done(false)
         end
      end)
   end

   function ItemPurchaser:PurchaseItem(item)
      assert(not self.pendingFuture)
      self.pendingFuture = self.futureObj

      -- Actually make the purchase here

      self.pendingFuture:Start()
      return self.pendingFuture
   end

   ItemPurchaser:Init()
   local future = ItemPurchaser:PurchaseItem(item)
   future:SetScript("OnDone", function(result)
      if result then
         print(format("Bought item (%s) successfully.", item))
      else
         print(format("Failed to buy item (%s).", item))
      end
   end)

API
---

.. lua:autoobject:: Future
   :members:
