yargs = require('yargs')
yargs
	.usage(require('./cliUsage').usage)
	.options(require './cliOptions')
	.epilogue(require('./cliUsage').epilogue)
	.wrap(yargs.terminalWidth())
	.help('h')
	.version(require('../package.json').version)
args = yargs.argv
requiresHelp = args.h or args.help

suppliedOptions =
	'glob': args.g or args.glob or args._[0]
	'command': args.x or args.execute or args._[1]
	'ignore': args.i or args.ignore
	'ignore-from-file': args.f or args['ignore-from-file']
	'nodir': args.nd or args.nodir
	'trim': args.t or args.trim
	'forceColor': args.c or args.forceColor
	'concurrent': args.C or args.concurrent
	'spin': args.spin
	'watch': args.w or args.watch
	'watch-file': args.W or args['watch-file']

if requiresHelp or not suppliedOptions.glob or not suppliedOptions.command
	yargs.getHelp().then (helpText) ->
		console.log(helpText)
		process.exit(0)



require('./foreach')(suppliedOptions).then (result) ->
	process.exit(0)
.catch ->
	process.exit(1)
