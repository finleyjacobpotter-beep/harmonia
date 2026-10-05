-- JSON/YAML commands. Each works on the whole buffer, or on a range or
-- visual selection (:'<,'>JsonPretty), and replaces the text in place.
--
--   :JsonPretty      serialized/minified JSON -> indented JSON. Also unwraps
--                    JSON that was stringified (once or several times), with
--                    or without the outer quotes: "{\"a\":1}" or {\"a\":1}.
--   :JsonMinify      JSON -> one line
--   :JsonSerialize   JSON -> one-line JSON string ("{\"a\":1}")
--   :JsonToYaml      JSON -> YAML
--   :YamlToJson      YAML -> JSON
--   :Prettier        format with prettier (JSON, YAML, Markdown, JS, CSS, ...)
--
-- Indents come from EditorConfig (two spaces for JSON/YAML).
local M = {}

-- Unwrap stringified JSON until it is no longer a string of JSON.
local unwrap = [[
def unwrap: if type == "string" then (try (fromjson | unwrap) catch .) else . end;
. as $raw
| (try fromjson catch (("\"" + ($raw | rtrimstr("\n")) + "\"") | fromjson))
| unwrap
]]

local function filepath(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return vim.fn.getcwd() .. "/untitled." .. (vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "json")
  end
  return name
end

local function indent(buf)
  local sw = vim.bo[buf].shiftwidth
  if sw == 0 then sw = vim.bo[buf].tabstop end
  return tostring(sw)
end

-- Pipe lines l1..l2 of the buffer through cmd and put the output back.
local function filter(opts, cmd, filetype)
  local buf = vim.api.nvim_get_current_buf()
  local l1, l2 = opts.line1, opts.line2
  local whole = l1 == 1 and l2 == vim.api.nvim_buf_line_count(buf)
  local input = table.concat(vim.api.nvim_buf_get_lines(buf, l1 - 1, l2, false), "\n") .. "\n"

  local res = vim.system(cmd(buf, filetype), { stdin = input, text = true }):wait()
  if res.code ~= 0 then
    vim.notify(vim.trim(res.stderr ~= "" and res.stderr or res.stdout), vim.log.levels.ERROR,
      { title = cmd(buf, filetype)[1] })
    return
  end
  local out = vim.split(res.stdout:gsub("\n+$", ""), "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, l1 - 1, l2, false, out)
  if whole and filetype and vim.bo[buf].filetype ~= filetype then
    vim.bo[buf].filetype = filetype
  end
end

local function command(name, desc, cmd, filetype)
  vim.api.nvim_create_user_command(name, function(opts)
    filter(opts, cmd, filetype)
  end, { range = "%", desc = desc })
end

function M.setup()
  command("JsonPretty", "Unserialize / pretty-print JSON", function(buf)
    return { "jq", "-Rs", "--indent", indent(buf), unwrap }
  end, "json")

  command("JsonMinify", "Minify JSON to one line", function()
    return { "jq", "-c", "." }
  end, "json")

  command("JsonSerialize", "Serialize JSON to a JSON string", function()
    return { "jq", "-c", "tojson" }
  end, "json")

  command("JsonToYaml", "Convert JSON to YAML", function(buf)
    return { "yq", "-p", "json", "-o", "yaml", "-P", "-I", indent(buf) }
  end, "yaml")

  command("YamlToJson", "Convert YAML to JSON", function(buf)
    return { "yq", "-p", "yaml", "-o", "json", "-I", indent(buf) }
  end, "json")

  command("Prettier", "Format with prettier", function(buf)
    return { "prettier", "--stdin-filepath", filepath(buf) }
  end)

  local map = function(lhs, cmd, desc)
    vim.keymap.set({ "n", "x" }, lhs, ":" .. cmd .. "<cr>", { desc = desc, silent = true })
  end
  map("<leader>jp", "JsonPretty", "JSON: unserialize / pretty")
  map("<leader>jm", "JsonMinify", "JSON: minify")
  map("<leader>js", "JsonSerialize", "JSON: serialize to string")
  map("<leader>jy", "JsonToYaml", "JSON -> YAML")
  map("<leader>jj", "YamlToJson", "YAML -> JSON")
  map("<leader>jf", "Prettier", "Format (prettier)")
end

return M
