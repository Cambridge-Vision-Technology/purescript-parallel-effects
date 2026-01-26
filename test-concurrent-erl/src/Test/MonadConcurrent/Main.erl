%% FFI for Test.MonadConcurrent.Main

-module(test_monadConcurrent_main@foreign).

-export([erlangHalt/1, delayMsImpl/1, getTimeMsImpl/0]).

%% @doc Exit the Erlang VM with the specified exit code.
erlangHalt(Code) ->
    fun() ->
        erlang:halt(Code)
    end.

%% @doc Sleep for the specified number of milliseconds.
delayMsImpl(Ms) ->
    fun() ->
        timer:sleep(round(Ms)),
        unit
    end.

%% @doc Get the current monotonic time in milliseconds.
getTimeMsImpl() ->
    fun() ->
        erlang:monotonic_time(millisecond) * 1.0
    end.
