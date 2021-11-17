local M = {}

---Reference https://vi.stackexchange.com/a/2577/33116
---@return string os_name
M.get_os = function ()
  if vim.fn.has('win32') == 1 then
    return 'Windows'
  end
  return tostring(io.popen('uname'):read())
end

---Get command to *check* and *paste* clipboard content
---@return string cmd_check, string cmd_paste
M.get_clip_command = function ()
  local cmd_check, cmd_paste = '', ''
  local this_os = M.get_os()
  if this_os == 'Linux' then
    local display_server = os.getenv('XDG_SESSION_TYPE')
    if display_server == 'x11' then
      cmd_check = 'xclip -selection clipboard -o -t TARGETS'
      cmd_paste = 'xclip -selection clipboard -t image/png -o > %s'
    elseif display_server == 'wayland' then
      cmd_check = 'wl-paste --list-types'
      cmd_paste = 'wl-paste --no-newline --type image/png > %s'
    end
  elseif this_os == 'Darwin' then
    cmd_check = 'pngpaste -b 2>&1'
    cmd_paste = 'pngpaste %s'
  elseif this_os == 'Windows' then
    cmd_check = 'Get-Clipboard -Format Image'
    cmd_paste = '$content = '..cmd_check..';$content.Save(\'%s\', \'png\')'
    cmd_check = 'powershell.exe \"'..cmd_check..'\"'
    cmd_paste = 'powershell.exe \"'..cmd_paste..'\"'
  end
  return cmd_check, cmd_paste
end

---Will be used in utils.is_clipboard_img to check if image data exist
---@param command string #command to check clip_content
M.get_clip_content = function (command)
  command = io.popen(command)
  local outputs = {}

  ---Store output in outputs table
  for output in command:lines() do
    table.insert(outputs, output)
  end
  return outputs
end

---Check if clipboard contain image data
---See also: [Data URI scheme](https://en.wikipedia.org/wiki/Data_URI_scheme)
---@param content string #clipboard content
M.is_clipboard_img = function (content)
  local this_os = M.get_os()
  if this_os == 'Linux' and vim.tbl_contains(content, 'image/png') then
    return true
  elseif this_os == 'Darwin' and string.sub(content[1], 1, 9) == 'iVBORw0KG' then -- Magic png number in base64
    return true
  elseif this_os == 'Windows' and content ~= nil then
    return true
  end
  return false
end

---@param dir string
M.create_dir = function (dir)
  dir = vim.fn.expand(dir)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end
end

---@param img_dir string
---@param img_name string
---@param is_txt? '"txt"'
---@return string img_path
M.get_img_path = function (dir, img_name, is_txt)
  local this_os = M.get_os()
  local dir = vim.fn.expand(dir)
  local img = img_name .. '.png'

  ---On cwd
  if dir == "" or dir == nil then
    return img
  end

  if this_os == 'Windows' and is_txt ~= 'txt' then
    return dir .. '\\' .. img
  end
  return dir .. '/' .. img
end

---Insert image's path with affix
---TODO: Probably need better description
M.insert_txt = function(affix, path_txt)
  local curpos = vim.fn.getcurpos()
  local line_num, line_col = curpos[2], curpos[3]
  local indent = string.rep(' ', line_col)
  local txt_topaste = string.format(affix, path_txt)

  ---Convert txt_topaste to lines table so it can handle multiline string
  local lines = {}
  for line in txt_topaste:gmatch('[^\r\n]+') do
    table.insert(lines, line)
  end

  for line_index, line in pairs(lines) do
    local current_line_num = line_num + line_index-1
    local current_line = vim.fn.getline(current_line_num)
    ---Since there's no collumn 0, remove extra space when current line is blank
    if current_line == '' then
      indent = indent:sub(1, -2)
    end

    local pre_txt = current_line:sub(1, line_col)
    local post_txt = current_line:sub(line_col+1, -1)
    local inserted_txt = pre_txt .. line .. post_txt

    vim.fn.setline(current_line_num, inserted_txt)
    ---Create new line so inserted_txt doesn't replace next lines
    if line_index ~= #lines then
      vim.fn.append(current_line_num, indent)
    end
  end
end

M.insert_text = M.insert_txt

return M
