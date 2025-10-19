local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local EnumType = LibTSMUtil:Include("BaseType.EnumType")



-- ============================================================================
-- Tests
-- ============================================================================

TestEnumType = {}

function TestEnumType:TestBasic()
	local DOG = EnumType.New("DOG", {
		POODLE = EnumType.NewValue(),
		BEAGLE = EnumType.NewValue(),
	})
	local CAT = EnumType.New("CAT", {
		DOMESTIC = EnumType.NewValue(),
		FERAL = EnumType.NewValue(),
	})

	assertTrue(DOG.POODLE == DOG.POODLE)
	assertTrue(DOG.POODLE ~= DOG.BEAGLE)
	assertTrue(DOG.BEAGLE ~= DOG.POODLE)
	assertTrue(DOG.POODLE ~= CAT.DOMESTIC)
	assertTrue(DOG ~= DOG.BEAGLE)
	assertTrue(DOG.BEAGLE ~= DOG)

	assertTrue(DOG:HasValue(DOG.POODLE))
	assertFalse(CAT:HasValue(DOG.POODLE))

	assertTrue(EnumType.IsType(DOG))
	assertFalse(EnumType.IsType(DOG.POODLE))

	assertEquals(tostring(DOG), "DOG")
	assertEquals(tostring(DOG.POODLE), "DOG.POODLE")
end

function TestEnumType:TestNested()
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
		GOAT = EnumType.NewValue(),
	})

	assertTrue(ANIMAL.COW == ANIMAL.COW)
	assertTrue(ANIMAL.COW ~= ANIMAL.GOAT)
	assertTrue(ANIMAL.COW ~= ANIMAL.CAT)
	assertTrue(ANIMAL.CAT == ANIMAL.CAT)
	assertTrue(ANIMAL.CAT.DOMESTIC == ANIMAL.CAT)
	assertTrue(ANIMAL.CAT == ANIMAL.CAT.DOMESTIC)
	assertTrue(ANIMAL.GOAT ~= ANIMAL.CAT.DOMESTIC)
	assertTrue(ANIMAL ~= ANIMAL.CAT.DOMESTIC)
	assertTrue(ANIMAL ~= ANIMAL.CAT)
	assertTrue(ANIMAL.CAT.DOMESTIC ~= ANIMAL.DOG.POODLE)
	assertTrue(ANIMAL.DOG == ANIMAL.DOG)
	assertTrue(ANIMAL.DOG == ANIMAL.DOG.POODLE)
	assertTrue(ANIMAL.DOG == ANIMAL.DOG.LAB)
	assertTrue(ANIMAL.DOG == ANIMAL.DOG.LAB.ENGLISH)
	assertTrue(ANIMAL.DOG.LAB == ANIMAL.DOG.LAB.ENGLISH)
	assertTrue(ANIMAL.DOG.LAB.ENGLISH == ANIMAL.DOG.LAB.ENGLISH)
	assertTrue(ANIMAL.DOG.POODLE ~= ANIMAL.DOG.LAB)
	assertTrue(ANIMAL.DOG.POODLE ~= ANIMAL.DOG.LAB.ENGLISH)

	assertTrue(ANIMAL:HasValue(ANIMAL.CAT.DOMESTIC))

	assertTrue(EnumType.IsType(ANIMAL))
	assertFalse(EnumType.IsType(ANIMAL.CAT))

	assertEquals(tostring(ANIMAL), "ANIMAL")
	assertEquals(tostring(ANIMAL.CAT), "ANIMAL.CAT")
	assertEquals(tostring(ANIMAL.CAT.DOMESTIC), "ANIMAL.CAT.DOMESTIC")
end
