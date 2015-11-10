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


function BattleScheme.create(engine)
   local o = { engine = engine }
   setmetatable(o, BattleScheme)

   -- capture functions
   local property_c = function(o,v) return _PropertyCondition.create(o,v) end
   local literal_c = function(v) return { kind = 'Literal', value = v } end
   local block_c = function(id) return _BlockCondition.create(id) end
   local relation_c = function(v1, op, v2) return { kind = 'Relation', operator = op, v1 = v1, v2 = v2} end
   local negation_c = function(e) return { kind = 'Negation', e = e } end
   local l_operation_c = function(e1, op, e2) return { kind = "LogicalOperation", operator = op, e1 = e1, e2 = e2} end

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

   return o
end

function BattleScheme:_parse_condition(c)
   local condition = self.condition_grammar:match(c)
   return condition
end

return BattleScheme
