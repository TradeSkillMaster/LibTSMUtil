import { defineConfig } from "vitepress"
export default defineConfig({
    base: "/LibTSMUtil/",
    title: "LibTSMUtil",
    description: "General utility functions and classes for World of Warcraft addons",
    ignoreDeadLinks: true,
    themeConfig: {
        nav: [{ text: "Home", link: "/" }],
        sidebar: [{
            items: [
                { text: "Home", link: "/" },
                { text: "Lua", items: [
                    { text: "DebugStack", link: "/DebugStack" },
                    { text: "Math", link: "/Math" },
                    { text: "Memory", link: "/Memory" },
                    { text: "String", link: "/String" },
                    { text: "Table", link: "/Table" },
                    { text: "Vararg", link: "/Vararg" },
                ]},
                { text: "BaseType", items: [
                    { text: "ContextManager", link: "/ContextManager" },
                    { text: "Encoder", link: "/Encoder" },
                    { text: "EnumType", link: "/EnumType" },
                    { text: "Future", link: "/Future" },
                    { text: "Iterator", link: "/Iterator" },
                    { text: "LongString", link: "/LongString" },
                    { text: "NamedTupleList", link: "/NamedTupleList" },
                    { text: "ObjectPool", link: "/ObjectPool" },
                    { text: "OrderedTable", link: "/OrderedTable" },
                    { text: "Range", link: "/Range" },
                    { text: "Signal", link: "/Signal" },
                    { text: "SmartMap", link: "/SmartMap" },
                    { text: "TempTable", link: "/TempTable" },
                    { text: "Tree", link: "/Tree" },
                ]},
                { text: "Util", items: [
                    { text: "BinarySearch", link: "/BinarySearch" },
                    { text: "CallbackRegistry", link: "/CallbackRegistry" },
                    { text: "ExecutionTime", link: "/ExecutionTime" },
                    { text: "Hash", link: "/Hash" },
                    { text: "Log", link: "/Log" },
                ]},
                { text: "Format", items: [
                    { text: "CSV", link: "/CSV" },
                    { text: "JSON", link: "/JSON" },
                    { text: "MoneyFormatter", link: "/MoneyFormatter" },
                    { text: "StringBuilder", link: "/StringBuilder" },
                ]},
                { text: "UI", items: [
                    { text: "Color", link: "/Color" },
                    { text: "HSLuv", link: "/HSLuv" },
                    { text: "Money", link: "/Money" },
                ]},
                { text: "FSM", link: "/FSM" },
            ],
        }],
    },
})
