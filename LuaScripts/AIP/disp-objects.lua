-- Скрипт по объектам диспетчеризации Часть 1 (ОД и энергообъекты) --
local allRoles = snapshot.GetObjects("OrganisationRole")

local UID_CDU = "91824B97-4177-4C4E-B593-F69CA8615C9C" -- ControlAreaOperator ЦДУ
local UID_DISP_VED = "10000D5A-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское ведение
local UID_DISP_UPR = "10000D60-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское управление
local UID_INF_VED = "10000D6C-0000-0000-C000-0000006D746C" -- RoleCategory Информационное ведение
local UID_Operation = "10000D78-0000-0000-C000-0000006D746C"

-- Проверяет, относится ли роль к РДУ, ОДУ или ЦДУ
function CheckSO(organisationRole)   
  local organisation = organisationRole.Organisation;
  local uid1 = organisation.Uid;
  local uid2 = organisation.ParentObject.Uid;
  local uid3 = organisation.ParentObject.ParentObject.Uid
  if uid1 == UID_CDU or uid2 == UID_CDU or uid3 == UID_CDU then
		return true
	end
	return false
end

-- Проверяет, является ли объект объектом диспетчеризации
function CheckDO(obj)
  local isOD = false
  for i = 1, #obj.OrganisationRoles do
    local role = obj.OrganisationRoles[i];
    local category = obj.OrganisationRoles[i].Category;
    if category ~= nil then
      if (category.Uid == UID_DISP_VED or category.Uid == UID_DISP_UPR or category.Uid == UID_INF_VED) and CheckSO(role) then
      	isOD = true;
        break
      end
    end
  end 
  return isOD
end

-- Поиск подстанции или станции
function FindSubPlant(container)
  local res = nil  
  if container == nil then return nil end

  if container:Is("Bay") then
    res = container.VoltageLevel.Substation
  elseif container:Is("VoltageLevel") then
    res = container.Substation
  elseif container:Is("Substation") then
    res = container
  end 

  if res.Plant then
    return res.Plant
  else
    return res
  end
end

-- Поиск энергообъекта 1
function FindEnergyObjectByFunctions(obj)
  for _, resource in ipairs(obj.PowerSystemResources or {}) do 
		if resource:Is("ProtectionEquipment") then	
			if resource.EquipmentContainer then
        local equipmentContainer = resource.EquipmentContainer
        if resource.EquipmentContainer:ClassName() == "Substation" then
					return equipmentContainer.Plant and equipmentContainer.Plant or equipmentContainer
				end
			end
		end
	end
  return nil
end

-- Поиск энергообъекта 2
function FindEnergyObjectByParentObject(obj)
  local parent = obj
  while true do
    if parent == nil or parent:ClassName() == "SubGeographicalRegion" or parent:ClassName() == "ControlAreaOperator" or parent:ClassName() == "BaseObjectRoot" then 
      return nil 
    end
    if parent:ClassName() == "Substation" then 
      return parent.Plant and parent.Plant or parent
    end
  	parent = parent.ParentObject;
  end
end

-- Поиск энергообъекта
function GetEnergyObject(obj)
  if obj:Is("ConductingEquipment") then
    local equipmentContainer = obj.EquipmentContainer 
    local className = equipmentContainer:ClassName()
    if className == "Line" then
    	return equipmentContainer
    else
      return FindSubPlant(equipmentContainer)
    end
      
  elseif obj:Is("ProtectionEquipmentContainer") then
    local energyObject = FindEnergyObjectByFunctions(obj)
    if energyObject then
      return energyObject
    end
    for _, asset in ipairs(obj.Assets or {}) do 
      energyObject = FindEnergyObjectByFunctions(asset)
      if energyObject then
        return energyObject
      end
    end
    return FindEnergyObjectByParentObject(obj)
    
	elseif obj:Is("AuxiliaryEquipment") then
    local equipmentContainer = obj.Terminal.ConductingEquipment.EquipmentContainer 
    local className = equipmentContainer:ClassName()
    if className == "Line" then
    	return equipmentContainer
    else
      return FindSubPlant(equipmentContainer)
    end
  
  elseif obj:Is("ProtectionEquipment") then
    local equipmentContainer = obj.EquipmentContainer
  	if equipmentContainer then
    	if equipmentContainer:Is("Substation") then
      	return equipmentContainer.Plant and equipmentContainer.Plant or equipmentContainer
      end
    end
  
  elseif obj:Is("Line") then  
    return obj

  elseif obj:Is("GeneratingUnit") then
    return obj.EquipmentContainer
    
  elseif obj:Is("DispObject") then  
    return FindEnergyObjectByParentObject(obj)
  
  elseif obj:Is("GeneratingUnit") then
    return obj.EquipmentContainer
  
  elseif obj:Is("RegulatingControl") then
    return FindSubPlant(obj.EquipmentContainer)
  
  elseif obj:Is("ExcitationSystem") then
    if obj.RotatingMachine then
      return FindSubPlant(obj.RotatingMachine.EquipmentContainer)
    else
      return FindEnergyObjectByParentObject(obj)
    end
  
  elseif obj:Is("GeneratingSet") then
    for _, sm in ipairs(obj.SynchronousMachines or {}) do 
      return FindSubPlant(sm.EquipmentContainer)
    end
  
  elseif obj:Is("Bay") then
    return FindSubPlant(obj)
  end
  return nil
end

-- Возвращает список напряжений всех обмоток ТР
function GetPowerTransformerVoltages(obj)
  local voltages = {}
  for _, endItem in ipairs(obj.PowerTransformerEnd) do
  	table.insert(voltages, endItem.BaseVoltage.nominalVoltage)
  end
  table.sort(voltages, function(a, b) return a > b end)
  return table.concat(voltages, ", ")
end

function GetLineVoltage(obj)
  for _, equip in ipairs(obj.Equipments) do
  	if equip:Is("ConductingEquipment") then
      return equip.BaseVoltage.nominalVoltage
    end
  end
  return ""
end

-- Возвращает напряжение
function GetVoltageRow(obj)
	if obj:Is("ConductingEquipment") then
  	if obj:Is("PowerTransformer") then
      return GetPowerTransformerVoltages(obj)
    end
    return obj.BaseVoltage.nominalVoltage
    
	elseif obj:Is("AuxiliaryEquipment") then
		local mainEquip = obj.Terminal.ConductingEquipment
  	if mainEquip:Is("PowerTransformer") then
      return GetPowerTransformerVoltages(mainEquip)
    end
    return mainEquip.BaseVoltage.nominalVoltage

  elseif obj:Is("Line") then 
    return GetLineVoltage(obj)
  
  elseif obj:Is("GeneratingUnit") then
  	if obj.RotatingMachine then
      return obj.RotatingMachine.BaseVoltage.nominalVoltage
    end
  
  elseif obj:Is("RegulatingControl") then
    if obj.RegulatingCondEq and obj.RegulatingCondEq[1] then
    	return obj.RegulatingCondEq[1].BaseVoltage.nominalVoltage
    end
  
  elseif obj:Is("ExcitationSystem") then
		if obj.RotatingMachine then
      return obj.RotatingMachine.BaseVoltage.nominalVoltage
    end
  
  elseif obj:Is("GeneratingSet") then
		if obj.SynchronousMachines and obj.SynchronousMachines[1] then
  		return obj.SynchronousMachines[1].BaseVoltage.nominalVoltage
    end
  
  elseif obj:Is("Bay") then
		return obj.VoltageLevel.BaseVoltage.nominalVoltage
  end
  return ""
end

-- Возвращает отвественного за моделирование оборудования
function GetModelingAuthority(identifiedObject)
  local parent = identifiedObject
  while true do
    if parent == nil then 
      return nil 
    end
    if parent.ModelingAuthoritySet ~= nil then 
      return parent.ModelingAuthoritySet.ModelingAuthority
    end
    parent = parent.ParentObject;
  end
  return nil
end

-- Роли
function GetRolesByCategoryUid(obj, uid)
  local names = {}
  for _, role in ipairs(obj.OrganisationRoles) do
    if role.Category and role.Category.Uid == uid then
        if role.Organisation and role.Organisation.name then
            table.insert(names, role.Organisation.name)
        end
    end
	end
	return table.concat(names, ", ")
end

-- Основной цикл
for _, role in ipairs(allRoles) do
  local categoryUid = role.Category and role.Category.Uid
  if categoryUid == UID_DISP_UPR or categoryUid == UID_DISP_VED then 
    if role.Objects then 
      for _, obj in ipairs(role.Objects) do
        if (CheckDO(obj) and (not obj:Is("EnergyConsumer")) and (not obj:Is("BranchGroup")) and (not obj:Is("BranchGroupPair")) and (not obj:Is("GenericPSR"))) then
		  		local addInfo = (obj:ClassName() == "DispObject" or obj:ClassName() == "DispObjectGS") and obj.Type.name or ""
          local energyObject = GetEnergyObject(obj)
          local ma = GetModelingAuthority(obj)
          local record = {
            ["Класс_объекта"] = obj:ClassName(),
          	["Комплекс_ОД"] = addInfo,
            ["Uid"] = obj.Uid,
            ["Класс_напряжения"] = GetVoltageRow(obj),
            ["Uid_энергообъекта"] = energyObject and energyObject.Uid or "",
            ["ДЦ"] = ma and ma.name or "",
            ["Диспетчерское_управление"] = GetRolesByCategoryUid(obj, UID_DISP_UPR),
			["Диспетчерское_ведение"] = GetRolesByCategoryUid(obj, UID_DISP_VED),
          }
          out.AddRecord(record)
        end
      end
    end
  end
end