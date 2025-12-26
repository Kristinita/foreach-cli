chai = require "chai"
execa = require "execa"
fs = require "node:fs"
{ resolve } = require "node:path"
bin = resolve "bin"
{ expect } = chai

DEFAULT_WATCH_FILE_PATH = "test/temp/.foreach-watch.json"


####################
# Helper functions #
####################
# [PURPOSE] Helper function to get the file path matched by glob template
fileMatchedByGlobTemplate = (testSuiteName) ->
	"test/temp/#{testSuiteName}_test_file.js"

###
[PURPOSE] Helper function to get the file path in which a CLI command run in tests is output
For ease of testing structure, a command appends a content to this file,
and test checks this content.
###
outputFileForTestCLICommands = (testSuiteName) ->
	"test/temp/#{testSuiteName}_result.txt"

# [PURPOSE] Helper function to create a timeout to ensure that the time in “Data.now()” be different
delayBetweenCommands = ->
	setTimeout ->
		1000

# [PURPOSE] Helper function to execute a command with the “--watch” option
executeWatchCommandWithParameters = (
	commandParameters, additionalArgumentsOfForeachCliCommand = [], watchFilePath = DEFAULT_WATCH_FILE_PATH
) ->
	argumentsList = [
		bin, "--glob", commandParameters.glob, "--execute", commandParameters.execute,
		"--watch", "--watch-file", watchFilePath, ...additionalArgumentsOfForeachCliCommand
	]
	execa.sync("node", argumentsList)
	# [INFO] Timeout to ensure sufficient time difference for “--watch”
	delayBetweenCommands()

# [PURPOSE] Helper function to read content in the files “_result.txt” where test commands write
readTestResultContentByName = (testSuiteName) ->
	resultFilePathLocation = outputFileForTestCLICommands(testSuiteName)
	fs.readFileSync(resultFilePathLocation, encoding: "utf8")

# [PURPOSE] Helper function to split text into individual trimmed lines
splitTextIntoTrimmedLines = (inputTextContent) ->
	inputTextContent.trim().split("\n").map((individualTextLine) -> individualTextLine)

# [PURPOSE] Helper function to initialize “_test_file.js” file used for tests
initializeSingleTestFileWithTestName = (testSuiteName) ->
	initializedFileForTest = fileMatchedByGlobTemplate(testSuiteName)

	fs.writeFileSync(initializedFileForTest, "")

	initializedFileForTest

# [PURPOSE] General helper function to perform a watch test with a single file
performSingleFileWatchTestWithParameters = ({
	additionalArgumentsOfForeachCliCommand = [], expectedResultsVerification, fileOperationBetweenExecutions,
	firstCommandParameters, secondCommandParameters, shouldReadResultFile = true,
	testSuiteName, watchFilePath = DEFAULT_WATCH_FILE_PATH
}) ->

	# [INFO] Initialize a single test file
	initializeSingleTestFileWithTestName(testSuiteName)

	# [INFO] Execute first command
	executeWatchCommandWithParameters(firstCommandParameters, additionalArgumentsOfForeachCliCommand, watchFilePath)

	# [INFO] Perform file operation between executions if provided
	if fileOperationBetweenExecutions
		fileOperationBetweenExecutions()

	# [INFO] Wait to ensure time difference
	delayBetweenCommands()

	# [INFO] Execute second command
	executeWatchCommandWithParameters(secondCommandParameters, additionalArgumentsOfForeachCliCommand, watchFilePath)

	# [INFO] Read the output file to check results if needed
	if shouldReadResultFile
		resultContent = readTestResultContentByName(testSuiteName)
		expectedResultsVerification(resultContent)


#########
# Tests #
#########
suite "Tests with the “--watch” argument", ->

	suiteSetup -> fs.mkdirSync("test/temp", { recursive: true })

	###
	[REQUIRED] The test 8 uses custom metadata path instead of default “.foreach-watch.json”.
	“force: true” is required. “When "force: true", exceptions will be ignored if "path" does not exist.”:
	https://nodejs.org/api/fs.html#fsrmsyncpath-options
	###
	teardown -> fs.rmSync(DEFAULT_WATCH_FILE_PATH, { force: true })

	suiteTeardown -> fs.rmSync("test/temp", { recursive: true })


	###
	[TEST] Run foreach-cli with the “--watch” argument, the same command and glob pattern two times.

	[EXPECTED_BEHAVIOR] The command should launch first time and not launch the second time.
	###
	test "1. Run foreach-cli with the “--watch” argument two times with the same command and glob template", ->
		testSuiteName = "watch_same_glob_and_command_two_times"

		# [INFO] The command that appends the text to result file
		appendCommandForResultFile = "npx shx echo This line should be one time in this file
										>> #{outputFileForTestCLICommands(testSuiteName)}"

		# [INFO] First and second runs using performSingleFileWatchTestWithParameters
		commandParameters =
			execute: appendCommandForResultFile
			glob: fileMatchedByGlobTemplate(testSuiteName)

		performSingleFileWatchTestWithParameters(
			expectedResultsVerification: (resultContent) ->
				###
				[INFO] The command should execute once because foreach-cli with the “--watch” argument
				won’t run again if files weren’t modified.
				###
				expect(resultContent.trim()).to.equal("This line should be one time in this file")
			firstCommandParameters: commandParameters
			secondCommandParameters: commandParameters
			testSuiteName: testSuiteName
		)

	###
	[TEST] Run foreach-cli with the “--watch” argument, the same command, and the different glob pattern.

	[EXPECTED_BEHAVIOR] The command should be launched 2 times.
	foreach-cli should create different recordings in the file “.foreach-watch.json” if glob patterns are different.
	###
	test "2. Run foreach-cli with the “--watch” argument with the same command and different glob pattern", ->
		testSuiteName = "watch_same_command_different_glob"
		appendCommandForResultFile = "npx shx echo This line should be two times in this file
										>> #{outputFileForTestCLICommands(testSuiteName)}"

		firstCommandParameters =
			execute: appendCommandForResultFile
			# [INFO] Matches solely the initial test file
			glob: fileMatchedByGlobTemplate(testSuiteName)
		secondCommandParameters =
			execute: appendCommandForResultFile
			# [INFO] Matches all “.js” files in the test directory
			glob: "test/temp/#{testSuiteName}_*.js"

		performSingleFileWatchTestWithParameters(
			expectedResultsVerification: (resultContent) ->
				resultLines = splitTextIntoTrimmedLines(resultContent)
				expect(resultLines.length).to.equal(2)
				expect(resultLines[0]).to.equal("This line should be two times in this file")
				expect(resultLines[1]).to.equal("This line should be two times in this file")
			firstCommandParameters: firstCommandParameters
			secondCommandParameters: secondCommandParameters
			testSuiteName: testSuiteName
		)

	###
	[TEST] Run foreach-cli with the “--watch” argument, the same glob pattern, and the different command.

	[EXPECTED_BEHAVIOR] The command should be launched 2 times.
	foreach-cli should create different recordings in the file “.foreach-watch.json” if commands are different.
	###
	test "3. Run foreach-cli with the “--watch” argument with the same glob pattern and different commands", ->
		testSuiteName = "watch_same_glob_different_commands"

		firstCommandParameters =
			execute: "npx shx echo This line should be one time in this file >> #{outputFileForTestCLICommands(testSuiteName)}"
			glob: fileMatchedByGlobTemplate(testSuiteName)
		secondCommandParameters =
			execute: "npx shx echo And this line too >> #{outputFileForTestCLICommands(testSuiteName)}"
			glob: fileMatchedByGlobTemplate(testSuiteName)

		performSingleFileWatchTestWithParameters(
			expectedResultsVerification: (resultContent) ->
				resultLines = splitTextIntoTrimmedLines(resultContent)
				expect(resultLines.length).to.equal(2)
				expect(resultLines[0]).to.equal("This line should be one time in this file")
				expect(resultLines[1]).to.equal("And this line too")
			firstCommandParameters: firstCommandParameters
			secondCommandParameters: secondCommandParameters
			testSuiteName: testSuiteName
		)

	###
	[TEST] Run foreach-cli with “--ignore” and “--watch”

	[EXPECTED_BEHAVIOR] The command shouldn’t be launched.
	foreach-cli with the “--watch” argument should ignore files and folders defined in the “--ignore” option.
	###
	test "4. Run foreach-cli with “--ignore” and “--watch” arguments", ->
		testSuiteName = "watch_with_ignore"

		commandForFileContentChange = "npx shx echo This line shouldn’t be in the file as the file itself
										>> #{outputFileForTestCLICommands(testSuiteName)}"

		commandParameters =
			execute: commandForFileContentChange
			glob: fileMatchedByGlobTemplate(testSuiteName)

		# [INFO] Additional command-line argument “--ignore” ignoring the initialized file
		additionalArgumentsOfForeachCliCommand = ["--ignore", fileMatchedByGlobTemplate(testSuiteName)]

		performSingleFileWatchTestWithParameters(
			additionalArgumentsOfForeachCliCommand: additionalArgumentsOfForeachCliCommand
			expectedResultsVerification: (resultContent) ->
				# [INFO] The result file shouldn’t exist because the test file was ignored
				resultFilePathLocation = outputFileForTestCLICommands(testSuiteName)
				expect(fs.existsSync(resultFilePathLocation)).to.equal(false)
			firstCommandParameters: commandParameters
			secondCommandParameters: commandParameters
			shouldReadResultFile: false
			testSuiteName: testSuiteName
		)

	###
	[TEST] Run foreach-cli with “--ignore-from-file” and “--watch”

	[EXPECTED_BEHAVIOR] The command shouldn’t be launched.
	foreach-cli with the “--watch” argument should ignore files and folders from the ignore file.
	###
	test "5. Run foreach-cli with “--ignore-from-file” and “--watch” arguments", ->
		testSuiteName = "watch_with_ignore_from_file"

		# [INFO] Create the ignore file that ignore the initialized file
		ignoreFilePath = ".#{testSuiteName}_custom_ignore"
		fs.writeFileSync ignoreFilePath, "#{fileMatchedByGlobTemplate(testSuiteName)}\n", encoding: "utf8"

		commandForFileContentChange = "npx shx echo This line shouldn’t be in the file as the file itself
										>> #{outputFileForTestCLICommands(testSuiteName)}"

		commandParameters =
			execute: commandForFileContentChange
			glob: fileMatchedByGlobTemplate(testSuiteName)

		###
		[INFO] Additional command-line argument “--ignore-from-file”
		with the content where the initialized file is ignored
		###
		additionalArgumentsOfForeachCliCommand = ["--ignore-from-file", ignoreFilePath]

		performSingleFileWatchTestWithParameters(
			additionalArgumentsOfForeachCliCommand: additionalArgumentsOfForeachCliCommand
			expectedResultsVerification: (resultContent) ->
				# [INFO] The result file shouldn’t exist because the initialized file was ignored
				expect(fs.existsSync(resultContent)).to.equal(false)
			firstCommandParameters: commandParameters
			secondCommandParameters: commandParameters
			shouldReadResultFile: false
			testSuiteName: testSuiteName
		)

		# [INFO] Delete the ignore file
		fs.rmSync(ignoreFilePath)

	###
	[TEST] Run foreach-cli for the file → modify the file → run the same command again

	[EXPECTED_BEHAVIOR] The command should be launched two times. foreach-cli should detect modifications.
	###
	test "6. Run foreach-cli with “--watch” argument for modified file", ->
		testSuiteName = "watch_modified_file"

		appendCommandForResultFile = "npx shx echo This line should be two times in this file
										>> #{outputFileForTestCLICommands(testSuiteName)}"

		commandParameters =
			execute: appendCommandForResultFile
			glob: fileMatchedByGlobTemplate(testSuiteName)

		# [INFO] Execute first and second runs with a file modification between them
		performSingleFileWatchTestWithParameters(
			expectedResultsVerification: (resultContent) ->
				resultLines = splitTextIntoTrimmedLines(resultContent)
				expect(resultLines.length).to.equal(2)
				expect(resultLines[0]).to.equal("This line should be two times in this file")
				expect(resultLines[1]).to.equal("This line should be two times in this file")
			fileOperationBetweenExecutions: ->
				# [INFO] Modify the initialization file
				fs.appendFileSync(fileMatchedByGlobTemplate(testSuiteName), "// File modification between executions")
			firstCommandParameters: commandParameters
			secondCommandParameters: commandParameters
			testSuiteName: testSuiteName
		)

	###
	[TEST] Run foreach-cli for the file → delete the file → run the same command again

	[EXPECTED_BEHAVIOR] The command shouldn’t be launched after the deletion.
	foreach-cli should unwatch deleted files.
	###
	test "7. Run foreach-cli with “--watch” argument for deleted file", ->
		testSuiteName = "watch_deleted_file"

		appendCommandForResultFile = "npx shx echo This line should be one time in this file
										>> #{outputFileForTestCLICommands(testSuiteName)}"

		commandParameters =
			execute: appendCommandForResultFile
			glob: fileMatchedByGlobTemplate(testSuiteName)

		# [INFO] Execute first and second runs with a file deletion between them
		performSingleFileWatchTestWithParameters(
			expectedResultsVerification: (resultContent) ->
				resultLines = splitTextIntoTrimmedLines(resultContent)
				expect(resultLines.length).to.equal(1)
				expect(resultLines[0]).to.equal("This line should be one time in this file")
			fileOperationBetweenExecutions: ->
				# [INFO] Delete the initialization file
				fs.rmSync(fileMatchedByGlobTemplate(testSuiteName))
			firstCommandParameters: commandParameters
			secondCommandParameters: commandParameters
			testSuiteName: testSuiteName
		)

	###
	[TEST] Run foreach-cli with “--watch” and “--watch-file” arguments.

	[EXPECTED_BEHAVIOR] foreach-cli should create the custom metadata file instead of default “.foreach-watch.json”
	###
	test "8. Run foreach-cli with “--watch” and “--watch-file” arguments", ->
		testSuiteName = "watch_with_custom_watch_file"
		customWatchFile = "test/temp/.example-file.json"
		defaultWatchFile = DEFAULT_WATCH_FILE_PATH

		commandParameters =
			execute: "npx shx echo This line shouldn’t be in any file"
			glob: fileMatchedByGlobTemplate(testSuiteName)

		performSingleFileWatchTestWithParameters(
			firstCommandParameters: commandParameters
			secondCommandParameters: commandParameters
			shouldReadResultFile: false
			testSuiteName: testSuiteName
			watchFilePath: customWatchFile
		)

		###
		[REQUIRED] Checking files with “expect()” outside the function “performSingleFileWatchTestWithParameters”.
		Otherwise, the test runs incorrectly.
		###
		expect(fs.existsSync(customWatchFile)).to.equal(true)
		expect(fs.existsSync(defaultWatchFile)).to.equal(false)

		# [INFO] Delete the custom metadata file
		fs.rmSync(customWatchFile)

module.exports = { splitTextIntoTrimmedLines }
