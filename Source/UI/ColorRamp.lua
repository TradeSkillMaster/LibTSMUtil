-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ColorRamp = LibTSMUtil:DefineClassType("ColorRamp")
local Color = LibTSMUtil:IncludeClassType("Color")
local OKLCH = LibTSMUtil:Include("UI.OKLCH")



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new color ramp defined by a constant hue and chroma.
---@param hue number Hue in degrees from 0 to 360
---@param chroma number Chroma in OKLab units (capped to the RGB gamut at each step)
---@return ColorRamp
function ColorRamp.__static.New(hue, chroma)
	return ColorRamp(hue, chroma)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ColorRamp.__private:__init(hue, chroma)
	self._hue = hue
	self._chroma = chroma
end

function ColorRamp:__tostring()
	return format("ColorRamp:%.1f,%.3f", self._hue, self._chroma)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the RGBA values at a lightness step on the ramp.
---@param step number Lightness step from 0 to 100
---@return number r
---@return number g
---@return number b
---@return number a
function ColorRamp:GetRGBA(step)
	local r, g, b = OKLCH.ToRGB(step, self._chroma, self._hue)
	return r, g, b, 255
end

---Gets the color at a lightness step on the ramp.
---@param step number Lightness step from 0 to 100
---@return Color
function ColorRamp:GetColor(step)
	return Color(self:GetRGBA(step))
end

---Sets the hue and chroma values of the ramp.
---@param hue number Hue in degrees from 0 to 360
---@param chroma number Chroma in OKLab units (capped to the RGB gamut at each step)
function ColorRamp:SetHueChroma(hue, chroma)
	self._hue = hue
	self._chroma = chroma
end

---Gets the hue and chroma values of the ramp.
---@return number hue
---@return number chroma
function ColorRamp:GetHueChroma()
	return self._hue, self._chroma
end
