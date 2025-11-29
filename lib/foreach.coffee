fs = require('fs')
path = require('path')
{glob} = require('glob')
walk = require('ignore-walk')
chalk = require('chalk')
Listr = require '@danielkalen/listr'
exec = require('child_process').exec
regEx = require './regex'


module.exports = (options)-> new Promise (finish, fail)->
	finalLogs = 'log':{}, 'error':{}

	# Helper function to create glob options from current options
	createGlobOptions = () ->
		globOptions = {}
		if options.ignore then globOptions.ignore = options.ignore
		if options.nodir then globOptions.nodir = options.nodir
		globOptions

	# Helper function for consistent error handling
	handleError = (err) ->
		console.error(err)
		fail(err)

	if options.gitignore
		# Get all the files that match the glob first
		globOptions = createGlobOptions()

		glob(options.glob, globOptions)
			.then (globFiles) ->
				# Use ignore-walk to determine which files should be filtered out
				walkOptions =
					path: process.cwd()
					ignoreFiles: ['.gitignore']

				try
					# Get all non-ignored files in the project and create a Set for fast lookup with normalized paths
					nonIgnoredFiles = new Set(walk.sync(walkOptions).map (file) -> file.replace(/\\/g, '/'))
					# Filter glob results to only include files that are NOT ignored
					filteredFiles = globFiles.filter (file) -> nonIgnoredFiles.has(file.replace(/\\/g, '/'))
					createTasksAndExecute(filteredFiles)
				catch err
					handleError(err)
			.catch (err) ->
				handleError(err)
	else
		globOptions = createGlobOptions()

		glob(options.glob, globOptions)
			.then (files) ->
				createTasksAndExecute(files)
			.catch (err) ->
				handleError(err)

	createTasksAndExecute = (files) ->
		tasks = new Listr files.map((file)=>
			title: "Executing command: #{chalk.dim(file)}"
			task: ()=> executeCommand(file)
		), options # same as {concurrent:options.concurrent}

		tasks.run().then(outputFinalLogs, outputFinalLogs)



	executeCommand = (filePath)-> new Promise (resolve, reject)->
		# Normalize filePath to use forward slashes for consistency across platforms
		normalizedFilePath = filePath.replace(/\\/g, '/')
		pathParams = path.parse path.resolve(filePath)
		# Normalize path components to use forward slashes for consistency across platforms
		pathParams.dir = pathParams.dir.replace(/\\/g, '/') if pathParams.dir
		pathParams.root = pathParams.root.replace(/\\/g, '/') if pathParams.root
		pathParams.reldir = getDirName(pathParams, path.resolve(filePath))

		command = options.command.replace regEx.placeholder, (entire, placeholder)-> switch
			when placeholder is 'path' then normalizedFilePath
			when pathParams[placeholder]? then pathParams[placeholder]
			else entire

		if options.forceColor and process.platform isnt 'win32'
			command = "FORCE_COLOR=true #{command}"

		exec command, (err, stdout, stderr)->
			# Remove surrounding quotes from output for Windows compatibility
			if isValidOutput(stdout)
				cleanedStdout = stdout?.replace(/^"|"$/g, '')
				finalLogs.log[normalizedFilePath] = cleanedStdout

			if isValidOutput(stderr) and not isValidOutput(err)
				finalLogs.log[normalizedFilePath] = stderr
			else if isValidOutput(err)
				finalLogs.error[normalizedFilePath] = stderr or err

			if isValidOutput(err) then reject() else resolve()













	## ==========================================================================
	## Helpers
	## ==========================================================================
	getDirName = (pathParams, filePath)->
		dirInGlob = options.glob.match(/^[^\*]*/)[0] || ''
		# Use pathParams.dir instead of filePath to get directory path without filename
		# Normalize paths to forward slashes for consistent replacement
		normalizedDirPath = pathParams.dir.replace(/\\/g, '/')
		# Remove trailing slash from dirInGlob before joining to avoid double slashes
		trimmedDirInGlob = dirInGlob.replace(/\/$/, '')
		relativeGlobPath = path.join(process.cwd(), trimmedDirInGlob).replace(/\\/g, '/')

		# Remove the glob prefix to get relative directory
		relativeDir = normalizedDirPath
			.replace(relativeGlobPath, '')
			# Remove leading slash if any
			.replace(/^\//, '')

		# Handle case where pathParams.dir equals the glob path (file in root)
		if relativeDir == '.' then relativeDir = ''
		relativeDir

	isValidOutput = (output)->
		output and
		output isnt 'null' and
		(
			(typeof output is 'string' and output.length >= 1) or
			(typeof output is 'object')
		)

	formatOutputMessage = (message)->
		# Remove surrounding quotes from message for Windows compatibility
		cleanedMessage = message?.replace(/^"|"$/g, '')
		if options.trim
			cleanedMessage.slice(0, options.trim)
		else
			cleanedMessage






	outputFinalLogs = ()-> if Object.keys(finalLogs.log).length or Object.keys(finalLogs.error).length
		process.stdout.write '\n\n'
		for file,message of finalLogs.log
			console.log chalk.bgWhite.black.bold("Output")+' '+chalk.dim(file)
			console.log formatOutputMessage(message)

		for file,message of finalLogs.error
			console.log chalk.bgRed.white.bold("Error")+' '+chalk.dim(file)
			console.log formatOutputMessage(message)

		if Object.keys(finalLogs.error).length
			fail()
		else
			finish()
