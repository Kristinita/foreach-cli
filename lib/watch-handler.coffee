# @flow
#################
# watch-handler #
#################
###
[OVERVIEW] watch-handler — a module launching foreach-cli solely for new and modified files
if a user use the command-line argument “--watch” in their command.
See the sections “--watch” and “--watch-file” in the README for details.


[GLOSSARY]

1. “Metadata file” — a file to which watch-handler writes a metadata.
By default, its name “.foreach-watch.json”. The default name may be changed through the option “--watch-file”.

2. “Entire metadata” — an entire content of a metadata file.

3. “Identifier” — a recording in a metadata file consisting of user’s glob template and subcommand.
For example, if a user runs the command “foreach --glob "*.coffee" --execute "echo test"”,
the identifier is “*.coffee::echo test”.

4. “Identifier object” — a value of an identifier.

[EXAMPLE] For example, if the file “.foreach-watch.json” has these recordings:

```json
"*.coffee::echo test": {
	"files": {
		"KiraFirst.coffee": 1765112821353,
		"KiraSecond.coffee": 1764780973444,
	},
	"timestamp": 1765123236917
},
```

The identifier object in this case is:

```json
{
	"files": {
		"KiraFirst.coffee": 1765112821353,
		"KiraSecond.coffee": 1764780973444,
	},
	"timestamp": 1765123236917
}
```

5. “Identifier timestamp value” — a value of the key “timestamp” in an identifier object.
For the example above, the identifier timestamp value is “1765123236917”.

6. “File last watch timestamp” — a time when a file was created or modified last time.
For the example above, the “last watch timestamp” for the file “KiraFirst” is “1765112821353”,
for the file “KiraSecond.coffee” is “1764780973444”.
###
fs = require("node:fs")
path = require("node:path")

METADATA_FILE_PATH = path.join(process.cwd(), ".foreach-watch.json")

###*
# [FUNCTION] Gets a metadata file path.
#
# @return {string} A metadata file when a user runs foreach-cli with the option “--watch”.
###
getMetadataFilePath = (foreachCliCommandObjectOfArguments ###: Object ###) ###: string ### ->
	if foreachCliCommandObjectOfArguments["watch-file"]

		# [INFO] Resolve a path relative to a current working directory and normalize it
		return path.join(process.cwd(), foreachCliCommandObjectOfArguments["watch-file"])
	return METADATA_FILE_PATH

###*
# [FUNCTION] Normalizes file paths for consistent comparison across different operating systems.
# @return {string} A path in the POSIX format.
###
normalizeFilePathsAcrossPlatforms = (inputFilePath ###: string ###) ###: string ### ->
	inputFilePath.split(path.win32.sep).join(path.posix.sep)

###*
# [FUNCTION] Gets a value from an object using a key.
# @return {mixed} A value can be of any type.
###
getValueFromObjectUsingKey = (objectToRetrieveFrom ###: Object ###, keyToAccess ###: mixed ###) ###: mixed ### ->
	objectToRetrieveFrom[keyToAccess]


###*
# [FUNCTION] Sets a value in an object using a key.
# @return {void} This function sets a value and doesn’t return anything.
###
setValueInObjectUsingKey = (
	objectToAssignTo ###: Object ###, keyToSet ###: mixed ###, valueToSet ###: mixed ###
) ###: void ### ->
	objectToAssignTo[keyToSet] = valueToSet
	return

###*
# [FUNCTION] Gets or creates a value of identifier.
#
# @param {string} Identifier in a metadata.
# @return {Object} A value of an identifier.
###
getOrCreateIdentifierObject = (
	entireMetadata ###: Object ###, identifierFromGlobAndSubcommand ###: string ###
) ###: Object ### ->
	identifierObject = getValueFromObjectUsingKey(
		entireMetadata, identifierFromGlobAndSubcommand) or {files: {}, timestamp: 0}
	return identifierObject

###*
# [FUNCTION] Loads a previous entire metadata from a metadata file.
#
# @return {[key: string]: {files: {[key: string]: number, timestamp: number}}} Entire metadata in a metadata file.
###
loadPreviousEntireMetadata = (metadataFilePath ###: string ###) ###:
	{[key: string]: {files: {[key: string]: number, timestamp: number}}}
### ->
	previousEntireMetadata = {}
	if fs.existsSync(metadataFilePath)
		previousEntireMetadata = JSON.parse(fs.readFileSync(metadataFilePath, "utf8"))
	return previousEntireMetadata

###*
# [FUNCTION] Creates an unique identifier based on a glob pattern and a subcommand.
# @return {string} An identifier.
###
createIdentifier = (foreachCliCommandObjectOfArguments ###: Object ###) ###: string ### ->
	return "#{foreachCliCommandObjectOfArguments.glob}::#{foreachCliCommandObjectOfArguments.command}"

###*
# [FUNCTION] Normalizes file paths in an identifier object to the POSIX format.
#
# @return {[key: string]: number} The object with normalized paths in the POSIX format and timestamps for them.
#
# ```json
# {
# 	"ExampleFolder/first.coffee": 1765112821353,
# 	"ExampleFolder/second.coffee": 1764780973444
# },
# ```
###
normalizeFilePathsInMetadataFile = (previousIdentifierObject ###: Object ###) ###: {[key: string]: number} ### ->
	identifierObjectWithNormalizedPaths = {}
	for inputFileForProcessing, fileLastWatchTimestamp of previousIdentifierObject.files
		if Object.hasOwn(previousIdentifierObject.files, inputFileForProcessing)
			normalizedFilePath = normalizeFilePathsAcrossPlatforms(inputFileForProcessing)
			setValueInObjectUsingKey(
				identifierObjectWithNormalizedPaths,
				normalizedFilePath,
				fileLastWatchTimestamp
			)
	return identifierObjectWithNormalizedPaths

###*
# [FUNCTION] Gets a file modification time.
# @return {number} The number of milliseconds since January 1, 1970.
###
getFileLastWatchTimestamp = (currentFile ###: string ###) ###: number ### ->
	currentFileStatistics = fs.statSync(currentFile)
	return currentFileStatistics.mtime.getTime()

###*
# [FUNCTION] Determines is a file new or modified since the last run of foreach-cli
# with the same subcommand and glob template.
#
# @return {boolean} Returns:
# 1. If a file is new (an identifier object hasn’t it) — include it (return “true”).
# 2. If a file exists and was modified after the last subcommand+glob launching — include it.
# 3. Otherwise, exclude it (a file hasn’t changed since the last subcommand+glob launching) (return “false”).
###
isFileNewOrModifiedSinceLastCommandExecution = (
	normalizedCurrentFilePath ###: string ###, currentFileLastWatchTimestamp ###: number ###,
	identifierObjectWithNormalizedPaths ###: Object ###, previousIdentifierTimestampValue ###: number ###
) ###: boolean ### ->

	# [INFO] Check if a file exists in a metadata and if it’s been modified since a last execution of the same command
	return not Object.hasOwn(identifierObjectWithNormalizedPaths, normalizedCurrentFilePath) or
	currentFileLastWatchTimestamp > previousIdentifierTimestampValue

###*
# [FUNCTION] Processes each file in an input list
#
# @return { newAndModifiedFilesList: Array<string>, identifierObject: Object } Returns:
# 1. A list of new and modified files since the last launching of the command
# with the same glob pattern and subcommand
# 2. An identifier object.
###
processFileList = (
	inputFileList ###: Array<string> ###,
	identifierObjectWithNormalizedPaths ###: Object ###,
	previousIdentifierTimestampValue ###: number ###
) ###: { newAndModifiedFilesList: Array<string>, identifierObject: Object } ### ->

	newAndModifiedFilesList ###: Array<string> ### = []
	identifierObject = {}

	for inputFileForProcessing in inputFileList
		currentFileLastWatchTimestamp = getFileLastWatchTimestamp(inputFileForProcessing)
		normalizedCurrentFilePath = normalizeFilePathsAcrossPlatforms(inputFileForProcessing)
		setValueInObjectUsingKey(
			identifierObject,
			normalizedCurrentFilePath,
			currentFileLastWatchTimestamp
		)

		###
		[INFO] Include a file if it’s new or was modified
		since the last execution of foreach-cli with this identifier.
		###
		if isFileNewOrModifiedSinceLastCommandExecution(
			normalizedCurrentFilePath, currentFileLastWatchTimestamp,
			identifierObjectWithNormalizedPaths, previousIdentifierTimestampValue
		)
			newAndModifiedFilesList.push(inputFileForProcessing)

	return { newAndModifiedFilesList, identifierObject }


###*
# [FUNCTION] Saves a metadata generated in the last launching of foreach-cli
# with the option “--watch” to a metadata file.
#
# @return {void} This function saves a data to a file and doesn’t return anything.
###
saveEntireMetadataGeneratedInLastExecutionToFile = (
	previousEntireMetadata ###: Object ###, identifierFromGlobAndSubcommand ###: string ###,
	identifierObject ###: Object ###, metadataFilePath ###: string ###
) ###: void ### ->
	previousIdentifierObject =
		files: identifierObject
		timestamp: Date.now()
	setValueInObjectUsingKey(
		previousEntireMetadata, identifierFromGlobAndSubcommand, previousIdentifierObject
	)
	fs.writeFileSync(metadataFilePath, JSON.stringify(previousEntireMetadata, undefined, "\t"))


###*
# [FUNCTION] The general function. Returns a list of files that be processed when a user
# launches foreach-cli with the argument “--watch”.
#
# @return {Array} A list of new files and files modified since the last launching of foreach-cli
# with the same identifier.
###
getListOfUnwatchedNewAndModifiedFiles = (
	inputFileList ###: Array<string> ###, foreachCliCommandObjectOfArguments ###: Object ###
) ###: Array<string> ### ->

	# [INFO] Return all files if a user runs foreach-cli without the “--watch” argument.
	return inputFileList unless foreachCliCommandObjectOfArguments.watch

	metadataFilePath = getMetadataFilePath(foreachCliCommandObjectOfArguments)

	# [INFO] Load a previous entire metadata in a metadata file
	previousEntireMetadata = loadPreviousEntireMetadata(metadataFilePath)

	# [INFO] Create an unique identifier for a combination of glob template and subcommand
	identifierFromGlobAndSubcommand = createIdentifier(foreachCliCommandObjectOfArguments)

	# [INFO] Get or create an identifier object
	previousIdentifierObject = getOrCreateIdentifierObject(
		previousEntireMetadata, identifierFromGlobAndSubcommand
	)
	previousIdentifierTimestampValue = previousIdentifierObject.timestamp

	# [INFO] Normalize paths in a previous identifier object
	identifierObjectWithNormalizedPaths = normalizeFilePathsInMetadataFile(previousIdentifierObject)

	# [INFO] Process each file in an input list
	{ identifierObject, newAndModifiedFilesList } = processFileList(
		inputFileList, identifierObjectWithNormalizedPaths, previousIdentifierTimestampValue
	)

	# [INFO] Overwrite an entire metadata in a metadata file
	saveEntireMetadataGeneratedInLastExecutionToFile(
		previousEntireMetadata, identifierFromGlobAndSubcommand,
		identifierObject, metadataFilePath
	)

	return newAndModifiedFilesList

module.exports = { getListOfUnwatchedNewAndModifiedFiles ###: Array ### }
