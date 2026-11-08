#!/usr/bin/env bash
# Runs the GdUnit4 suite headless; reports go to reports/.
# Usage: tools/run_tests.sh [-j N] [res://path ...]   (default: res://tests, N: auto)
#   -j N           run the suites in N parallel Godot processes (shards); -j 1 runs one process.
#   TEST_JOBS      same as -j (default: auto = min(12, logical cores / 2), never more than suites).
#   TEST_IMPORT=1  force the project import even when no file changed since the last one.
#   TEST_FIXED_FPS frames per second of simulated time (default 144, see below); 0 = real time.
# Godot binary: $GODOT_BIN, defaulting to the project's standard install path.
# Prints one "Overall Summary" line and exits non-zero on any failure, crash or project script error.
# Details: design/tech/testing.md ("Running tests", "Writing fast tests"), ADR 0084.
set -euo pipefail
cd "$(dirname "$0")/.."
now_ms() { echo $(($(date +%s%N) / 1000000)); }
t_start=$(now_ms)
# stamp FILE: passes stdin through and writes each line, prefixed with its arrival time, to FILE.
if gawk -l time 'BEGIN { gettimeofday() }' 2> /dev/null; then
	stamp() { gawk -l time -v out="$1" '{ printf "%.6f %s\n", gettimeofday(), $0 > out; print; fflush() }'; }
else
	stamp() {
		: > "$1"
		cat
	}
fi

export GODOT_BIN="${GODOT_BIN:-/c/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"
jobs="${TEST_JOBS:-auto}"
targets=()
while [ $# -gt 0 ]; do
	case "$1" in
	-j) jobs="$2"; shift 2 ;;
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

# Keep the editor's filesystem scan (and importer) out of the generated HTML reports.
mkdir -p reports
touch reports/.gdignore

# Import only when a project file changed since the last successful import (or TEST_IMPORT=1):
# a stale global class cache (new class_names after a merge) makes tests fail with
# "Could not find base class" and segfault Godot. The stamp hashes every file's path, size and
# mtime (deletions and renames change it too) plus the Godot binary path.
stamp_file=.godot/run_tests_import.stamp
project_stamp() {
	{
		echo "$GODOT_BIN"
		find . \( -path ./.godot -o -path ./.git -o -path ./reports -o -path ./.venv -o -path ./.claude \
			-o -path ./.api-docs -o -name __pycache__ \) -prune -o -type f -printf '%P %s %T@\n' | LC_ALL=C sort
	} | md5sum | cut -d' ' -f1
}
stamp="$(project_stamp)"
imported=no
if [ "${TEST_IMPORT:-0}" = "1" ] || [ ! -f "$stamp_file" ] || [ "$(cat "$stamp_file")" != "$stamp" ]; then
	rm -f "$stamp_file"
	imported=yes
	if ! "$GODOT_BIN" --headless --path . --import > reports/import.log 2>&1; then
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

# Split the suites (in canonical, sorted order) into `jobs` contiguous slices of about equal time,
# using each suite's last measured time (reports/suite_times.tsv, written after every run; unknown
# suites count 3 s if they use a scene runner, else 0.5 s). Contiguous slices keep every shard's
# suite order a run of the serial order, so a suite only ever follows the suites it follows in a
# serial run: state a suite leaks into the next one (late-freed nodes, viewport-parented effects)
# cannot reach suites it never met before.
times_file=reports/suite_times.tsv
[ -f "$times_file" ] || : > "$times_file"
scene_suites="$(printf '%s\n' "${suites[@]}" | sed 's|^res://||' | grep '\.gd$' | xargs grep -l 'scene_runner(' 2>/dev/null | sed 's|^|res://|' || true)"
declare -a shard_suites
for ((i = 0; i < jobs; i++)); do shard_suites[i]=""; done
while read -r i s; do
	shard_suites[i]+=" -a $s"
done < <(
	printf '%s\n' "${suites[@]}" | awk -v jobs="$jobs" -v times="$times_file" -v scenes="$scene_suites" '
		BEGIN {
			while ((getline line < times) > 0) { split(line, f, "\t"); t[f[1]] = f[2] + 0 }
			n_sc = split(scenes, sc, "\n"); for (k = 1; k <= n_sc; k++) is_scene[sc[k]] = 1
		}
		{ n++; name[n] = $0; w[n] = ($0 in t) ? t[$0] : (($0 in is_scene) ? 3 : 0.5); total += w[n]; if (w[n] > big) big = w[n] }
		function shards_for(cap,   k, load, used) {
			used = 1; load = 0
			for (k = 1; k <= n; k++) { if (load + w[k] > cap && load > 0) { used++; load = 0 } load += w[k] }
			return used
		}
		END {
			lo = big; hi = total
			for (it = 0; it < 60; it++) { mid = (lo + hi) / 2; if (shards_for(mid) <= jobs) hi = mid; else lo = mid }
			shard = 0; load = 0
			for (k = 1; k <= n; k++) {
				if (load + w[k] > hi && load > 0 && shard < jobs - 1) { shard++; load = 0 }
				load += w[k]; print shard, name[k]
			}
		}'
)
# Slices are contiguous, so any unused shards are the last ones.
while [ "$jobs" -gt 1 ] && [ -z "${shard_suites[jobs - 1]}" ]; do jobs=$((jobs - 1)); done

# Each shard is its own Godot process with its own user:// (APPDATA) and report directory, so saves,
# GdUnit temp files and Godot logs never collide (with each other or with other checkouts' runs).
shard_root=reports/shards
rm -rf "$shard_root"
pids=()
fps_args=()
[ "$fixed_fps" != "0" ] && fps_args=(--fixed-fps "$fixed_fps")
t_shards=$(now_ms)
for ((i = 0; i < jobs; i++)); do
	dir="$shard_root/$i"
	mkdir -p "$dir/appdata"
	# Its suites in run order: `tools/run_tests.sh -j 1 $(cat reports/shards/<n>/suites.txt)` replays it.
	echo "${shard_suites[i]}" | tr ' ' '\n' | grep -v -e '^-a$' -e '^$' > "$dir/suites.txt"
	# --remote-debug tcp://127.0.0.1:0 (as addons/gdUnit4/runtest.sh) keeps Godot's interactive CLI
	# debugger from looping on script parse errors: port 0 is never bound.
	# The output goes to output.log as is and, with each line's arrival time, to timed.log (read by
	# tools/test_timing.awk for the timing breakdown).
	(
		set +e
		now_ms > "$dir/start_ms"
		# shellcheck disable=SC2086
		APPDATA="$(cygpath -w "$PWD/$dir/appdata" 2>/dev/null || echo "$PWD/$dir/appdata")" \
			"$GODOT_BIN" --path . --headless "${fps_args[@]}" -s -d --remote-debug tcp://127.0.0.1:0 \
			res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -rd "res://$dir" ${shard_suites[i]} \
			2>&1 | stamp "$dir/timed.log" > "$dir/output.log"
		rc_shard=${PIPESTATUS[0]}
		now_ms > "$dir/end_ms"
		exit "$rc_shard"
	) &
	pids+=($!)
done
trap 'kill "${pids[@]}" 2>/dev/null || true' INT TERM

if [ "$jobs" -eq 1 ]; then
	# One shard: stream its output as it runs.
	tail -n +1 -f "$shard_root/0/output.log" --pid="${pids[0]}" 2>/dev/null || true
fi

rcs=()
for ((i = 0; i < jobs; i++)); do
	rc_i=0
	wait "${pids[i]}" || rc_i=$?
	rcs+=("$rc_i")
done
trap - INT TERM
t_post=$(now_ms)

log=reports/test_output.log
cat "$shard_root"/*/output.log > "$log"
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

# Per-shard results; a shard without an "Overall Summary" line crashed.
rc=0
crashed=0
totals=(0 0 0 0 0 0)
for ((i = 0; i < jobs; i++)); do
	out="$shard_root/$i/output.log"
	summary="$(strip < "$out" | grep -a 'Overall Summary:' | tail -n 1 || true)"
	if [ -z "$summary" ]; then
		echo "FAIL: shard $i crashed (exit ${rcs[i]}, no Overall Summary); last 30 lines of $out:" >&2
		strip < "$out" | tail -n 30 >&2
		crashed=$((crashed + 1))
		[ "$rc" -eq 0 ] && rc=1
		[ "${rcs[i]}" -ne 0 ] && rc="${rcs[i]}"
		continue
	fi
	if [ "$jobs" -gt 1 ]; then
		# Failed tests with their messages (the single shard already streamed them).
		strip < "$out" | awk '/ (FAILED|ERROR)( |$)/ { show = 1 } / (PASSED|STARTED)( |$)/ { show = 0 } show' | head -n 200
		echo "shard $i: ${summary#Overall Summary: } (exit ${rcs[i]})"
	fi
	[ "${rcs[i]}" -ne 0 ] && [ "$rc" -eq 0 ] && rc="${rcs[i]}"
	read -r -a nums <<< "$(echo "$summary" | grep -oE '[0-9]+ (test cases|errors|failures|flaky|skipped|orphans)' | cut -d' ' -f1 | tr '\n' ' ')"
	for k in 0 1 2 3 4 5; do totals[k]=$((totals[k] + ${nums[k]:-0})); done
done

# Remember each suite's time for the next run's shard balancing.
{
	for xml in "$shard_root"/*/report_*/results.xml; do
		[ -f "$xml" ] || continue
		grep -o '<testsuite [^>]*>' "$xml" | sed -nE 's/.*name="([^"]*)" package="([^"]*)".* time="([0-9.]+)".*/res:\/\/\2\/\1.gd\t\3/p'
	done
	[ -f "$times_file" ] && cat "$times_file"
} | awk -F'\t' '!seen[$1]++' > "$times_file.tmp" && mv "$times_file.tmp" "$times_file"

# GdUnit4 can pass while Godot prints script errors from project code: fail on those.
# Offending = SCRIPT ERROR:/ERROR: lines whose block (the line plus its indented "at:" line) mentions
# a res:// path outside res://addons/, minus tools/test_error_allowlist.txt regexes.
allow="tools/test_error_allowlist.txt"
patterns="$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$allow" 2>/dev/null | tr -d '\r' || true)"
tr -d '\r' < "$log" | awk '
	/^(SCRIPT )?ERROR:/ { if (blk != "") print blk; blk = $0; next }
	/^[[:space:]]+at:/ && blk != "" { blk = blk " " $0; next }
	{ if (blk != "") print blk; blk = "" }
	END { if (blk != "") print blk }
' | grep -E 'res://' | grep -vE 'res://addons/' > reports/.project_errors.tmp || true
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
# one sets the pace; tools/test_timing.awk splits each into startup, scan, suites, between suites
# and reports/shutdown) and after them (result merge, error scan).
t_end=$(now_ms)
secs() { awk -v ms="$1" 'BEGIN { printf "%.1fs", ms / 1000 }'; }
slowest=0
slowest_ms=0
for ((i = 0; i < jobs; i++)); do
	dir="$shard_root/$i"
	start_i="$(cat "$dir/start_ms" 2>/dev/null || echo "$t_shards")"
	end_i="$(cat "$dir/end_ms" 2>/dev/null || echo "$t_post")"
	gawk -v launch="$start_i" -v end="$end_i" -v ms=1 -f tools/test_timing.awk "$dir/timed.log" \
		> "$dir/timing.txt" 2> /dev/null || true
	ms=$((end_i - t_shards))
	if [ "$ms" -gt "$slowest_ms" ]; then
		slowest=$i
		slowest_ms=$ms
	fi
done
echo
echo "Timing: total $(secs $((t_end - t_start))) = before shards $(secs $((t_shards - t_start))) (import: $imported)" \
	"+ shards $(secs $((t_post - t_shards))) + after $(secs $((t_end - t_post)))"
echo "  slowest shard $slowest ($(secs "$slowest_ms")): $(cat "$shard_root/$slowest/timing.txt" 2> /dev/null)"
echo "Overall Summary: ${totals[0]} test cases | ${totals[1]} errors | ${totals[2]} failures | ${totals[3]} flaky | ${totals[4]} skipped | ${totals[5]} orphans | $crashed crashed shard(s) | ${#suites[@]} suites in $jobs shard(s), $(secs $((t_end - t_start))) | exit $rc"
echo "Reports: reports/shards/<n>/report_1/ (index.html, results.xml), timing.txt; full output: $log"
exit "$rc"
