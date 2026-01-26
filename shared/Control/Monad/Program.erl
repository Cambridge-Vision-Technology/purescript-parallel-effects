%% FFI for Control.Monad.Program (Erlang backend)
%%
%% This module provides pattern matching on FreeAp structures for the Erlang
%% backend. FreeAp has three constructors: Pure, Lift, and Ap.
%%
%% NOTE: This is FFI code that necessarily contains logic to inspect the
%% internal structure of FreeAp values. This is unavoidable because FreeAp
%% from purescript-freeap does not export its constructors or provide a
%% pattern matching function.
%%
%% The Erlang representation of PureScript ADTs uses tagged tuples:
%%   - {pure, Value}                : Pure value
%%   - {lift, FunctorValue}         : Lifted effect
%%   - {ap, FreeApFunc, FreeApArg}  : Applicative composition

-module(control_monad_program@foreign).
-export([matchFreeApView/4]).

%% @doc Pattern match on FreeAp structure using continuation-passing style.
%%
%% Takes three callbacks:
%%   - OnPure: Called with the pure value for Pure nodes
%%   - OnLift: Called with the lifted functor value for Lift nodes
%%   - OnAp: Called with both FreeAp arguments for Ap nodes
%%
%% Returns the result of calling the appropriate callback.
matchFreeApView(OnPure, OnLift, OnAp, FreeAp) ->
    case FreeAp of
        {pure, Value} ->
            OnPure(Value);
        {lift, FunctorValue} ->
            OnLift(FunctorValue);
        {ap, FreeApFunc, FreeApArg} ->
            (OnAp(FreeApFunc))(FreeApArg);
        _ ->
            %% Should never happen - defensive error for debugging
            erlang:error({unknown_freeap_constructor, FreeAp})
    end.
