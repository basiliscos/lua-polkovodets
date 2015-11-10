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

local _PropertyCondition = {}
_PropertyCondition.__index = _PropertyCondition

function _PropertyCondition.create(value)
   return setmetatable({ kind = 'Property', value = value }, _PropertyCondition)
end



function BattleScheme.create(engine)
   local o = { engine = engine }
   setmetatable(o, BattleScheme)

   -- capture functions
   local property_c = function(v) return _PropertyCondition.create(v) end
   local object_c = function(v) return { kind = 'Object', value = v } end
   local literal_c = function(v) return { kind = 'Literal', value = v } end
   local block_c = function(v) return { kind = 'Block', value = v } end
   local value_c = function(...) return { kind = 'Value', value = {...} } end
   local method_c = function(o, m, ...) return { kind = 'Method', object = o, method = m, args = { ... } } end
   local relation_c = function(v1, op, v2) return { kind = 'Relation', operator = op, v1 = v1, v2 = v2} end
   local negation_c = function(e) return { kind = 'Negation', e = e } end
   local l_relation_c = function(e1, op, e2) return { kind = "LogicalRelation", operator = op, e1 = e1, e2 = e2} end

   -- Lexical Elements
   local Space = lpeg.S(" ")^0
   local Property = ((lpeg.R("09") + lpeg.R("az", "AZ"))^1) / property_c
   local Object = (lpeg.P("I") + lpeg.P("P")) / object_c
   local BareString = ((lpeg.R("09") + lpeg.R("az", "AZ") +lpeg.S("._"))^0)
   local Literal = (lpeg.P("'") * (BareString/literal_c)  * lpeg.P("'"))
   local Arg = Literal
   local Method = Object * lpeg.P('.') * lpeg.C(BareString) * lpeg.P('(') * Arg^0 * lpeg.P(')') / method_c
   local Value  = (Literal + (Object * lpeg.P('.') * Property) + Method) / value_c
   local Block = (lpeg.P("block(") * Literal * lpeg.P(")"))/ block_c
   local Relation = Value * Space * lpeg.C(lpeg.P("==") + lpeg.P("!=")) * Space * Value / relation_c
   local Atom = Block + Relation

   -- Grammar
   local G = lpeg.P{
      "Expr";
      Expr
         = Atom
         + lpeg.V("Negation")
         + (Space * lpeg.P('(') * lpeg.V("Expr") * lpeg.P(')'))
         + lpeg.V("Logical_Expr"),
      Negation
         = (lpeg.P('!')^1 * Space * lpeg.V('Expr')) / negation_c,
      Logical_Expr
         = lpeg.P('(') * lpeg.V('Expr') * Space
            * lpeg.C(lpeg.P('&&') + lpeg.P('&&')) * Space * lpeg.V('Expr')
         * lpeg.P(')') / l_relation_c,
   }

   o.grammar = G

   return o
end

function BattleScheme:_parse_condition(c)
   local condition = self.grammar:match(c)
   return condition
end

return BattleScheme
