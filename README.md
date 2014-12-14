Exrun
=====

Version: 0.0.1

Something, like advanced runtime_tools for elixir.

There is another great tool [dbg](https://github.com/fishcakez/dbg), which is based on erlang [dbg](http://erlang.org/doc/man/dbg.html). Why another debugging tool? At first, the tracing setter is implemented as macro, because it allows to use native elixir macro capabilites to capture call in natural syntax (with arguments and conditions, see more examples and tests). Second is, safity, the tracer comes with possibility to ratelimit tracer with absolut and relative to a time values. Another difference, is, that in some cases your will need to debug
different functions on different nodes, that why `Tracer` build, that it is possible to trace different functions on different nodes.

## Example

```elixir
iex(1)> import Tracer
nil
iex(2)> trace :lists.seq(a, b) when a < 1 and b > 100, node: my_remote_node, limit: %{rate: 1000, time: 1000}
{:ok, 2}
```

More documentation you should refer

```elixir
iex(1)> h Tracer.trace
```

## Feature Roadmap
- Tracer
  - Pattern setter
    - [x] set trace all functions in a module
    - [x] set trace all module.function with any arity
    - [x] module.function/arity
    - [x] set trace for module.function(args...)
    - [x] set trace module.function(args...) when conditions
    - [ ] set trace for send/recive
    - [x] macro to set trace
    - [ ] unsetting of traces
  - Printer
    - [x] format stacktrace
  - Distributed
    - [x] distributed tracing
    - [x] erlang distributed transport
    - [ ] enviroments-based configuration (for easily multinode setup)
    - [x] io output
    - [ ] tcp transport
    - [ ] trace to tcp
    - [ ] handle tcp traces
    - [ ] trace to file
    - [ ] possibility to implement own transportes(like zeromq)
  - [ ] time feature  (Example, every 1 minute should be time printed or trace messages with, for correlation with other logs and so on)
  - [x] overflow protection as an option
  - CLI
    - [ ] basic command line interface to invoke preconfigured tracer
    - [ ] tracer outputs
    - [ ] define trace nodes from CLI
    - [ ] define tracing patterns from CLI
    - [ ] define how should it be transported (erlang, tcp, custom)
