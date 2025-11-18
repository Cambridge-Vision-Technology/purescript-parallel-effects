# Feature: FileSystem operations are deterministic and sandboxed

## Scenario: write, read, delete within sandbox
Given a sandbox directory "out/test/fs/basic"

When I write file "hello.txt" with contents "hello-world"

And I read file "hello.txt"

Then the contents equals "hello-world"

When I delete file "hello.txt"

Then file "hello.txt" does not exist
