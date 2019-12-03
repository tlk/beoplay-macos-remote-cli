#!/bin/bash

total=0
passed=0
failed=0

echo "======================================================"
echo "=  Running integration tests" 
echo "======================================================"

alias beoplay-cli=../../.build/debug/beoplay-cli
export BEOPLAY_NAME="IntegrationTestDevice"

for integrationTest in *.test; do
	(beoplay-cli emulator "$BEOPLAY_NAME" 2>&1 >/dev/null) &

	output=$(./$integrationTest 2>&1)
	testResult=$?

	kill $(jobs -rp)
	wait $(jobs -rp) 2>/dev/null

	if [ "$testResult" == "0" ]; then
		echo "=  PASS: $integrationTest"
		passed=$(($passed+1))
	else
		echo "=  FAIL: $integrationTest"
		echo "$output"
		echo ""
		failed=$(($failed+1))
	fi

	total=$(($total+1))
done

echo "======================================================"

if [ "$failed" == "0" ]; then
	echo "=  PASSED: All test cases completed successfully."
else
	echo "=  FAILED: Not all test cases completed successfully."
fi

echo "======================================================"
echo "=  Failed: $failed"
echo "=  Passed: $passed"
echo "=  Total:  $total"
echo "======================================================"

exit $failed
