# Where the shard processes of one tools/run_tests.sh run spent their time, from GdUnit's XML reports.
# Usage: gawk -v times_out=NEW -v times_old=OLD -f tools/test_timing.awk shards.tsv
#   shards.tsv: one line per shard: <shard> <start ms> <end ms> <results.xml path or "-"> (tab-separated)
# Prints, per shard with a report, one line
#   timing <shard> <wall ms> <text>
# where the text splits the wall time into the suites (GdUnit's suite times, split into test cases and
# the rest: before()/after(), scene runners, orphan checks) and everything outside the suites
# (engine start-up, GdUnit's scan of the suite scripts, loading each suite, reports, shutdown); then
#   slowest <shard> <wall ms> <text>      (the same line for the shard that took longest)
#   overhead <per shard s> <per suite s> <shards fitted>
# from a least-squares fit of (wall - suite times) = per shard + per suite x suites over the shards.
# times_out gets "<res://suite path>\t<seconds>" per suite: its GdUnit time plus the per-suite
# overhead, i.e. its share of a shard's wall time (tools/run_tests.sh balances shards on it),
# followed by the suites of times_old this run did not measure.
BEGIN { FS = "\t" }
function attr(s, name) {
	if (match(s, " " name "=\"[^\"]*\"")) return substr(s, RSTART + length(name) + 3, RLENGTH - length(name) - 4)
	return ""
}
{
	shard = $1
	wall = ($3 - $2) / 1000.0
	xml = $4
	if (xml == "-" || xml == "") next
	n = 0
	suite_s = 0
	case_s = 0
	while ((getline line < xml) > 0) {
		if (line ~ /<testsuite /) {
			path = "res://" attr(line, "package") "/" attr(line, "name") ".gd"
			t = attr(line, "time") + 0
			suite_time[path] = t
			suite_s += t
			n++
		} else if (line ~ /<testcase /) {
			case_s += attr(line, "time") + 0
		}
	}
	close(xml)
	if (n == 0) next
	k++
	x[k] = n
	y[k] = wall - suite_s
	text = sprintf("%d suites %.1fs (test cases %.1fs, suite hooks and scene set-up %.1fs) + start-up, scan, suite loading and shutdown %.1fs",
		n, suite_s, case_s, suite_s - case_s, wall - suite_s)
	printf "timing %s %d %s\n", shard, wall * 1000, text
	if (wall > slowest_wall) { slowest_wall = wall; slowest = sprintf("slowest %s %d %s", shard, wall * 1000, text) }
}
END {
	# Fit y = a + b x; with fewer than 3 shards or equal suite counts, assume 0.1 s per suite.
	b = 0.1
	if (k >= 3) {
		for (i = 1; i <= k; i++) { mx += x[i] / k; my += y[i] / k }
		for (i = 1; i <= k; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) ^ 2 }
		if (sxx > 0) b = sxy / sxx
	}
	if (b < 0) b = 0
	if (b > 2) b = 2
	a = 0
	for (i = 1; i <= k; i++) a += (y[i] - b * x[i]) / k
	if (slowest != "") print slowest
	printf "overhead %.1f %.2f %d\n", a, b, k
	if (times_out != "" && k > 0) {
		for (p in suite_time) printf "%s\t%.3f\n", p, suite_time[p] + b > times_out
		if (times_old != "") {
			while ((getline line < times_old) > 0) {
				split(line, f, "\t")
				if (!(f[1] in suite_time) && f[1] != "") print line > times_out
			}
			close(times_old)
		}
		close(times_out)
	}
}
