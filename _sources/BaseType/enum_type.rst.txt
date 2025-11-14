Enum Type
=========

The EnumType module allows for defining enums in Lua. The resulting types support equality checks
and conversion to human-readable strings for ease of debugging.

Simple Enums
------------

A simple enum can be created by calling the ``EnumType.New()`` API which takes the name of the enum
as the first argument. The second argument is a table where the desied enum values are the keys and
the special ``EnumType.NewValue()`` value is set to as the value. Below is an example of creating
two simple enum types and showing the basic usage. ::

   local DOG = EnumType.New("DOG", {
      POODLE = EnumType.NewValue(),
      BEAGLE = EnumType.NewValue(),
   })

   print(DOG) -- "DOG"
   print(DOG.POODLE) -- "DOG.POODLE"
   print(DOG.POODLE == DOG.POODLE) -- true
   print(DOG.POODLE == DOG.BEAGLE) -- false

Simple enum types like this are very performant, with equality checks being simple table reference
equality checks and not involving any metamethod calls.

Nested Enums
------------

The next level of complexity with enums is to define a nested enum. The best way to demonstration
nested enums is with an example.::

   local MyModule = select(2, ...).MyModule
   local EnumType = MyModule:From("LibTSMUtil"):Include("BaseType.EnumType")

   local ANIMAL = EnumType.NewNested("ANIMAL", {
      CAT = {
         DOMESTIC = EnumType.NewValue(),
         FERAL = EnumType.NewValue(),
      },
      DOG = {
         POODLE = EnumType.NewValue(),
         BEAGLE = EnumType.NewValue(),
         LAB = {
            ENGLISH = EnumType.NewValue(),
            AMERICAN = EnumType.NewValue(),
         },
      },
      COW = EnumType.NewValue(),
   })

   local function Speak(animal)
      if animal == ANIMAL.CAT then
         print("Meow")
      elseif animal == ANIMAL.DOG then
         print("Woof")
      elseif animal == ANIMAL.COW then
         print("Moo")
      end
   end
   Speak(ANIMAL.DOG.LAB.AMERICAN) -- "Woof"

As shown above, nested enums can be very powerful when the individual values have natural groupings
and there's code that needs to be run for any value within the group, without needing to check for
each discrete value.

One of the downsides of nested enums is that equality is implemented via a metamethod, making it
much more computationally expensive. For the vast majority of cases, the performance impact is
negligible, but it may be worth considering for cases where thousands of enum values are being
compared.

LuaLS Support
-------------

One of the goals with the design of the EnumType module was to provide language server support for
the enum types. This is accomplished with the help of generics, such that the resulting enum type
returned by ``EnumType.New()`` / ``EnumType.NewNested()`` has the typing information of its second
argument preserved.

API
---

.. lua:autoobject:: BaseType.EnumType
   :members:

.. lua:autoobject:: EnumObject
   :members:
