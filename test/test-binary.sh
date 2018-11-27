#!/bin/sh

set -e

nohup ./_build/default/bin/main.exe -r test/rules.sexp -vv </dev/null >/dev/null 2>/dev/null &

pid=$!

function cleanup {
  kill $pid
}
trap cleanup EXIT

function assert_expected {
    actual=`mktemp`
    expected=`mktemp`
    printf "$1\n" | nc localhost 30303 >"$actual"
    printf "$2" >"$expected"
    if ! diff "$actual" "$expected"
    then
        return 1
    else
        rm -f "$actual" "$expected"
    fi
}

sleep 2

assert_expected "health" "200 ok\n"

assert_expected "get abcd" "200 bbcd\n"
assert_expected "get wxyz" "200 wxyz\n"
assert_expected "get aazz" "500 not found\n"

assert_expected "get ab0011856cd" "200 bbNUMBERScd\n"
assert_expected "get ab0cd1" "200 bbNUMBERScd1\n"

# switched off connection keep-alive because it does not work well with postfix
# assert_expected "get abcd\nget wxyz" "200 bbcd\n200 wxyz\n"
