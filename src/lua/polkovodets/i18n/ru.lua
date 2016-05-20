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
    ['map.unit_info']                = 'Информация о соединении',


    -- unit info window
    ['ui.unit-info.tab.info.hint']        = 'Общая информация',
    ['ui.unit-info.tab.problems.hint']    = 'Проблемы',
    ['ui.unit-info.tab.attachments.hint'] = 'Прикреплённые соединения',
    ['ui.unit-info.tab.management.hint']  = 'Управление',


    ['ui.unit-info.tab.problems.absent']  = 'Проблем не обнаружено',
    ['ui.unit-info.tab.problems.present'] = 'Обнаружены следующие проблемы',


    ['ui.unit-info.size']            = 'Тип',
    ['ui.unit-info.class']           = 'Класс',
    ['ui.unit-info.spotting']        = 'Радиус обзора',
    ['ui.unit-info.state']           = 'Состояние',
    ['ui.unit-info.entrenchement']   = 'Укрепления и окопы',
    ['ui.unit-info.experience']      = 'Опыт',
    ['ui.unit-info.orientation']     = 'Пространственная ориентация',

    -- radial menu
    ['ui.radial-menu.hex_button']               = 'Меню для гекса',
    ['ui.radial-menu.general_button']           = 'Общеигровое меню',
    ['ui.radial-menu.general.end_turn']         = 'Конец хода',
    ['ui.radial-menu.general.toggle_layer']     = 'Переключить активный уровень (поверхность/воздух)',
    ['ui.radial-menu.general.toggle_history']   = 'Показать последние действия',
    ['ui.radial-menu.general.toggle_landscape'] = 'Показать только ландшафт',

    ['ui.radial-menu.hex.select_unit'] = 'Выбрать соединиенне (%{name})',
    ['ui.radial-menu.hex.unit_info']   = 'Информация соединиенне (%{name})',

    -- UI buttons
    ['ui.button.change_orientation'] = 'Изменить пространсветнную ориентацию соединения',
    ['ui.button.information']        = 'Дополнительная информация',
    ['ui.button.detach']             = 'Открепить соединение',
    ['ui.button.detach_unit']        = 'Открепить соединение (%{name})',

    -- windows
    ['ui.window.battle_details.header.was']         = 'Было',
    ['ui.window.battle_details.header.casualities'] = 'Потери',

    -- popups
    ['ui.popup.battle_selector.battle'] = '%{i} / %{p}',

    -- problems
    ['problem.transport']             = "Tранспортная проблема: недостаточно транспорта (%{capabilities}) для траспортировки %{needed} (%{details}) единиц оружия.",
    ['problem.missing_weapon']        = "Полностью отсутствует оружие класса '%{weapon_type}', заявленное в штатном расписании.",

    -- [[ database names translations ]]--
    -- states
    ['db.unit.state.attacking']       = 'атака',
    ['db.unit.state.defending']       = 'защита',
    ['db.unit.state.landed']          = 'посажен',
    ['db.unit.state.flying']          = 'в полёте',

    -- orientation
    ['db.unit.orientation.left']      = 'налево',
    ['db.unit.orientation.right']     = 'направо',

    -- size
    ['db.unit.size.S']                 = 'батальон',
    ['db.unit.size.M']                 = 'бригада',
    ['db.unit.size.L']                 = 'дивизия',

    -- unit classes
    ['db.unit-class.inf']             = 'Пехота',
    ['db.unit-class.tank']            = 'Бронетехника',

    -- weapon classes
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
