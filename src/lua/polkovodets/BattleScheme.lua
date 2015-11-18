--[[

Copyright (C) 2015 Ivan Baidakou

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

]]--

--[[

Formal grammar definition:

Expr       ← RELATION / '(' EXPR ')' / L_RELATION
L_RELATION ← Expr (('&&' / '||') Expr)*
RELATION   ← VALUE ('==' / '!=') VALUE

VALUE    ← LITERAL / OBJECT '.' PROPERTY / OBJECT '.' METHOD '(' (ARG (',' ARG)*)* ')'
LITERAL  ← '[a-Z0-9_]+'
OBJECT   ← 'I' | 'P'
PROPERTY ← [a-Z0-9_]+
ARG      ← LITERAL

]]--


local Parser = require 'polkovodets.Parser'
local inspect = require('inspect')
local lpeg = require('lpeg')
local _ = require ("moses")

local BattleScheme = {}
BattleScheme.__index = BattleScheme


-- condition classes

--[[ Condition base class ]]--
local _ConditionBase = {}
_ConditionBase.__index = _ConditionBase

function _ConditionBase:set_block(block)
   assert(block)
   self.block = block
end


--[[ Property Condition class ]]--
local _PropertyCondition = {}
_PropertyCondition.__index = _PropertyCondition
setmetatable(_PropertyCondition, _ConditionBase)

function _PropertyCondition.create(object, prop)
   local t = {
      kind     = 'Property',
      object   = object,
      property = prop,
   }
   return setmetatable(t, _PropertyCondition)
end

function _PropertyCondition:validate()
   assert((self.property == 'state') or (self.property == 'orientation'))
end

function _PropertyCondition:get_value(I_unit, P_unit)
  local o = (self.object == 'I') and I_unit or P_unit
  local value = o.data[self.property]
  return value
end

--[[ Literal Condition class ]]--
local _LiteralCondition = {}
_LiteralCondition.__index = _LiteralCondition
setmetatable(_LiteralCondition, _ConditionBase)

function _LiteralCondition.create(value)
   local t = {
      kind  = 'Literal',
      value = value,
   }
   return setmetatable(t, _LiteralCondition)
end
function _LiteralCondition:validate() end
function _LiteralCondition:get_value(I_unit, P_unit) return self.value end

--[[ Relation Condition class ]]--
local _RelationCondition = {}
_RelationCondition.__index = _RelationCondition
setmetatable(_RelationCondition, _ConditionBase)

function _RelationCondition.create(operator, v1, v2)
   local t = {
      kind  = 'Relation',
      operator = operator,
      v1       = v1,
      v2       = v2,
   }
   return setmetatable(t, _RelationCondition)
end

function _RelationCondition:validate()
   self.v1:validate()
   self.v2:validate()
end

function _RelationCondition:matches(I_unit, P_unit)
  local v1 = self.v1:get_value(I_unit, P_unit)
  local v2 = self.v2:get_value(I_unit, P_unit)
  assert(type(v1) == 'string')
  assert(type(v2) == 'string')
  local result = (self.operator == '==')
    and (v1 == v2)
    or  (v1 ~= v2)
  -- print("result " .. (result and 't' or 'f'))
  return result
end

--[[ Negation Condition class ]]--
local _NegationCondition = {}
_NegationCondition.__index = _NegationCondition
setmetatable(_NegationCondition, _ConditionBase)

function _NegationCondition.create(expr)
   local t = {
      kind = 'Negation',
      expr = expr,
   }
   return setmetatable(t, _NegationCondition)
end

function _NegationCondition:validate()
   return self.expr:validate()
end

--[[ LogicalOperation Condition class ]]--
local _LogicalOperationCondition = {}
_LogicalOperationCondition.__index = _LogicalOperationCondition
setmetatable(_LogicalOperationCondition, _ConditionBase)

function _LogicalOperationCondition.create(operator, relations)
   local t = {
      kind      = 'LogicalOperation',
      operator  = operator,
      relations = relations,
   }
   return setmetatable(t, _LogicalOperationCondition)
end

function _LogicalOperationCondition:validate()
    for idx, relation in pairs(self.relations) do
      relation:validate()
    end
end

function _LogicalOperationCondition:matches(I_unit, P_unit)
  local result = false
  if (self.operator == '&&') then
    result = #self.relations > 0
    for idx, relation in pairs(self.relations) do
      local r_match = relation:matches(I_unit, P_unit)
      result = result and r_match
    end
  end
  return result
end

-- Selector classes
--[[ Selector class ]]--
local _Selector = {}
_Selector.__index = _Selector

function _Selector.create(object, method, specification)
   local t = {
      kind          = 'Selector',
      object        = object,
      method        = method,
      specification = specification,
   }
   return setmetatable(t, _Selector)
end

function _Selector:select_weapons(role, ctx)
  -- select object and enemy data
  local o = (self.object == 'I') and ctx.i or ctx.p
  local e = (self.object == 'I') and ctx.p or ctx.i
  assert(o)
  assert(e)

  local select_by_selector = function(weapon_instance)
    if (self.method == 'category') then
      return weapon_instance.weapon.category == self.specification
    end
  end

  local select_by_filter = function(filter)
    local instances = {}
    local quantities = {}
    for idx, wi in pairs(o.weapon_instances) do
      if (select_by_selector(wi) and filter(wi)) then
        table.insert(instances, wi)
        quantities[wi.uniq_id] = o.current_quantities[wi.uniq_id]
      end
    end
    -- print("selected by role " .. role .. " " .. inspect(instances))
    return instances, quantities
  end

  -- For active weapon we additionally ensure that weapon is
  -- capable to shoot on the required range.
  -- for passive weapon we just ensure, that it (still) exists
  local role_filter
  if (role == 'active') then
    local e_layer = e.layer
    role_filter = function(weapon_instance)
        local range_ok = weapon_instance.weapon.data.range[e_layer] >= ctx.range
        local quantities_ok = o.current_quantities[weapon_instance.uniq_id] > 0
        return range_ok and quantities_ok
    end
  else
    role_filter = function(weapon_instance)
        local quantities_ok = o.current_quantities[weapon_instance.uniq_id] > 0
        return quantities_ok
    end
  end

  return select_by_filter(role_filter)
end

--[[ SelectorNegation class ]]--
local _SelectorNegation = {}
_SelectorNegation.__index = _SelectorNegation

function _SelectorNegation.create(selector)
   local t = {
      kind     = 'SelectorNegation',
      selector = selector,
   }
   return setmetatable(t, _SelectorNegation)
end

--[[ SelectorOperation class ]]--
local _SelectorOperation = {}
_SelectorOperation.__index = _SelectorOperation

function _SelectorOperation.create(operator, selectors)
   local t = {
      kind      = 'SelectorOperation',
      operator  = operator,
      selectors = selectors,
   }
   return setmetatable(t, _SelectorOperation)
end


function _SelectorOperation:select_weapons(role, ctx)
  local weapons = {}
  local quantities = {}
  if (self.operator == '||') then
    for idx, selector in pairs(self.selectors) do
      local weapon_instances, weapon_quantities = selector:select_weapons(role, ctx)
      for idx2, wi in pairs(weapon_instances) do
        table.insert(weapons, wi)
        quantities[wi.uniq_id] = weapon_quantities[wi.uniq_id]
      end
    end
  end
  return weapons, quantities
end

--[[ Block class ]]--
local _Block = {}
_Block.__index = _Block


function _Block.create(battle_scheme, id, fire_type, condition,
                       active_weapon_selector, passive_weapon_selector, action)
   assert(id)
   assert(string.find(id, "%w+(%.?%w*)"))

   local parent_id_start, parent_id_end = string.find(id, '%w+%.')
   local parent_id
   if (parent_id_end) then
      parent_id = string.sub(id, parent_id_start, parent_id_end - parent_id_start)
   end
   local o = {
      id            = id,
      parent_id     = parent_id,
      battle_scheme = battle_scheme,
      fire_type     = fire_type,
      condition     = condition,
      active        = active_weapon_selector,
      passive       = passive_weapon_selector,
      action        = action,
      children      = {},
   }
   setmetatable(o, _Block)
   if (condition) then condition:set_block(o) end
   if (active) then active:set_block(o) end
   if (passive) then passive:set_block(o) end
   return o
end

function _Block:validate()
   if (not self.parent_id) then
      assert(self.fire_type)
      assert(self.condition)
      self.condition:validate()
   else
      local parent_block = self.battle_scheme:_lookup_block(self.parent_id)
      assert(parent_block)
      assert(not self.fire_type)
      if (self.condition) then self.condition:validate() end
   end
end

function _Block:matches(fire_type, i_unit, p_unit)
  if (self.fire_type == fire_type) then
    return self.condition:matches(i_unit, p_unit)
  end
end

function _Block:select_pair(ctx)
  assert(self.parent_id)
  local a_weapons, a_quantities = self.active:select_weapons('active', ctx)
  if (#a_weapons > 0) then
    local p_weapons, p_quantities = self.passive:select_weapons('passive', ctx)
    if (#p_weapons > 0) then
      -- by default all weapons shot, and no casualities
      return {
        a = {
          weapons     = a_weapons,
          quantities  = a_quantities,
          shots       = _.clone(a_quantities),
          casualities = _.map(a_quantities, function(k, v) return 0 end),
        },
        p = {
          weapons     = p_weapons,
          quantities  = p_quantities,
          shots       = _.clone(p_quantities),
          casualities = _.map(p_quantities, function(k, v) return 0 end),
        },
        action  = self.action,
      }
    end
  end
end

function _Block:perform_battle(i_unit, p_unit, fire_type)
  local range = i_unit.tile:distance_to(p_unit.tile)
  local i_weapon_instances = i_unit:_united_staff()
  local p_weapon_instances = p_unit:_united_staff()

  -- prepare context
  local ctx = {
    range              = range,
    i = {
      layer              = i_unit.data.layer,
      weapon_instances   = i_weapon_instances,
      current_quantities = {},
    },
    p = {
      layer              = p_unit.data.layer,
      weapon_instances   = p_weapon_instances,
      current_quantities = {},
    },
  }
  -- initialize weapon quantities
  for idx, wi in pairs(i_weapon_instances) do
    ctx.i.current_quantities[wi.uniq_id] = wi.data.quantity
  end
  for idx, wi in pairs(p_weapon_instances) do
    ctx.p.current_quantities[wi.uniq_id] = wi.data.quantity
  end

  for idx, block in pairs(self.children) do
    print("trying block " .. block.id)
    local pair = block:select_pair(ctx)
    if (pair) then
      print("matching pair = " .. inspect(pair))
      self.battle_scheme.engine.battle_formula:perform_battle(pair)
    end
  end
end


function BattleScheme.create(engine)
   local o = {
      engine      = engine,
      block_for   = {}, -- all blocks, k: block_id, value _Block object
      root_blocks = {}, -- blocks with parent = nil
   }
   setmetatable(o, BattleScheme)

   -- conditions
   do
      -- capture functions
      local property_c = function(o,v) return _PropertyCondition.create(o,v) end
      local literal_c = function(v) return _LiteralCondition.create(v) end
      local relation_c = function(v1, op, v2) return  _RelationCondition.create(op, v1, v2) end
      local negation_c = function(e) return _NegationCondition.create(e) end
      local l_operation_c = function(...)
         local args = { ... }
         local operator = args[2]
         local relations = {}
         for idx, value in pairs(args) do
            if (idx % 2 == 1) then table.insert(relations, value) end
         end
         return _LogicalOperationCondition.create(operator, relations)
      end

      -- Lexical Elements
      local Space = lpeg.S(" ")^0
      local BareString = ((lpeg.R("09") + lpeg.R("az", "AZ") +lpeg.S("._"))^0)
      local Literal = (lpeg.P('"') * BareString * lpeg.P('"'))
      local Object = (lpeg.P("I") + lpeg.P("P"))
      local Property = (lpeg.C(Object) * lpeg.P('.') * lpeg.C((lpeg.R("09") + lpeg.R("az", "AZ"))^1)) / property_c
      local Value  = (lpeg.P('"') * (BareString/literal_c) * lpeg.P('"')) + Property
      local Relation = Value * Space * lpeg.C(lpeg.P("==") + lpeg.P("!=")) * Space * Value / relation_c
      local RelationAtom = (lpeg.P('(') * Space * Relation * Space * lpeg.P(')')) + Relation

      -- Grammar
      local condition_grammar = lpeg.P{
         "Expr";
         Expr
            = lpeg.V("Logical_Operation")
            + lpeg.V("Negation")
            + RelationAtom
            + (Space * lpeg.P('(') * Space * lpeg.V("Expr") * Space * lpeg.P(')')),
         Negation
            = (lpeg.P('!') * Space * lpeg.V('Expr')) / negation_c,
         Logical_Operation
            = (RelationAtom * (Space * lpeg.C(lpeg.P('&&')) * Space * RelationAtom)^1) / l_operation_c,
      }

      o.condition_grammar = condition_grammar
   end

   -- selectors
   do
      -- capture functions
      local selector_c = function(o, m, s) return _Selector.create(o, m, s) end
      local negation_c = function(selector) return _SelectorNegation.create(selector) end
      local operation_c = function(...)
         local args = { ... }
         local operator = args[2]
         local selectors = {}
         for idx, value in pairs(args) do
            if (idx % 2 == 1) then table.insert(selectors, value) end
         end
         return _SelectorOperation.create(operator, selectors)
      end

      -- Lexical Elements
      local Space = lpeg.S(" ")^0
      local BareString = ((lpeg.R("09") + lpeg.R("az", "AZ") +lpeg.S("_"))^0)
      local Literal = (lpeg.P('"') * BareString * lpeg.P('"'))
      local Object = (lpeg.P("I") + lpeg.P("P"))
      local Selector = (lpeg.C(Object) * lpeg.P('.') * lpeg.C(BareString)
                           * lpeg.P('("') * lpeg.C(BareString) * lpeg.P('")'))  / selector_c
      local SelectorNegation = (lpeg.P('!') * Selector) / negation_c
      local SelectorAtom = Selector + SelectorNegation

      -- Grammar
      local selection_grammar = lpeg.P{
         "Expr";
         Expr
            = lpeg.V("Selector_Operation")
            + SelectorAtom,
         Selector_Operation
            = (SelectorAtom * (Space * lpeg.C(lpeg.P('&&')) * Space * SelectorAtom)^1)/operation_c
            + (SelectorAtom * (Space * lpeg.C(lpeg.P('||')) * Space * SelectorAtom)^1)/operation_c
      }

      o.selection_grammar = selection_grammar
   end
   -- make battle scheme available via Engine
   engine.battle_scheme = o
   return o
end

function BattleScheme:_parse_condition(c)
   local condition = self.condition_grammar:match(c)
   return condition
end

function BattleScheme:_parse_selection(s)
   local selection = self.selection_grammar:match(s)
   return selection
end

function BattleScheme:_create_block(id, fire_type, condition,
                                    active_weapon_selector, passive_weapon_selector, action)
   assert(not self.block_for[id], "block " .. id .. " alredy exists")
   local b = _Block.create(self, id, fire_type, condition, active_weapon_selector, passive_weapon_selector, action)
   self.block_for[id] = b
   if (not b.parent_id) then
      table.insert(self.root_blocks, b)
   else
      local parent_block = self:_lookup_block(b.parent_id)
      table.insert(parent_block.children, b)
   end
   return b
end

function BattleScheme:_lookup_block(id)
   return self.block_for[id]
end

function BattleScheme:load(path)
   local parser = Parser.create(path)
   for idx, data in pairs(parser:get_raw_data()) do
      local id = assert(data.block_id)
      local fire_type = data.fire_type
      local action = data.action
      local condition_str = data.condition
      local active_weapon_selector = data.active_weapon
      local passive_weapon_selector = data.passive_weapon

      local condition, active_weapon, passive_weapon
      if (condition_str) then
         condition = self:_parse_condition(condition_str)
         assert(condition, "the condtion " .. condition_str .. " isn't valid")
      end

      if (active_weapon_selector) then
         active_weapon = self:_parse_selection(active_weapon_selector)
         assert(active_weapon, "active weapon " .. active_weapon_selector .. " isn't valid")
      end

      if (passive_weapon_selector) then
         passive_weapon = self:_parse_selection(passive_weapon_selector)
         assert(passive_weapon, "passive weapon " .. passive_weapon_selector .. " isn't valid")
      end

      local block = self:_create_block(
         id,
         fire_type,
         condition,
         active_weapon,
         passive_weapon,
         action
      )
   end
   print("Battle scheme has been loaded, " .. #self.root_blocks .. " root blocks")
   -- print(inspect(self.root_blocks))
end

function BattleScheme:_find_block(initiator_unit, passive_unit, fire_type)
  for idx, block in pairs(self.root_blocks) do
    print("examining " .. block.id)
    if (block:matches(fire_type, initiator_unit, passive_unit)) then
      return block
    end
  end
end

return BattleScheme
