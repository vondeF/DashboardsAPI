-- Скрипт по получению основных данных ЛЭП, ПС и ЭС (роли, география, отвественность за моделирование и т.д.) --

local lines = snapshot.GetObjects("Line")
local substations = snapshot.GetObjects("Substation")
local plants = snapshot.GetObjects("Plant")

local UID_DISP_VED = "10000D5A-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское ведение
local UID_DISP_UPR = "10000D60-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское управление
local UID_Operation = "10000D78-0000-0000-C000-0000006D746C"

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

-- Регион
function GetSubGeoRegion(container)
    if container:ClassName() == "Substation" then
        return container.Region
    elseif container:ClassName() == "Plant" then
        return container.Region
    elseif container:ClassName() == "Line" then
        return container.Region
    else
        return nil
    end
end

-- AssetOwner
function GetAssetOwnersNames(obj)
    local names = {}
    for _, role in ipairs(obj.OrganisationRoles or {}) do
        if role:ClassName() == "AssetOwner" and role.Organisation and role.Organisation.name then
            table.insert(names, role.Organisation.name)
        end
    end
    return table.concat(names, ", ")
end

-- AssetDataSource
function GetLineAssetDataSourcesNames(obj)
    local names = {}
    for _, role in ipairs(obj.OrganisationRoles or {}) do
        if role:ClassName() == "AssetDataSource" and role.Organisation and role.Organisation.name then
            table.insert(names, role.Organisation.name)
        end
    end
    return table.concat(names, ", ")
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

-- Высшее напряжение энергообъекта
function GetVoltage(obj)
  if obj:Is("Substation") then
    return GetSubVoltage(obj)
    
  elseif obj:Is("Plant") then
    if obj.Substations and obj.Substations[1] then
      return GetSubVoltage(obj.Substations[1])
    end
    
  elseif obj:Is("Line") then
    return GetLineVoltage(obj)
  end
  
  return 0
end

-- Напряжение ПС
function GetSubVoltage(obj)
  local voltage = 0
	if obj.VoltageLevels then
    local maxVoltage = 0
    for _, level in ipairs(obj.VoltageLevels) do
        if level and level.BaseVoltage and level.BaseVoltage.nominalVoltage then
            local v = level.BaseVoltage.nominalVoltage
            if v > maxVoltage then
                maxVoltage = v
            end
        end
    end
    voltage = maxVoltage
	end
  return voltage
end	

-- Напряжение ЛЭП
function GetLineVoltage(obj)
  for _, equip in ipairs(obj.Equipments) do
  	if equip:Is("ConductingEquipment") and equip.BaseVoltage then
      return equip.BaseVoltage.nominalVoltage
    end
  end
  return 0
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

-- Возвращает имя ОДУ
function GetOduName(identifiedObject)
  organisation = GetModelingAuthority(identifiedObject)
  if organisation and organisation:ClassName() == "ControlAreaOperator" then
    if string.find(organisation.name, "ОДУ") or string.find(organisation.name, "ЦДУ") then
      return organisation.name
    elseif string.find(organisation.name, "РДУ") then
      return organisation.ParentObject.name
    end
  end
  return ""
end

-- Обработка набора объектов
function Processing (objects)
  for _, obj in ipairs(objects) do
    local ma = GetModelingAuthority(obj)
    local subGeoRegion = GetSubGeoRegion(obj)
	local geoRegion = subGeoRegion and subGeoRegion.Region or nil
	local hyperRegion = geoRegion and geoRegion.HyperGeoRegion or nil
    local record = {
      ["Класс_объекта"] = obj:ClassName(),
      ["ОДУ"] = GetOduName(obj),
	  ["ОтвЗаМод"] = GetModelingAuthority(obj).name,
      ["Наименование_объекта"] = obj.name,
      ["Uid"] = obj.Uid,
      ["ДЦ"] = ma and ma.name or "",
      ["Страна"] = hyperRegion and hyperRegion.name or "",
      ["ФО"] = geoRegion and geoRegion.name or "",
      ["Субъект_РФ"] = subGeoRegion and subGeoRegion.name or "",
      ["Класс_напряжения"] = GetVoltage(obj),
      ["Источник_информации"] = GetLineAssetDataSourcesNames(obj),
      ["Владение"] = GetAssetOwnersNames(obj),
      ["Эксплуатация"] = GetRolesByCategoryUid(obj, UID_Operation),
    }
    out.AddRecord(record)
  end
end

Processing(substations)
Processing(lines)
Processing(plants)