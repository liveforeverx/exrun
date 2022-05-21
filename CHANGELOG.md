# 0.2.0

This has backwards-incompatible changes.

The `trace` was splitted to `use Tracer`, which starts and configure tracer and `trace` macro,
which actually set tracer and pattern.

* Enhancements
  * redesign the start and trace to be used with `use Tracer` and `trace`
  * redesign, how `:io` works and add option `:file` for easier file tracing
  * add `unlink` option for file and network tracing
  * do not crash on tracing non-existing module
  * by starting of tracer reports if there was already one running or new one started

# 0.1.7

* Enhancements
  * add `limit: number` as shortcut for `limit: %{overall: number}`
  * update collector to work again in Erlang nodes without Elixir
  * add `pid` option to trace specific processes
  * add possibility to write traces to file, via `io` option
  * print locally, when tracer reached limit and flush remaining messages before stoping processes

# 0.1.7

* Bug fixes
  * remove bug in `Runner.processes`

* Enhancements
  * add `Runner.tabs` function for tables size introspection
  * add formatted datetime to tracing calls
  * make default limit higher
  * trace_off doesn't crash, if tracer is already stoped

# 0.1.6

* Enhancements
  * remove warnings for elixir v1.6
  * add `Runtime` introspection module with some basic functions for inspection
    ** util allocators
    ** memory usage of processors
    ** scheduler usage
  * output format for `:stack` option changed, now erlang modules has `:` as in shell

# 0.1.5

* Enhancements
  * remove warnings for elixir v1.4

# 0.1.4

* Bug fixes
  * set collector state correct for using with dump

# 0.1.3

* Enhancements
  * print time used for function call

# 0.1.2

* Enhancements
  * add sheduler usage calculation

# 0.1.1

* Bug fixes
  * do not replace _ with existing variable, it should be `ignored` variable

# 0.1.0

First release!
