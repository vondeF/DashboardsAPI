-- Скрипт по получению детализированной информации ПС и ЭС --


local lines = snapshot.GetObjects("Line")
local substations = snapshot.GetObjects("Substation")

local UID_CDU = "91824B97-4177-4C4E-B593-F69CA8615C9C" -- ControlAreaOperator ЦДУ
local UID_DISP_VED = "10000D5A-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское ведение
local UID_DISP_UPR = "10000D60-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское управление
local UID_INF_VED = "10000D6C-0000-0000-C000-0000006D746C" -- RoleCategory Информационное ведение

-- Является ли объект или его дочерние объекты в любом поколении объектами диспетчеризации
function IsObjectControlled(obj)
    if ObjectIsControlledOrHasControlledChild(obj) then
        return true
    end
    for _, child in ipairs(obj.ChildObjects or {}) do
        if IsObjectControlled(child) then
            return true
        end
    end
    return false
end

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
  if obj.OrganisationRoles == nil then
    return isOD
  end
  if #obj.OrganisationRoles == 0 then
    return isOD
  end
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

-- Цикл перебора всех дочерних объектов на предмет не являются ли они объектами диспетчеризации СО
function ObjectIsControlledOrHasControlledChild(obj)
    if CheckDO(obj) then
        return true
    end
    for _, child in ipairs(obj.ChildObjects or {}) do
        if CheckDO(child) then
            return true
        end
    end
    return false
end

-- Определяет, что к подстанции подключена ЛЭП, являющаяся ОД
function SubstationHasConnectedControlledLines(substation)
    if ConnectivityNodeHasControlledLineConnection(substation) then
        return true
    end
    
    if substation.Bays then
        for _, bay in ipairs(substation.Bays) do
            if ConnectivityNodeHasControlledLineConnection(bay) then
                return true
            end
        end
    end
    
    if substation.VoltageLevels then
        for _, voltLevel in ipairs(substation.VoltageLevels) do
            if ConnectivityNodeHasControlledLineConnection(voltLevel) then
                return true
            end
            
            if voltLevel.Bays then
                for _, bay in ipairs(voltLevel.Bays) do
                    if ConnectivityNodeHasControlledLineConnection(bay) then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Определяет подключены ли к точке подключения полюса ЛЭП, которая является ОД
function ConnectivityNodeHasControlledLineConnection(eqContainer)
    for _, cn in ipairs(eqContainer.ConnectivityNodes or {}) do
        for _, t in ipairs(cn.Terminals or {}) do
            local eq = t.ConductingEquipment
            if eq and eq:ClassName() == "ACLineSegment" then
                local container = eq.EquipmentContainer
                if container and container:ClassName() == "Line" and CheckDO(container) then
                    return true
                end
            end
        end
    end
    return false
end

--  Суммарная мощность станции
function GetRatedP(substation)
  local sumRatedP = 0
  if substation.ParentObject and substation.ParentObject:ClassName() == "Plant" then
    local plant = substation.ParentObject
    if plant.ratedP and plant.ratedP ~= 0 then
        sumRatedP = plant.ratedP
    else
        for _, obj in ipairs(plant.Equipments or {}) do
        		local className = obj:ClassName()
            if  className == "HydroGeneratingUnit" or className == "NuclearGeneratingUnit" or className == "ThermalGeneratingUnit" or className == "WindGeneratingUnit" then
                sumRatedP = sumRatedP + obj.nominalP
            end
        end
    end
	end
  return sumRatedP
end

-- Получение essCode
function GetEssCode(substation)
  local essCodeName = nil
  if substation and substation.Plant and substation.Plant.Names then
      for _, name in ipairs(substation.Plant.Names) do
          if name.NameType and name.NameType.name == "essCode" then
              return name.name
          end
      end
  end
  return ""
end

for i = 1, #substations do
  sub = substations[i]
  local isPlant = sub.ParentObject:ClassName() == "Plant"
  local hasControlledObjects = IsObjectControlled(sub)
  local hasConnectedControlledLines = SubstationHasConnectedControlledLines(sub)
  local isSubstationControlled
  
  if hasControlledObjects == false and isPlant == true then
    hasControlledObjects = IsObjectControlled(sub.ParentObject)
  end
  
  if hasControlledObjects == true then
    isSubstationControlled = true
  else
    isSubstationControlled = hasConnectedControlledLines
  end
  
  local plantType = "-"
  if sub.PSRType ~= nil then plantType = sub.PSRType.name end
  
  local record = {
    ["UID"] = sub.Uid,
    ["UID_станции"] = sub.Plant and sub.Plant.Uid or "",
    ["Является_станцией"] = isPlant,
    ["Содержит_ОД"] = hasControlledObjects,
    ["Подключены_ЛЭП_являющиеся_ОД"] = hasConnectedControlledLines,
    ["Содержит_ОД_или_подключены_ЛЭП_являющиеся_ОД"] = isSubstationControlled,
    ["Суммарная_мощность_ген_оборудования"] = GetRatedP(sub),
	["Тип_станции"] = plantType,
    ["Код_ЕСС"] = GetEssCode(sub)
  }
	out.AddRecord(record)
end