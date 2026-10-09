local addonName, ns = ...
local L = ForeverExpFoodL

local function makeCheckbox(parent, name, label, y)
	local checkbox = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
	_G[name .. "Text"]:SetText(label)
	return checkbox
end

local function refreshOptions()
	local panel = ns.optionsPanel
	if not panel or not ns.db then
		return
	end

	panel.chatCheckbox:SetChecked(ns.db.chatAlerts)
	panel.screenCheckbox:SetChecked(ns.db.screenAlerts)
	panel.noFoodCheckbox:SetChecked(ns.db.remindWhenNoFood)
	panel.repeatCheckbox:SetChecked(ns.db.repeatReminders)
	panel.intervalSlider:SetValue(ns.db.reminderMinutes)
	panel.intervalSlider:SetEnabled(ns.db.repeatReminders)
	UIDropDownMenu_SetSelectedValue(panel.snoozeDropdown, ns.db.snoozeMinutes)
	panel.messageBox:SetText(ns.db.screenMessage)
	panel.durationSlider:SetValue(ns.db.screenDuration == 0 and 21 or ns.db.screenDuration)
	panel.scaleSlider:SetValue(ns.db.screenScale * 100)
	panel.colorSwatch:SetColorTexture(ns.db.screenColor.r, ns.db.screenColor.g, ns.db.screenColor.b)
end

function ns.OpenOptions()
	if ns.settingsCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(ns.settingsCategory:GetID())
	elseif ns.settingsCategoryID and InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(ns.settingsCategoryID)
	end
end

function ns.InitializeOptions()
	if ns.optionsPanel then
		return
	end

	local panel = CreateFrame("Frame", "ForeverExpFoodOptionsPanel", UIParent)
	panel.name = "ForeverExpFood"
	ns.optionsPanel = panel

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -24)
	title:SetText("ForeverExpFood")

	local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	description:SetWidth(560)
	description:SetJustifyH("LEFT")
	description:SetText(L.description)

	panel.chatCheckbox = makeCheckbox(panel, "ForeverExpFoodChatCheckbox", L.chatOption, -105)
	panel.screenCheckbox = makeCheckbox(panel, "ForeverExpFoodScreenCheckbox", L.screenOption, -135)
	panel.repeatCheckbox = makeCheckbox(panel, "ForeverExpFoodRepeatCheckbox", L.repeatOption, -165)
	panel.noFoodCheckbox = makeCheckbox(panel, "ForeverExpFoodNoFoodCheckbox", L.noFoodOption, -195)

	panel.chatCheckbox:SetScript("OnClick", function(self)
		ns.db.chatAlerts = self:GetChecked()
		ns.Scan()
	end)
	panel.screenCheckbox:SetScript("OnClick", function(self)
		ns.db.screenAlerts = self:GetChecked()
		if not ns.db.screenAlerts then
			ns.HideScreenAlert()
		end
		ns.Scan()
	end)
	panel.repeatCheckbox:SetScript("OnClick", function(self)
		ns.db.repeatReminders = self:GetChecked()
		panel.intervalSlider:SetEnabled(ns.db.repeatReminders)
		ns.Scan()
	end)
	panel.noFoodCheckbox:SetScript("OnClick", function(self)
		ns.db.remindWhenNoFood = self:GetChecked()
		ns.Scan()
	end)

	local intervalLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intervalLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 48, -235)
	intervalLabel:SetText(string.format(L.interval, ns.db.reminderMinutes))

	panel.intervalSlider = CreateFrame("Slider", "ForeverExpFoodIntervalSlider", panel, "OptionsSliderTemplate")
	panel.intervalSlider:SetPoint("TOPLEFT", intervalLabel, "BOTTOMLEFT", 0, -12)
	panel.intervalSlider:SetMinMaxValues(1, 60)
	panel.intervalSlider:SetValueStep(1)
	panel.intervalSlider:SetObeyStepOnDrag(true)
	panel.intervalSlider:SetWidth(260)
	panel.intervalSlider:SetScript("OnValueChanged", function(_, value)
		local minutes = math.floor(value + 0.5)
		ns.db.reminderMinutes = minutes
		intervalLabel:SetText(string.format(L.interval, minutes))
	end)

	local snoozeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	snoozeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 340, -235)
	snoozeLabel:SetText(L.snoozeOption)

	panel.snoozeDropdown = CreateFrame("Frame", "ForeverExpFoodSnoozeDropdown", panel, "UIDropDownMenuTemplate")
	panel.snoozeDropdown:SetPoint("TOPLEFT", snoozeLabel, "BOTTOMLEFT", -16, -2)
	UIDropDownMenu_SetWidth(panel.snoozeDropdown, 105)
	UIDropDownMenu_Initialize(panel.snoozeDropdown, function(_, level)
		for _, minutes in ipairs({ 1, 5, 10, 15, 30, 60 }) do
			local duration = minutes
			local info = UIDropDownMenu_CreateInfo()
			info.text = string.format(L.snoozeDuration, duration)
			info.value = duration
			info.checked = ns.db.snoozeMinutes == duration
			info.func = function()
				ns.db.snoozeMinutes = duration
				UIDropDownMenu_SetSelectedValue(panel.snoozeDropdown, duration)
				ns.RefreshAlertButtons()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	local messageLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	messageLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 48, -330)
	messageLabel:SetText(L.screenMessageLabel)

	local messageHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	messageHint:SetPoint("TOPLEFT", messageLabel, "BOTTOMLEFT", 0, -4)
	messageHint:SetText(L.screenMessageHint)

	panel.messageBox = CreateFrame("EditBox", "ForeverExpFoodMessageEditBox", panel, "InputBoxTemplate")
	panel.messageBox:SetSize(390, 24)
	panel.messageBox:SetPoint("TOPLEFT", messageHint, "BOTTOMLEFT", 0, -8)
	panel.messageBox:SetAutoFocus(false)
	panel.messageBox:SetMaxLetters(200)
	panel.messageBox:SetScript("OnTextChanged", function(self)
		ns.db.screenMessage = self:GetText()
	end)

	panel.previewButton = CreateFrame("Button", "ForeverExpFoodPreviewButton", panel, "UIPanelButtonTemplate")
	panel.previewButton:SetSize(150, 24)
	panel.previewButton:SetPoint("LEFT", panel.messageBox, "RIGHT", 14, 0)
	panel.previewButton:SetText(L.previewMove)
	panel.previewButton:SetScript("OnClick", function()
		panel.messageBox:ClearFocus()
		local message = ns.db.screenMessage
		ns.ShowScreenAlert(message ~= "" and message or string.format(L.chatMessage, 5), true)
	end)

	local durationLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	durationLabel:SetPoint("TOPLEFT", panel.messageBox, "BOTTOMLEFT", 0, -24)
	durationLabel:SetText(ns.db.screenDuration == 0 and L.screenDurationUnlimited
		or string.format(L.screenDuration, ns.db.screenDuration))

	panel.durationSlider = CreateFrame("Slider", "ForeverExpFoodDurationSlider", panel, "OptionsSliderTemplate")
	panel.durationSlider:SetPoint("TOPLEFT", durationLabel, "BOTTOMLEFT", 0, -12)
	panel.durationSlider:SetMinMaxValues(1, 21)
	panel.durationSlider:SetValueStep(1)
	panel.durationSlider:SetObeyStepOnDrag(true)
	panel.durationSlider:SetWidth(260)
	panel.durationSlider:SetScript("OnValueChanged", function(_, value)
		local seconds = math.floor(value + 0.5)
		ns.db.screenDuration = seconds == 21 and 0 or seconds
		durationLabel:SetText(ns.db.screenDuration == 0 and L.screenDurationUnlimited
			or string.format(L.screenDuration, ns.db.screenDuration))
		ns.RefreshScreenAlert()
	end)

	local scaleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	scaleLabel:SetPoint("TOPLEFT", panel.durationSlider, "BOTTOMLEFT", 0, -24)
	scaleLabel:SetText(string.format(L.screenScale, math.floor(ns.db.screenScale * 100 + 0.5)))

	panel.scaleSlider = CreateFrame("Slider", "ForeverExpFoodScaleSlider", panel, "OptionsSliderTemplate")
	panel.scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -12)
	panel.scaleSlider:SetMinMaxValues(75, 150)
	panel.scaleSlider:SetValueStep(5)
	panel.scaleSlider:SetObeyStepOnDrag(true)
	panel.scaleSlider:SetWidth(260)
	panel.scaleSlider:SetScript("OnValueChanged", function(_, value)
		local percent = math.floor(value / 5 + 0.5) * 5
		ns.db.screenScale = percent / 100
		scaleLabel:SetText(string.format(L.screenScale, percent))
	end)

	local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	colorLabel:SetPoint("TOPLEFT", panel.scaleSlider, "BOTTOMLEFT", 0, -24)
	colorLabel:SetText(L.screenColor)

	panel.colorButton = CreateFrame("Button", "ForeverExpFoodColorButton", panel, "UIPanelButtonTemplate")
	panel.colorButton:SetSize(110, 24)
	panel.colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 12, 0)
	panel.colorButton:SetText(L.screenColor)
	panel.colorSwatch = panel.colorButton:CreateTexture(nil, "OVERLAY")
	panel.colorSwatch:SetSize(16, 16)
	panel.colorSwatch:SetPoint("RIGHT", panel.colorButton, "RIGHT", -6, 0)
	panel.colorButton:SetScript("OnClick", function()
		if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
			return
		end

		local color = ns.db.screenColor
		ColorPickerFrame:SetupColorPickerAndShow({
			r = color.r,
			g = color.g,
			b = color.b,
			hasOpacity = false,
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				ns.db.screenColor = { r = r, g = g, b = b }
				panel.colorSwatch:SetColorTexture(r, g, b)
				ns.RefreshScreenAlert()
			end,
			cancelFunc = function(previous)
				ns.db.screenColor = { r = previous.r, g = previous.g, b = previous.b }
				panel.colorSwatch:SetColorTexture(previous.r, previous.g, previous.b)
				ns.RefreshScreenAlert()
			end,
		})
	end)

	panel.resetPositionButton = CreateFrame("Button", "ForeverExpFoodResetPositionButton", panel, "UIPanelButtonTemplate")
	panel.resetPositionButton:SetSize(145, 24)
	panel.resetPositionButton:SetPoint("LEFT", panel.colorButton, "RIGHT", 12, 0)
	panel.resetPositionButton:SetText(L.resetPosition)
	panel.resetPositionButton:SetScript("OnClick", function()
		ns.ResetScreenAlertPosition()
	end)

	panel:SetScript("OnShow", refreshOptions)
	panel:SetScript("OnHide", function()
		if ns.alertFrame and ns.alertFrame.isPreview then
			ns.HideScreenAlert()
		end
		ns.Scan()
	end)
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		ns.settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "ForeverExpFood")
		Settings.RegisterAddOnCategory(ns.settingsCategory)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
		ns.settingsCategoryID = panel.name
	end

	SLASH_FOREVEREXPFOOD1 = "/foreverexpfood"
	SLASH_FOREVEREXPFOOD2 = "/fef"
	SlashCmdList.FOREVEREXPFOOD = function(message)
		local command = (message or ""):lower():match("^%s*(.-)%s*$")
		if command == "debug" then
			ns.DebugStatus()
		else
			ns.OpenOptions()
		end
	end
	refreshOptions()
end