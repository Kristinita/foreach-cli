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
		describe: 'Ignore files and folders specified in the given ignore file (e.g., .gitignore, .customignore)'
		type: 'string'
	'nd':
		alias: 'nodir'
		describe: 'Exclude directories from glob matches'
		type: 'boolean'
	'x':
		alias: 'execute'
		describe: 'Command to execute upon file addition/change'
		type: 'string'
	'c':
		alias: 'forceColor'
		describe: 'Force color TTY output (pass --no-c to disable)'
		type: 'boolean'
		default: true
	't':
		alias: 'trim'
		describe: 'Trims the output of the command executions to only show the first X characters of the output'
		type: 'number'
		default: undefined
	'C':
		alias: 'concurrent'
		describe: 'Execute commands concurrently (pass --no-C to disable)'
		type: 'boolean'
		default: true
	'spin':
		describe: 'Show spinners when executing commands (pass --no-spin to disable)'
		type: 'boolean'
		default: true
