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

Expr       ← ATOM / NEGATION / '(' EXPR ')' / L_RELATION
L_RELATION ← Expr (('&&' / '||') Expr)*
ATOM       ← BLOCK / RELATION
BLOCK_REF  ← 'block(' BLOCK_ID ')'
RELATION   ← VALUE ('==' / '!=') VALUE
NEGATION   ← '!' Expr

BLOCK_ID ← ('.' ? [0-9]+)+
VALUE    ← LITERAL / OBJECT '.' PROPERTY / OBJECT '.' METHOD '(' (ARG (',' ARG)*)* ')'
LITERAL  ← '[a-Z0-9_]+'
OBJECT   ← 'I' | 'P'
PROPERTY ← [a-Z0-9_]+
ARG      ← LITERAL


]]--


local Parser = require 'polkovodets.Parser'
local inspect = require('inspect')
local lpeg = require('lpeg')

local BattleScheme = {}
BattleScheme.__index = BattleScheme

--[[ Property Condition class ]]--
local _PropertyCondition = {}
_PropertyCondition.__index = _PropertyCondition

function _PropertyCondition.create(object, prop)
   local t = {
      kind     = 'Property',
      object   = object,
      property = prop,
   }
   return setmetatable(t, _PropertyCondition)
end

-- condition classes

--[[ Block Condition class ]]--
local _BlockCondition = {}
_BlockCondition.__index = _BlockCondition

function _BlockCondition.create(id)
   local t = {
      kind = 'Block',
      id   = id
   }
   return setmetatable(t, _BlockCondition)
end

--[[ Literal Condition class ]]--
local _LiteralCondition = {}
_LiteralCondition.__index = _LiteralCondition

function _LiteralCondition.create(value)
   local t = {
      kind  = 'Literal',
      value = value,
   }
   return setmetatable(t, _LiteralCondition)
end

--[[ Relation Condition class ]]--
local _RelationCondition = {}
_RelationCondition.__index = _RelationCondition

function _RelationCondition.create(operator, v1, v2)
   local t = {
      kind  = 'Relation',
      operator = operator,
      v1       = v1,
      v2       = v2,
   }
   return setmetatable(t, _RelationCondition)
end

--[[ Negation Condition class ]]--
local _NegationCondition = {}
_NegationCondition.__index = _NegationCondition

function _NegationCondition.create(expr)
   local t = {
      kind = 'Negation',
      expr = expr,
   }
   return setmetatable(t, _NegationCondition)
end

--[[ LogicalOperation Condition class ]]--
local _LogicalOperationCondition = {}
_LogicalOperationCondition.__index = _LogicalOperationCondition

function _LogicalOperationCondition.create(operator, e1, e2)
   local t = {
      kind     = 'LogicalOperation',
      operator = operator,
      e1       = e1,
      e2       = e2,
   }
   return setmetatable(t, _LogicalOperationCondition)
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


function BattleScheme.create(engine)
   local o = { engine = engine }
   setmetatable(o, BattleScheme)

   -- conditions
   do
      -- capture functions
      local property_c = function(o,v) return _PropertyCondition.create(o,v) end
      local literal_c = function(v) return _LiteralCondition.create(v) end
      local block_c = function(id) return _BlockCondition.create(id) end
      local relation_c = function(v1, op, v2) return  _RelationCondition.create(op, v1, v2) end
      local negation_c = function(e) return _NegationCondition.create(e) end
      local l_operation_c = function(e1, op, e2) return _LogicalOperationCondition.create(op, e1, e2) end

      -- Lexical Elements
      local Space = lpeg.S(" ")^0
      local BareString = ((lpeg.R("09") + lpeg.R("az", "AZ") +lpeg.S("._"))^0)
      local Literal = (lpeg.P("'") * BareString * lpeg.P("'"))
      local Object = (lpeg.P("I") + lpeg.P("P"))
      local Property = (lpeg.C(Object) * lpeg.P('.') * lpeg.C((lpeg.R("09") + lpeg.R("az", "AZ"))^1)) / property_c
      local Value  = (lpeg.P("'") * (BareString/literal_c) * lpeg.P("'")) + Property
      local Block = (lpeg.P("block(") * (lpeg.P("'") * lpeg.C(BareString) * lpeg.P("'"))  * lpeg.P(")"))/ block_c
      local Relation = Value * Space * lpeg.C(lpeg.P("==") + lpeg.P("!=")) * Space * Value / relation_c

      -- Grammar
      local condition_grammar = lpeg.P{
         "Expr";
         Expr
            = Relation
            + lpeg.V("Block_Negation")
            + lpeg.V("Negation")
            + (Space * lpeg.P('(') * Space * lpeg.V("Expr") * Space * lpeg.P(')'))
            + lpeg.V("Logical_Operation"),
         Block_Negation
            = (lpeg.P('!')^1 * Space * Block) / negation_c,
         Negation
            = (lpeg.P('!')^1 * Space * lpeg.V('Expr')) / negation_c,
         Logical_Operation
            = lpeg.P('(') * Space * lpeg.V('Expr') * Space
            * lpeg.C(lpeg.P('&&') + lpeg.P('&&')) * Space * lpeg.V('Expr')
            * Space * lpeg.P(')') / l_operation_c,
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
      local Literal = (lpeg.P("'") * BareString * lpeg.P("'"))
      local Object = (lpeg.P("I") + lpeg.P("P"))
      local Selector = (lpeg.C(Object) * lpeg.P('.') * lpeg.C(BareString)
                           * lpeg.P("('") * lpeg.C(BareString) * lpeg.P("')"))  / selector_c
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

function BattleScheme:_parse_condition(c)
   local condition = self.condition_grammar:match(c)
   return condition
end

function BattleScheme:_parse_selection(s)
   local selection = self.selection_grammar:match(s)
   print(inspect(selection))
   return selection
end

return BattleScheme
