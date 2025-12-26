chai = require "chai"
execa = require "execa"
{ resolve } = require "node:path"
bin = resolve "bin"
{ expect } = chai


###################
# Helper function #
###################
# [PURPOSE] Helper function to execute a command and return the exit code
executeCommandAndGetExitCode = (commandArguments ###: Array<string> ###) ###: number ### ->
	argumentsList = [bin, ...commandArguments]
	result = execa.sync("node", argumentsList)

	if result.status isnt 0
		result.status
	else
		0


#########
# Tests #
#########
suite "Tests for exit codes", ->

	###
	[TEST] Run foreach-cli with a subcommand that exits with the exit code 0.

	[EXPECTED_BEHAVIOR] foreach-cli should return exit code 0.
	###
	test "1. Test foreach-cli exit code if a subcommand exits with the exit code 0", ->
		commandArguments = [
			"--execute", "npx shx echo Exit code is zero!"
			"--glob", "test/samples/stylus/**/personal-stylus.styl"
		]
		expect(executeCommandAndGetExitCode(commandArguments)).to.equal(0)

	###
	[TEST] Run foreach-cli with a non-existent subcommand.

	[EXPECTED_BEHAVIOR] foreach-cli should return the exit code 4,
	because a subcommand exits with a non-zero exit code.
	###
	test "2. Test foreach-cli exit code with a non-existent subcommand", ->
		commandArguments = [
			"--execute", "non-existent-subcommand"
			"--glob", "test/samples/stylus/**/personal-stylus.styl"
		]
		expect(executeCommandAndGetExitCode(commandArguments)).to.equal(4)

	###
	[TEST] Run foreach-cli with 2 subcommands where a first subcommand
	exits with a non-zero exit code and a second — with the exit code 0.

	[EXPECTED_BEHAVIOR] foreach-cli should return the exit code 4, if at least one
	of subcommands exits with a non-zero exit code.
	###
	test "3. Test foreach-cli exit code if one of subcommands exits with a non-zero exit code", ->
		commandArguments = [
			"--execute", "node --eval \"if('{{base}}' === 'personal-stylus.styl') process.exit(14)\""
			"--glob", "test/samples/stylus/**/*.styl"
		]
		expect(executeCommandAndGetExitCode(commandArguments)).to.equal(4)
