local lines = snapshot.GetObjects("Line")

local UID_CDU = "91824B97-4177-4C4E-B593-F69CA8615C9C" -- ControlAreaOperator ЦДУ
local UID_DISP_VED = "10000D5A-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское ведение
local UID_DISP_UPR = "10000D60-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское управление
local UID_INF_VED = "10000D6C-0000-0000-C000-0000006D746C" -- RoleCategory Информационное ведение
local UID_RF = "359ED497-8706-4799-B717-E19AA68CF462"

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

-- Проверяет, является ли ЛЭП объектом диспетчеризации
function CheckDO(line)
  local isOD = false
  for i = 1, #line.OrganisationRoles do
    local role = line.OrganisationRoles[i];
    local category = line.OrganisationRoles[i].Category;
    if category ~= nil then
      if (category.Uid == UID_DISP_VED or category.Uid == UID_DISP_UPR or category.Uid == UID_INF_VED) and CheckSO(role) then
      	isOD = true;
        break
      end
    end
  end 
  return isOD
end

-- Определение ЛЭП в управлении ДЦ СО
function CheckControlledLine(line)
  local isOD = false
  for i = 1, #line.OrganisationRoles do
    local role = line.OrganisationRoles[i];
    local category = line.OrganisationRoles[i].Category;
    if category ~= nil then
      if category.Uid == UID_DISP_UPR and CheckSO(role) then
      	isOD = true;
        break
      end
    end
  end
  return isOD
end

-- Поиск подстанции
function FindSubstation(container)
  if container:ClassName() == "Bay" then
    return container.VoltageLevel.Substation
  elseif container:ClassName() == "VoltageLevel" then
  	return container.Substation
  elseif container:ClassName() == "Substation" then
    return container
  else 
    return nil
  end
end

-- Находится ли в РФ
function IsRF(substation)
  if(substation.Region.Region.HyperGeoRegion.Uid == UID_RF) then
    return true;
  else
    return false;
  end
end

-- Тип линии
function GetLineType(line)
  isRussian = false
  isNotRussian = false
  if line.Equipments == nil then
    return "не определено"
  end
  for i = 1, #line.Equipments do
    local object = line.Equipments[i]
    local className = object:ClassName()
    if className == "ACLineSegment" or className == "Breaker" or className == "Disconnector" or className == "Jumper" or className == "Junction" or className == "GroundDisconnector" or className == "SeriesCompensator" then
  		for j = 1, #object.Terminals do
        local terminal = object.Terminals[j]
        if terminal.ConnectivityNode ~= nil then
          local container = terminal.ConnectivityNode.ConnectivityNodeContainer
          if container ~= nil then
            if FindSubstation(container) ~= nil then
              if IsRF(FindSubstation(container)) then
                isRussian = true
              else 
                isNotRussian = true
              end
            end
          end
        end
      end
    end
  end
  if isRussian == true and isNotRussian == false then
    return "только в РФ"
  end
  if isRussian == false and isNotRussian == true then
  	return "только в Зарубежье"
  end
  if isRussian == true and isNotRussian == true then
    return "межгосударственная"
  end
  return "не определено"
end

-- Длина линии
function LineLength(line)
  local length = 0
  if line.Equipments ~= nil then
    for i = 1, #line.Equipments do
      local equipment = line.Equipments[i]
      if equipment:ClassName() == "ACLineSegment" then
        if equipment.length ~= nil then
          length = length + equipment.length
        end
      end
    end
    return length/1000
  end
  return 0
end 

-- ДЦ, в чьем управлении ЛЭП
function GetFilialRespForControl(line)
  if line.OrganisationRoles ~= nil then
    for i = 1, #line.OrganisationRoles do
    	local role = line.OrganisationRoles[i]
      if role.Category ~= nil then
        if role.Category.Uid == UID_DISP_UPR then
          if role.Organisation ~= nil then
            return role.Organisation.name
          end
        end
      end
    end
  end
  return ""
end

-- Определение ОДУ или ЦДУ
-- если ЛЭП в диспетчерском управлении ЦДУ, то указывается ЦДУ. Если ЛЭП в диспетчерском управлении РДУ, то указывается вышестоящее ОДУ
function GetOduCduName(line)
  if line.OrganisationRoles ~= nil then
    for i = 1, #line.OrganisationRoles do
    	local role = line.OrganisationRoles[i]
      if role.Category ~= nil then
        if role.Category.Uid == UID_DISP_UPR then
          if role.Organisation ~= nil then
            local p1 = role.Organisation.ParentOrganisation
            if p1 ~= nil then
              local p2 = p1.ParentOrganisation
              if p2 ~= nil then
                if p2.Uid == UID_CDU then
                  return p1.name
                end
              end
            end
            return role.Organisation.name
          end
        end
      end
    end
  end
  return ""
end

for i = 1, #lines do
  line = lines[i]
  local record = {
    ["Является_ли_ОД"] = CheckDO(line),
    ["Находится_в_ДУ_ДЦ_СО"] = CheckControlledLine(line),
    ["Расположение_ЛЭП"] = GetLineType(line),
    ["Совокупная_длина"] = LineLength(line),
    ["ДЦ_в_чьем_управлении_ЛЭП"] = GetFilialRespForControl(line),
    ["ЛЭП_в_управлении_ЦДУ_или_ОДУ_РДУ"] = GetOduCduName(line),
    ["UID"] = line.Uid,
  }
	out.AddRecord(record)
end