#! /usr/bin/env tclsh

set haveReg 0
catch {
	package require registry
	set haveReg 1
}

if {!$haveReg} {
	exit 0
}

catch {
	registry delete HKEY_CURRENT_USER test
}

set value "TestValue"
registry set HKEY_CURRENT_USER test $value multi_sz

set check [registry get HKEY_CURRENT_USER test]

if {$value != $check} {
	puts "Expected: $value"
	puts "Got:      $check"

	exit 1
}

exit 0
