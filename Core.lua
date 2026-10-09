local addonName, ns = ...

local defaults = {
	chatAlerts = true,
	screenAlerts = true,
	remindWhenNoFood = false,
	repeatReminders = true,
	reminderMinutes = 10,
	snoozeMinutes = 1,
	screenMessage = "",
	screenDuration = 5,
	screenScale = 1,
	alertOffsetX = 0,
	alertOffsetY = 120,
	configured = false,
}

local foodTooltipCache = {}
local auraTooltipCache = {}
local cachedBagResult
local lastReminderTime
local reminderState
local dismissedReminderState
local snoozeUntil
local scanTicker

local snoozeDurations = { 1, 5, 10, 15, 30, 60 }

local function initializeSettings()
	if type(ForeverExpFoodDB) ~= "table" then
		ForeverExpFoodDB = {}
	end

	for key, value in pairs(defaults) do
		if type(ForeverExpFoodDB[key]) ~= type(value) then
			ForeverExpFoodDB[key] = value
		end
	end

	ForeverExpFoodDB.reminderMinutes = math.max(1, math.min(60, math.floor(ForeverExpFoodDB.reminderMinutes)))
	local validSnoozeDuration = false
	for _, minutes in ipairs(snoozeDurations) do
		if ForeverExpFoodDB.snoozeMinutes == minutes then
			validSnoozeDuration = true
			break
		end
	end
	if not validSnoozeDuration then
		ForeverExpFoodDB.snoozeMinutes = defaults.snoozeMinutes
	end
	ForeverExpFoodDB.screenDuration = math.max(1, math.min(20, math.floor(ForeverExpFoodDB.screenDuration)))
	ForeverExpFoodDB.screenScale = math.max(0.75, math.min(1.5, ForeverExpFoodDB.screenScale))
	if type(ForeverExpFoodDB.screenColor) ~= "table" then
		ForeverExpFoodDB.screenColor = { r = 1, g = 0.82, b = 0 }
	else
		for _, channel in ipairs({ "r", "g", "b" }) do
			local value = ForeverExpFoodDB.screenColor[channel]
			if type(value) ~= "number" or value ~= value then
				ForeverExpFoodDB.screenColor[channel] = channel == "r" and 1 or channel == "g" and 0.82 or 0
			else
				ForeverExpFoodDB.screenColor[channel] = math.max(0, math.min(1, value))
			end
		end
	end
	ns.db = ForeverExpFoodDB
end

local function tooltipHasExperienceBonus(tooltipData)
	if not tooltipData or type(tooltipData.lines) ~= "table" or #tooltipData.lines == 0 then
		return nil
	end

	local text = {}
	for _, line in ipairs(tooltipData.lines) do
		if line.leftText then
			table.insert(text, line.leftText)
		end
		if line.rightText then
			table.insert(text, line.rightText)
		end
	end

	local description = table.concat(text, " "):lower()
	local uppercaseToLowercase = {
		["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü", ["É"] = "é", ["È"] = "è",
		["Ê"] = "ê", ["À"] = "à", ["Â"] = "â", ["Ç"] = "ç", ["Î"] = "î",
		["Ï"] = "ï", ["Ô"] = "ô", ["Ù"] = "ù", ["Û"] = "û", ["Ñ"] = "ñ",
		["Ё"] = "ё", ["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г",
		["Д"] = "д", ["Е"] = "е", ["Ж"] = "ж", ["З"] = "з", ["И"] = "и",
		["Й"] = "й", ["К"] = "к", ["Л"] = "л", ["М"] = "м", ["Н"] = "н",
		["О"] = "о", ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т",
		["У"] = "у", ["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц", ["Ч"] = "ч",
		["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ", ["Ы"] = "ы", ["Ь"] = "ь",
		["Э"] = "э", ["Ю"] = "ю", ["Я"] = "я",
	}
	for uppercase, lowercase in pairs(uppercaseToLowercase) do
		description = description:gsub(uppercase, lowercase)
	end
	description = description:gsub("%s+%%", "%%")

	local function containsAny(terms)
		for _, term in ipairs(terms) do
			if description:find(term, 1, true) then
				return true
			end
		end
		return false
	end

	local hasFivePercentBonus = false
	for percentage in description:gmatch("(%d+)%s*%%") do
		if tonumber(percentage) == 5 then
			hasFivePercentBonus = true
			break
		end
	end

	return containsAny(ForeverExpFoodL.experienceTerms)
		and containsAny(ForeverExpFoodL.killTerms)
		and containsAny(ForeverExpFoodL.increaseTerms)
		and hasFivePercentBonus
end

local function hasQualifyingFood()
	if cachedBagResult ~= nil then
		return cachedBagResult
	end
	if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
		return nil
	end

	local unresolvedTooltip = false
	local bagCount = NUM_BAG_SLOTS or 0
	for bagID = 0, bagCount do
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slot = 1, slotCount do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
			local itemID = itemInfo and itemInfo.itemID
			if itemID then
				local isQualifyingFood = foodTooltipCache[itemID]
				if isQualifyingFood == nil then
					local tooltipData = C_TooltipInfo and C_TooltipInfo.GetBagItem
						and C_TooltipInfo.GetBagItem(bagID, slot)
					if tooltipData and type(tooltipData.lines) == "table" and #tooltipData.lines > 0 then
						isQualifyingFood = tooltipHasExperienceBonus(tooltipData)
						foodTooltipCache[itemID] = isQualifyingFood
					else
						unresolvedTooltip = true
					end
				end
				if isQualifyingFood then
					cachedBagResult = true
					return true
				end
			end
		end
	end

	if unresolvedTooltip then
		return nil
	end
	cachedBagResult = false
	return false
end

local function invalidateBagScan(itemID)
	cachedBagResult = nil
	if itemID then
		foodTooltipCache[itemID] = nil
	end
end

local function hasExperienceBuff()
	if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex
		or not C_TooltipInfo or not C_TooltipInfo.GetUnitBuff then
		return nil
	end

	local index = 1
	local unresolvedTooltip = false
	while true do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
		if not aura then
			if unresolvedTooltip then
				return nil
			end
			return false
		end

		local hasExperienceBonus = aura.spellId and auraTooltipCache[aura.spellId]
		if hasExperienceBonus == nil then
			local tooltipData = C_TooltipInfo.GetUnitBuff("player", index, "HELPFUL")
			if tooltipData and type(tooltipData.lines) == "table" and #tooltipData.lines > 0 then
				hasExperienceBonus = tooltipHasExperienceBonus(tooltipData)
				if aura.spellId then
					auraTooltipCache[aura.spellId] = hasExperienceBonus
				end
			else
				unresolvedTooltip = true
			end
		end
		if hasExperienceBonus then
			return true
		end
		index = index + 1
	end
end

local function sendReminder(message, useCustomScreenMessage)
	local sent = false
	if ns.db.chatAlerts and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff80d7ffForeverExpFood:|r " .. message)
		sent = true
	end
	if ns.db.screenAlerts and ns.ShowScreenAlert then
		local screenMessage = useCustomScreenMessage and ns.db.screenMessage ~= "" and ns.db.screenMessage or message
		sent = ns.ShowScreenAlert(screenMessage) or sent
	end
	return sent
end

function ns.Scan()
	if not ns.db then
		return
	end
	if UnitAffectingCombat and UnitAffectingCombat("player") then
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
		return
	end
	if not ns.db.chatAlerts and not ns.db.screenAlerts then
		lastReminderTime = nil
		reminderState = nil
		dismissedReminderState = nil
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
		return
	end

	local hasFood = hasQualifyingFood()
	if hasFood == nil then
		return
	end

	local state
	local message
	local useCustomScreenMessage = false
	if hasFood then
		local hasBuff = hasExperienceBuff()
		if hasBuff == nil then
			return
		elseif hasBuff then
			lastReminderTime = nil
			reminderState = nil
			dismissedReminderState = nil
			if ns.HideScreenAlert then
				ns.HideScreenAlert()
			end
			return
		end
		state = "missing-buff"
		message = ForeverExpFoodL.chatMessage
		useCustomScreenMessage = true
	elseif ns.db.remindWhenNoFood then
		local hasBuff = hasExperienceBuff()
		if hasBuff == nil then
			return
		elseif hasBuff then
			lastReminderTime = nil
			reminderState = nil
			dismissedReminderState = nil
			if ns.HideScreenAlert then
				ns.HideScreenAlert()
			end
			return
		end
		state = "missing-food"
		message = ForeverExpFoodL.noFoodMessage
	else
		lastReminderTime = nil
		reminderState = nil
		dismissedReminderState = nil
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
		return
	end

	if not ns.db.configured then
		return
	end
	if reminderState ~= state then
		reminderState = state
		lastReminderTime = nil
	end
	if dismissedReminderState and dismissedReminderState ~= state then
		dismissedReminderState = nil
	end
	if dismissedReminderState == state then
		return
	end

	local now = GetTime()
	if snoozeUntil then
		if now < snoozeUntil then
			return
		end
		snoozeUntil = nil
	end
	local intervalElapsed = lastReminderTime
		and now - lastReminderTime >= ns.db.reminderMinutes * 60
	if not lastReminderTime or (ns.db.repeatReminders and intervalElapsed) then
		if sendReminder(message, useCustomScreenMessage) then
			lastReminderTime = now
		end
	end
end

function ns.SnoozeReminders()
	if not ns.db then
		return
	end

	snoozeUntil = GetTime() + ns.db.snoozeMinutes * 60
	lastReminderTime = nil
	if ns.alertFrame then
		ns.HideScreenAlert()
	end
end

function ns.DismissReminder()
	if reminderState then
		dismissedReminderState = reminderState
	end
	lastReminderTime = nil
	if ns.alertFrame then
		ns.HideScreenAlert()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
if eventFrame.RegisterUnitEvent then
	eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
else
	eventFrame:RegisterEvent("UNIT_AURA")
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then
			return
		end
		eventFrame:UnregisterEvent("ADDON_LOADED")
		initializeSettings()
		if ns.InitializeOptions then
			ns.InitializeOptions()
		end
	elseif event == "PLAYER_LOGIN" then
		invalidateBagScan()
		if C_Timer and C_Timer.NewTicker then
			scanTicker = C_Timer.NewTicker(60, ns.Scan)
		else
			local elapsedSinceScan = 0
			eventFrame:SetScript("OnUpdate", function(_, elapsed)
				elapsedSinceScan = elapsedSinceScan + elapsed
				if elapsedSinceScan >= 60 then
					elapsedSinceScan = elapsedSinceScan % 60
					ns.Scan()
				end
			end)
		end
		if not ns.db.configured and ns.OpenOptions then
			if C_Timer and C_Timer.After then
				C_Timer.After(2, ns.OpenOptions)
			else
				ns.OpenOptions()
			end
		end
		ns.Scan()
	elseif event == "BAG_UPDATE_DELAYED" then
		invalidateBagScan()
		ns.Scan()
	elseif event == "PLAYER_ENTERING_WORLD" then
		invalidateBagScan()
		ns.Scan()
	elseif event == "PLAYER_REGEN_DISABLED" then
		lastReminderTime = nil
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.Scan()
	elseif event == "UNIT_AURA" then
		if arg1 == "player" then
			ns.Scan()
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		invalidateBagScan(arg1)
		ns.Scan()
	end
end)