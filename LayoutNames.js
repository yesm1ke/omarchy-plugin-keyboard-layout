// Human names for xkb layout codes, for the popup's layout list.
//
// Parses `xkbcli list` output into a map keyed by the bare layout code (e.g.
// "us", "ru" -- what kb_layout in input.lua and hyprctl's `layout` field use),
// taking only the base entry for each code (empty variant) rather than every
// variant. Lets the popup show a human name for whatever is configured
// without switching to it first to read active_keymap.
function layoutCodeMap(text) {
  var map = {}
  var code = ""
  var variant = null

  String(text || "").split("\n").forEach(function (line) {
    var layoutField = line.match(/^- layout: '(.*)'$/)
    if (layoutField) {
      code = layoutField[1]
      variant = null
      return
    }
    var variantField = line.match(/^  variant: '(.*)'$/)
    if (variantField) {
      variant = variantField[1]
      return
    }
    var descField = line.match(/^  description: (.*)$/)
    if (descField && code && variant === "" && !map[code]) map[code] = descField[1]
  })

  return map
}

// The configured layout list and the active index, read off `hyprctl -j
// devices`. Every keyboard on the seat carries the same kb_layout, so prefer
// the one the stock widget is describing and fall back to any that lists more
// than one layout.
function layoutState(text, preferredName) {
  var keyboards
  try {
    keyboards = JSON.parse(text || "{}").keyboards
  } catch (e) {
    return null
  }
  if (!Array.isArray(keyboards)) return null

  var chosen = null
  for (var i = 0; i < keyboards.length; i++) {
    var kb = keyboards[i]
    if (!kb || kb.layout === undefined) continue
    if (preferredName && String(kb.name || "") === preferredName) { chosen = kb; break }
    if (!chosen && String(kb.layout).indexOf(",") !== -1) chosen = kb
  }
  if (!chosen) return null
  return {
    codes: String(chosen.layout || ""),
    index: chosen.active_layout_index !== undefined ? chosen.active_layout_index : -1
  }
}

if (typeof module !== "undefined") {
  module.exports = { layoutCodeMap: layoutCodeMap, layoutState: layoutState }
}
