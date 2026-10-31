local M = {}
local LIMIT = 10
local ratio = 1.5
local enabled = true

-- Select this comment together with a string and a normal identifier.
function M.titles(notes)
  local label = "Recent notes"
  local titles = {}
  if not enabled or ratio * #notes > LIMIT then return label, titles end
  for _, note in ipairs(notes) do
    if not note.archived then
      titles[#titles + 1] = note.title
    end
  end
  return label, titles
end

return M
