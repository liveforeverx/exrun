Exrun
=====

Version: 0.1.0

Something, like advanced runtime_tools for elixir.

Why another debugging tool? At first, the tracing setter is implemented as macro, because it allows
to use native elixir macro capabilities to capture call in natural syntax (with arguments and
conditions, see more examples and tests). Write tracing, as you write Elixir code.

Second is, safety, the tracer comes with possibility to ratelimit tracer with absolute and relative
to time values. Default configuration is to disable tracing with a output rate more, than 250 messages
in a second.

Another difference, is, that in some cases your will need to debug, different functions on different
nodes, that it is possible to trace different functions on different nodes.

Additionally it prints time and how long the function took to execute (to analyse time consuming
functions additionally).

Via erlang distributed you can use even `exrun` on production nodes, which doesn't have `exrun`
installed. So if you need to trace something, you can attach it to any Elixir or even Erlang running
system.

Setup project and app dependency in your mix.exs:

```elixir
{:exrun, "~> 0.2.0"}
```

With remsh ( and with CLI in future ) it possible to trace nodes, where elixir or exrun are not installed, as it build to
remote check and load modules needed (with option `formatter_local: false` only 2 modules) to trace the needed machine.

## Example

```elixir
iex(1)> use Tracer, node: my_remote_node, limit: %{rate: 1000, time: 1000}
nil
iex(2)> trace :lists.seq(a, b) when a < 1 and b > 100
{:ok, 2}
iex(3)> :lists.seq(0, 110)
#PID<0.68.0> [17:35:23.118] call :lists.seq(0, 110)
#PID<0.68.0> [3] returned :lists.seq/2 -> [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, ...]
iex(4)> trace :erlang.make_tuple, [:stack]
{:ok, 2}
iex(5)> Tuple.duplicate(:hello, 3)
{:hello, :hello, :hello}
#PID<0.68.0> call :erlang.make_tuple(3, :hello)
  erl_eval.do_apply/6
  elixir.erl_eval/3
  elixir.eval_forms/4
  IEx.Evaluator.handle_eval/4
  IEx.Evaluator.eval/2
  IEx.Evaluator.loop/1
  IEx.Evaluator.start/2
#PID<0.68.0> returned :erlang.make_tuple/2 -> {:hello, :hello, :hello}
```

More documentation you should refer

```elixir
iex(1)> h Tracer
iex(2)> h Tracer.trace
```

## Feature Roadmap
- Tracer
  - Pattern setter
    - [x] set trace all functions in a module
    - [x] set trace all module.function with any arity
    - [x] module.function/arity
    - [x] set trace for module.function(args...)
    - [x] set trace module.function(args...) when conditions
    - [ ] set trace for send/receive
    - [x] macro to set trace
    - [ ] unsetting of traces
  - Printer
    - [x] format stacktrace
    - [x] custom formatter
    - [x] possibility to add timestamp to default formatter
    - [x] possibility to pass inspect options
  - Distributed
    - [x] distributed tracing
    - [x] erlang distributed transport
    - [ ] environments-based configuration (for easily multinode setup)
    - [x] io output with file shortcut
    - [x] possibility to implement own transports(like file, tcp, zeromq), use formatters
  - [x] time feature  (Example, every 1 minute should be time printed or trace messages with, for correlation with other logs and so on)
  - [x] overflow protection as an option
  - CLI
    - [ ] basic command line interface
    - [ ] tracer outputs
    - [ ] define trace nodes from CLI
    - [ ] define tracing patterns from CLI
    - [ ] define how should it be transported (erlang, tcp, custom)

## License

   Copyright 2015 Dmitry Russ

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
