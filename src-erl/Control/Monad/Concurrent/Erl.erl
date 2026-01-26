%% FFI for Control.Monad.Concurrent.Erl
%%
%% NOTE: This module requires the purerl backend to compile and run.
%% All logic is in PureScript - these are thin stubs only.

-module(control_monad_concurrent_erl@foreign).

-export([
    spawnMonitorImpl/1,
    receiveDownImpl/1,
    exitProcessImpl/1,
    tupleSize/1,
    tupleElement/2,
    atomEqualsIfAtom/2,
    atomToString/1,
    stringToAtom/1,
    formatTerm/1,
    toFiber/1,
    fromFiber/1
]).

spawnMonitorImpl(Thunk) -> fun() -> do_spawn_monitor(Thunk) end.

do_spawn_monitor(Thunk) ->
    {Pid, Ref} = erlang:spawn_monitor(spawn_wrapper(Thunk)),
    #{pid => Pid, monitorRef => Ref}.

spawn_wrapper(Thunk) -> fun() -> run_with_catch(Thunk) end.

run_with_catch(Thunk) ->
    try Thunk() of
        Result -> exit({ok, Result})
    catch
        Class:E:S -> exit({error, Class, E, S})
    end.

receiveDownImpl(Fiber) -> fun() -> do_receive_down(Fiber) end.

do_receive_down(#{pid := Pid, monitorRef := Ref}) ->
    receive
        {'DOWN', Ref, process, Pid, Reason} -> Reason
    end.

exitProcessImpl(Fiber) -> fun() -> do_exit_process(Fiber) end.

do_exit_process(#{pid := Pid}) ->
    erlang:exit(Pid, kill),
    unit.

tupleSize(T) when is_tuple(T) -> tuple_size(T);
tupleSize(_) -> 0.

tupleElement(N, T) -> element(N, T).

atomEqualsIfAtom(Reason, Atom) when is_atom(Reason) -> Reason =:= Atom;
atomEqualsIfAtom(_, _) -> false.

atomToString(A) -> atom_to_binary(A, utf8).

stringToAtom(S) -> binary_to_atom(S, utf8).

formatTerm(T) -> iolist_to_binary(io_lib:format("~p", [T])).

toFiber(FiberErl) -> FiberErl.

fromFiber(Fiber) -> Fiber.
