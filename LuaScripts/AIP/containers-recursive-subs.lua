-- Скрипт по рекурсивному поиску для ПС --

local objects = snapshot.GetObjects("Substation")

local UID_DISP_VED = "10000D5A-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское ведение
local UID_DISP_UPR = "10000D60-0000-0000-C000-0000006D746C" -- RoleCategory Диспетчерское управление

-- Сбор информации об кол-ве дочерних объектов, диспетчерском управлении и ведении
function GetDispatchingControlOrganizations(identifiedObject)
  local namesVed = {}
  local seenVed = {}
  local namesUpr = {}
  local seenUpr = {}
  local count = -1
  
  local stack = {identifiedObject}
  
  -- Обходим стек, пока он не пуст
  while #stack > 0 do
		local current = table.remove(stack)  -- Pop
    count = count + 1
    local nameVed = GetOrganisationNames(current, UID_DISP_VED)
    local nameUpr = GetOrganisationNames(current, UID_DISP_UPR)
    
    if nameVed ~= nil and not seenVed[nameVed] then
      seenVed[nameVed] = true
      table.insert(namesVed, nameVed)
    end
    
    if nameUpr ~= nil and not seenUpr[nameUpr] then
      seenUpr[nameUpr] = true
      table.insert(namesUpr, nameUpr)
    end
    
    -- Если есть дети, добавляем их в стек
    if current.ChildObjects and #current.ChildObjects > 0 then
        for _, child in ipairs(current.ChildObjects) do
            table.insert(stack, child)  -- Push
        end
    end
  end
  
  table.sort(namesUpr)
  table.sort(namesVed)
  return count, table.concat(namesUpr, ", "), table.concat(namesVed, ", ")
end

-- Выгрузка наименований организации нужной категории
function GetOrganisationNames(obj, uid)
  if obj.OrganisationRoles then
    for _, item in ipairs(obj.OrganisationRoles) do
			if item.Category and item.Category.Uid == uid then
        local org = item.Organisation
        return org.name
      end
    end
  end
  return nil
end

-- Обработка набора объектов
function Processing (objects)
  for _, obj in ipairs(objects) do
    local count, namesUpr, namesVed = GetDispatchingControlOrganizations(obj)
    local record = {
      ["Uid"] = obj.Uid,
      ["Диспетчерское_управление"] = namesUpr,
      ["Диспетчерское_ведение"] = namesVed,
      ["Количество_всех_дочерних_объектов"] = count
    }
    out.AddRecord(record)
  end
end

Processing(objects)