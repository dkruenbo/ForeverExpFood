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
local uppercaseToLowercase = {
	["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü", ["Á"] = "á", ["É"] = "é",
	["Í"] = "í", ["Ó"] = "ó", ["Ú"] = "ú", ["À"] = "à", ["È"] = "è",
	["Ì"] = "ì", ["Ò"] = "ò", ["Ù"] = "ù", ["Ê"] = "ê", ["Â"] = "â",
	["Î"] = "î", ["Ô"] = "ô", ["Û"] = "û", ["Ç"] = "ç", ["Ñ"] = "ñ",
	["Ё"] = "ё", ["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г",
	["Д"] = "д", ["Е"] = "е", ["Ж"] = "ж", ["З"] = "з", ["И"] = "и",
	["Й"] = "й", ["К"] = "к", ["Л"] = "л", ["М"] = "м", ["Н"] = "н",
	["О"] = "о", ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т",
	["У"] = "у", ["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц", ["Ч"] = "ч",
	["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ", ["Ы"] = "ы", ["Ь"] = "ь",
	["Э"] = "э", ["Ю"] = "ю", ["Я"] = "я",
}

local function normalizeTooltipText(text)
	text = text:lower()
	for uppercase, lowercase in pairs(uppercaseToLowercase) do
		text = text:gsub(uppercase, lowercase)
	end
	return text
end

local function containsAny(text, terms)
	for _, term in ipairs(terms) do
		if text:find(term, 1, true) then
			return true
		end
	end
	return false
end

local function hasExperienceKillContext(text)
	return containsAny(text, ForeverExpFoodL.experienceTerms)
		and containsAny(text, ForeverExpFoodL.killTerms)
		and containsAny(text, ForeverExpFoodL.increaseTerms)
end

local function distanceToTerms(text, terms, percentStart, percentEnd)
	local closestDistance = math.huge
	for _, term in ipairs(terms) do
		local searchStart = 1
		while true do
			local termStart, termEnd = text:find(term, searchStart, true)
			if not termStart then
				break
			end

			local distance
			if termEnd < percentStart then
				distance = percentStart - termEnd
			elseif termStart > percentEnd then
				distance = termStart - percentEnd
			else
				distance = 0
			end
			closestDistance = math.min(closestDistance, distance)
			searchStart = termStart + 1
		end
	end
	return closestDistance
end

local function tooltipLineText(line)
	return table.concat({ line.leftText or "", line.rightText or "" }, " ")
end

local function debugPrint(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff80d7ffForeverExpFood debug:|r " .. message)
	end
end

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

local function tooltipExperienceBonusPercent(tooltipData)
	if not tooltipData or type(tooltipData.lines) ~= "table" or #tooltipData.lines == 0 then
		return nil
	end

	for _, line in ipairs(tooltipData.lines) do
		local text = normalizeTooltipText(tooltipLineText(line))
		if hasExperienceKillContext(text) then
			local searchStart = 1
			local closestPercent
			local closestDistance = math.huge
			while true do
				local matchStart, matchEnd, percentage = text:find("(%d+)%s*%%", searchStart)
				if not matchStart then
					break
				end

				local previousCharacter = matchStart > 1 and text:sub(matchStart - 1, matchStart - 1)
				if not previousCharacter or not previousCharacter:match("[%d%.,]") then
					local value = tonumber(percentage)
					if value and value > 0 then
						local experienceDistance = distanceToTerms(
							text, ForeverExpFoodL.experienceTerms, matchStart, matchEnd
						)
						local increaseDistance = distanceToTerms(
							text, ForeverExpFoodL.increaseTerms, matchStart, matchEnd
						)
						local distance = experienceDistance + increaseDistance * 2
						if distance < closestDistance then
							closestPercent = value
							closestDistance = distance
						end
					end
				end
				searchStart = matchEnd + 1
			end
			if closestPercent then
				return closestPercent
			end
		end
	end
	return false
end

local function hasQualifyingFood()
	if cachedBagResult ~= nil then
		return cachedBagResult
	end
	if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
		return nil
	end

	local unresolvedTooltip = false
	local bestBonusPercent = 0
	local bagCount = NUM_BAG_SLOTS or 0
	for bagID = 0, bagCount do
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slot = 1, slotCount do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
			local itemID = itemInfo and itemInfo.itemID
			if itemID then
				local bonusPercent = foodTooltipCache[itemID]
				if bonusPercent == nil then
					local tooltipData = C_TooltipInfo and C_TooltipInfo.GetBagItem
						and C_TooltipInfo.GetBagItem(bagID, slot)
					if tooltipData and type(tooltipData.lines) == "table" and #tooltipData.lines > 0 then
						bonusPercent = tooltipExperienceBonusPercent(tooltipData)
						foodTooltipCache[itemID] = bonusPercent or false
					else
						unresolvedTooltip = true
					end
				end
				if type(bonusPercent) == "number" and bonusPercent > bestBonusPercent then
					bestBonusPercent = bonusPercent
				end
			end
		end
	end

	if unresolvedTooltip then
		return nil
	end
	cachedBagResult = bestBonusPercent > 0 and bestBonusPercent or false
	return cachedBagResult
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
	local bestBonusPercent = 0
	while true do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
		if not aura then
			if unresolvedTooltip then
				return nil
			end
			return bestBonusPercent > 0 and bestBonusPercent or false
		end

		local bonusPercent = aura.spellId and auraTooltipCache[aura.spellId]
		if bonusPercent == nil then
			local tooltipData = C_TooltipInfo.GetUnitBuff("player", index, "HELPFUL")
			if tooltipData and type(tooltipData.lines) == "table" and #tooltipData.lines > 0 then
				bonusPercent = tooltipExperienceBonusPercent(tooltipData)
				if aura.spellId then
					auraTooltipCache[aura.spellId] = bonusPercent or false
				end
			else
				unresolvedTooltip = true
			end
		end
		if type(bonusPercent) == "number" and bonusPercent > bestBonusPercent then
			bestBonusPercent = bonusPercent
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
		elseif type(hasBuff) == "number" and hasBuff >= hasFood then
			lastReminderTime = nil
			reminderState = nil
			dismissedReminderState = nil
			if ns.HideScreenAlert then
				ns.HideScreenAlert()
			end
			return
		end
		state = "missing-buff:" .. hasFood
		message = string.format(ForeverExpFoodL.chatMessage, hasFood)
		useCustomScreenMessage = true
	elseif ns.db.remindWhenNoFood then
		local hasBuff = hasExperienceBuff()
		if hasBuff == nil then
			return
		elseif type(hasBuff) == "number" and hasBuff > 0 then
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

local function debugTooltipCandidates(tooltipData)
	local candidates = {}
	for _, line in ipairs(tooltipData and tooltipData.lines or {}) do
		local rawText = tooltipLineText(line)
		local text = normalizeTooltipText(rawText)
		if rawText:find("%", 1, true)
			or containsAny(text, ForeverExpFoodL.experienceTerms)
			or containsAny(text, ForeverExpFoodL.killTerms) then
			table.insert(candidates, rawText)
		end
	end
	return candidates
end

function ns.DebugStatus()
	if not DEFAULT_CHAT_FRAME then
		return
	end
	if UnitAffectingCombat and UnitAffectingCombat("player") then
		debugPrint("Leave combat before running the diagnostic.")
		return
	end
	if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo
		or not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
		debugPrint("Bag or tooltip API is unavailable.")
		return
	end

	invalidateBagScan()
	local scannedItems = 0
	local unresolvedItems = 0
	local recognizedFoods = 0
	local bestFoodPercent = 0
	local bagCount = NUM_BAG_SLOTS or 0
	debugPrint("Scanning carried bags and helpful buffs...")
	for bagID = 0, bagCount do
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slot = 1, slotCount do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
			local itemID = itemInfo and itemInfo.itemID
			if itemID then
				scannedItems = scannedItems + 1
				local tooltipData = C_TooltipInfo.GetBagItem(bagID, slot)
				if not tooltipData or type(tooltipData.lines) ~= "table" or #tooltipData.lines == 0 then
					unresolvedItems = unresolvedItems + 1
					debugPrint("Item " .. itemID .. ": tooltip data unavailable.")
				else
					local bonusPercent = tooltipExperienceBonusPercent(tooltipData)
					foodTooltipCache[itemID] = bonusPercent or false
					local itemName = itemInfo.itemName or (GetItemInfo and GetItemInfo(itemID)) or ("item " .. itemID)
					if type(bonusPercent) == "number" then
						recognizedFoods = recognizedFoods + 1
						bestFoodPercent = math.max(bestFoodPercent, bonusPercent)
						debugPrint(string.format("Food: %s (ID %d) -> %d%% kill XP", itemName, itemID, bonusPercent))
					else
						for _, candidate in ipairs(debugTooltipCandidates(tooltipData)) do
							debugPrint(string.format("Item candidate %s (ID %d): %s", itemName, itemID, candidate))
						end
					end
				end
			end
		end
	end

	if unresolvedItems == 0 then
		cachedBagResult = bestFoodPercent > 0 and bestFoodPercent or false
	else
		cachedBagResult = nil
	end
	if recognizedFoods == 0 then
		debugPrint(string.format("No XP food recognized in %d carried item(s).", scannedItems))
	else
		debugPrint(string.format("Recognized %d XP food item(s); best available bonus is %d%%.", recognizedFoods, bestFoodPercent))
	end

	if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex or not C_TooltipInfo.GetUnitBuff then
		debugPrint("Aura or unit-tooltip API is unavailable.")
		return
	end

	local auraIndex = 1
	local auraCount = 0
	local recognizedBuffs = 0
	local bestBuffPercent = 0
	while true do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", auraIndex, "HELPFUL")
		if not aura then
			break
		end
		auraCount = auraCount + 1
		local tooltipData = C_TooltipInfo.GetUnitBuff("player", auraIndex, "HELPFUL")
		if not tooltipData or type(tooltipData.lines) ~= "table" or #tooltipData.lines == 0 then
			debugPrint("Buff " .. (aura.name or tostring(aura.spellId)) .. ": tooltip data unavailable.")
		else
			local bonusPercent = tooltipExperienceBonusPercent(tooltipData)
			if aura.spellId then
				auraTooltipCache[aura.spellId] = bonusPercent or false
			end
			if type(bonusPercent) == "number" then
				recognizedBuffs = recognizedBuffs + 1
				bestBuffPercent = math.max(bestBuffPercent, bonusPercent)
				debugPrint(string.format("Buff: %s (spell %s) -> %d%% kill XP", aura.name or "unknown", aura.spellId or "unknown", bonusPercent))
			else
				for _, candidate in ipairs(debugTooltipCandidates(tooltipData)) do
					debugPrint(string.format("Buff candidate %s (spell %s): %s", aura.name or "unknown", aura.spellId or "unknown", candidate))
				end
			end
		end
		auraIndex = auraIndex + 1
	end
	if recognizedBuffs == 0 then
		debugPrint(string.format("No XP kill-buff recognized among %d helpful buff(s).", auraCount))
	else
		debugPrint(string.format("Recognized %d XP buff(s); strongest active bonus is %d%%.", recognizedBuffs, bestBuffPercent))
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