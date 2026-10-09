local addonName, ns = ...

local function setAlertPosition(frame)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", ns.db.alertOffsetX, ns.db.alertOffsetY)
end

local function updateAlertAppearance(frame)
	local color = ns.db.screenColor
	frame:SetScale(ns.db.screenScale)
	frame.text:SetTextColor(color.r, color.g, color.b)
	frame:SetBackdropBorderColor(color.r, color.g, color.b, 0.9)
end

local function createAlertFrame()
	local frame = CreateFrame("Frame", "ForeverExpFoodAlertFrame", UIParent, "BackdropTemplate")
	frame:SetSize(460, 128)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.04, 0.05, 0.07, 0.94)

	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	frame.text:SetPoint("TOP", frame, "TOP", 0, -16)
	frame.text:SetWidth(420)
	frame.text:SetHeight(64)
	frame.text:SetJustifyH("CENTER")
	frame.text:SetWordWrap(true)

	frame.snoozeButton = CreateFrame("Button", "ForeverExpFoodAlertSnoozeButton", frame, "UIPanelButtonTemplate")
	frame.snoozeButton:SetSize(120, 24)
	frame.snoozeButton:SetPoint("BOTTOM", frame, "BOTTOM", -68, 12)
	frame.snoozeButton:SetScript("OnClick", function()
		ns.SnoozeReminders()
	end)

	frame.dismissButton = CreateFrame("Button", "ForeverExpFoodAlertDismissButton", frame, "UIPanelButtonTemplate")
	frame.dismissButton:SetSize(100, 24)
	frame.dismissButton:SetPoint("LEFT", frame.snoozeButton, "RIGHT", 8, 0)
	frame.dismissButton:SetScript("OnClick", function()
		ns.DismissReminder()
	end)

	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		local centerX, centerY = UIParent:GetCenter()
		ns.db.alertOffsetX = x - centerX
		ns.db.alertOffsetY = y - centerY
		setAlertPosition(self)
	end)
	frame:SetScript("OnUpdate", function(self, elapsed)
		if not self.remaining then
			return
		end

		self.remaining = self.remaining - elapsed
		if self.remaining <= 0 then
			self.remaining = nil
			self:Hide()
		end
	end)

	setAlertPosition(frame)
	updateAlertAppearance(frame)
	return frame
end

function ns.ShowScreenAlert(message, isPreview)
	if not ns.db then
		return false
	end

	local frame = ns.alertFrame or createAlertFrame()
	ns.alertFrame = frame
	local displayMessage = message
	if not displayMessage or displayMessage == "" then
		displayMessage = ns.db.screenMessage
	end
	if displayMessage == "" then
		displayMessage = ForeverExpFoodL.chatMessage
	end
	frame.text:SetText(displayMessage)
	if isPreview then
		frame.snoozeButton:Hide()
		frame.dismissButton:Hide()
	else
		frame.snoozeButton:SetText(string.format(ForeverExpFoodL.snoozeButton, ns.db.snoozeMinutes))
		frame.dismissButton:SetText(ForeverExpFoodL.dismissButton)
		frame.snoozeButton:Show()
		frame.dismissButton:Show()
	end
	updateAlertAppearance(frame)
	frame.remaining = ns.db.screenDuration
	frame:Show()
	return true
end

function ns.RefreshAlertButtons()
	if not ns.alertFrame or not ns.db then
		return
	end
	ns.alertFrame.snoozeButton:SetText(string.format(ForeverExpFoodL.snoozeButton, ns.db.snoozeMinutes))
end

function ns.HideScreenAlert()
	if not ns.alertFrame then
		return
	end
	ns.alertFrame.remaining = nil
	ns.alertFrame:Hide()
end

function ns.RefreshScreenAlert()
	if not ns.alertFrame or not ns.db then
		return
	end

	local message = ns.db.screenMessage
	ns.alertFrame.text:SetText(message ~= "" and message or ForeverExpFoodL.chatMessage)
	updateAlertAppearance(ns.alertFrame)
	ns.alertFrame.remaining = ns.db.screenDuration
end

function ns.ResetScreenAlertPosition()
	if not ns.db then
		return
	end

	ns.db.alertOffsetX = 0
	ns.db.alertOffsetY = 120
	if ns.alertFrame then
		setAlertPosition(ns.alertFrame)
	end
end