t = {
  ru = {
    -- map buttons
    ['map.battle-on-tile'] = {
      one   = 'Произошло %{count} сражение на клетке %{tile}',
      few   = 'Произошло %{count} сражения на клетке %{tile}',
      many  = 'Произошло %{count} сражений на клетке %{tile}',
      other = 'Произошло %{count} сражения на клетке %{tile}',
    },
    ['map.change-attack-kind']       = 'Изменить вид аттаки',

    -- UI buttons
    ['ui.button.end_turn']           = 'Конец хода',
    ['ui.button.toggle_layer']       = 'Переключить активный уровень (поверхность/воздух)',
    ['ui.button.toggle_history']     = 'Показать последние действия оппонента',
    ['ui.button.toggle_landscape']   = 'Показать только ландшафт',
    ['ui.button.change_orientation'] = 'Изменить пространсветнную ориентацию соединения',
    ['ui.button.information']        = 'Дополнительная информация',
    ['ui.button.detach']             = 'Открепить соединение',
    ['ui.button.detach_unit']        = 'Открепить соединение (%{name})',

    -- windows
    ['ui.window.battle_details.header.was']         = 'Было',
    ['ui.window.battle_details.header.casualities'] = 'Потери',

    -- database names translations
    ['db.weapon-class.wk_infant']     = 'Пехота',
    ['db.weapon-class.wk_armor']      = 'Бронетехника',
    ['db.weapon-class.wk_min']        = 'Миномёты',
    ['db.weapon-class.wk_artil']      = 'Артиллерия',
    ['db.weapon-class.wk_antiair']    = 'Средства ПВО',
    ['db.weapon-class.wk_antitank']   = 'Средства ПТО',
    ['db.weapon-class.wk_engeneer']   = 'Инженерная, химическая и вспомогательная техника',
    ['db.weapon-class.wk_transp']     = 'Транспорт',
    ['db.weapon-class.wk_fighter']    = 'Истребители',
    ['db.weapon-class.wk_bomb']       = 'Бомбардировщики',
    ['db.weapon-class.wk_airrecon']   = 'Разведчики',
    ['db.weapon-class.wk_airtrans']   = 'Транспортная	авиация',
    ['db.weapon-class.wk_helicopter'] = 'Вертолеты',
    ['db.weapon-class.wk_aerostat']   = 'Аэростаты и дирижабли',
    ['db.weapon-class.wk_hq']         = 'Штабы и связь',
    ['db.weapon-class.wk_fort']       = 'Фортификации',
  },
}

return t
