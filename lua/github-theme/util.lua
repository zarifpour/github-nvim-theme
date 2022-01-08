local types = require('github-theme.types')

---@class gt.Util
local util = {}

util.colors_name = ''

---@type table<number, gt.HexColor>
util.used_color = {}

---@type gt.HexColor
util.bg = '#000000'

---@type gt.HexColor
util.fg = '#ffffff'

---Convert HexColor to RGB
---@param hex_str gt.HexColor
---@return table<number, number>
local hex_to_rgb = function(hex_str)
  local hex = '[abcdef0-9][abcdef0-9]'
  local pat = '^#(' .. hex .. ')(' .. hex .. ')(' .. hex .. ')$'
  hex_str = string.lower(hex_str)

  assert(string.find(hex_str, pat) ~= nil, 'hex_to_rgb: invalid hex_str: ' .. tostring(hex_str))

  local r, g, b = string.match(hex_str, pat)
  return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

---@param fg gt.HexColor foreground color
---@param bg gt.HexColor background color
---@param alpha number number between 0 and 1. 0 results in bg, 1 results in fg
---@return gt.HexColor
util.blend = function(fg, bg, alpha)
  bg = hex_to_rgb(bg)
  fg = hex_to_rgb(fg)

  local blend_channel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end

  return string.format('#%02X%02X%02X', blend_channel(1), blend_channel(2), blend_channel(3))
end

---@param hex gt.HexColor Color
---@param amount number number between 0 and 1. 0 results in bg, 1 results in fg
---@param bg gt.HexColor Background color
---@return gt.HexColor
util.darken = function(hex, amount, bg)
  return util.blend(hex, bg or util.bg, math.abs(amount))
end

---@param hex gt.HexColor Color
---@param amount number number between 0 and 1. 0 results in bg, 1 results in fg
---@param fg gt.HexColor Foreground color
---@return gt.HexColor
util.lighten = function(hex, amount, fg)
  return util.blend(hex, fg or util.fg, math.abs(amount))
end

---Dump unused colors
---@param colors gt.ColorPalette
util.debug = function(colors)
  for name, color in pairs(colors) do
    if type(color) == 'table' then
      util.debug(color)
    else
      if util.used_color[color] == nil then
        print('not used color: ' .. name .. ' : ' .. color)
      end
    end
  end
end

---@param group string
---@param color gt.Highlight|gt.LinkHighlight
util.highlight = function(group, color)
  if color.fg then
    util.used_color[color.fg] = true
  end
  if color.bg then
    util.used_color[color.bg] = true
  end
  if color.sp then
    util.used_color[color.sp] = true
  end

  local style = color.style and 'gui=' .. color.style or 'gui=NONE'
  local fg = color.fg and 'guifg=' .. color.fg or 'guifg=NONE'
  local bg = color.bg and 'guibg=' .. color.bg or 'guibg=NONE'
  local sp = color.sp and 'guisp=' .. color.sp or ''

  local hl = 'highlight ' .. group .. ' ' .. style .. ' ' .. fg .. ' ' .. bg .. ' ' .. sp

  if color.link then
    vim.cmd('highlight! link ' .. group .. ' ' .. color.link)
  else
    -- local data = {}
    -- if color.fg then data.foreground = color.fg end
    -- if color.bg then data.background = color.bg end
    -- if color.sp then data.special = color.sp end
    -- if color.style then data[color.style] = true end
    -- vim.api.nvim_set_hl(ns, group, data)
    vim.cmd(hl)
  end
end

---Delete the autocmds when the theme changes to something else
util.on_colorscheme = function()
  if vim.g.colors_name ~= util.colors_name then
    vim.cmd('autocmd! ' .. util.colors_name)
    vim.cmd('augroup!' .. util.colors_name)
  end
end

---@param config gt.ConfigSchema
util.autocmds = function(config)
  vim.cmd('augroup ' .. util.colors_name)
  vim.cmd([[  autocmd!]])
  vim.cmd([[  autocmd ColorScheme * lua require("github-theme.util").on_colorscheme()]])
  if config.dev then
    vim.cmd('  autocmd BufWritePost */lua/github-theme/** nested colorscheme ' .. util.colors_name)
  end
  for _, sidebar in ipairs(config.sidebars) do
    if sidebar == 'terminal' then
      vim.cmd([[  autocmd TermOpen * setlocal winhighlight=Normal:NormalSB,SignColumn:SignColumnSB]])
    else
      vim.cmd([[  autocmd FileType ]] .. sidebar .. [[ setlocal winhighlight=Normal:NormalSB,SignColumn:SignColumnSB]])
    end
  end
  vim.cmd([[augroup end]])
end

util.syntax = function(syntax)
  for group, colors in pairs(syntax) do
    util.highlight(group, colors)
  end
end

---@param colors gt.ColorPalette
util.terminal = function(colors)
  -- dark
  vim.g.terminal_color_0 = colors.black
  vim.g.terminal_color_8 = colors.fg_dark
  -- light
  vim.g.terminal_color_7 = colors.fg_dark
  vim.g.terminal_color_15 = colors.fg_term
  -- colors
  vim.g.terminal_color_1 = colors.red
  vim.g.terminal_color_9 = colors.bright_red
  vim.g.terminal_color_2 = colors.green
  vim.g.terminal_color_10 = colors.bright_green
  vim.g.terminal_color_3 = colors.yellow
  vim.g.terminal_color_11 = colors.bright_yellow
  vim.g.terminal_color_4 = colors.blue
  vim.g.terminal_color_12 = colors.bright_blue
  vim.g.terminal_color_5 = colors.magenta
  vim.g.terminal_color_13 = colors.bright_magenta
  vim.g.terminal_color_6 = colors.cyan
  vim.g.terminal_color_14 = colors.bright_cyan
end

---@param hi gt.Highlights
util.load = function(hi)
  vim.cmd('hi clear')
  if vim.fn.exists('syntax_on') then
    vim.cmd('syntax reset')
  end
  util.colors_name = 'github_' .. hi.config.theme_style
  vim.o.termguicolors = true
  vim.g.colors_name = util.colors_name
  -- vim.api.nvim__set_hl_ns(ns)
  util.syntax(hi.base)
  util.autocmds(hi.config)
  util.terminal(hi.colors)
  util.syntax(hi.plugins)
end

---Override custom highlights in `group`
---@param group table
---@param overrides table
util.apply_overrides = function(group, overrides)
  for k, v in pairs(overrides) do
    if group[k] ~= nil and type(v) == 'table' then
      group[k] = v
    end
  end
end

---@param colors gt.ColorPalette
---@param oride_colors gt.ColorPalette
---@return gt.ColorPalette
function util.color_overrides(colors, oride_colors)
  if type(oride_colors) == 'table' then
    for key, value in pairs(oride_colors) do
      if not colors[key] then
        error('Color ' .. key .. ' does not exist')
      end
      -- Patch: https://github.com/ful1e5/onedark.nvim/issues/6
      if type(colors[key]) == 'table' then
        util.color_overrides(colors[key], value)
      else
        if value:lower() == types.gt.HighlightStyle.None:lower() then
          -- set to none
          colors[key] = types.gt.HighlightStyle.None
        elseif string.sub(value, 1, 1) == '#' then
          -- hex override
          colors[key] = value
        else
          -- another group
          if not colors[value] then
            error('Color ' .. value .. ' does not exist')
          end
          colors[key] = colors[value]
        end
      end
    end
  end
  return colors
end

-- Simple string interpolation.
--
-- Example template: "${name} is ${value}"
--
---@param str string template string
---@param table table key value pairs to replace in the string
util.template = function(str, table)
  return (str:gsub('($%b{})', function(w)
    return table[w:sub(3, -2)] or w
  end))
end

return util
