local Health = {}
ShadowUF:RegisterModule(Health, "healthBar", ShadowUF.L["Health bar"], true)

local function getGradientColor(unit)
	local percent = UnitHealth(unit) / UnitHealthMax(unit)
	if( percent >= 1 ) then return ShadowUF.db.profile.healthColors.green.r, ShadowUF.db.profile.healthColors.green.g, ShadowUF.db.profile.healthColors.green.b end
	if( percent == 0 ) then return ShadowUF.db.profile.healthColors.red.r, ShadowUF.db.profile.healthColors.red.g, ShadowUF.db.profile.healthColors.red.b end
	
	local sR, sG, sB, eR, eG, eB = 0, 0, 0, 0, 0, 0
	local modifier, inverseModifier = percent * 2, 0
	if( percent > 0.50 ) then
		sR, sG, sB = ShadowUF.db.profile.healthColors.green.r, ShadowUF.db.profile.healthColors.green.g, ShadowUF.db.profile.healthColors.green.b
		eR, eG, eB = ShadowUF.db.profile.healthColors.yellow.r, ShadowUF.db.profile.healthColors.yellow.g, ShadowUF.db.profile.healthColors.yellow.b

		modifier = modifier - 1
	else
		sR, sG, sB = ShadowUF.db.profile.healthColors.yellow.r, ShadowUF.db.profile.healthColors.yellow.g, ShadowUF.db.profile.healthColors.yellow.b
		eR, eG, eB = ShadowUF.db.profile.healthColors.red.r, ShadowUF.db.profile.healthColors.red.g, ShadowUF.db.profile.healthColors.red.b
	end
	
	inverseModifier = 1 - modifier
	return eR * inverseModifier + sR * modifier, eG * inverseModifier + sG * modifier, eB * inverseModifier + sB * modifier
end

Health.getGradientColor = getGradientColor

function Health:OnEnable(frame)
	if( not frame.healthBar ) then
		frame.healthBar = ShadowUF.Units:CreateBar(frame)
	end
	
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_CONNECTION", self, "Update")
	frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateColor")
	frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", self, "UpdateColor")
	
	if( frame.unit == "pet" ) then
		frame:RegisterUnitEvent("UNIT_POWER", self, "UpdateColor")
	end
	
	frame:RegisterUpdateFunc(self, "UpdateColor")
	frame:RegisterUpdateFunc(self, "Update")
end

function Health:OnLayoutApplied(frame)
	if( not frame.visibility.healthBar ) then return end

	if( ShadowUF.db.profile.units[frame.unitType].healthBar.predicted ) then
	    frame:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", self, "UpdateFrequent")
	else
		frame:UnregisterEvent("UNIT_HEALTH_FREQUENT", self)
	end
end

function Health:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Health:UpdateColor(frame)
	frame.healthBar.hasReaction = nil
	frame.healthBar.hasPercent = nil
	frame.healthBar.wasOffline = nil
	
	local color
	local unit = frame.unit
	local reactionType = ShadowUF.db.profile.units[frame.unitType].healthBar.reactionType
	if( not UnitIsConnected(unit) ) then
		frame.healthBar.wasOffline = true
		frame:SetBarColor("healthBar", ShadowUF.db.profile.units[frame.unitType].healthBar.invert, ShadowUF.db.profile.healthColors.offline.r, ShadowUF.db.profile.healthColors.offline.g, ShadowUF.db.profile.healthColors.offline.b)
		return
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorAggro and UnitThreatSituation(frame.unit) == 3 ) then
		frame:SetBarColor("healthBar", ShadowUF.db.profile.units[frame.unitType].healthBar.invert, ShadowUF.db.profile.healthColors.hostile.r, ShadowUF.db.profile.healthColors.hostile.g, ShadowUF.db.profile.healthColors.hostile.b)
		return
	elseif( frame.inVehicle ) then
		color = ShadowUF.db.profile.classColors.VEHICLE
	elseif( not UnitIsTappedByPlayer(unit) and UnitIsTapped(unit) and UnitCanAttack("player", unit) ) then
		color = ShadowUF.db.profile.healthColors.tapped
	elseif( not UnitPlayerOrPetInRaid(unit) and not UnitPlayerOrPetInParty(unit) and ( ( ( reactionType == "player" or reactionType == "both" ) and UnitIsPlayer(unit) and not UnitIsFriend(unit, "player") ) or ( ( reactionType == "npc" or reactionType == "both" )  and not UnitIsPlayer(unit) ) ) ) then
		if( not UnitIsFriend(unit, "player") and UnitPlayerControlled(unit) ) then
			if( UnitCanAttack("player", unit) ) then
				color = ShadowUF.db.profile.healthColors.hostile
			else
				color = ShadowUF.db.profile.healthColors.enemyUnattack
			end
		elseif( UnitReaction(unit, "player") ) then
			local reaction = UnitReaction(unit, "player")
			if( reaction > 4 ) then
				color = ShadowUF.db.profile.healthColors.friendly
			elseif( reaction == 4 ) then
				color = ShadowUF.db.profile.healthColors.neutral
			elseif( reaction < 4 ) then
				color = ShadowUF.db.profile.healthColors.hostile
			end
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "class" and ( UnitIsPlayer(unit) or UnitCreatureFamily(unit) ) ) then
		local class = UnitCreatureFamily(frame.unit) or select(2, UnitClass(frame.unit))
		color = class and ShadowUF.db.profile.classColors[class]
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "static" ) then
		color = ShadowUF.db.profile.healthColors.static
	end
	
	if( color ) then
		frame:SetBarColor("healthBar", ShadowUF.db.profile.units[frame.unitType].healthBar.invert, color.r, color.g, color.b)
	else
		frame.healthBar.hasPercent = true
		frame:SetBarColor("healthBar", ShadowUF.db.profile.units[frame.unitType].healthBar.invert, getGradientColor(unit))
	end
end

function Health:UpdateFrequent(frame)
	frame.healthBar.currentHealth = UnitHealth(frame.unit)
	frame.healthBar:SetValue(frame.healthBar.currentHealth)

	-- As much as I would rather not have to do this in an OnUpdate, I don't have much choice large health changes in a single update will make them very clearly be lagging behind
	for _, fontString in pairs(frame.fontStrings) do
		if( fontString.fastHealth ) then
			fontString:UpdateTags()
		end
	end
		
	-- Update incoming heal number
	if( frame.incHeal and frame.incHeal.healed ) then
		frame.incHeal:SetValue(frame.healthBar.currentHealth + frame.incHeal.healed)
	end
	
	-- The target is not offline, and we have a health percentage so update the gradient
	if( not frame.healthBar.wasOffline and frame.healthBar.hasPercent ) then
		frame:SetBarColor("healthBar", ShadowUF.db.profile.units[frame.unitType].healthBar.invert, getGradientColor(frame.unit))
	end
end

function Health:Update(frame)
	local isOffline = not UnitIsConnected(frame.unit)
	frame.isDead = UnitIsDeadOrGhost(frame.unit)
	frame.healthBar.currentHealth = UnitHealth(frame.unit)
	frame.healthBar:SetMinMaxValues(0, UnitHealthMax(frame.unit))
	frame.healthBar:SetValue(isOffline and UnitHealthMax(frame.unit) or frame.isDead and 0 or frame.healthBar.currentHealth)
	
	-- Unit is offline, fill bar up + grey it
	if( isOffline ) then
		frame.healthBar.wasOffline = true
		frame.unitIsOnline = nil
		frame:SetBarColor("healthBar", ShadowUF.db.profile.units[frame.unitType].healthBar.invert, ShadowUF.db.profile.healthColors.offline.r, ShadowUF.db.profile.healthColors.offline.g, ShadowUF.db.profile.healthColors.offline.b)
	-- The unit was offline, but they no longer are so we need to do a forced color update
	elseif( frame.healthBar.wasOffline ) then
		frame.healthBar.wasOffline = nil
		self:UpdateColor(frame)
	-- Color health by percentage
	elseif( frame.healthBar.hasPercent ) then
		frame:SetBarColor("healthBar", ShadowUF.db.profile.units[frame.unitType].healthBar.invert, getGradientColor(frame.unit))
	end
end