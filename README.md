## 1. Description

CLI utility to execute a command for each file matching a glob. Originally a fork of [**each-cli**](https://www.npmjs.com/package/each-cli), but then completely rewritten in order to provoke simplicity and eliminate annoying bugs. It differs from the original mainly by setting the CWD (current working directory) to the directory the foreach command was executed from, as opposed to the original package’s behavior which set the CWD to the matched file’s directory. It also takes the command arguments as strings to allow more complex commands such as piping.

## 2. Installation

```bash
npm install foreach-cli
```

## 3. Usage

**Command Line**

```shell
foreach --glob <glob> --execute <command to execute>
```

**Command Line Options**

```bash
-g, --glob        Specify the glob
-i, --ignore      Glob ignore pattern(s)
-x, --execute     Command to execute upon file addition/change
-c, --forceColor  Force color TTY output (pass --no-c to disable)
-t, --trim        Trims the output of the command executions to only show the first X characters of the output
-C, --concurrent  Execute commands concurrently (pass --no-C to disable)
-h                Show help
--version         Show version number
```

**Executing Command Placeholders**

```text
"path"  -  full path and filename
"root"  -  file root
"dir"   -  path without the filename
"reldir"-  directory name of file relative to the glob provided
"base"  -  file name and extension
"ext"   -  just file extension
"name"  -  just file name
```

**Examples**

```shell
foreach --glob "**/*.tar" --execute "tar xvf #{path}"
foreach --glob "*/*.jpg" --execute "convert #{path}.jpg #{dir}/#{name}.converted.png"
```

## 4. Options

### 4.1. `--watch`, `-w`

#### 4.1.1. Usage

foreach-cli with this option launches a subcommand solely for new and modified files since the last run of foreach-cli with the same identifier — the combination of glob template and subcommand. foreach-cli with the `--watch` unwatches files deleted since the last run and doesn’t launch a subcommand for them. foreach-cli with the `--watch` doesn’t watch files ignored through `--ignore` and `--ignore-from-file` options.

```shell
# [INFO] Using shx for launching UNIX commands cross-platform:
# https://github.com/shelljs/shx

# [STEP] Creating 2 files in an empty folder.
shx touch FirstFile.coffee SecondFile.coffee

# [STEP] Launching foreach-cli with the “--watch” argument first time.
foreach --execute "shx echo This is the file {{path}}" --glob "*.coffee" --watch

 √ Executing the subcommand for the file SecondFile.coffee
 √ Executing the subcommand for the file FirstFile.coffee


Output for the subcommand executed for the file SecondFile.coffee
This is the file SecondFile.coffee

Output for the subcommand executed for the file FirstFile.coffee
This is the file FirstFile.coffee

# [STEP] Launching the same foreach-cli command second time.
#
# [EXPECTED_BEHAVIOR] No output, because no new or modified files
# since the last run of foreach-cli with “--watch”.
foreach --execute "shx echo This is the file {{path}}" --glob "*.coffee" --watch

# [STEP] Modifying “FirstFile.coffee”
shx echo "# Example comment" >> FirstFile.coffee

# [STEP] Launching the same foreach command third time.
#
# [EXPECTED_BEHAVIOR] The subcommand must be launched solely for the “FirstFile.coffee”,
# because this file was modified, and “SecondFile.coffee” — no.
foreach --execute "shx echo This is the file {{path}}" --glob "*.coffee" --watch

 √ Executing the subcommand for the file FirstFile.coffee


Output for the subcommand executed for the file FirstFile.coffee
This is the file FirstFile.coffee

# [STEP] Deleting “FirstFile.coffee”.
shx rm FirstFile.coffee

# [STEP] Launching the same foreach command fourth time.
#
# [EXPECTED_BEHAVIOR] No output, because foreach-cli doesn’t launch commands for deleted and non-modified files.
# foreach-cli unwatches deleted files.
foreach --execute "shx echo This is the file {{path}}" --glob "*.coffee" --watch
```

#### 4.1.2. `.foreach-watch.json`

When a user launches foreach-cli with the `--watch` argument first time, foreach-cli creates the file `.foreach-watch.json` in the root directory of a project. foreach-cli updates it during subsequent launches with the option `--watch`. It’s recommended to add `.foreach-watch.json` to the ignore file of your VCS (like `.gitignore`, `.bzrignore` or `.hgignore`). The structure of the `.foreach-watch.json` after launching commands from the previous section:

```json
{
	"*.coffee::shx echo This is the file {{path}}": {
		"files": {
			"SecondFile.coffee": 1765195015991
		},
		"timestamp": 1765195296209
	}
}
```

#### 4.1.3. Execution recordings

foreach-cli with the `--watch` option watches identifiers — combinations of glob templates and subcommands. If a glob template and/or subcommand is different, foreach-cli watches files for a new identifier separately.

```shell
# [STEP] Creating a file in an empty folder.
shx touch ExampleFile.coffee

# [STEP] Launching foreach-cli with the first identifier.
foreach --execute "shx echo This is the file {{path}}" --glob "*.coffee" --watch

 √ Executing the subcommand for the file ExampleFile.coffee


Output for the subcommand executed for the file ExampleFile.coffee
This is the file ExampleFile.coffee

# [STEP] Launching foreach-cli with the second glob template and the first subcommand.
#
# [EXPECTED_BEHAVIOR] The subcommand should be launched for the file,
# because the glob template is different.
foreach --execute "shx echo This is the file {{path}}" --glob "**/*.coffee" --watch

 √ Executing the subcommand for the file ExampleFile.coffee


Output for the subcommand executed for the file ExampleFile.coffee
This is the file ExampleFile.coffee

# [STEP] Launching foreach-cli with the second glob template and the first subcommand second time.
#
# [EXPECTED_BEHAVIOR] No output, because no new or modified files
# since the last run of foreach-cli with this identifier.
foreach --execute "shx echo This is the file {{path}}" --glob "**/*.coffee" --watch

# [STEP] Launching foreach-cli with the second glob template and subcommand.
#
# [EXPECTED_BEHAVIOR] The subcommand must be launched for the file,
# because it differs from the previous subcommand.
foreach --execute "shx echo Output the filename {{path}} differently" --glob "**/*.coffee" --watch

 √ Executing the subcommand for the file ExampleFile.coffee


Output for the subcommand executed for the file ExampleFile.coffee
Output the filename ExampleFile.coffee differently

# [STEP] Launching foreach-cli with the second glob template and subcommand second time.
#
# [EXPECTED_BEHAVIOR] No output. Files weren’t created or modified since the last
# run of foreach-cli with this identifier.
foreach --execute "shx echo Output the filename {{path}} differently" --glob "**/*.coffee" --watch

# [STEP] Launching foreach-cli with the first glob template and subcommand second time.
#
# [EXPECTED_BEHAVIOR] No output. Since the first run of foreach-cli with this identifier
# files weren’t created or modified.
foreach --execute "shx echo This is the file {{path}}" --glob "*.coffee" --watch
```

`.foreach-watch.json` after launching commands above:

```json
{
	"*.coffee::shx echo This is the file {{path}}": {
		"files": {
			"ExampleFile.coffee": 1765199663614
		},
		"timestamp": 1765200226007
	},
	"**/*.coffee::shx echo This is the file {{path}}": {
		"files": {
			"ExampleFile.coffee": 1765199663614
		},
		"timestamp": 1765199778755
	},
	"**/*.coffee::shx echo Output the filename {{path}} differently": {
		"files": {
			"ExampleFile.coffee": 1765199663614
		},
		"timestamp": 1765200111577
	}
}
```

foreach-cli creates the unique identifiers for the each combination of glob template and subcommand in the file `.foreach-watch.json`.

#### 4.1.4. Sources

1. `lib/watch-handler.coffee` — the watch module.
1. `test/watch.test.coffee` — the end-to-end tests for the `--watch` and `--watch-file` command-line arguments.

### 4.2. `--watch-file`, `-W` (string)

Use this options solely with the `--watch` option.

Define the path to the file with the `--watch` recordings. Use this option if you need a different path and/or filename instead of default `.foreach-watch.json` in the root folder of your project.
