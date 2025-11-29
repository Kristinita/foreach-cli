PATH = require 'path'
execa = require 'execa'
fs = require 'fs-extra'
chai = require 'chai'
expect = chai.expect
should = chai.should()
bin = PATH.resolve 'bin'

parsePlaceholdersResult = (result) ->
	parsedResults = { lines: undefined, linesMap: {} }
	parsedResults.lines = result.split('\n').filter (validLine)-> validLine

	parsedResults.lines.forEach (resultLine) ->
		placeHoldersObj = {}
		placeHolders = resultLine.split(' ')
		placeHoldersObj.name = placeHolders[0]?.replace(/^"|"$/g, '')
		placeHoldersObj.ext = placeHolders[1]?.replace(/^"|"$/g, '')
		placeHoldersObj.base = placeHolders[2]?.replace(/^"|"$/g, '')
		placeHoldersObj.reldir = placeHolders[3]?.replace(/^"|"$/g, '')
		placeHoldersObj.path = placeHolders[4]?.replace(/^"|"$/g, '')
		placeHoldersObj.dir = placeHolders[5]?.replace(/^"|"$/g, '')
		parsedResults.linesMap[placeHoldersObj.path] = placeHoldersObj

	return parsedResults


suite "ForEach-cli", ()->
	suiteSetup (done)-> fs.ensureDir 'test/temp', done
	suiteTeardown (done)-> fs.remove 'test/temp', done

	test "Will execute a given command on all matched files/dirs in a given glob when using explicit arguments", ()->
		execa(bin, ['-g', 'test/samples/sass/css/*', '-x', 'echo {{base}} >> test/temp/one']).then (err)->
			result = fs.readFileSync 'test/temp/one', {encoding:'utf8'}
			resultLines = result.split('\n').filter (validLine)-> validLine

			# Because there is 3, and all of them are within the list of 3. Then each of them makes a line
			expect(resultLines.length).to.equal 3
			expect(resultLines.find (line) -> line == 'foldr.css').to.be.truthy
			expect(resultLines.find (line) -> line == 'main.copy.css').to.be.truthy
			expect(resultLines.find (line) -> line == 'main.css').to.be.truthy


	test "Will execute a given command on all matched files/dirs in a given glob when using positional arguments", ()->
		execa(bin, ['test/samples/sass/css/*', 'echo {{base}} >> test/temp/two']).then (err)->
			result = fs.readFileSync 'test/temp/two', {encoding:'utf8'}
			resultLines = result.split('\n').filter (validLine)-> validLine

			expect(resultLines.length).to.equal 3
			expect(resultLines.find (line) -> line == 'foldr.css').to.be.truthy
			expect(resultLines.find (line) -> line == 'main.copy.css').to.be.truthy
			expect(resultLines.find (line) -> line == 'main.css').to.be.truthy



	test "Placeholders can be used in the command which will be dynamically filled according to the subject path", ()->
		execa(bin, ['-g', 'test/samples/sass/css/**/*', '-x', 'echo "{{name}} {{ext}} {{base}} {{reldir}} {{path}} {{dir}}" >> test/temp/three']).then (err)->
			result = fs.readFileSync 'test/temp/three', {encoding:'utf8'}

			parsedResult = parsePlaceholdersResult(result)

			# Check length
			expect(parsedResult.lines.length).to.equal 4

			# Check the paths
			[
				' test/samples/sass/css/foldr.css ',
				' test/samples/sass/css/foldr.css/sub.css ',
				' test/samples/sass/css/main.copy.css ',
				' test/samples/sass/css/main.css '
			].forEach (path) -> expect(result.includes(path)).to.be.truthy


			# Normalized path for cross-platform compatibility
			normalizedCwd = process.cwd().replace(/\\/g, '/')
			# We are using mapping to make tests pure, as Listr run doesn't guarantee the order of execution
			expectedResults = [
				# folder file match
				{
					path: 'test/samples/sass/css/foldr.css',
					name: 'foldr',
					ext: '.css',
					base: 'foldr.css',
					reldir: '',
					dir: "#{normalizedCwd}/test/samples/sass/css" # because a folder
				},
				# ✨ Nested folder, and reldir
				{
					path: 'test/samples/sass/css/foldr.css/sub.css',
					name: 'sub',
					ext: '.css',
					base: 'sub.css',
					reldir: 'foldr.css',
					dir: "#{normalizedCwd}/test/samples/sass/css/foldr.css"
				},
				{
					path: 'test/samples/sass/css/main.copy.css',
					name: 'main.copy',
					ext: '.css',
					base: 'main.copy.css',
					reldir: '',
					dir: "#{normalizedCwd}/test/samples/sass/css"
				},
				{
					path: 'test/samples/sass/css/main.css',
					name: 'main',
					ext: '.css',
					base: 'main.css',
					reldir: '',
					dir: "#{normalizedCwd}/test/samples/sass/css"
				}
			]

			for expected in expectedResults
				m = parsedResult.linesMap[expected.path]
				expect(m.name).to.equal expected.name
				expect(m.ext).to.equal expected.ext
				expect(m.base).to.equal expected.base
				expect(m.reldir).to.equal expected.reldir
				expect(m.path).to.equal expected.path
				expect(m.dir).to.equal expected.dir

	test "Placeholders can be denoted either with dual curly braces or a hash + single curly brace wrap", ()->
		execa(bin, ['-g', 'test/samples/sass/css/**/*', '-x', 'echo "#{name} #{ext} #{base} #{reldir} #{path} #{dir}" >> test/temp/four']).then (err)->
			result = fs.readFileSync 'test/temp/four', {encoding:'utf8'}
			parsedResult = parsePlaceholdersResult(result)

			# Check length
			expect(parsedResult.lines.length).to.equal 4

			# Check the paths
			[
				' test/samples/sass/css/foldr.css ',
				' test/samples/sass/css/foldr.css/sub.css ',
				' test/samples/sass/css/main.copy.css ',
				' test/samples/sass/css/main.css '
			].forEach (path) -> expect(result.includes(path)).to.be.truthy

			# Normalized path for cross-platform compatibility
			normalizedCwd = process.cwd().replace(/\\/g, '/')
			# We are using mapping to make tests pure, as Listr run doesn't guarantee the order of execution
			expectedResults = [
				# folder file match
				{
					path: 'test/samples/sass/css/foldr.css',
					name: 'foldr',
					ext: '.css',
					base: 'foldr.css',
					reldir: '',
					dir: "#{normalizedCwd}/test/samples/sass/css" # because a folder
				},
				# ✨ Nested folder, and reldir
				{
					path: 'test/samples/sass/css/foldr.css/sub.css',
					name: 'sub',
					ext: '.css',
					base: 'sub.css',
					reldir: 'foldr.css',
					dir: "#{normalizedCwd}/test/samples/sass/css/foldr.css"
				},
				{
					path: 'test/samples/sass/css/main.copy.css',
					name: 'main.copy',
					ext: '.css',
					base: 'main.copy.css',
					reldir: '',
					dir: "#{normalizedCwd}/test/samples/sass/css"
				},
				{
					path: 'test/samples/sass/css/main.css',
					name: 'main',
					ext: '.css',
					base: 'main.css',
					reldir: '',
					dir: "#{normalizedCwd}/test/samples/sass/css"
				}
			]

			for expected in expectedResults
				m = parsedResult.linesMap[expected.path]
				expect(m.name).to.equal expected.name
				expect(m.ext).to.equal expected.ext
				expect(m.base).to.equal expected.base
				expect(m.reldir).to.equal expected.reldir
				expect(m.path).to.equal expected.path
				expect(m.dir).to.equal expected.dir


	test "Will execute a given command on all matched files/dirs in a given glob with ignore option", ()->
		execa(bin, ['-g', 'test/samples/sass/css/*', '-i', '**/*copy*', '-x', 'echo {{base}} >> test/temp/five']).then (err)->
			result = fs.readFileSync 'test/temp/five', {encoding:'utf8'}
			resultLines = result.split('\n').filter (validLine)-> validLine

			expect(resultLines.length).to.equal 2
			expect(resultLines.find (line) -> line == 'foldr.css').to.be.truthy
			expect(resultLines.find (line) -> line == 'main.css').to.be.truthy


	test "Will execute a given command on all matched files in a given glob but ignoring the folders", ()->
		execa(bin, ['-g', 'test/samples/sass/css/*', '--nodir', 'true', '-x', 'echo {{base}} >> test/temp/six']).then (err)->
			result = fs.readFileSync 'test/temp/six', {encoding:'utf8'}
			resultLines = result.split('\n').filter (validLine)-> validLine

			expect(resultLines.length).to.equal 2
			expect(resultLines.find (line) -> line == 'main.copy.css').to.be.truthy
			expect(resultLines.find (line) -> line == 'main.css').to.be.truthy


	test "Will execute a given command on all matched `.css` files in a given glob with ** but ignoring the folders", ()->
		execa(bin, ['-g', 'test/samples/sass/css/**/*.css', '--nodir', 'true', '-x', 'echo {{base}} >> test/temp/seven']).then (err)->
			result = fs.readFileSync 'test/temp/seven', {encoding:'utf8'}
			resultLines = result.split('\n').filter (validLine)-> validLine

			expect(resultLines.length).to.equal 3
			expect(resultLines.find (line) -> line == 'sub.css').to.be.truthy
			expect(resultLines.find (line) -> line == 'main.copy.css').to.be.truthy
			expect(resultLines.find (line) -> line == 'main.css').to.be.truthy


	test "Will execute a given command on matched files that are not in .gitignore when --gitignore flag is used", () ->
		execa(bin, ['-g', 'test/samples/sass/css/*', '--gitignore', 'true', '-x', 'echo {{base}} >> test/temp/eight']).then (err) ->
			result = fs.readFileSync 'test/temp/eight', {encoding:'utf8'}
			resultLines = result.split('\n').filter (validLine) -> validLine

			# Should solely contain “main.css” since “main.copy.css” and “foldr.css” are in “.gitignore”
			expect(resultLines.length).to.equal 1
			# Remove any trailing whitespace/line endings that may vary by OS
			expect(resultLines[0].trim()).to.equal 'main.css'


	# Helper function to run foreach with a slow command and check for spinner characters
	runSpinnerTest = (useNoSpin, testName) ->
		# Create a slow command to allow spinner animation to appear in output
		filename = 'test/temp/slow_test_' + testName + '.js'
		fs.writeFileSync filename, '''
		setTimeout(() => {
		  console.log('Slow command completed');
		}, 2000);
		''', {encoding: 'utf8'}

		# Prepare command arguments
		args = [bin, '-g', 'test/samples/sass/css/*.css', '-x', "node #{filename}"]
		if useNoSpin
			args.push('--no-spin')

		# Run foreach with the slow command and capture all output
		execa('node', args).then (result) ->
			# Clean up temporary file
			fs.removeSync(filename)

			# Save the output to a file for checking spinner characters
			output = result.stdout + result.stderr
			outputFile = 'test/temp/spinner_output_' + testName + '.txt'
			fs.writeFileSync(outputFile, output, {encoding:'utf8'})

			# Check if the output file contains any spinner characters at the beginning of lines
			outputFromFile = fs.readFileSync(outputFile, {encoding:'utf8'})
			lines = outputFromFile.split('\n')

			spinnerChars = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏', '-', '\\', '|', '/']

			hasSpinnerChars = false
			for line in lines when line
				for char in spinnerChars
					if line.trim().startsWith(char)
						hasSpinnerChars = true
						break
				break if hasSpinnerChars

			# Verify the command completed successfully
			expect(outputFromFile).to.contain("Slow command completed")

			return
				outputFromFile: outputFromFile
				hasSpinnerChars: hasSpinnerChars


	test "Will execute command with --no-spin flag without showing spinners", () ->
		runSpinnerTest(true, "no_spin").then (result) ->
			# Check that no spinner characters appear when the argument “--no-spin” is used
			if result.hasSpinnerChars
				throw new Error("Spinner characters found when --no-spin was used: #{result.outputFromFile}")


	test "Will find spinner characters when not using --no-spin flag", () ->
		runSpinnerTest(false, "with_spin").then (result) ->
			# The test verifies that spinner characters appear without the argument “--no-spin”
			if not result.hasSpinnerChars
				throw new Error("Spinner characters should appear when --no-spin is not used, but were not found in output")
