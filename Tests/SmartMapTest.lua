local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local SmartMap = LibTSMUtil:IncludeClassType("SmartMap")



-- ============================================================================
-- Tests
-- ============================================================================

TestSmartMap = {}

function TestSmartMap:TestBasic()
	local valueLookupTable = {
		[10] = 20,
		[-2] = -4,
	}
	local function ValueFunc(key)
		return valueLookupTable[key]
	end

	local map = SmartMap.New("number", "number", ValueFunc)
	assertEquals(map:GetKeyType(), "number")
	assertEquals(map:GetValueType(), "number")

	local reader = map:CreateReader()
	assertEquals(reader[10], 20)
	assertEquals(reader[-2], -4)
	assertEquals(reader(-2), -4)
end

function TestSmartMap:TestChange()
	local valueLookupTable = {
		[10] = 20,
		[-2] = -4,
		[0] = 100,
	}
	local function ValueFunc(key)
		return valueLookupTable[key]
	end
	local callbacks = {}
	local function ReaderCallback(reader, changes)
		for key, prevValue in pairs(changes) do
			tinsert(callbacks, { reader = reader, key = key, prevValue = prevValue, newValue = reader[key] })
		end
	end

	local map = SmartMap.New("number", "number", ValueFunc)

	-- create 2 readers
	local reader1 = map:CreateReader(ReaderCallback)
	local reader2 = map:CreateReader(ReaderCallback)
	assertEquals(reader1[10], 20)
	assertEquals(reader1[-2], -4)

	-- change a value to the same thing and make sure we don't get a callback
	map:ValueChanged(-2)
	assertEquals(#callbacks, 0)

	-- change one of the values
	valueLookupTable[-2] = 7

	-- old value should be cached
	assertEquals(reader1[10], 20)
	assertEquals(reader1[-2], -4)

	-- notify the map of the update and make sure our reader1 callback (only) is called
	assertEquals(#callbacks, 0)
	map:ValueChanged(-2)
	assertEquals(#callbacks, 1)
	assertEquals(callbacks[1].reader, reader1)
	assertEquals(callbacks[1].key, -2)
	assertEquals(callbacks[1].prevValue, -4)
	assertEquals(callbacks[1].newValue, 7)
	wipe(callbacks)

	-- should now get the new value
	assertEquals(reader1[10], 20)
	assertEquals(reader1[-2], 7)
end

function TestSmartMap:TestPause()
	local valueLookupTable = {
		[10] = 20,
		[-2] = -4,
		[0] = 100,
	}
	local function ValueFunc(key)
		return valueLookupTable[key]
	end
	local callbacks = {}
	local function ReaderCallback(reader, changes)
		for key, prevValue in pairs(changes) do
			tinsert(callbacks, { reader = reader, key = key, prevValue = prevValue, newValue = reader[key] })
		end
	end

	local map = SmartMap.New("number", "number", ValueFunc)

	-- create a reader
	local reader = map:CreateReader(ReaderCallback)
	assertEquals(reader[10], 20)
	assertEquals(reader[-2], -4)

	-- pause callbacks twice
	map:SetCallbacksPaused(true)
	map:SetCallbacksPaused(true)

	-- change all the values
	valueLookupTable[10] = 1
	map:ValueChanged(10)
	valueLookupTable[-2] = 2
	map:ValueChanged(-2)
	valueLookupTable[0] = 3
	map:ValueChanged(0)
	assertEquals(#callbacks, 0)

	-- unpause callbacks
	map:SetCallbacksPaused(false)
	assertEquals(#callbacks, 0)
	map:SetCallbacksPaused(false)
	assertEquals(#callbacks, 2)

	-- sort the callbacks by key to make this stable
	sort(callbacks, function(a, b) return a.key < b.key end)

	-- check the callbacks
	assertEquals(callbacks[1].reader, reader)
	assertEquals(callbacks[1].key, -2)
	assertEquals(callbacks[1].prevValue, -4)
	assertEquals(callbacks[1].newValue, 2)
	assertEquals(callbacks[2].reader, reader)
	assertEquals(callbacks[2].key, 10)
	assertEquals(callbacks[2].prevValue, 20)
	assertEquals(callbacks[2].newValue, 1)
end
