FSM
===

The ``FSM`` module provides a set of classes for creating finite state machines.

Example
-------

The following code demonstrates the usage of the FSM module. ::

   local MyModule = select(2, ...).MyModule
   local FSM = MyModule:From("LibTSMUtil"):Include("FSM")

   local fsm = FSM.New("ENEMY_NPC")
      :AddState(FSM.NewState("ST_PATROLLING")
         :SetOnEnter(function(context)
            context.health = 100
         end)
         :AddTransition("ST_ATTACKING")
         :AddEventTransition("EV_AGROED", "ST_ATTACKING")
      )
      :AddState(FSM.NewState("ST_ATTACKING")
         :SetOnEnter(function(context)
            print("I'm coming after you!")
         end)
         :AddTransition("ST_DEAD")
         :AddTransition("ST_PATROLLING")
         :AddEventTransition("EV_DEAGRO", "ST_PATROLLING")
         :AddEvent("EV_DAMAGE", function(context, damage)
            context.health = context.health - damage
            if context.health <= 0 then
               return "ST_DEAD"
            end
         end)
      )
      :AddState(FSM.NewState("ST_DEAD")
         :SetOnEnter(function(context)
            print("Argh!")
         end)
         :AddTransition("ST_PATROLLING")
         :AddEventTransition("EV_RESPAWN", "ST_PATROLLING")
      )
      :Init("ST_PATROLLING", {health = 100})

   fsm:ProcessEvent("EV_AGROED") -- print: I'm coming after you!
   fsm:ProcessEvent("EV_DAMAGE", 70)
   fsm:ProcessEvent("EV_DAMAGE", 40) -- print: Argh!
   fsm:ProcessEvent("EV_RESPAWN")

API
---

.. lua:autoobject:: FSM
   :members:

.. lua:autoobject:: FSMObject
   :members:

.. lua:autoobject:: FSMState
   :members:
