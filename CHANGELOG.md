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
