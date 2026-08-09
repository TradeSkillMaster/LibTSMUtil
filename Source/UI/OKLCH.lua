-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

-- NOTE: This implements the OKLab / OKLCH color spaces by Björn Ottosson (https://bottosson.github.io/posts/oklab/).

local LibTSMUtil = select(2, ...).LibTSMUtil
local OKLCH = LibTSMUtil:Init("UI.OKLCH")
local Math = LibTSMUtil:Include("Lua.Math")
local private = {}
local GAMUT_SEARCH_ITERATIONS = 24
local MAX_GAMUT_CHROMA = 0.5
local GAMUT_EPSILON = 0.0001
local DEG_TO_RAD = math.pi / 180



-- ============================================================================
-- Module Functions
-- ============================================================================

---Converts from OKLCH to RGB, reducing chroma as needed to stay within the RGB gamut.
---@param l number Lightness from 0 to 100
---@param c number Chroma in OKLab units (typically 0 to ~0.4)
---@param h number Hue in degrees from 0 to 360
---@return number r
---@return number g
---@return number b
function OKLCH.ToRGB(l, c, h)
	return private.OKLCHToRGB(l, c, h)
end

---Converts from RGB to OKLCH.
---@param r number The red value from 0 to 255
---@param g number The green value from 0 to 255
---@param b number The blue value from 0 to 255
---@return number l
---@return number c
---@return number h
function OKLCH.FromRGB(r, g, b)
	return private.RGBToOKLCH(r, g, b)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ToLinear(c)
	if c > 0.04045 then
		return ((c + 0.055) / 1.055) ^ 2.4
	else
		return c / 12.92
	end
end

function private.FromLinear(c)
	if c > 0.0031308 then
		return 1.055 * (c ^ (1 / 2.4)) - 0.055
	else
		return 12.92 * c
	end
end

function private.LinearRGBToOKLab(r, g, b)
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
	local okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
	local okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
	local okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	return okL, okA, okB
end

function private.OKLabToLinearRGB(okL, okA, okB)
	local l = okL + 0.3963377774 * okA + 0.2158037573 * okB
	local m = okL - 0.1055613458 * okA - 0.0638541728 * okB
	local s = okL - 0.0894841775 * okA - 1.2914855480 * okB
	l = l * l * l
	m = m * m * m
	s = s * s * s
	local r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	local b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	return r, g, b
end

function private.OKLCHToLinearRGB(l, c, h)
	local hrad = h * DEG_TO_RAD
	return private.OKLabToLinearRGB(l, c * math.cos(hrad), c * math.sin(hrad))
end

function private.IsLinearRGBInGamut(r, g, b)
	return r >= -GAMUT_EPSILON and r <= 1 + GAMUT_EPSILON
		and g >= -GAMUT_EPSILON and g <= 1 + GAMUT_EPSILON
		and b >= -GAMUT_EPSILON and b <= 1 + GAMUT_EPSILON
end

function private.MaxChromaForLH(l, h)
	if l <= 0 or l >= 100 then
		return 0
	end
	local lFraction = l / 100
	local low, high = 0, MAX_GAMUT_CHROMA
	for _ = 1, GAMUT_SEARCH_ITERATIONS do
		local mid = (low + high) / 2
		local r, g, b = private.OKLCHToLinearRGB(lFraction, mid, h)
		if private.IsLinearRGBInGamut(r, g, b) then
			low = mid
		else
			high = mid
		end
	end
	return low
end

function private.OKLCHToRGB(l, c, h)
	if l <= 0 then
		return 0, 0, 0
	elseif l >= 100 then
		return 255, 255, 255
	end
	c = min(c, private.MaxChromaForLH(l, h))
	local r, g, b = private.OKLCHToLinearRGB(l / 100, c, h)
	r = Math.Round(private.FromLinear(Math.Bound(r, 0, 1)) * 255)
	g = Math.Round(private.FromLinear(Math.Bound(g, 0, 1)) * 255)
	b = Math.Round(private.FromLinear(Math.Bound(b, 0, 1)) * 255)
	assert(r >= 0 and r <= 255)
	assert(g >= 0 and g <= 255)
	assert(b >= 0 and b <= 255)
	return r, g, b
end

function private.RGBToOKLCH(r, g, b)
	local okL, okA, okB = private.LinearRGBToOKLab(private.ToLinear(r / 255), private.ToLinear(g / 255), private.ToLinear(b / 255))
	local h = math.atan2(okB, okA) / DEG_TO_RAD
	if h < 0 then
		h = h + 360
	end
	return okL * 100, math.sqrt(okA * okA + okB * okB), h
end
