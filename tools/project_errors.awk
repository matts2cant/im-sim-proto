# Prints one line per error block in Godot output (CR already stripped) caused by project code.
# Used by tools/run_tests.sh. A block is a "SCRIPT ERROR:" or "ERROR:" line, its indented "at:" line
# and, when Godot prints one, its "GDScript backtrace" with "[n] func (path:line)" frames.
# The block counts when its error or "at:" line names a res:// path outside res://addons/ (a script
# error in project code) or when a backtrace frame does (an engine error, e.g. at: scene/...cpp,
# raised by a call from project code). Output: the error and "at:" lines joined by a space, then
# " | backtrace: " and the project frames joined by "; " when there are any.

# True when s mentions a res:// path outside res://addons/.
function project_path(s,   rest, p) {
	rest = s
	while ((p = index(rest, "res://")) > 0) {
		rest = substr(rest, p + 6)
		if (index(rest, "addons/") != 1) return 1
	}
	return 0
}

function flush() {
	if (blk != "" && (project_path(blk) || frames != "")) {
		print blk (frames != "" ? " | backtrace: " frames : "")
	}
	blk = ""; frames = ""; in_bt = 0
}

/^(SCRIPT )?ERROR:/ { flush(); blk = $0; next }
blk != "" && !in_bt && /^[[:space:]]+at:/ { blk = blk " " $0; next }
blk != "" && /^[[:space:]]+GDScript backtrace/ { in_bt = 1; next }
in_bt && /^[[:space:]]+\[[0-9]+\] / {
	if (project_path($0)) {
		f = $0; sub(/^[[:space:]]+/, "", f)
		frames = frames (frames != "" ? "; " : "") f
	}
	next
}
{ flush() }
END { flush() }
