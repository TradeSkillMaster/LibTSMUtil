local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local Tree = LibTSMUtil:IncludeClassType("Tree")



-- ============================================================================
-- Tests
-- ============================================================================

TestTree = {}

local function DumpTree(tree)
	local result = {}
	local parentResultLookup = {}
	for node in tree:DepthFirstIterator() do
		local name = tree:GetData(node, "name")
		local parentNode = tree:GetParent(node)
		local parentName = parentNode and tree:GetData(parentNode, "name") or nil
		local parentResult = parentName and parentResultLookup[parentName] or result
		parentResultLookup[name] = {}
		parentResult[name] = parentResultLookup[name]
	end
	return result
end

function TestTree:TestSimple()
	local tree = Tree.Create("name")

	local nodeA = tree:Insert(nil, "a")
	local nodeAA = tree:Insert(nodeA, "aa")
	local nodeAB = tree:Insert(nodeA, "ab")
	local nodeAAA = tree:Insert(nodeAA, "aaa")
	assertEquals(DumpTree(tree), {
		a = {
			aa = {
				aaa = {},
			},
			ab = {},
		},
	})

	tree:RemoveAllChildren(nodeAA)
	tree:SetChildren(nodeAB, nodeAAA)
	assertEquals(DumpTree(tree), {
		a = {
			aa = {},
			ab = {
				aaa = {},
			},
		},
	})

	tree:MoveUp(nodeAB)
	assertEquals(DumpTree(tree), {
		ab = {
			aaa = {},
		},
	})

	tree:SetData(nodeAB, "name", "newA")
	assertEquals(DumpTree(tree), {
		newA = {
			aaa = {},
		},
	})
end
