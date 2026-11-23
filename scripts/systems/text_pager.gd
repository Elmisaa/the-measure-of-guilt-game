class_name TextPager
extends RefCounted


static func pages(text: String, max_chars: int = 80) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if text.length() <= max_chars:
		out.append(text)
		return out
	var re: RegEx = RegEx.new()
	re.compile("[^.!?…]+[.!?…]+[\"»”]*\\s*|[^.!?…]+$")
	var cur: String = ""
	for m: RegExMatch in re.search_all(text):
		var s: String = m.get_string()
		if cur.is_empty():
			cur = s
		elif (cur + s).strip_edges().length() <= max_chars:
			cur += s
		else:
			out.append(cur.strip_edges())
			cur = s
	if not cur.strip_edges().is_empty():
		out.append(cur.strip_edges())
	return out
