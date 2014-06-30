Exrun
=====

[WiP] Do not use it. As the interface to the functionallity is not implemented.

Something, like advanced runtime_tools for elixir.

It is a subset replacement for dbg for elixir (not a replacment at al), that should be as an dbg distributed over nodes, but with
overload protection, with possibility to add custom transporters. Very flexible macro-based tracers.

## Feature Roadmap
- Tracer
  - Pattern setter
    - [x] set trace all functions in a module
    - [x] set trace all module.function with any arity
    - [x] module.function/arity
    - [x] set trace for module.function(args...)
    - [x] set trace module.function(args...) when conditions
    - [ ] set trace for send/recive
    - [ ] macro to set trace and start application
  - Printer
    - [x] format stacktrace
  - Distributed
    - [ ] defining a nodes, where should be traced
    - [ ] enviroments-based configuration (for easily multinode setup)
    - [ ] erlang distributed transport
    - [x] io output
    - [ ] tcp transport
    - [ ] trace to tcp
    - [ ] handle tcp traces
    - [ ] trace to file
    - [ ] possibility to implement own transportes(like zeromq)
  - [ ] time feature  (Example, every 1 minute should be time printed or trace messages with, for correlation with other logs and so on)
  - [ ] tracer collector options
  - [ ] overflow protection as an option
  - CLI
    - [ ] basic command line interface to invoke preconfigured tracer
    - [ ] tracer outputs
    - [ ] define trace nodes from CLI
    - [ ] define tracing patterns from CLI
    - [ ] define how should it be transported (erlang, tcp, custom)
