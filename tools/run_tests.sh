#!/usr/bin/env bash
# Runs the GdUnit4 suite headless; reports go to reports/.
# Usage: tools/run_tests.sh [-j N] [--dry-run] [res://path ...]   (default: res://tests, N: auto)
#   -j N           run the suites in N parallel Godot processes (shards); -j 1 runs one process.
#   --dry-run      print the shard split (each suite's weight, * = estimated) and exit: no import, no run.
#   TEST_JOBS      same as -j (default: auto = min(12, logical cores / 2), never more than suites).
#   TEST_IMPORT=1  force the project import even when no file changed since the last one.
#   TEST_FIXED_FPS frames per second of simulated time (default 144, see below); 0 = real time.
# Godot binary: $GODOT_BIN, defaulting to the project's standard install path.
# Prints one "Overall Summary" line and exits non-zero on any failure, crash or project script error.
# Details: design/tech/testing.md ("Running tests", "Writing fast tests"), ADR 0084.
set -euo pipefail
cd "$(dirname "$0")/.."
# Milliseconds since the epoch, without forking a process (each fork costs ~50 ms in Git Bash):
# stamp_ms VAR stores them in VAR, now_ms prints them.
stamp_ms() {
	local _ms="${EPOCHREALTIME/[.,]/}"
	printf -v "$1" '%d' $((_ms / 1000))
}
now_ms() {
	local t
	stamp_ms t
	echo "$t"
}
stamp_ms t_start

export GODOT_BIN="${GODOT_BIN:-/c/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"
jobs="${TEST_JOBS:-auto}"
dry_run=0
targets=()
while [ $# -gt 0 ]; do
	case "$1" in
	-j) jobs="$2"; shift 2 ;;
	--dry-run) dry_run=1; shift ;;
	-j*) jobs="${1#-j}"; shift ;;
	*) targets+=("$1"); shift ;;
	esac
done
[ ${#targets[@]} -eq 0 ] && targets=("res://tests")

# --fixed-fps decouples simulated time from the wall clock: every frame advances exactly 1/FPS s
# (times Engine.time_scale), physics still steps at physics_ticks_per_second (delta 1/60 with any
# runner time factor) and Godot no longer sleeps between headless frames, so physics-frame waits
# run as fast as the CPU allows. 144 keeps the process/physics frame ratio of a real-time headless
# run (Godot sleeps ~6.9 ms per headless frame): ~2.4 process frames per physics frame at time
# factor 1, ~0.27 at time factor 9.
fixed_fps="${TEST_FIXED_FPS:-144}"

# No Godot log file (user://logs/godot.log) during test runs: the runner already saves every line
# (reports/) and GdUnit collects errors through OS.add_logger. Windows refuses the reserved name
# NUL, so Godot prints "ERROR: Failed to open log file for writing: NUL" (and a WARNING) at start-up
# (no res:// path: the error scan ignores them) and logs to stdout only.
# Test runs only: the game and the editor keep their log file (project.godot is unchanged).
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) log_args=(--log-file NUL) ;;
*) log_args=(--log-file /dev/null) ;;
esac

# Keep the editor's filesystem scan (and importer) out of the generated HTML reports.
mkdir -p reports
touch reports/.gdignore

# Import only when something the import depends on changed since the last successful import (or
# TEST_IMPORT=1): a stale global class cache (new class_names after a merge) makes tests fail with
# "Could not find base class" and segfault Godot. The stamp hashes every file's path (new, deleted
# and renamed files change it), the size and mtime of every file except scripts and Markdown (never
# imported), and for scripts only the lines the global class cache is built from (class_name,
# extends, @tool, @abstract, @icon): editing a script's body, the usual edit while iterating on
# tests, needs no import.
stamp_file=.godot/run_tests_import.stamp
project_stamp() {
	local prune=(\( -path ./.godot -o -path ./.git -o -path ./reports -o -path ./.venv -o -path ./.claude
		-o -path ./.api-docs -o -name __pycache__ \) -prune -o)
	{
		echo "$GODOT_BIN"
		find . "${prune[@]}" -type f ! -name '*.gd' ! -name '*.md' -printf '%P %s %T@\n'
		find . "${prune[@]}" -type f \( -name '*.gd' -o -name '*.md' \) -printf '%P\n'
		find . "${prune[@]}" -type f -name '*.gd' -print0 |
			xargs -0 grep -HE '^[[:space:]]*(class_name|extends|@tool|@abstract|@icon)' || true
	} | LC_ALL=C sort | md5sum | cut -d' ' -f1
}
stamp="$(project_stamp)"
imported=no
if [ "$dry_run" = "1" ]; then
	imported=skipped
elif [ "${TEST_IMPORT:-0}" = "1" ] || [ ! -f "$stamp_file" ] || [ "$(cat "$stamp_file")" != "$stamp" ]; then
	rm -f "$stamp_file"
	imported=yes
	if ! "$GODOT_BIN" --headless --path . "${log_args[@]}" --import > reports/import.log 2>&1; then
		echo "Godot import failed; last 20 lines of reports/import.log:" >&2
		tail -n 20 reports/import.log >&2
		exit 1
	fi
	# The import itself can touch files (uid sidecars): stamp what is there afterwards.
	project_stamp > "$stamp_file"
else
	echo "Project unchanged since the last import: skipping it (TEST_IMPORT=1 forces it)."
fi

# Expand the targets into suite files so they can be spread over shards, in GdUnit's own order for a
# directory (it lists folders like NTFS does: case-insensitive, so `skills_test` before `skill_table_test`).
suites=()
for t in "${targets[@]}"; do
	p="${t#res://}"
	if [ -d "$p" ]; then
		while IFS= read -r f; do suites+=("res://$f"); done < <(find "$p" -name '*_test.gd' | LC_ALL=C sort -f)
	else
		suites+=("$t")
	fi
done
if [ ${#suites[@]} -eq 0 ]; then
	echo "No test suites found in: ${targets[*]}" >&2
	exit 1
fi

if [ "$jobs" = "auto" ]; then
	cores="$(nproc 2>/dev/null || echo 4)"
	jobs=$((cores / 2))
	[ "$jobs" -gt 12 ] && jobs=12
fi
[ "$jobs" -lt 1 ] && jobs=1
[ "$jobs" -gt ${#suites[@]} ] && jobs=${#suites[@]}

# Split the suites into `jobs` shards of about equal wall time, using each suite's share of a shard's
# wall time in earlier runs (reports/suite_times.tsv, updated after every run by
# tools/test_timing.awk: GdUnit's suite time plus the measured per-suite overhead): longest first,
# each suite to the least loaded shard (LPT), so the slowest shard ends close to the others. A suite
# with no recorded time counts as the median recorded time of the suites of its kind (scene runner or
# not) under its own folder, else under the nearest ancestor folder that has one, else of its kind in
# this run, else 3 s / 0.5 s; unmeasured suites are dealt out first, one per shard in turn, so new
# suites added side by side (a milestone's suites in one folder) never share a shard on a guess.
# Each shard runs its suites in serial (sorted) order, so a shard replays exactly from its
# suites.txt; a suite can follow other suites than in a serial run, so a suite that leaks state
# (late-freed nodes, viewport-parented effects, engine settings) must be fixed at the source
# (design/tech/testing.md "Writing fast tests").
times_file=reports/suite_times.tsv
[ -f "$times_file" ] || : > "$times_file"
scene_suites="$(printf '%s\n' "${suites[@]}" | sed 's|^res://||' | grep '\.gd$' | xargs grep -l 'scene_runner(' 2>/dev/null | sed 's|^|res://|' || true)"
declare -a shard_suites
for ((i = 0; i < jobs; i++)); do shard_suites[i]=""; done
plan=""
while read -r i s wt est; do
	shard_suites[i]+=" -a $s"
	plan+="$i $wt$est $s"$'\n'
done < <(
	printf '%s\n' "${suites[@]}" | awk -v jobs="$jobs" -v times="$times_file" -v scenes="$scene_suites" '
		BEGIN {
			while ((getline line < times) > 0) { split(line, f, "\t"); t[f[1]] = f[2] + 0 }
			n_sc = split(scenes, sc, "\n"); for (k = 1; k <= n_sc; k++) is_scene[sc[k]] = 1
		}
		function median(arr, cnt,   i, j, tmp) {
			for (i = 2; i <= cnt; i++) for (j = i; j > 1 && arr[j - 1] > arr[j]; j--) { tmp = arr[j]; arr[j] = arr[j - 1]; arr[j - 1] = tmp }
			return (cnt % 2) ? arr[(cnt + 1) / 2] : (arr[cnt / 2] + arr[cnt / 2 + 1]) / 2
		}
		{
			n++; name[n] = $0; kind[n] = ($0 in is_scene) ? 1 : 0
			if ($0 in t) { w[n] = t[$0]; known[kind[n], ++cnt[kind[n]]] = t[$0] }
		}
		# Estimate for a suite with no recorded time: the median of the recorded suites of its kind under
		# its own folder (subfolders included), else under the parent folder and so on up, else of its
		# kind in this run, else the constant.
		function estimate(k,   d, j, c, v) {
			d = name[k]
			while (sub(/\/[^\/]*$/, "", d) && index(d, "res://") == 1 && d != "res:/") {
				c = 0
				for (j = 1; j <= n; j++)
					if ((name[j] in t) && kind[j] == kind[k] && index(name[j], d "/") == 1) v[++c] = t[name[j]]
				if (c > 0) return median(v, c)
			}
			return fallback[kind[k]]
		}
		# Sorts the suite indices sel[1..cnt] by weight, heaviest first (ties: serial order).
		function by_weight(sel, cnt,   i, j, tmp) {
			for (i = 2; i <= cnt; i++)
				for (j = i; j > 1 && (w[sel[j - 1]] < w[sel[j]] || (w[sel[j - 1]] == w[sel[j]] && sel[j - 1] > sel[j])); j--) {
					tmp = sel[j]; sel[j] = sel[j - 1]; sel[j - 1] = tmp
				}
		}
		# The least loaded shard (ties: the lowest index); with `spread`, the one holding the fewest
		# unmeasured suites first.
		function lightest(spread,   s, best) {
			best = 0
			for (s = 1; s < jobs; s++) {
				if (spread && unk[s] != unk[best]) { if (unk[s] < unk[best]) best = s; continue }
				if (load[s] < load[best]) best = s
			}
			return best
		}
		END {
			for (kd = 0; kd <= 1; kd++) {
				fallback[kd] = kd ? 3 : 0.5
				if (cnt[kd] > 0) { for (i = 1; i <= cnt[kd]; i++) vals[i] = known[kd, i]; fallback[kd] = median(vals, cnt[kd]) }
			}
			n_unk = 0; n_known = 0
			for (k = 1; k <= n; k++) {
				if (!(name[k] in t)) { w[k] = estimate(k); unk_sel[++n_unk] = k } else known_sel[++n_known] = k
			}
			for (s = 0; s < jobs; s++) { load[s] = 0; unk[s] = 0 }
			# Unmeasured suites first, heaviest guess first, each to the shard holding the fewest of them
			# (new suites of one milestone never share a shard on a guess); then the measured ones, longest
			# first, each to the least loaded shard (LPT: no shard ends far after the others).
			by_weight(unk_sel, n_unk)
			for (i = 1; i <= n_unk; i++) { k = unk_sel[i]; s = lightest(1); shard_of[k] = s; load[s] += w[k]; unk[s]++ }
			by_weight(known_sel, n_known)
			for (i = 1; i <= n_known; i++) { k = known_sel[i]; s = lightest(0); shard_of[k] = s; load[s] += w[k] }
			# Printed in serial order, so each shard runs its suites in serial order.
			for (k = 1; k <= n; k++) print shard_of[k], name[k], sprintf("%.1f", w[k]), ((name[k] in t) ? "" : "*")
		}'
)
# Every shard gets a suite while there are at least as many suites as shards (jobs is capped above);
# drop empty trailing shards anyway.
while [ "$jobs" -gt 1 ] && [ -z "${shard_suites[jobs - 1]}" ]; do jobs=$((jobs - 1)); done
if [ "$dry_run" = "1" ]; then
	# One block per shard: its total weight, then each suite's weight in seconds (* = estimated).
	printf '%s' "$plan" | awk '
		{ tot[$1] += $2 + 0; line[$1] = line[$1] sprintf("    %7ss  %s\n", $2, $3); if ($1 > last) last = $1 }
		END { for (i = 0; i <= last; i++) printf "shard %d: %.1fs\n%s", i, tot[i], line[i] }'
	echo "${#suites[@]} suites in $jobs shard(s), weights from $times_file (* = no recorded time: estimated)"
	exit 0
fi

# Each shard is its own Godot process with its own user:// (APPDATA) and report directory, so saves,
# GdUnit temp files and Godot logs never collide (with each other or with other checkouts' runs).
shard_root=reports/shards
rm -rf "$shard_root"
pids=()
fps_args=()
[ "$fixed_fps" != "0" ] && fps_args=(--fixed-fps "$fixed_fps")
stamp_ms t_shards
for ((i = 0; i < jobs; i++)); do
	dir="$shard_root/$i"
	mkdir -p "$dir/appdata"
	# Its suites in run order: `tools/run_tests.sh -j 1 $(cat reports/shards/<n>/suites.txt)` replays it.
	echo "${shard_suites[i]}" | tr ' ' '\n' | grep -v -e '^-a$' -e '^$' > "$dir/suites.txt"
	: > "$dir/output.log"
	# --remote-debug tcp://127.0.0.1:0 (as addons/gdUnit4/runtest.sh) keeps Godot's interactive CLI
	# debugger from looping on script parse errors: port 0 is never bound.
	# The output goes straight to a file, never through a pipe: Godot flushes stdout on every print,
	# and with stdout on a pipe read by an MSYS program (cat, gawk, tee) the flushes stalled the
	# process: a pure-logic test took 30-90 ms instead of 9 ms (see ADR 0084).
	(
		set +e
		now_ms > "$dir/start_ms"
		# shellcheck disable=SC2086
		APPDATA="$(cygpath -w "$PWD/$dir/appdata" 2>/dev/null || echo "$PWD/$dir/appdata")" \
			"$GODOT_BIN" --path . --headless "${log_args[@]}" "${fps_args[@]}" -s -d --remote-debug tcp://127.0.0.1:0 \
			res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -rd "res://$dir" ${shard_suites[i]} \
			> "$dir/output.log" 2>&1
		rc_shard=$?
		now_ms > "$dir/end_ms"
		exit "$rc_shard"
	) &
	pids+=($!)
done
trap 'kill "${pids[@]}" 2>/dev/null || true' INT TERM

if [ "$jobs" -eq 1 ]; then
	# One shard: stream its output as it runs (tail polls the file; Godot never writes to a pipe).
	# GdUnit's own summary is renamed so the runner's line below stays the only "Overall Summary".
	tail -n +1 -s 0.2 -f "$shard_root/0/output.log" --pid="${pids[0]}" 2>/dev/null |
		sed -u 's/Overall Summary:/Shard summary:/' || true
fi

rcs=()
for ((i = 0; i < jobs; i++)); do
	rc_i=0
	wait "${pids[i]}" || rc_i=$?
	rcs+=("$rc_i")
done
trap - INT TERM
stamp_ms t_post

log=reports/test_output.log
cat "$shard_root"/*/output.log > "$log"

# Per-shard results, merged in one gawk pass; a shard without an "Overall Summary" line crashed.
outputs=()
for ((i = 0; i < jobs; i++)); do outputs+=("$shard_root/$i/output.log"); done
show=1
[ "$jobs" -eq 1 ] && show=0
gawk -v rcs="${rcs[*]}" -v show="$show" -v totals_out="$shard_root/totals.txt" -f tools/test_results.awk "${outputs[@]}"
read -r _ t_cases t_errors t_failures t_flaky t_skipped t_orphans crashed rc < "$shard_root/totals.txt"
# A flaky test passed only on a retry: GdUnit's flaky check must stay off (no retry-until-green).
if [ "$t_flaky" -gt 0 ]; then
	echo "FAIL: $t_flaky flaky test(s): GdUnit retried them (gdunit4 settings flaky_check_enable must stay off)" >&2
	[ "$rc" -eq 0 ] && rc=1
fi

# GdUnit4 can pass while Godot prints errors caused by project code: fail on those.
# Offending = SCRIPT ERROR:/ERROR: blocks whose error or "at:" line names a res:// path outside
# res://addons/ (script errors), or whose GDScript backtrace has a frame there (engine errors raised
# by project code, e.g. "at: ... (scene/...cpp:123)"), minus tools/test_error_allowlist.txt regexes.
# One line per block (tools/project_errors.awk): error and "at:" line, then " | backtrace: " frames.
allow="tools/test_error_allowlist.txt"
patterns="$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$allow" 2>/dev/null | tr -d '\r' || true)"
tr -d '\r' < "$log" | awk -f tools/project_errors.awk > reports/.project_errors.tmp || true
if [ -n "$patterns" ]; then
	grep -vEf <(printf '%s\n' "$patterns") reports/.project_errors.tmp > reports/project_errors.log || true
else
	cp reports/.project_errors.tmp reports/project_errors.log
fi
rm -f reports/.project_errors.tmp
if [ -s reports/project_errors.log ]; then
	echo "FAIL: script errors from project code in test output:" >&2
	cat reports/project_errors.log >&2
	[ "$rc" -eq 0 ] && rc=1
fi


# Where the time went: before the shards (import check, import), the shard processes (the slowest
# one sets the pace; tools/test_timing.awk splits each into its suites and the rest) and after them
# (result merge, error scan). The same pass records each suite's share of the wall time for the
# next run's balancing (crashed shards have no report and record nothing).
secs() { printf '%d.%ds' $(($1 / 1000)) $(($1 % 1000 / 100)); }
for ((i = 0; i < jobs; i++)); do
	dir="$shard_root/$i"
	xmls=("$dir"/report_*/results.xml)
	xml="${xmls[${#xmls[@]} - 1]}"
	[ -f "$xml" ] || xml=-
	start_i="$t_shards"
	end_i="$t_post"
	[ -s "$dir/start_ms" ] && start_i="$(< "$dir/start_ms")"
	[ -s "$dir/end_ms" ] && end_i="$(< "$dir/end_ms")"
	printf '%s\t%s\t%s\t%s\n' "$i" "$start_i" "$end_i" "$xml"
done > "$shard_root/shards.tsv"
gawk -v times_out="$times_file.new" -v times_old="$times_file" -f tools/test_timing.awk "$shard_root/shards.tsv" \
	> "$shard_root/timing.txt" 2> /dev/null || true
[ -s "$times_file.new" ] && mv "$times_file.new" "$times_file"
slowest=""
overhead=""
load=""
while read -r kind a b c rest; do
	case "$kind" in
	slowest) slowest="slowest shard $a ($(secs "$b")): $c $rest" ;;
	overhead) overhead="fit over the shards: start-up, scan and shutdown ~${a}s per shard + ~${b}s per suite" ;;
	load)
		if [ "$c" -gt 0 ]; then
			read -r new_n new_s <<< "$rest"
			load="$(awk -v now="$a" -v old="$b" -v n="$c" -v nn="$new_n" -v ns="$new_s" 'BEGIN {
				printf "suite time: %d suites %.1fs (last run %.1fs, %+.0f%%); %d new suites %.1fs", n, now, old, (old > 0 ? (now - old) * 100 / old : 0), nn, ns }')"
		fi
		;;
	esac
done < "$shard_root/timing.txt"
stamp_ms t_end
echo
echo "Timing: total $(secs $((t_end - t_start))) = before shards $(secs $((t_shards - t_start))) (import: $imported)" \
	"+ shards $(secs $((t_post - t_shards))) + after $(secs $((t_end - t_post)))"
[ -n "$slowest" ] && echo "  $slowest"
[ -n "$overhead" ] && echo "  $overhead"
[ -n "$load" ] && echo "  $load"
echo "Overall Summary: $t_cases test cases | $t_errors errors | $t_failures failures | $t_flaky flaky | $t_skipped skipped | $t_orphans orphans | $crashed crashed shard(s) | ${#suites[@]} suites in $jobs shard(s), $(secs $((t_end - t_start))) | exit $rc"
echo "Reports: reports/shards/<n>/ (output.log, suites.txt, report_1/index.html and results.xml); all output: $log"
exit "$rc"
