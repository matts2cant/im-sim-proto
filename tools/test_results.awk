# Merges the results of the shard processes of one tools/run_tests.sh run, in one pass (every extra
# process costs ~50 ms in Git Bash).
# Usage: gawk -v rcs="<exit code of shard 0> <of shard 1> ..." -v show=1 -v totals_out=FILE \
#          -f tools/test_results.awk reports/shards/0/output.log reports/shards/1/output.log ...
#   show=1: print each shard's failed tests with their messages and its summary (a single shard
#   already streamed its output, so the runner passes show=0 then).
# Prints the failures and shard lines, writes the last 30 lines of every shard without an
# "Overall Summary" (it crashed: also an empty or missing output) to stderr, and writes one line
# to totals_out:
#   totals <test cases> <errors> <failures> <flaky> <skipped> <orphans> <crashed shards> <exit code>
# where the exit code is the first non-zero shard exit code, or 1 for a crash that exited with 0.
BEGIN {
	n_rc = split(rcs, rc, " ")
	split("test cases|errors|failures|flaky|skipped|orphans", names, "|")
}
{
	s = ARGIND - 1
	line = $0
	gsub(/\x1b\[[0-9;]*m/, "", line)
	sub(/\r$/, "", line)
	tail[s, lines[s] % 30] = line
	lines[s]++
	if (line ~ /Overall Summary:/) summary[s] = line
	if (show) {
		if (line ~ / (FAILED|ERROR)( |$)/) failing = 1
		else if (line ~ / (PASSED|STARTED)( |$)/) failing = 0
		if (failing && shown < 200) { print line; shown++ }
	}
}
END {
	code = 0
	for (s = 0; s < n_rc; s++) {
		if (summary[s] == "") {
			crashed++
			printf "FAIL: shard %d crashed (exit %s, no Overall Summary); last 30 lines of %s:\n", s, rc[s + 1], ARGV[s + 1] > "/dev/stderr"
			n = (lines[s] < 30) ? lines[s] : 30
			for (i = lines[s] - n; i < lines[s]; i++) print tail[s, i % 30] > "/dev/stderr"
			if (code == 0) code = (rc[s + 1] != 0) ? rc[s + 1] : 1
			continue
		}
		if (show) printf "shard %d: %s (exit %s)\n", s, substr(summary[s], index(summary[s], ":") + 2), rc[s + 1]
		if (rc[s + 1] != 0 && code == 0) code = rc[s + 1]
		for (k = 1; k <= 6; k++) {
			if (match(summary[s], "[0-9]+ " names[k])) totals[k] += substr(summary[s], RSTART, RLENGTH) + 0
		}
	}
	line = "totals"
	for (k = 1; k <= 6; k++) line = line " " (totals[k] + 0)
	print line, crashed + 0, code > totals_out
}
