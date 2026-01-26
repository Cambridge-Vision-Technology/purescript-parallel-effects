%% FFI for Demo.Main.Erl (Erlang backend)
%%
%% Provides Erlang-specific operations for the demo CLI application:
%% - Command-line argument parsing (escript style)
%% - Timing operations (delay, get time)
%% - File I/O
%% - Process exit

-module(demo_main_erl@foreign).

-export([
    getArgv/0,
    delayMsImpl/1,
    getTimeMsImpl/0,
    writeFileImpl/2,
    erlangHalt/1,
    throwErrorImpl/1
]).

%% @doc Get command-line arguments (escript style).
%% Returns only the actual arguments, not the escript path.
%% Converts to Erlang array (purerl Array representation).
%% Skips the first argument which is the escript path.
getArgv() ->
    fun() ->
        AllArgs = init:get_plain_arguments(),
        Args =
            case AllArgs of
                [_EscriptPath | Rest] -> Rest;
                [] -> []
            end,
        BinaryArgs = [list_to_binary(Arg) || Arg <- Args],
        array:from_list(BinaryArgs)
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
        float(erlang:monotonic_time(millisecond))
    end.

%% @doc Write content to a file at the given path.
writeFileImpl(Path, Content) ->
    fun() ->
        PathStr = binary_to_list(Path),
        ok = filelib:ensure_dir(PathStr),
        ok = file:write_file(PathStr, Content),
        unit
    end.

%% @doc Exit the Erlang VM with the specified exit code.
erlangHalt(Code) ->
    fun() ->
        erlang:halt(Code)
    end.

%% @doc Throw an error with the given message.
throwErrorImpl(Msg) ->
    fun() ->
        erlang:error({error, Msg})
    end.
