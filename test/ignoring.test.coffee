chai = require "chai"
execa = require "execa"
fs = require "node:fs"
{ resolve } = require "node:path"
bin = resolve "bin"
{ expect } = chai
{ splitTextIntoTrimmedLines } = require "./watch.test.coffee"


#########
# Tests #
#########
suite "Ignoring tests", ->

	suiteSetup -> fs.mkdirSync("test/temp", { recursive: true })
	suiteTeardown -> fs.rmSync("test/temp", { recursive: true })

	teardown -> fs.rmSync(".bzrignore", { force: true })

	###
	[TEST] Run foreach-cli with the option “--ignore-from-file”.

	[EXPECTED_BEHAVIOR] foreach-cli should process solely the file “main.css”,
	because the files “main.copy.css” and “folder.css/sub.css” are matched by the ignore patterns
	in the file “.bzrignore”.
	###
	test "1. Test of the option --ignore-from-file", ->

		fs.writeFileSync ".bzrignore", "*.copy.css\nfolder.css\n", encoding: "utf8"

		###
		[INFO] The option “--no-concurrent” is required, because if foreach-cli
		writes a data to the same file in parallel, a user get the error
		“The process cannot access the file because it is being used by another process.”.
		###
		execa.sync("node", [bin, "--execute", "npx shx echo {{base}} >> test/temp/ignore-from-file",
					"--glob", "test/samples/sass/css/**/*.css", "--ignore-from-file", ".bzrignore"
					"--no-concurrent"])

		resultContent = fs.readFileSync "test/temp/ignore-from-file", encoding: "utf8"
		resultLines = splitTextIntoTrimmedLines(resultContent)

		expect(resultLines.length).to.equal 1
		expect(resultLines[0]).to.equal "main.css"


	###
	[TEST] Check that foreach-cli with the option “--ignore-from-file” doesn’t match the directory
	matched by the glob template.

	[EXPECTED_BEHAVIOR] ignore-walk matches solely files, not directories.
	Therefore, foreach-cli with the option “--ignore-from-file” shouldn’t match the folder “folder.css”.
	foreach-cli should process the files “main.css” and “folder.css/sub.css”.
	The file “main.copy.css” should be ignored, because it matches by the ignore pattern in the file “.bzrignore”.
	###
	test "2. Test that the option --ignore-from-file doesn’t match folders", ->

		fs.writeFileSync ".bzrignore", "*.copy.css\n", encoding: "utf8"
		execa.sync(bin, ["--execute", "npx shx echo {{base}} >> test/temp/ignore-file-and-matching-folders",
					"--glob", "test/samples/sass/css/**/*.css", "--ignore-from-file", ".bzrignore"
					"--no-concurrent"])

		resultContent = fs.readFileSync "test/temp/ignore-file-and-matching-folders", encoding: "utf8"
		resultLines = splitTextIntoTrimmedLines(resultContent)

		expect(resultLines.length).to.equal 2
		expect(resultLines[0]).to.equal "main.css"
		expect(resultLines[1]).to.equal "sub.css"
