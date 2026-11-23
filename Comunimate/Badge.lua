-- The orc badge: Comunimate's mascot on screen, showing whether you're talking.
--   quiet     whistling, happy "U U" eyes, music notes
--   speaking  yelling on red, bouncing
-- Our own cartoon art (Media/orc_*.tga, drawn by tools/make_icons.py).
-- Click him to open settings. Turn on "Move the orc" in settings to drag him.

local _, ns = ...
local B = {}
ns.Badge = B


function B:Build()
	if self.frame then return end
	local b = CreateFrame("Frame", "ComunimateBadge", UIParent)
	self.frame = b
	b:SetFrameStrata("MEDIUM")
	b:SetClampedToScreen(true)
	b:SetMovable(true)
	b:RegisterForDrag("LeftButton")
	b:EnableMouse(true)
	b:SetScript("OnDragStart", function(self)
		if ns.db.badgeMovable then
			self.dragging = true
			self:StartMoving()
		end
	end)
	b:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		ns.db.badgePosition = { point, relPoint, x, y }
	end)
	b:SetScript("OnMouseUp", function(self, mouse)
		if self.dragging then
			self.dragging = false
			return
		end
		if mouse == "LeftButton" or mouse == "RightButton" then ns.Options:Toggle() end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Comunimate")
		GameTooltip:AddLine("Click for settings", 1, 1, 1)
		GameTooltip:AddLine("Hold the mic button to talk", 0.8, 0.8, 0.8)
		if ns.db.badgeMovable then GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local art = b:CreateTexture(nil, "ARTWORK")
	art:SetAllPoints()
	self.art = art

	-- Optional gold ring on top (Settings > Badge > Gold frame).
	local ring = b:CreateTexture(nil, "OVERLAY")
	ring:SetTexture("Interface\\AddOns\\Comunimate\\Media\\frame_gold")
	ring:SetPoint("TOPLEFT", -2, 2)
	ring:SetPoint("BOTTOMRIGHT", 2, -2)
	self.ring = ring

	-- Comic bounce while yelling.
	local bounce = art:CreateAnimationGroup()
	bounce:SetLooping("BOUNCE")
	local grow = bounce:CreateAnimation("Scale")
	grow:SetScaleFrom(1, 1)
	grow:SetScaleTo(1.12, 1.12)
	grow:SetDuration(0.18)
	grow:SetOrigin("BOTTOM", 0, 0)
	self.bounce = bounce

	local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOP", b, "BOTTOM", 0, -2)
	self.label = label

	-- Shown only while moving it.
	local hint = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("BOTTOM", b, "TOP", 0, 2)
	hint:SetText("Drag me")
	self.hint = hint

	self:ApplyLayout()
	self:SetState(nil)
end

function B:ApplyLayout()
	local b = self.frame
	if not b then return end
	local size = ns.db.badgeSize or 56
	b:SetSize(size, size)
	b:ClearAllPoints()
	local p = ns.db.badgePosition
	if p then
		b:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 470, 150)
	end
	self.hint:SetShown(ns.db.badgeMovable and true or false)
	self.ring:SetShown(ns.db.badgeFrame and true or false)
	self:SetState(self.state)  -- picks up a new mascot
	b:SetShown(ns.db.showBadge)
end

-- state: nil (quiet) | "listening" | "thinking" | "noapp"
function B:SetState(state)
	if not self.frame then return end
	self.state = state
	local speaking = state == "listening"
	self.art:SetTexture(ns.Mascot:Path(speaking))
	self.art:SetDesaturated(state == "noapp")
	if speaking then self.bounce:Play() else self.bounce:Stop() end
	if speaking then
		self.label:SetText("|cffff5040Speaking|r")
	elseif state == "thinking" then
		self.label:SetText("|cffaaaaaaWriting...|r")
	elseif state == "noapp" then
		self.label:SetText("|cffff9900No voice app|r")
	else
		self.label:SetText("")
	end
end
