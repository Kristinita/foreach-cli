module.exports =
	'g':
		alias: 'glob'
		describe: 'Specify the glob'
		type: 'string'
	'i':
		alias: 'ignore'
		describe: 'Glob ignore'
		type: 'string'
	'f':
		alias: 'ignore-from-file'
		describe: 'Ignore files and folders specified in the given ignore file (for example, .gitignore, .bzrignore)'
		type: 'string'
	'nd':
		alias: 'nodir'
		describe: 'Exclude directories from glob matches'
		type: 'boolean'
	'x':
		alias: 'execute'
		describe: 'Command to execute upon file addition/change'
		type: 'string'
	'w':
		alias: 'watch'
		describe: 'Process solely new and modified files since the last execution
					of foreach-cli with the same glob template and subcommand'
		type: 'boolean'
	'W':
		alias: 'watch-file'
		describe: 'Specify the path to the watch metadata file (default: .foreach-watch.json)'
		type: 'string'
	'c':
		alias: 'forceColor'
		describe: 'Force color TTY output (pass --no-forceColor to disable)'
		type: 'boolean'
		default: true
	't':
		alias: 'trim'
		describe: 'Trims the output of the command executions to only show the first X characters of the output'
		type: 'number'
		default: undefined
	'C':
		alias: 'concurrent'
		describe: 'Execute commands concurrently (pass --no-concurrent to disable)'
		type: 'boolean'
		default: true
	'spin':
		describe: 'Show spinners when executing commands (pass --no-spin to disable)'
		type: 'boolean'
		default: true
