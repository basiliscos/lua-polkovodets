--[[

Copyright (C) 2015, 2016 Ivan Baidakou

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


local inspect = require('inspect')
local lpeg = require('lpeg')
local _ = require ("moses")
local Probability = require 'polkovodets.utils.Probability'

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
    local v = self.property
    assert((v == 'state') or (v == 'orientation') or (v == 'type'))
end

function _PropertyCondition:get_value(I_unit, P_unit)
    local o = (self.object == 'I') and I_unit or P_unit
    local property = self.property
    local value
    if (property == 'orientation') then
        value = o.data.orientation
    elseif (property == 'state') then
        value = o.data.state
    elseif (property == 'type') then
        value = o.definition.unit_type.id
    else
        error("unknow unit property " .. property)
    end
    -- print(string.format("k = %s => ", property, value))
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
    local result
    if (self.operator == '==') then
        result = (v1 == v2)
    elseif (self.operator == '!=') then
        result = (v1 ~= v2)
    else
        error("Unknown operator: " .. self.operator)
    end
    -- print(string.format("matching result for (%s '%s' %s) => %s", v1, self.operator, v2, result))
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
    elseif (self.operator == '||') then
        for idx, relation in pairs(self.relations) do
            local r_match = relation:matches(I_unit, P_unit)
            result = result or r_match
        end
    else
        error("uknown logical condition operator " .. self.operator)
    end
    -- print(string.format("logic condition '%s' matches for I.state = %s, P.state = %s => %s", self.operator, I_unit.data.state, P_unit.data.state, result))
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
  -- select object and  side and enemy data
  local o = (self.object == 'I') and ctx.i or ctx.p
  local e = (self.object == 'I') and ctx.p or ctx.i
  assert(o)
  assert(e)

  local select_by_selector = function(weapon_instance)
    -- print(string.format("select_by_selector, method %s", self.method))
    if (self.method == 'category') then
      local result = weapon_instance.weapon.category.id == self.specification
      -- print(string.format("select_by_selector/category = %s, wi.cat = %s, result = %s", self.specification, weapon_instance.weapon.category.id, result))
      return result
    elseif ((self.method == 'target') and (self.specification == 'any')) then
      return true
    end
  end

  local select_by_filter = function(filter)
    local instances = {}
    for idx, wi in pairs(o.weapon_instances) do
      if (select_by_selector(wi) and filter(wi)) then
        table.insert(instances, wi)
      end
    end
    -- print("selected by role " .. role .. " " .. inspect(instances))
    return instances, o
  end

  -- For active weapon we additionally ensure that weapon is
  -- capable to shoot on the required range and there are remained shots
  -- for passive weapon we just ensure, that it (still) exists
  local role_filter
  if (role == 'active') then
    local e_layer = e.layer
    role_filter = function(weapon_instance)
        local range_ok = weapon_instance.weapon.range[e_layer] >= ctx.range
        local quantities_ok = weapon_instance.data.quantity > 0
        local shots_ok = o.shots[weapon_instance.id] > 0
        -- print(string.format("range: %s, quantities_ok = %s, shots = %s", range_ok, quantities_ok, shots_ok))
        return range_ok and quantities_ok and shots_ok
    end
  else
    role_filter = function(weapon_instance)
        local quantities_ok = weapon_instance.data.quantity > 0
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
  local selected_side
  if (self.operator == '||') then
    for idx, selector in pairs(self.selectors) do
      local weapon_instances, side = selector:select_weapons(role, ctx)
      assert(side)
      if (not selected_side) then
        selected_side = side
      else
        assert(selected_side == side)
      end
      for idx2, wi in pairs(weapon_instances) do
        table.insert(weapons, wi)
      end
    end
  end
  return weapons, selected_side
end

--[[ Block class ]]--
local _Block = {}
_Block.__index = _Block


function _Block.create(battle_scheme, id, command, condition,
                       active_weapon_selector, active_multiplier,
                       passive_weapon_selector, passive_multiplier,
                       action)
    assert(id)
    assert(string.find(id, "%w+(%.?%w*)"))

    local parent_id_start, parent_id_end = string.find(id, '%w+%.')
    local parent_id
    if (parent_id_end) then
        parent_id = string.sub(id, parent_id_start, parent_id_end - parent_id_start)
        active_multiplier = tonumber(active_multiplier)
        passive_multiplier = tonumber(passive_multiplier)
        assert(active_multiplier and (active_multiplier > 0))
        assert(passive_multiplier and (passive_multiplier > 0))
        assert(action)
    end
    if (not parent_id) then
        assert(condition, "no condition for block " .. id)
    end

    local o = {
        id            = id,
        parent_id     = parent_id,
        battle_scheme = battle_scheme,
        command       = command,
        condition     = condition,
        active        = active_weapon_selector,
        a_multiplier  = active_multiplier,
        passive       = passive_weapon_selector,
        p_multiplier  = passive_multiplier,
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
      assert(self.command)
      assert(self.condition)
      self.condition:validate()
   else
      local parent_block = self.battle_scheme:_lookup_block(self.parent_id)
      assert(parent_block)
      assert(not self.command)
      if (self.condition) then self.condition:validate() end
   end
end

function _Block:matches(command, i_unit, p_unit)
  assert(i_unit)
  assert(p_unit)
  if (self.command == command) then
    return self.condition:matches(i_unit, p_unit)
  end
end

function _Block:select_pair(ctx)
    assert(self.parent_id)

    local calculate_effective_bonuses = function(role, summary)
        -- zero bonus with probability 1
        local defaults = {  }
        _.each(summary.side.weapon_instances, function(_, wi)
            defaults[wi.id] =  {
                values = { { value = 0, quantity = 1 } },
                fn     = { { index = 1, prob = 1 } },
            }
        end)
        -- print("defaults " .. inspect(defaults))
        summary.bonus = {
            attack  = defaults,
            defence = _.clone(defaults),
        }
        if (summary.side == ctx.i) then
            -- GRANTS_DEF_ATTACK
            local armor_granting = {} -- k: bonus, v: quantity (number of weapon instances to be applied for)
            local total_bonuses = 0
            _.each(ctx.i.weapon_instances, function(_, wi)
                local _, value = wi:is_capable("GRANTS_DEF_ATTACK")
                if (value) then
                    local to, bonus = value:match("(%d+)/(%d+)")
                    to = tonumber(to)
                    bonus = tonumber(bonus)
                    assert(to > 0)
                    assert(bonus > 0)
                    local count = wi.data.quantity * to + (armor_granting[bonus] or 0)
                    total_bonuses = total_bonuses + wi.data.quantity * to
                    armor_granting[bonus] = count
                end
            end)
            local subjects = _.select(ctx.i.weapon_instances, function(_, wi)
                return wi.weapon.category.id == 'wc_infant'
            end)
            local requirements = _.reduce(subjects, function(state, wi)
                    return state + wi.data.quantity
                end,
                0
            )
            -- add zero armor bonus for normalization
            local zero_bonus = requirements - total_bonuses
            if (zero_bonus >= 0) then armor_granting[0] = zero_bonus end
            local armors = {}
            for bonus, quantity in pairs(armor_granting) do
                table.insert(armors, {
                    value = bonus,
                    quantity = quantity
                })
            end
            local armors_fn = Probability.fn(armors, function(item)
                return item.quantity
            end)
            local subjects_results = {
                values = armors,
                fn     = armors_fn,
            }
            for _, wi in pairs(subjects) do
                -- OK, probably we should merge here IF different kinds of armor bonuses
                summary.bonus.defence[wi.id] = subjects_results
            end
        else
            local unit = ctx.p.unit
            local unit_entr = unit.data.entr
            for _, item in pairs(summary.bonus.defence) do
                item.values[1].value = unit_entr
            end
        end
    end

    local a_weapons, a_side = self.active:select_weapons('active', ctx)
    if (#a_weapons > 0) then
        local p_weapons, p_side = self.passive:select_weapons('passive', ctx)
        if (#p_weapons > 0) then
            local a_summary = {
                weapons     = a_weapons,
                shots       = a_side.shots,
                casualities = a_side.casualities,
                side        = a_side,
                multiplier  = self.a_multiplier,
            }
            calculate_effective_bonuses('active', a_summary)
            local p_summary = {
                weapons     = p_weapons,
                shots       = p_side.shots,
                casualities = p_side.casualities,
                side        = p_side,
                multiplier  = self.p_multiplier,
            }
            calculate_effective_bonuses('passive', p_summary)

            return {
                a      = a_summary,
                p      = p_summary,
                action = self.action,
            }
        end
    end
end

function _Block:perform_battle(i_unit, p_unit, command)
  local range = i_unit.tile:distance_to(p_unit.tile)
  local i_weapon_instances = i_unit:_united_staff()
  local p_weapon_instances = p_unit:_united_staff()

  -- prepare context; by default all weapons do shot, and no casualities
  local i_shots, p_shots = {}, {}
  _.each(i_weapon_instances, function(k, wi) i_shots[wi.id] = wi.data.quantity end)
  _.each(p_weapon_instances, function(k, wi) p_shots[wi.id] = wi.data.quantity end)

  -- participants is equal to shots count
  local i_participants = _.clone(i_shots)
  local p_participants = _.clone(p_shots)

  local ctx = {
    range              = range,
    i = {
      unit               = i_unit,
      layer              = i_unit.data.layer,
      weapon_instances   = i_weapon_instances,
      shots              = i_shots,
      casualities        = _.map(i_shots, function(k, v) return 0 end),
    },
    p = {
      unit               = p_unit,
      layer              = p_unit.data.layer,
      weapon_instances   = p_weapon_instances,
      shots              = p_shots,
      casualities        = _.map(p_shots, function(k, v) return 0 end),
    },
  }

  for idx, block in pairs(self.children) do
    print("trying block " .. block.id)
    local pair = block:select_pair(ctx)
    if (pair) then
      -- print("matching pair = " .. inspect(pair))
      -- print("shots i = " .. inspect(ctx.i.shots))
      -- print("shots p = " .. inspect(ctx.p.shots))
      self.battle_scheme.battle_formula:perform_battle(pair)
      print("casualities for I = " .. inspect(ctx.i.casualities))
      print("casualities for P = " .. inspect(ctx.p.casualities))
    end
  end
  _.each(i_weapon_instances, function(k, wi) wi.data.can_attack = false end)
  return ctx.i.casualities, ctx.p.casualities, i_participants, p_participants
end

function BattleScheme.create()
   local o = {
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
      local LogicalRelation = lpeg.P('&&') + lpeg.P('||')

      -- Grammar
      local condition_grammar = lpeg.P{
         "Expr";
         Expr
            = lpeg.V("Logical_Operation")
            + lpeg.V("Negation")
            + lpeg.V("PExpr")
            + RelationAtom
            ,
         Negation = (lpeg.P('!') * Space * lpeg.V('Expr')) / negation_c,
         PExpr = lpeg.P('(') * lpeg.V("Expr") * lpeg.P(')'),
         Logical_Operation = (lpeg.V("PExpr") * (Space * lpeg.C(LogicalRelation) * Space * lpeg.V("PExpr"))^1) / l_operation_c
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
   return o
end

function BattleScheme:initialize(battle_formula, battle_blocks)
  self.battle_formula = battle_formula

  for idx, data in pairs(battle_blocks) do
    local id = assert(data.block_id)
    local command = data.command
    local action = data.action
    local condition_str = data.condition
    local active_weapon_selector = data.active_weapon
    local passive_weapon_selector = data.passive_weapon
    local active_weapon, passive_weapon

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

    -- print(string.format("creating block, active = %s, passive = %s, data = %s", active_weapon, passive_weapon, inspect(data)))

    local block = self:_create_block(
      id,
      command,
      condition,
      active_weapon,
      data.active_multiplier,
      passive_weapon,
      data.passive_multiplier,
      action
    )
  end
  print("Battle scheme initialized, " .. #self.root_blocks .. " root blocks")
   -- print(inspect(self.root_blocks))
end

function BattleScheme:_parse_condition(c)
   local condition = self.condition_grammar:match(c)
   return condition
end

function BattleScheme:_parse_selection(s)
   local selection = self.selection_grammar:match(s)
   return selection
end

function BattleScheme:_create_block(id, command, condition, active_weapon_selector, active_multiplier,
                                    passive_weapon_selector, passive_multiplier, action)
   assert(not self.block_for[id], "block " .. id .. " alredy exists")
   local b = _Block.create(self, id, command, condition, active_weapon_selector, active_multiplier, passive_weapon_selector, passive_multiplier, action)
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

function BattleScheme:_find_block(initiator_unit, passive_unit, command)
  for idx, block in pairs(self.root_blocks) do
    local match_found = block:matches(command, initiator_unit, passive_unit)
    print("examining block " .. block.id .. " " .. (match_found and 'y' or 'n'))
    if (match_found) then
      return block
    end
  end
end

function BattleScheme:perform_battle(initiator_unit, passive_unit, command)
    local block = self:_find_block(initiator_unit, passive_unit, command)
    if (not block) then
        error(string.format("no suitable battle scheme rule for command '%s', istate: %s, pstate: %s",
                            command, initiator_unit.data.state, passive_unit.data.state))
    end
    return block:perform_battle(initiator_unit, passive_unit, command)
end

return BattleScheme
