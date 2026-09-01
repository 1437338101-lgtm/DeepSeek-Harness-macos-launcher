# Security

## Scope

DSH Launcher only starts a separately installed DeepSeek Harness Web profile
on the loopback interface and opens its local URL. It does not collect,
transmit, proxy, or store model credentials.

DeepSeek Harness is experimental developer-preview software that can execute
model-generated commands and modify files available to it. Read the upstream
safety guidance before use:

https://github.com/deepseek-ai/deepseek-harness/blob/master/SAFETY.md

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could expose credentials,
execute code unexpectedly, or compromise a host. Use GitHub's private security
advisory feature for this repository. Upstream Harness vulnerabilities should
be reported through the upstream project's documented security channel.

## Design constraints

- The Web server binds to `127.0.0.1` only.
- PID ownership is verified against the DSH command before a process is reused
  or stopped.
- The launcher never reads files from `~/.dsh`.
- Logs and PID state remain outside the application bundle in the current
  user's standard Library directories.
