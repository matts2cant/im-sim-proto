# Where one GdUnit process spent its time, from its timestamped output ("<epoch s.us> <line>" per
# line, as tools/run_tests.sh writes reports/shards/<n>/timed.log).
# Usage: gawk -v launch=<epoch s> -v end=<epoch s> -f tools/test_timing.awk timed.log
#   launch, end: when the process started and exited (default: first and last line); with -v ms=1
#   they are in milliseconds.
# Prints one line with seconds that add up to end - launch:
#   startup  process start -> GdUnit banner (engine, project and autoload start-up)
#   scan     -> first "Run Test Suite" (GdUnit init; loads each suite script with its preloads and parses it)
#   suites   "Run Test Suite" -> "Statistics" of each suite, split into test bodies (STARTED ->
#            PASSED/FAILED) and around tests (before/after hooks, scene runner set-up and free,
#            GdUnit's orphan and error checks)
#   between  "Statistics" -> next "Run Test Suite" (suite load and instantiation, report writes)
#   tail     last "Statistics" -> process exit (summary, HTML/XML reports, shutdown)
{
	t = $1 + 0
	line = substr($0, index($0, " ") + 1)
	gsub(/\x1b\[[0-9;]*m/, "", line)
	sub(/\r$/, "", line)
	if (first_t == "") first_t = t
	last_t = t
}
scan0 == "" && line ~ /GdUnit4 Comandline Tool/ { scan0 = t }
line ~ /^Run Test Suite: / {
	if (run0 == "") run0 = t
	if (stats_t != "") between += t - stats_t
	suite_t = t
	in_suite = 1
	test_t = ""
	next
}
in_suite && line ~ / STARTED$/ { test_t = t; next }
in_suite && test_t != "" && line !~ /^Statistics:/ && line ~ / (PASSED|FAILED|ERROR|FLAKY|SKIPPED)( |$)/ {
	tests += t - test_t
	test_t = ""
	next
}
in_suite && line ~ /^Statistics: / {
	suites += t - suite_t
	n_suites++
	stats_t = t
	in_suite = 0
	next
}
END {
	if (ms) {
		launch /= 1000
		end /= 1000
	}
	if (launch == "") launch = first_t
	if (end == "") end = last_t
	if (run0 == "") run0 = end
	if (scan0 == "") scan0 = run0
	tail_s = (stats_t != "" ? end - stats_t : end - run0)
	printf "startup %.1fs + scan %.1fs + %d suites %.1fs (test bodies %.1fs, around tests %.1fs) + between suites %.1fs + reports/shutdown %.1fs\n",
		scan0 - launch, run0 - scan0, n_suites, suites, tests, suites - tests, between, tail_s
}
