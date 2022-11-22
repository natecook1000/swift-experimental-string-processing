# Understanding Regex Captures

Regex literals allow compile-time recognition of capture groups and their types. 

## Overview

Re: https://github.com/apple/swift-evolution/blob/main/proposals/0354-regex-literals.md

Every regex has an output type
If the regex has no capture groups, the output type is `Substring`, representing the whole match.
If the regex has one or more capture groups, the output type is a tuple, with the first component a `Substring` representing the whole match.

### Capture Groups

One `Substring` for each capture group
Capture groups are counted by their opening parenthesis
Capture groups that appear within optional-making things are `Substring?`
- repetition
- alternation
Repetition or alternation within a capture group does not make it optional

### Named Capture Groups

Capture groups that are given a name include the name in the output tuple type
Option for only capturing named groups

### Dynamic Output

Regexes created from a string have a dynamic output type
You can convert to a strongly-typed output type by passing the output that would have been given if compiled


