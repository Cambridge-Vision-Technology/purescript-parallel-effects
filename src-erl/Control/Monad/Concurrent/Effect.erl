-module(control_monad_concurrent_effect@foreign).

-export([
    toFiberConcurrentImpl/1,
    fromFiberConcurrentImpl/1
]).

%% Convert FiberErl to abstract Fiber type (identity)
toFiberConcurrentImpl(FiberErl) ->
    FiberErl.

%% Convert abstract Fiber type back to FiberErl (identity)
fromFiberConcurrentImpl(Fiber) ->
    Fiber.
